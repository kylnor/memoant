"""Folder watcher for automatic audio processing."""

import os
import time

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from .config import (
    AUDIO_EXTENSIONS,
    FILE_SETTLE_SECONDS,
    INBOX_DIR,
    NOTES_DIR,
    VOICE_MEMOS_DIR,
    ensure_dirs,
)
from .pipeline import process_file


class AudioHandler(FileSystemEventHandler):
    """Watch for new audio files and process them."""

    def __init__(self, db_path: str, notes_dir: str, skip_diarization: bool = False):
        self.db_path = db_path
        self.notes_dir = notes_dir
        self.skip_diarization = skip_diarization
        self._processing = set()

    def on_created(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def on_modified(self, event):
        if event.is_directory:
            return
        self._handle(event.src_path)

    def _handle(self, path: str):
        ext = os.path.splitext(path)[1].lower()
        if ext not in AUDIO_EXTENSIONS:
            return

        # Skip if already being processed
        if path in self._processing:
            return
        self._processing.add(path)

        try:
            # Wait for file to finish writing (iCloud sync, etc.)
            self._wait_for_stable(path)

            print(f"\n[memoant] New audio file: {os.path.basename(path)}")
            result = process_file(
                path,
                db_path=self.db_path,
                notes_dir=self.notes_dir,
                skip_diarization=self.skip_diarization,
            )
            print(f"[memoant] Result: {result.get('status')} - {result.get('summary', '')[:60]}")

        except Exception as e:
            print(f"[memoant] Error processing {path}: {e}")
        finally:
            self._processing.discard(path)

    def _wait_for_stable(self, path: str, timeout: int = 60):
        """Wait until file size stops changing."""
        prev_size = -1
        waited = 0
        while waited < timeout:
            try:
                size = os.path.getsize(path)
            except OSError:
                return
            if size == prev_size and size > 0:
                return
            prev_size = size
            time.sleep(FILE_SETTLE_SECONDS)
            waited += FILE_SETTLE_SECONDS


def start_watcher(
    db_path: str,
    notes_dir: str = NOTES_DIR,
    skip_diarization: bool = False,
    watch_voice_memos: bool = True,
    watch_inbox: bool = True,
):
    """Start watching folders for new audio files.

    Args:
        db_path: path to oracle.db
        notes_dir: directory for Obsidian markdown output
        skip_diarization: skip speaker diarization
        watch_voice_memos: watch Apple Voice Memos folder
        watch_inbox: watch ~/.memoant/inbox/ folder
    """
    ensure_dirs()
    handler = AudioHandler(db_path, notes_dir, skip_diarization)
    observer = Observer()

    watched = []
    if watch_voice_memos and os.path.isdir(VOICE_MEMOS_DIR):
        observer.schedule(handler, VOICE_MEMOS_DIR, recursive=False)
        watched.append(f"Voice Memos: {VOICE_MEMOS_DIR}")

    if watch_inbox:
        os.makedirs(INBOX_DIR, exist_ok=True)
        observer.schedule(handler, INBOX_DIR, recursive=False)
        watched.append(f"Inbox: {INBOX_DIR}")

    if not watched:
        print("No folders to watch!")
        return

    print("memoant watcher started")
    print(f"  DB: {db_path}")
    print(f"  Notes: {notes_dir}")
    print(f"  Diarization: {'off' if skip_diarization else 'on'}")
    for w in watched:
        print(f"  Watching: {w}")
    print("  Press Ctrl+C to stop\n")

    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down watcher...")
        observer.stop()
    observer.join()
