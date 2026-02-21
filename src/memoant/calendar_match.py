"""Cross-reference audio recordings with Oracle calendar events."""

import sqlite3

from .config import ORACLE_DB


def find_overlapping_event(
    recorded_at: str,
    duration_seconds: float,
    db_path: str = ORACLE_DB,
) -> dict | None:
    """Find a calendar event that overlaps with the recording time window.

    Args:
        recorded_at: ISO 8601 timestamp of recording start
        duration_seconds: recording length in seconds
        db_path: path to oracle.db

    Returns:
        dict with "event_id" and "title", or None if no match
    """
    db = sqlite3.connect(db_path)
    db.execute("PRAGMA journal_mode=WAL")

    try:
        row = db.execute(
            """
            SELECT google_id, title
            FROM os_calendar_events
            WHERE start_time <= datetime(:recorded_at, '+' || :duration || ' seconds')
              AND end_time >= :recorded_at
            ORDER BY start_time DESC
            LIMIT 1
            """,
            {"recorded_at": recorded_at, "duration": int(duration_seconds)},
        ).fetchone()

        if row:
            return {"event_id": row[0], "title": row[1]}
        return None

    finally:
        db.close()
