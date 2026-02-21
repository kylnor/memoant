"""Full processing pipeline: audio file -> Oracle DB record + Obsidian note."""

import hashlib
import os
import shutil
import time
from datetime import datetime, timezone

from . import audio, chunker, db, merge, structure
from .calendar_match import find_overlapping_event
from .config import ARCHIVE_DIR, NOTES_DIR, ORACLE_DB, TMP_DIR, ensure_dirs
from .markdown import generate_note


def file_hash(path: str) -> str:
    """SHA256 hash of file contents (dedup key)."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def get_recorded_at(path: str) -> str:
    """Extract recording timestamp from file metadata or mtime.

    Tries file creation time first, falls back to modification time.
    Returns ISO 8601 string.
    """
    stat = os.stat(path)
    # On macOS, st_birthtime is the creation time
    ts = getattr(stat, "st_birthtime", None) or stat.st_mtime
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def process_file(
    input_path: str,
    db_path: str = ORACLE_DB,
    notes_dir: str = NOTES_DIR,
    skip_diarization: bool = False,
    force: bool = False,
    mode: str = "auto",
) -> dict:
    """Process a single audio file through the full pipeline.

    Args:
        input_path: path to audio file (.m4a, .wav, etc.)
        db_path: path to oracle.db
        notes_dir: directory for Obsidian markdown output
        skip_diarization: skip speaker diarization (faster, single-speaker)
        force: reprocess even if file_id exists in DB
        mode: auto | meeting | dictation (hints for structuring)

    Returns:
        dict with processing results and stats
    """
    ensure_dirs()
    start_time = time.time()
    print(f"\n{'=' * 60}")
    print(f"Processing: {os.path.basename(input_path)}")

    # Step 1: Hash for dedup
    fid = file_hash(input_path)
    print(f"  file_id: {fid[:16]}...")

    database = db.open_db(db_path)
    db.ensure_schema(database)

    if not force and db.file_exists(database, fid):
        print("  SKIP: already processed")
        database.close()
        return {"status": "skipped", "file_id": fid}

    source_file = os.path.basename(input_path)
    source_path = os.path.abspath(input_path)
    recorded_at = get_recorded_at(input_path)

    # Step 2: Convert to WAV
    print("  Converting to WAV...")
    wav_path = audio.convert_to_wav(input_path)
    duration = audio.get_duration(wav_path)
    print(f"  Duration: {duration:.1f}s ({duration/60:.1f}m)")

    # Step 3: VAD
    print("  Running VAD...")
    speech_segments = audio.detect_speech_segments(wav_path)
    speech_duration = audio.total_speech_duration(speech_segments)
    print(f"  Speech: {speech_duration:.1f}s ({len(speech_segments)} segments)")

    if speech_duration < 1.0:
        print("  SKIP: less than 1 second of speech detected")
        _cleanup(wav_path)
        database.close()
        return {"status": "no_speech", "file_id": fid, "duration": duration}

    # Step 4: Plan chunks (if needed)
    silence_gaps = chunker.find_silence_gaps(speech_segments)
    chunks = chunker.plan_chunks(duration, silence_gaps)
    print(f"  Chunks: {len(chunks)}")

    # Step 5: Transcribe
    print("  Transcribing...")
    if len(chunks) == 1:
        from .transcribe import transcribe
        transcript_result = transcribe(wav_path)
    else:
        from .transcribe import transcribe_chunk
        all_text = []
        all_words = []
        all_segments = []
        for i, chunk in enumerate(chunks):
            print(f"    Chunk {i+1}/{len(chunks)}: {chunk['start']:.0f}s - {chunk['end']:.0f}s")
            result = transcribe_chunk(wav_path, chunk["start"], chunk["end"])
            all_text.append(result["text"])
            all_words.extend(result["words"])
            all_segments.extend(result["segments"])
        transcript_result = {
            "text": " ".join(all_text),
            "words": all_words,
            "segments": all_segments,
        }

    plain_text = transcript_result["text"]
    words = transcript_result["words"]
    word_count = len(plain_text.split())
    print(f"  Words: {word_count}")

    # Step 6: Diarization (optional)
    # In dictation mode or short recordings, skip diarization
    should_diarize = (
        not skip_diarization
        and duration > 10
        and mode != "dictation"
    )

    speaker_count = 1
    speakers = []
    speaker_transcript = plain_text
    conversation_segments = []

    if should_diarize:
        print("  Diarizing...")
        try:
            from .diarize import diarize, get_speaker_labels
            diarization_segments = diarize(wav_path)
            speakers = get_speaker_labels(diarization_segments)
            speaker_count = len(speakers)
            print(f"  Speakers: {speaker_count} ({', '.join(speakers)})")

            # Step 7: Merge words + speakers
            if words and diarization_segments:
                labeled_words = merge.assign_speakers(words, diarization_segments)
                speaker_transcript = merge.build_speaker_transcript(labeled_words)
                conversation_segments = merge.build_segments(labeled_words)
        except Exception as e:
            print(f"  Diarization failed (proceeding without): {e}")
    else:
        # Single speaker, build simple segments
        conversation_segments = [{
            "speaker": "SPEAKER_00",
            "start": 0.0,
            "end": duration,
            "text": plain_text,
        }]

    # Step 8: LLM structuring
    print("  Extracting structure (Ollama)...")
    structured = structure.extract_structure(
        speaker_transcript if speaker_transcript else plain_text
    )

    llm_error = structured.pop("error", None)
    llm_tokens = structured.pop("_tokens", 0)
    llm_duration = structured.pop("_duration", 0)
    if llm_error:
        print(f"  LLM warning: {llm_error}")
    else:
        print(f"  Summary: {(structured.get('summary') or '')[:80]}...")
        print(f"  Sphere: {structured.get('sphere')}, Type: {structured.get('conversation_type')}")

    # Override conversation_type if mode was explicitly set
    if mode == "meeting":
        structured["conversation_type"] = "meeting"
    elif mode == "dictation":
        structured["conversation_type"] = "dictation"

    # Step 9: Calendar match
    cal_match = find_overlapping_event(recorded_at, duration, db_path)
    cal_event_id = None
    cal_event_title = None
    if cal_match:
        cal_event_id = cal_match["event_id"]
        cal_event_title = cal_match["title"]
        print(f"  Calendar match: {cal_event_title}")

    # Step 10: Write to DB
    processing_time = time.time() - start_time
    record = {
        "file_id": fid,
        "source_file": source_file,
        "source_path": source_path,
        "recorded_at": recorded_at,
        "duration_seconds": duration,
        "processed_at": datetime.now(tz=timezone.utc).isoformat(),
        "transcript": speaker_transcript,
        "transcript_plain": plain_text,
        "word_count": word_count,
        "speaker_count": speaker_count,
        "speakers": speakers if speakers else None,
        "segments": conversation_segments,
        "summary": structured.get("summary"),
        "topics": structured.get("topics"),
        "action_items": structured.get("action_items"),
        "decisions": structured.get("decisions"),
        "entities": structured.get("entities"),
        "key_quotes": structured.get("key_quotes"),
        "sphere": structured.get("sphere"),
        "tags": structured.get("tags"),
        "sentiment": structured.get("sentiment"),
        "conversation_type": structured.get("conversation_type"),
        "calendar_event_id": cal_event_id,
        "calendar_event_title": cal_event_title,
        "processing_time_seconds": processing_time,
        "error": llm_error,
    }

    print("  Writing to Oracle DB...")
    db.write_audio_log(database, record)
    database.close()

    # Step 11: Generate Obsidian note
    print("  Generating Obsidian note...")
    note_path = generate_note(record, notes_dir)
    print(f"  Note: {note_path}")

    # Step 12: Archive
    archive_path = os.path.join(ARCHIVE_DIR, source_file)
    if not os.path.exists(archive_path):
        shutil.copy2(input_path, archive_path)
        print(f"  Archived: {archive_path}")

    # Cleanup
    _cleanup(wav_path)

    print(f"  Done in {processing_time:.1f}s")
    print(f"{'=' * 60}")

    return {
        "status": "processed",
        "file_id": fid,
        "duration": duration,
        "word_count": word_count,
        "speaker_count": speaker_count,
        "sphere": structured.get("sphere"),
        "conversation_type": structured.get("conversation_type"),
        "summary": structured.get("summary"),
        "note_path": note_path,
        "processing_time": processing_time,
    }


def _cleanup(wav_path: str):
    """Remove temporary WAV file."""
    try:
        if os.path.exists(wav_path) and TMP_DIR in wav_path:
            os.unlink(wav_path)
    except OSError:
        pass
