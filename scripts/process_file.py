#!/usr/bin/env python3
"""Process a single audio file through the memoant pipeline."""

import argparse
import os
import sys

# Add src to path for direct execution
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from memoant.config import NOTES_DIR, ORACLE_DB, ensure_dirs
from memoant.pipeline import process_file


def main():
    parser = argparse.ArgumentParser(
        description="Process a single audio file into Oracle DB + Obsidian note"
    )
    parser.add_argument("file", help="Path to audio file (.m4a, .wav, etc.)")
    parser.add_argument("--db", default=ORACLE_DB, help="Path to oracle.db")
    parser.add_argument("--notes", default=NOTES_DIR, help="Notes output directory")
    parser.add_argument(
        "--skip-diarization", action="store_true",
        help="Skip speaker diarization (faster, single-speaker recordings)"
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Reprocess even if file already exists in DB"
    )
    parser.add_argument(
        "--mode", default="auto", choices=["auto", "meeting", "dictation"],
        help="Processing mode hint (default: auto)"
    )
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"Error: file not found: {args.file}")
        sys.exit(1)

    ensure_dirs()
    result = process_file(
        args.file,
        db_path=args.db,
        notes_dir=args.notes,
        skip_diarization=args.skip_diarization,
        force=args.force,
        mode=args.mode,
    )

    if result["status"] == "processed":
        print(f"\nSummary: {result.get('summary', 'N/A')}")
        print(f"Duration: {result['duration']:.0f}s | Words: {result['word_count']}")
        print(f"Speakers: {result['speaker_count']} | Sphere: {result.get('sphere', 'N/A')}")
        print(f"Note: {result.get('note_path', 'N/A')}")
        print(f"Processing time: {result['processing_time']:.1f}s")
    elif result["status"] == "skipped":
        print("File already processed. Use --force to reprocess.")
    elif result["status"] == "no_speech":
        print("No speech detected in file.")


if __name__ == "__main__":
    main()
