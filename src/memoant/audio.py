"""Audio conversion (ffmpeg) and voice activity detection (silero VAD)."""

import subprocess
import tempfile

import torch

from .config import AUDIO_SAMPLE_RATE, SILENCE_THRESHOLD, TMP_DIR


def convert_to_wav(input_path: str, output_path: str = None) -> str:
    """Convert any audio/video file to WAV 16kHz mono using ffmpeg.

    Returns path to the WAV file.
    """
    if output_path is None:
        output_path = tempfile.mktemp(suffix=".wav", dir=TMP_DIR)

    cmd = [
        "ffmpeg", "-y",
        "-i", input_path,
        "-ar", str(AUDIO_SAMPLE_RATE),
        "-ac", "1",
        "-c:a", "pcm_s16le",
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr[:500]}")
    return output_path


def get_duration(file_path: str) -> float:
    """Get audio duration in seconds using ffprobe."""
    cmd = [
        "ffprobe",
        "-v", "quiet",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        file_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"ffprobe failed: {result.stderr[:500]}")
    return float(result.stdout.strip())


def detect_speech_segments(wav_path: str) -> list[dict]:
    """Run silero VAD on a WAV file. Returns list of speech segments.

    Each segment: {"start": float_seconds, "end": float_seconds}
    """
    model, utils = torch.hub.load(
        repo_or_dir="snakers4/silero-vad",
        model="silero_vad",
        trust_repo=True,
    )
    (get_speech_timestamps, _, read_audio, _, _) = utils

    wav = read_audio(wav_path, sampling_rate=AUDIO_SAMPLE_RATE)
    speech_timestamps = get_speech_timestamps(
        wav,
        model,
        sampling_rate=AUDIO_SAMPLE_RATE,
        threshold=SILENCE_THRESHOLD,
        return_seconds=True,
    )

    return [{"start": ts["start"], "end": ts["end"]} for ts in speech_timestamps]


def total_speech_duration(segments: list[dict]) -> float:
    """Sum the duration of all speech segments."""
    return sum(s["end"] - s["start"] for s in segments)
