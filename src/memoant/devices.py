"""Audio device discovery via ffmpeg avfoundation."""

import re
import subprocess


def list_devices() -> dict:
    """Parse ffmpeg avfoundation device list.

    Returns dict with 'video' and 'audio' keys, each a list of
    (index, name) tuples.
    """
    try:
        result = subprocess.run(
            ["ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", ""],
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = result.stderr  # ffmpeg writes device list to stderr
    except FileNotFoundError:
        raise RuntimeError("ffmpeg not found. Install with: brew install ffmpeg")
    except subprocess.TimeoutExpired:
        raise RuntimeError("ffmpeg device listing timed out")

    video = []
    audio = []
    section = None

    for line in output.splitlines():
        if "AVFoundation video devices:" in line:
            section = "video"
            continue
        elif "AVFoundation audio devices:" in line:
            section = "audio"
            continue

        # Match lines like: [AVFoundation indev @ 0x...] [0] Device Name
        m = re.search(r"\[(\d+)]\s+(.+)$", line)
        if m and section:
            idx = int(m.group(1))
            name = m.group(2).strip()
            if section == "video":
                video.append((idx, name))
            else:
                audio.append((idx, name))

    return {"video": video, "audio": audio}


def resolve_audio_device(device: str) -> str:
    """Resolve device name/index to ffmpeg avfoundation input string.

    Accepts:
        "default" -> ":0"
        "3" or 3  -> ":3"
        "MacBook Pro Microphone" -> ":3" (looked up by name)
    """
    if device == "default":
        return ":0"

    # Numeric index
    if str(device).isdigit():
        return f":{device}"

    # Name lookup
    devices = list_devices()
    for idx, name in devices["audio"]:
        if device.lower() in name.lower():
            return f":{idx}"

    raise ValueError(
        f"Audio device not found: {device!r}. "
        f"Available: {[name for _, name in devices['audio']]}"
    )
