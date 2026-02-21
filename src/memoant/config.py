"""Unified TOML config loader for memoant."""

import os
import sys

if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib

CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".config", "memoant")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.toml")
STATE_DIR = os.path.join(os.path.expanduser("~"), ".memoant", "state")

# ── Defaults (overridden by config.toml) ──────────────────────────

# Recording
AUDIO_DEVICE = "default"
SAMPLE_RATE = 48000
CHANNELS = 2

# Processing
WHISPER_MODEL = "mlx-community/whisper-large-v3-turbo"
OLLAMA_MODEL = "llama3.1:8b"
OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_MODE = "auto"  # auto | meeting | dictation

# Output
ORACLE_DB = os.path.join(os.path.expanduser("~"), ".oracle", "oracle.db")
NOTES_DIR = os.path.join(
    os.path.expanduser("~"), "Code", "vault", "kylnor", "02 - Store", "Meetings"
)
RECORDINGS_DIR = os.path.join(os.path.expanduser("~"), "Documents", "Memoant", "Recordings")
ARCHIVE_DIR = os.path.join(os.path.expanduser("~"), ".memoant", "archive")

# Watch
WATCH_VOICE_MEMOS = True
INBOX_DIR = os.path.join(os.path.expanduser("~"), ".memoant", "inbox")

# Voice Memos (iCloud sync path)
VOICE_MEMOS_DIR = os.path.join(
    os.path.expanduser("~"),
    "Library",
    "Group Containers",
    "group.com.apple.VoiceMemos.shared",
    "Recordings",
)

# Audio processing (internal, not in config.toml)
AUDIO_SAMPLE_RATE = 16000  # whisper input rate
AUDIO_CHANNELS = 1
MAX_CHUNK_SECONDS = 1800
MIN_SILENCE_MS = 500
SILENCE_THRESHOLD = 0.3

# File handling
AUDIO_EXTENSIONS = {".m4a", ".wav", ".mp3", ".aac", ".flac", ".ogg", ".wma", ".mp4", ".mov", ".mkv"}
FILE_SETTLE_SECONDS = 5
TMP_DIR = os.path.join(os.path.expanduser("~"), ".memoant", "tmp")

# Swift binaries (screen recording)
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SWIFT_DIR = os.path.join(_PROJECT_ROOT, "swift")
WINDOW_PICKER_BIN = os.path.join(SWIFT_DIR, "WindowPicker")
WINDOW_RECORDER_BIN = os.path.join(SWIFT_DIR, "WindowRecorder")


def _expand(path: str) -> str:
    """Expand ~ and env vars in a path."""
    return os.path.expandvars(os.path.expanduser(path))


def load_config():
    """Load config.toml and override module-level defaults."""
    global AUDIO_DEVICE, SAMPLE_RATE, CHANNELS
    global WHISPER_MODEL, OLLAMA_MODEL, OLLAMA_URL, DEFAULT_MODE
    global ORACLE_DB, NOTES_DIR, RECORDINGS_DIR, ARCHIVE_DIR
    global WATCH_VOICE_MEMOS, INBOX_DIR

    if not os.path.isfile(CONFIG_FILE):
        return

    with open(CONFIG_FILE, "rb") as f:
        cfg = tomllib.load(f)

    rec = cfg.get("recording", {})
    AUDIO_DEVICE = rec.get("audio_device", AUDIO_DEVICE)
    SAMPLE_RATE = rec.get("sample_rate", SAMPLE_RATE)
    CHANNELS = rec.get("channels", CHANNELS)

    proc = cfg.get("processing", {})
    WHISPER_MODEL = proc.get("whisper_model", WHISPER_MODEL)
    OLLAMA_MODEL = proc.get("ollama_model", OLLAMA_MODEL)
    OLLAMA_URL = proc.get("ollama_url", OLLAMA_URL)
    DEFAULT_MODE = proc.get("default_mode", DEFAULT_MODE)

    out = cfg.get("output", {})
    ORACLE_DB = _expand(out.get("oracle_db", ORACLE_DB))
    NOTES_DIR = _expand(out.get("notes_dir", NOTES_DIR))
    RECORDINGS_DIR = _expand(out.get("recordings_dir", RECORDINGS_DIR))
    ARCHIVE_DIR = _expand(out.get("archive_dir", ARCHIVE_DIR))

    watch = cfg.get("watch", {})
    WATCH_VOICE_MEMOS = watch.get("voice_memos", WATCH_VOICE_MEMOS)
    INBOX_DIR = _expand(watch.get("inbox_dir", INBOX_DIR))


def ensure_dirs():
    """Create all required directories."""
    for d in [
        os.path.dirname(CONFIG_FILE),
        STATE_DIR,
        ARCHIVE_DIR,
        INBOX_DIR,
        TMP_DIR,
        NOTES_DIR,
        RECORDINGS_DIR,
    ]:
        os.makedirs(d, exist_ok=True)


# Load config on import
load_config()
