"""Oracle DB writer for audio logs. Follows SQLiteIndexer conventions."""

import json
import sqlite3

from .config import ORACLE_DB

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS os_audio_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id TEXT UNIQUE NOT NULL,
    source_file TEXT NOT NULL,
    source_path TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    duration_seconds REAL NOT NULL,
    processed_at TEXT NOT NULL,
    transcript TEXT NOT NULL,
    transcript_plain TEXT NOT NULL,
    word_count INTEGER NOT NULL,
    speaker_count INTEGER DEFAULT 1,
    speakers TEXT,
    segments TEXT NOT NULL,
    summary TEXT,
    topics TEXT,
    action_items TEXT,
    decisions TEXT,
    entities TEXT,
    key_quotes TEXT,
    sphere TEXT,
    tags TEXT,
    sentiment TEXT,
    conversation_type TEXT,
    calendar_event_id TEXT,
    calendar_event_title TEXT,
    processing_time_seconds REAL,
    model_whisper TEXT DEFAULT 'large-v3-turbo',
    model_llm TEXT DEFAULT 'llama3.1:8b',
    error TEXT
);
"""

INDEX_SQL = [
    "CREATE INDEX IF NOT EXISTS idx_audio_recorded_at ON os_audio_logs(recorded_at);",
    "CREATE INDEX IF NOT EXISTS idx_audio_sphere ON os_audio_logs(sphere);",
    "CREATE INDEX IF NOT EXISTS idx_audio_type ON os_audio_logs(conversation_type);",
]


def _json(val):
    """Serialize value to JSON string, or None."""
    if val is None:
        return None
    if isinstance(val, str):
        return val
    return json.dumps(val, ensure_ascii=False)


def open_db(db_path=ORACLE_DB):
    """Open Oracle DB with WAL mode."""
    db = sqlite3.connect(db_path)
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("PRAGMA busy_timeout=10000")
    return db


def ensure_schema(db):
    """Create the os_audio_logs table and indexes if they don't exist."""
    db.execute(SCHEMA_SQL)
    for sql in INDEX_SQL:
        db.execute(sql)
    db.commit()


def write_audio_log(db, record: dict):
    """Insert or replace an audio log record."""
    db.execute(
        """INSERT OR REPLACE INTO os_audio_logs (
            file_id, source_file, source_path, recorded_at, duration_seconds,
            processed_at, transcript, transcript_plain, word_count,
            speaker_count, speakers, segments, summary, topics,
            action_items, decisions, entities, key_quotes, sphere, tags,
            sentiment, conversation_type, calendar_event_id, calendar_event_title,
            processing_time_seconds, model_whisper, model_llm, error
        ) VALUES (
            :file_id, :source_file, :source_path, :recorded_at, :duration_seconds,
            :processed_at, :transcript, :transcript_plain, :word_count,
            :speaker_count, :speakers, :segments, :summary, :topics,
            :action_items, :decisions, :entities, :key_quotes, :sphere, :tags,
            :sentiment, :conversation_type, :calendar_event_id, :calendar_event_title,
            :processing_time_seconds, :model_whisper, :model_llm, :error
        )""",
        {
            "file_id": record["file_id"],
            "source_file": record["source_file"],
            "source_path": record["source_path"],
            "recorded_at": record["recorded_at"],
            "duration_seconds": record["duration_seconds"],
            "processed_at": record["processed_at"],
            "transcript": record["transcript"],
            "transcript_plain": record["transcript_plain"],
            "word_count": record["word_count"],
            "speaker_count": record.get("speaker_count", 1),
            "speakers": _json(record.get("speakers")),
            "segments": _json(record["segments"]),
            "summary": record.get("summary"),
            "topics": _json(record.get("topics")),
            "action_items": _json(record.get("action_items")),
            "decisions": _json(record.get("decisions")),
            "entities": _json(record.get("entities")),
            "key_quotes": _json(record.get("key_quotes")),
            "sphere": record.get("sphere"),
            "tags": _json(record.get("tags")),
            "sentiment": record.get("sentiment"),
            "conversation_type": record.get("conversation_type"),
            "calendar_event_id": record.get("calendar_event_id"),
            "calendar_event_title": record.get("calendar_event_title"),
            "processing_time_seconds": record.get("processing_time_seconds"),
            "model_whisper": record.get("model_whisper", "large-v3-turbo"),
            "model_llm": record.get("model_llm", "llama3.1:8b"),
            "error": record.get("error"),
        },
    )
    db.commit()


def file_exists(db, file_id: str) -> bool:
    """Check if a file_id already exists in os_audio_logs."""
    row = db.execute(
        "SELECT 1 FROM os_audio_logs WHERE file_id = ?", (file_id,)
    ).fetchone()
    return row is not None
