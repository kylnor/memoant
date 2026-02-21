"""Split long audio files into chunks at silence boundaries."""

from .config import MAX_CHUNK_SECONDS, MIN_SILENCE_MS


def find_silence_gaps(speech_segments: list[dict], min_gap_ms: int = MIN_SILENCE_MS) -> list[dict]:
    """Find gaps between speech segments that are at least min_gap_ms long.

    Returns list of {"start": float, "end": float, "duration_ms": float}
    """
    gaps = []
    for i in range(len(speech_segments) - 1):
        gap_start = speech_segments[i]["end"]
        gap_end = speech_segments[i + 1]["start"]
        gap_ms = (gap_end - gap_start) * 1000
        if gap_ms >= min_gap_ms:
            gaps.append({
                "start": gap_start,
                "end": gap_end,
                "duration_ms": gap_ms,
            })
    return gaps


def plan_chunks(
    total_duration: float,
    silence_gaps: list[dict],
    max_chunk_seconds: int = MAX_CHUNK_SECONDS,
) -> list[dict]:
    """Plan chunk boundaries at silence gaps, targeting max_chunk_seconds per chunk.

    Returns list of {"start": float, "end": float} for each chunk.
    If total_duration <= max_chunk_seconds, returns a single chunk.
    """
    if total_duration <= max_chunk_seconds:
        return [{"start": 0.0, "end": total_duration}]

    chunks = []
    chunk_start = 0.0
    target_end = max_chunk_seconds

    while chunk_start < total_duration:
        if target_end >= total_duration:
            chunks.append({"start": chunk_start, "end": total_duration})
            break

        # Find the silence gap closest to our target boundary
        best_gap = None
        best_distance = float("inf")
        for gap in silence_gaps:
            mid = (gap["start"] + gap["end"]) / 2
            if mid <= chunk_start:
                continue
            distance = abs(mid - target_end)
            if distance < best_distance:
                best_distance = distance
                best_gap = gap

        if best_gap and best_distance < max_chunk_seconds * 0.3:
            split_point = (best_gap["start"] + best_gap["end"]) / 2
            chunks.append({"start": chunk_start, "end": split_point})
            chunk_start = split_point
        else:
            chunks.append({"start": chunk_start, "end": target_end})
            chunk_start = target_end

        target_end = chunk_start + max_chunk_seconds

    return chunks
