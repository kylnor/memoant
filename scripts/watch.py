#!/usr/bin/env python3
"""Daemon entry point: watch for new audio files and auto-process."""

import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from memoant.config import NOTES_DIR, ORACLE_DB
from memoant.watcher import start_watcher


def main():
    parser = argparse.ArgumentParser(
        description="Watch for new audio files and process them automatically"
    )
    parser.add_argument("--db", default=ORACLE_DB, help="Path to oracle.db")
    parser.add_argument("--notes", default=NOTES_DIR, help="Notes output directory")
    parser.add_argument(
        "--skip-diarization", action="store_true",
        help="Skip speaker diarization"
    )
    parser.add_argument(
        "--no-voice-memos", action="store_true",
        help="Don't watch Voice Memos folder"
    )
    parser.add_argument(
        "--no-inbox", action="store_true",
        help="Don't watch inbox folder"
    )
    args = parser.parse_args()

    start_watcher(
        db_path=args.db,
        notes_dir=args.notes,
        skip_diarization=args.skip_diarization,
        watch_voice_memos=not args.no_voice_memos,
        watch_inbox=not args.no_inbox,
    )


if __name__ == "__main__":
    main()
