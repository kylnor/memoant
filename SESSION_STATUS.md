# Memoant Session Status - 2026-02-15

## Current State: PAUSED FOR TWEAKING

Core pipeline works end-to-end (record, transcribe, diarize, extract metadata, save). Raycast extension removed while reworking audio device handling and UX flow. Landing page live at memoant.com.

## What Was Built (Sessions 1-3)

### Core App
- `record-meeting.sh` - Main script: audio/screen recording, WhisperX transcription, Ollama metadata extraction
- Config-driven architecture via `~/.config/memoant/config` (no hardcoded paths)
- Credentials loaded from `~/.env` (HF_TOKEN for diarization)
- Swift binaries: WindowPicker (GUI window selector), WindowRecorder (ScreenCaptureKit)
- `install.sh` - One-command installer (Homebrew, ffmpeg, jq, Ollama, WhisperX, Swift compile, config)
- `memoant` shell alias installed to ~/.zshrc

### Raycast Extension (REMOVED, needs rework)
- 6 commands: Record Audio, Record Screen, Stop Recording, Meeting History, Recording Status, Menu Bar
- Uses `spawn({ detached: true })` so recordings survive Raycast lifecycle
- Reads state from `/tmp/meeting-recorder/` (PID file, mode, path)
- Logging to `/tmp/meeting-recorder/start.log` and `stop.log` for debugging

### Landing Page (LIVE)
- https://memoant.com (Vercel + Cloudflare DNS)
- Next.js static site, dark theme, ant logo with audio waveform antennae
- Privacy copy updated to be honest (not "100% local" since HF model download exists)
- Install command: `curl -fsSL https://memoant.com/install.sh | bash`

## Key Bugs Fixed

### 1. Recording wouldn't start (Google Drive timeout)
- **Root cause**: `check_dependencies()` tried to `mkdir -p` the Google Drive output path at startup. When Drive was unresponsive, the script hung/failed before ffmpeg launched.
- **Fix**: Split into `check_recording_deps()` (ffmpeg only) and `check_processing_deps()` (warnings only). Output dirs created at save time via `ensure_output_dirs()` with 3s perl alarm timeout and local fallback to `~/Documents/Memoant/`.

### 2. Recording process died immediately
- **Root cause**: Shell script ran ffmpeg with `&` but no `nohup`/`disown`. When parent script exited, ffmpeg got SIGHUP. Raycast used `exec()` which kills child process group on completion.
- **Fix**: Added `nohup` + `disown` in shell. Switched Raycast from `exec()` to `spawn({ detached: true }) + child.unref()`.

### 3. set -e killing script silently
- **Root cause**: `((wait_count++))` when wait_count=0 evaluates to 0, exit code 1, killed by `set -e`. Also, all output went to /dev/null when spawned detached.
- **Fix**: Changed to `wait_count=$((wait_count + 1))`. Added `exec > >(tee -a /tmp/meeting-recorder/memoant.log) 2>&1` for logging.

### 4. Leaked HF token in git history
- **Root cause**: Token was hardcoded in script, committed to git.
- **Fix**: Nuked git history (`rm -rf .git && git init`), rotated token, moved to `~/.env`.

## Known Issues (TO FIX BEFORE RE-ENABLING)

### Audio device hardcoded to wrong mic
- ffmpeg uses `-i ":0"` which is MX Brio webcam mic (silent/far away)
- Available devices: [0] MX Brio, [1] ZoomAudioDevice, [2] iPhone Mic, [3] MacBook Pro Mic, [4] Cluely, [5] MS Teams Audio, [6] Camo, [7] Splashtop, [8] AirPods Max
- **Need**: Configurable `MEMOANT_AUDIO_DEVICE` in config, or auto-detect system default, or device picker UI
- For meetings: probably want system default input or a multi-source capture

### Google Drive path hangs
- `~/Library/CloudStorage/GoogleDrive-.../My Drive/000/03 - Store/Meetings` times out
- Fallback to `~/Documents/Memoant/` works but isn't ideal
- Need to investigate why Drive is unresponsive (might be a Finder/CloudStorage daemon issue)

### WhisperX model warnings
- pyannote.audio version mismatch (trained 0.0.1, running 3.4.0)
- torch version mismatch (trained 1.10.0, running 2.5.1)
- Works but may produce suboptimal results

## Architecture

```
Raycast Command
  -> spawn(record-meeting.sh audio, { detached: true })
    -> nohup ffmpeg -f avfoundation -i ":DEVICE" recording.m4a &
    -> writes PID to /tmp/meeting-recorder/recording.pid

Raycast Stop
  -> spawn(record-meeting.sh stop, { detached: true })
    -> kill -INT ffmpeg
    -> whisperx transcribe + diarize
    -> ollama extract metadata (title, tags, summary, actions, decisions)
    -> ensure_output_dirs (with cloud timeout fallback)
    -> save recording to RECORDINGS_DIR/YYYY-MM-DD_subject/
    -> save markdown note to NOTES_DIR/YYYY-MM-DD_subject.md
```

## Config Files

### ~/.config/memoant/config
```
MEMOANT_RECORDINGS_DIR="$HOME/Library/CloudStorage/GoogleDrive-.../Meetings"
MEMOANT_NOTES_DIR="$HOME/Code/vault/kylnor/02 - Store/Meetings"
MEMOANT_OLLAMA_MODEL="gpt-oss:20b"
# TODO: MEMOANT_AUDIO_DEVICE=3
```

### Key paths
- Project: `/Users/kylenorthup/Code/meeting-recorder/`
- Config: `~/.config/memoant/config`
- Temp: `/tmp/meeting-recorder/` (PID, mode, path, logs)
- Logs: `/tmp/meeting-recorder/memoant.log`
- Installer: `https://memoant.com/install.sh`
- WhisperX: `/Users/kylenorthup/Library/Python/3.9/bin/whisperx`

## Infrastructure
- Vercel project: `memoant` (prj_ayJhsH5rONWJDHSrXUiweTGQfBZT)
- Cloudflare zone: `e2e611e4f0969ce8cbeb9d8df242185d`
- DNS: CNAME @ and www -> cname.vercel-dns.com
- Git: local only (history was reset, not pushed to GitHub yet)

---

**Status**: Paused. Core pipeline works. Reworking audio device selection before re-enabling Raycast extension.
**Last Updated**: 2026-02-15 05:10 AM MT
