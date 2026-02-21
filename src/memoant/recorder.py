"""Audio and screen recording with state management."""

import json
import os
import signal
import subprocess
import time
from datetime import datetime

from .config import (
    AUDIO_DEVICE,
    CHANNELS,
    RECORDINGS_DIR,
    SAMPLE_RATE,
    STATE_DIR,
    WINDOW_PICKER_BIN,
    WINDOW_RECORDER_BIN,
    ensure_dirs,
)
from .devices import resolve_audio_device

STATE_FILE = os.path.join(STATE_DIR, "recording.json")


def _read_state() -> dict | None:
    """Read current recording state, or None if not recording."""
    if not os.path.isfile(STATE_FILE):
        return None
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
        # Verify process is actually alive
        pid = state.get("pid")
        if pid:
            try:
                os.kill(pid, 0)
            except OSError:
                # Process is dead, clean up stale state
                _clear_state()
                return None
        return state
    except (json.JSONDecodeError, KeyError):
        _clear_state()
        return None


def _write_state(state: dict):
    """Write recording state."""
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def _clear_state():
    """Remove state file."""
    if os.path.isfile(STATE_FILE):
        os.remove(STATE_FILE)


def is_recording() -> bool:
    """Check if a recording is in progress."""
    return _read_state() is not None


