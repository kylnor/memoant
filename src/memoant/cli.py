"""Click CLI for memoant."""

import os
import sys

import click

from .config import (
    DEFAULT_MODE,
    NOTES_DIR,
    ORACLE_DB,
    WATCH_VOICE_MEMOS,
    ensure_dirs,
    load_config,
)


@click.group()
@click.version_option()
def cli():
    """Record meetings, transcribe voice memos, structure everything."""
    load_config()


# ── Recording Commands ───────────────────────────────────────────────


@cli.command()
@click.option("--device", default=None, help="Audio device name or index")
@click.option("--screen", is_flag=True, help="Record a window (screen + audio)")
@click.option(
    "--mode",
    type=click.Choice(["auto", "meeting", "dictation"]),
    default=None,
    help="Processing mode hint",
)
def record(device, screen, mode):
    """Start recording audio or screen."""
    ensure_dirs()

    if screen:
        from .recorder import start_screen

        effective_mode = mode or "meeting"
        try:
            state = start_screen(mode=effective_mode)
        except RuntimeError as e:
            click.echo(f"Error: {e}", err=True)
            sys.exit(1)
    else:
        from .recorder import start

        effective_mode = mode or "auto"
        try:
            state = start(device=device, mode=effective_mode)
        except RuntimeError as e:
            click.echo(f"Error: {e}", err=True)
            sys.exit(1)

    rec_type = state.get("recording_type", "audio")
    click.echo(f"Recording started (PID: {state['pid']})")
    click.echo(f"  Type: {rec_type}")
    click.echo(f"  Device: {state['device']}")
    click.echo(f"  Mode: {state['mode']}")
    click.echo(f"  File: {state['path']}")
    click.echo("\nRun 'memoant stop' to finish and process.")


@cli.command()
@click.option("--no-process", is_flag=True, help="Stop without processing")
def stop(no_process):
    """Stop recording and process the audio."""
    from .recorder import stop as recorder_stop

    try:
        result = recorder_stop(process=not no_process)
    except RuntimeError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

    if not result.get("exists"):
        click.echo(f"Error: {result.get('error', 'Recording file not found')}", err=True)
        sys.exit(1)

    mins = int(result["duration_seconds"] // 60)
    secs = int(result["duration_seconds"] % 60)
    rec_type = result.get("recording_type", "audio")
    click.echo(f"Recording stopped ({rec_type}, {mins:02d}:{secs:02d})")
    click.echo(f"  File: {result['path']}")
    click.echo(f"  Size: {result.get('size_bytes', 0) / 1024:.0f} KB")

    if result.get("warning"):
        click.echo(f"  Warning: {result['warning']}")

    pipeline = result.get("pipeline")
    if pipeline and pipeline.get("status") == "processed":
        click.echo(f"\nSummary: {pipeline.get('summary', 'N/A')}")
        click.echo(f"Duration: {pipeline['duration']:.0f}s | Words: {pipeline['word_count']}")
        click.echo(f"Speakers: {pipeline['speaker_count']} | Sphere: {pipeline.get('sphere', 'N/A')}")
        click.echo(f"Note: {pipeline.get('note_path', 'N/A')}")
        click.echo(f"Processing time: {pipeline['processing_time']:.1f}s")
    elif no_process:
        click.echo("\nSkipped processing (--no-process).")
    elif pipeline:
        click.echo(f"\nPipeline status: {pipeline.get('status', 'unknown')}")


@cli.command()
def status():
    """Show recording status."""
    from .recorder import get_status

    state = get_status()
    if state:
        rec_type = state.get("recording_type", "audio")
        click.echo(f"Recording in progress ({rec_type})")
        click.echo(f"  PID: {state['pid']}")
        click.echo(f"  Elapsed: {state['elapsed']}")
        click.echo(f"  Mode: {state['mode']}")
        click.echo(f"  Device: {state['device']}")
        click.echo(f"  File: {state['path']}")
    else:
        click.echo("Idle (no recording in progress)")


# ── Processing Commands ──────────────────────────────────────────────


@cli.command()
@click.argument("file", type=click.Path(exists=True))
@click.option("--db", default=None, help="Path to oracle.db")
@click.option("--notes", default=None, help="Notes output directory")
@click.option("--skip-diarization", is_flag=True, help="Skip speaker diarization")
@click.option("--force", is_flag=True, help="Reprocess even if already in DB")
@click.option(
    "--mode",
    type=click.Choice(["auto", "meeting", "dictation"]),
    default=None,
    help="Processing mode hint",
)
def process(file, db, notes, skip_diarization, force, mode):
    """Process an audio file through the full pipeline."""
    from .pipeline import process_file

    ensure_dirs()
    result = process_file(
        file,
        db_path=db or ORACLE_DB,
        notes_dir=notes or NOTES_DIR,
        skip_diarization=skip_diarization,
        force=force,
        mode=mode or DEFAULT_MODE,
    )

    if result["status"] == "processed":
        click.echo(f"\nSummary: {result.get('summary', 'N/A')}")
        click.echo(f"Duration: {result['duration']:.0f}s | Words: {result['word_count']}")
        click.echo(f"Speakers: {result['speaker_count']} | Sphere: {result.get('sphere', 'N/A')}")
        click.echo(f"Note: {result.get('note_path', 'N/A')}")
        click.echo(f"Processing time: {result['processing_time']:.1f}s")
    elif result["status"] == "skipped":
        click.echo("File already processed. Use --force to reprocess.")
    elif result["status"] == "no_speech":
        click.echo("No speech detected in file.")


@cli.command()
@click.option("--db", default=None, help="Path to oracle.db")
@click.option("--notes", default=None, help="Notes output directory")
@click.option("--skip-diarization", is_flag=True, help="Skip speaker diarization")
@click.option("--no-voice-memos", is_flag=True, help="Don't watch Voice Memos folder")
@click.option("--no-inbox", is_flag=True, help="Don't watch inbox folder")
def watch(db, notes, skip_diarization, no_voice_memos, no_inbox):
    """Start watching folders for new audio files."""
    from .watcher import start_watcher

    start_watcher(
        db_path=db or ORACLE_DB,
        notes_dir=notes or NOTES_DIR,
        skip_diarization=skip_diarization,
        watch_voice_memos=not no_voice_memos and WATCH_VOICE_MEMOS,
        watch_inbox=not no_inbox,
    )


# ── Info Commands ────────────────────────────────────────────────────


@cli.command()
def devices():
    """List available audio input devices."""
    from .devices import list_devices

    try:
        devs = list_devices()
    except RuntimeError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)

    click.echo("Audio input devices:")
    for idx, name in devs["audio"]:
        click.echo(f"  [{idx}] {name}")

    if not devs["audio"]:
        click.echo("  (none found)")


