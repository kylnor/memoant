"""Merge transcription words with speaker diarization labels."""


def assign_speakers(words: list[dict], diarization_segments: list[dict]) -> list[dict]:
    """Assign speaker labels to transcribed words using majority vote.

    For each word, find which diarization segment(s) overlap with it,
    and assign the speaker that covers the most of the word's duration.
    """
    for word in words:
        w_start = word["start"]
        w_end = word["end"]
        w_duration = w_end - w_start

        if w_duration <= 0:
            word["speaker"] = "UNKNOWN"
            continue

        speaker_overlap = {}
        for seg in diarization_segments:
            overlap_start = max(w_start, seg["start"])
            overlap_end = min(w_end, seg["end"])
            overlap = overlap_end - overlap_start

            if overlap > 0:
                speaker = seg["speaker"]
                speaker_overlap[speaker] = speaker_overlap.get(speaker, 0) + overlap

        if speaker_overlap:
            word["speaker"] = max(speaker_overlap, key=speaker_overlap.get)
        else:
            word["speaker"] = "UNKNOWN"

    return words


def build_speaker_transcript(words: list[dict]) -> str:
    """Build a speaker-attributed transcript from labeled words.

    Groups consecutive words by the same speaker into turns.
    """
    if not words:
        return ""

    lines = []
    current_speaker = None
    current_words = []

    for word in words:
        speaker = word.get("speaker", "UNKNOWN")
        if speaker != current_speaker:
            if current_words:
                text = " ".join(w["word"] for w in current_words)
                lines.append(f"{current_speaker}: {text}")
            current_speaker = speaker
            current_words = [word]
        else:
            current_words.append(word)

    if current_words:
        text = " ".join(w["word"] for w in current_words)
        lines.append(f"{current_speaker}: {text}")

    return "\n".join(lines)


def build_segments(words: list[dict]) -> list[dict]:
    """Build conversation segments from labeled words.

    Each segment represents a continuous speaker turn with timestamps.
    Returns: [{"speaker": str, "start": float, "end": float, "text": str}]
    """
    if not words:
        return []

    segments = []
    current_speaker = None
    current_words = []
    seg_start = 0.0

    for word in words:
        speaker = word.get("speaker", "UNKNOWN")
        if speaker != current_speaker:
            if current_words:
                text = " ".join(w["word"] for w in current_words)
                segments.append({
                    "speaker": current_speaker,
                    "start": seg_start,
                    "end": current_words[-1]["end"],
                    "text": text,
                })
            current_speaker = speaker
            current_words = [word]
            seg_start = word["start"]
        else:
            current_words.append(word)

    if current_words:
        text = " ".join(w["word"] for w in current_words)
        segments.append({
            "speaker": current_speaker,
            "start": seg_start,
            "end": current_words[-1]["end"],
            "text": text,
        })

    return segments
