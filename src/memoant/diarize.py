"""Speaker diarization using pyannote.audio."""

import os

from dotenv import load_dotenv

load_dotenv(os.path.expanduser("~/.env"))


def get_pipeline():
    """Load pyannote speaker diarization pipeline.

    Requires HUGGINGFACE_TOKEN in ~/.env and accepted model licenses at:
    - huggingface.co/pyannote/segmentation-3.0
    - huggingface.co/pyannote/speaker-diarization-3.1
    """
    import torch
    from pyannote.audio import Pipeline

    token = os.environ.get("HUGGINGFACE_TOKEN")
    if not token:
        raise RuntimeError(
            "HUGGINGFACE_TOKEN not found in ~/.env. "
            "Get one at huggingface.co/settings/tokens"
        )

    pipeline = Pipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1",
        use_auth_token=token,
    )

    if torch.backends.mps.is_available():
        pipeline.to(torch.device("mps"))

    return pipeline


def diarize(wav_path: str, pipeline=None) -> list[dict]:
    """Run speaker diarization on a WAV file.

    Returns list of speaker segments:
        [{"start": float, "end": float, "speaker": "SPEAKER_00"}, ...]
    """
    if pipeline is None:
        pipeline = get_pipeline()

    diarization = pipeline(wav_path)

    segments = []
    for turn, _, speaker in diarization.itertracks(yield_label=True):
        segments.append({
            "start": turn.start,
            "end": turn.end,
            "speaker": speaker,
        })

    return segments


def get_speaker_labels(segments: list[dict]) -> list[str]:
    """Extract unique speaker labels from diarization segments."""
    return sorted(set(s["speaker"] for s in segments))