@cli.command("config")
def show_config():
    """Show current configuration."""
    from . import config as cfg

    click.echo("memoant configuration")
    click.echo(f"  Config file: {cfg.CONFIG_FILE}")
    click.echo(f"  Config exists: {os.path.isfile(cfg.CONFIG_FILE)}")
    click.echo()
    click.echo("[recording]")
    click.echo(f"  audio_device = {cfg.AUDIO_DEVICE}")
    click.echo(f"  sample_rate = {cfg.SAMPLE_RATE}")
    click.echo(f"  channels = {cfg.CHANNELS}")
    click.echo()
    click.echo("[processing]")
    click.echo(f"  whisper_model = {cfg.WHISPER_MODEL}")
    click.echo(f"  ollama_model = {cfg.OLLAMA_MODEL}")
    click.echo(f"  ollama_url = {cfg.OLLAMA_URL}")
    click.echo(f"  default_mode = {cfg.DEFAULT_MODE}")
    click.echo()
    click.echo("[output]")
    click.echo(f"  oracle_db = {cfg.ORACLE_DB}")
    click.echo(f"  notes_dir = {cfg.NOTES_DIR}")
    click.echo(f"  recordings_dir = {cfg.RECORDINGS_DIR}")
    click.echo(f"  archive_dir = {cfg.ARCHIVE_DIR}")
    click.echo()
    click.echo("[watch]")
    click.echo(f"  voice_memos = {cfg.WATCH_VOICE_MEMOS}")
    click.echo(f"  inbox_dir = {cfg.INBOX_DIR}")
    click.echo(f"  voice_memos_dir = {cfg.VOICE_MEMOS_DIR}")
    click.echo()
    click.echo("[screen]")
    click.echo(f"  swift_dir = {cfg.SWIFT_DIR}")
    click.echo(f"  window_picker = {cfg.WINDOW_PICKER_BIN} ({'found' if os.path.isfile(cfg.WINDOW_PICKER_BIN) else 'NOT FOUND'})")
    click.echo(f"  window_recorder = {cfg.WINDOW_RECORDER_BIN} ({'found' if os.path.isfile(cfg.WINDOW_RECORDER_BIN) else 'NOT FOUND'})")