def get_status() -> dict | None:
    """Get current recording status, or None if idle."""
    state = _read_state()
    if not state:
        return None

    elapsed = time.time() - state["start_time"]
    mins = int(elapsed // 60)
    secs = int(elapsed % 60)
    state["elapsed"] = f"{mins:02d}:{secs:02d}"
    state["elapsed_seconds"] = elapsed
    return state


def _check_already_recording():
    """Raise if a recording is already in progress."""
    if is_recording():
        state = _read_state()
        raise RuntimeError(
            f"Already recording (PID: {state['pid']}, "
            f"started: {state.get('started_at', 'unknown')})"
        )


def _stop_process(pid: int):
    """Stop a recording process gracefully (SIGINT, then SIGKILL)."""
    try:
        os.kill(pid, signal.SIGINT)
    except OSError:
        return  # already dead

    # Wait for process to finish (max 10s)
    for _ in range(20):
        try:
            os.kill(pid, 0)
            time.sleep(0.5)
        except OSError:
            return  # process exited
    # Force kill
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass


def start(device: str | None = None, mode: str = "auto") -> dict:
    """Start an audio recording.

    Args:
        device: Audio device name, index, or "default". Uses config if None.
        mode: Processing mode hint ("auto", "meeting", "dictation").

    Returns:
        Dict with pid, path, start_time, mode, recording_type.

    Raises:
        RuntimeError: If already recording or ffmpeg fails to start.
    """
    _check_already_recording()
    ensure_dirs()

    # Resolve audio device
    device_input = resolve_audio_device(device or AUDIO_DEVICE)

    # Generate output path
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output_path = os.path.join(RECORDINGS_DIR, f"recording_{timestamp}.m4a")
    log_path = os.path.join(STATE_DIR, "ffmpeg.log")

    # Build ffmpeg command
    cmd = [
        "ffmpeg",
        "-f", "avfoundation",
        "-i", device_input,
        "-ac", str(CHANNELS),
        "-ar", str(SAMPLE_RATE),
        "-ab", "128k",
        "-y",  # overwrite if exists
        output_path,
    ]

    # Start ffmpeg in background
    with open(log_path, "w") as log_f:
        proc = subprocess.Popen(
            cmd,
            stdout=log_f,
            stderr=log_f,
            stdin=subprocess.DEVNULL,
            start_new_session=True,  # detach from terminal
        )

    # Verify it started
    time.sleep(0.5)
    if proc.poll() is not None:
        log_content = ""
        if os.path.isfile(log_path):
            with open(log_path) as f:
                log_content = f.read()
        raise RuntimeError(f"ffmpeg failed to start (exit {proc.returncode}): {log_content[-500:]}")

    # Save state
    state = {
        "pid": proc.pid,
        "path": output_path,
        "start_time": time.time(),
        "started_at": datetime.now().isoformat(),
        "mode": mode,
        "device": device_input,
        "recording_type": "audio",
    }
    _write_state(state)

    return state


def start_screen(mode: str = "meeting") -> dict:
    """Start a screen recording via WindowPicker + WindowRecorder.

    Launches the GUI window picker, then starts WindowRecorder on the
    selected window. The recording is an MP4 with audio.

    Args:
        mode: Processing mode hint (defaults to "meeting" for screen recordings).

    Returns:
        Dict with pid, path, start_time, mode, recording_type, window_index.

    Raises:
        RuntimeError: If binaries not found, picker cancelled, or recorder fails.
    """
    _check_already_recording()
    ensure_dirs()

    # Verify binaries exist
    if not os.path.isfile(WINDOW_PICKER_BIN):
        raise RuntimeError(
            f"WindowPicker not found at {WINDOW_PICKER_BIN}\n"
            f"Build with: cd swift && make"
        )
    if not os.path.isfile(WINDOW_RECORDER_BIN):
        raise RuntimeError(
            f"WindowRecorder not found at {WINDOW_RECORDER_BIN}\n"
            f"Build with: cd swift && make"
        )

    # Step 1: Launch window picker (blocking GUI)
    try:
        result = subprocess.run(
            [WINDOW_PICKER_BIN],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("Window picker timed out (60s)")

    if result.returncode != 0:
        raise RuntimeError("Window selection cancelled")

    # WindowPicker outputs "id:WINDOW_ID" or "desktop"
    window_selector = result.stdout.strip().split("\n")[-1].strip()
    if not (window_selector.startswith("id:") or window_selector == "desktop"):
        raise RuntimeError(f"Invalid window selector from picker: {window_selector!r}")

    # Step 2: Start WindowRecorder with the selected window
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output_path = os.path.join(RECORDINGS_DIR, f"screen_{timestamp}.mp4")
    log_path = os.path.join(STATE_DIR, "recorder.log")

    with open(log_path, "w") as log_f:
        proc = subprocess.Popen(
            [WINDOW_RECORDER_BIN, output_path, window_selector],
            stdout=log_f,
            stderr=log_f,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )

    # Verify it started
    time.sleep(1.0)
    if proc.poll() is not None:
        log_content = ""
        if os.path.isfile(log_path):
            with open(log_path) as f:
                log_content = f.read()
        raise RuntimeError(f"WindowRecorder failed to start (exit {proc.returncode}): {log_content[-500:]}")

    # Save state
    device_label = "desktop" if window_selector == "desktop" else f"screen ({window_selector})"
    state = {
        "pid": proc.pid,
        "path": output_path,
        "start_time": time.time(),
        "started_at": datetime.now().isoformat(),
        "mode": mode,
        "device": device_label,
        "recording_type": "screen",
        "window_selector": window_selector,
    }
    _write_state(state)

    return state


def stop(process: bool = True) -> dict:
    """Stop the current recording.

    Works for both audio (ffmpeg) and screen (WindowRecorder) recordings.
    Both respond to SIGINT for graceful shutdown.

    Args:
        process: If True, run the recording through the pipeline after stopping.

    Returns:
        Dict with recording info and optionally pipeline results.

    Raises:
        RuntimeError: If not recording.
    """
    state = _read_state()
    if not state:
        raise RuntimeError("No recording in progress")

    pid = state["pid"]
    recording_path = state["path"]
    mode = state["mode"]
    recording_type = state.get("recording_type", "audio")

    _stop_process(pid)

    # Wait for file to be fully written
    time.sleep(1)

    _clear_state()

    elapsed = time.time() - state["start_time"]
    result = {
        "path": recording_path,
        "mode": mode,
        "recording_type": recording_type,
        "duration_seconds": elapsed,
        "exists": os.path.isfile(recording_path),
    }

    if not result["exists"]:
        result["error"] = "Recording file not found after stopping"
        return result

    file_size = os.path.getsize(recording_path)
    result["size_bytes"] = file_size

    if file_size < 1000:
        result["warning"] = "Recording file is very small, may be empty"

    # Optionally process through pipeline
    if process and result["exists"] and file_size >= 1000:
        from .config import NOTES_DIR, ORACLE_DB
        from .pipeline import process_file

        print("\nProcessing recording through pipeline...")
        pipeline_result = process_file(
            recording_path,
            db_path=ORACLE_DB,
            notes_dir=NOTES_DIR,
            mode=mode,
        )
        result["pipeline"] = pipeline_result

    return result
