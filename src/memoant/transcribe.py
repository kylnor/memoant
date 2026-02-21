"""MLX-Whisper transcription wrapper."""

import mlx_whisper

from .config import WHISPER_MODEL


def transcribe(wav_path: str, language: str = "en") -> dict:
    """Transcribe a WAV file using mlx-whisper.

    Returns dict with:
        - "text": full transcript string
        - "segments": list of segment dicts with timestamps
        - "words": list of word-level dicts (if available)
    """
    result = mlx_whisper.transcribe(
        wav_path,
        path_or_hf_repo=WHISPER_MODEL,
        language=language,
        word_timestamps=True,
        condition_on_previous_text=True,
    )

    # Extract word-level timestamps from segments
    words = []
    for seg in result.get("segments", []):
        for w in seg.get("words", []):
            words.append({
                "word": w["word"].strip(),
                "start": w["start"],
                "end": w["end"],
            })

    return {
        "text": result.get("text", "").strip(),
        "segments": result.get("segments", []),
        "words": words,
    }


def transcribe_chunk(wav_path: str, start: float, end: float, language: str = "en") -> dict:
    """Transcribe a specific time range of a WAV file.

    Uses ffmpeg to extract the chunk first, then transcribes.
    """
    import subprocess
    import tempfile

    from .config import AUDIO_SAMPLE_RATE, TMP_DIR

    chunk_path = tempfile.mktemp(suffix=".wav", dir=TMP_DIR)
    cmd = [
        "ffmpeg", "-y",
        "-i", wav_path,
        "-ss", str(start),
        "-to", str(end),
        "-ar", str(AUDIO_SAMPLE_RATE),
        "-ac", "1",
        "-c:a", "pcm_s16le",
        chunk_path,
    ]
    subprocess.run(cmd, capture_output=True, text=True, timeout=60)

    try:
        result = transcribe(chunk_path, language)
        # Offset timestamps back to absolute positions
        for w in result["words"]:
            w["start"] += start
            w["end"] += start
        for seg in result["segments"]:
            seg["start"] += start
            seg["end"] += start
        return result
    finally:
        import os
        os.unlink(chunk_path)
