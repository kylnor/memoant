# Memoant 🎙️

Self-hosted meeting recorder with automatic transcription and AI-powered note generation.

## Features

- **Two Recording Modes:**
  - 🎙️ **Audio-only**: System audio + microphone
  - 🎥 **Screen**: Window-specific recording with Zoom-style picker

- **AI Processing:**
  - 📝 WhisperX transcription with speaker diarization (Speaker 1, Speaker 2, etc.)
  - 🤖 Ollama metadata extraction (subject, tags, summary, action items, decisions)

- **Auto-Organization:**
  - 💾 Recordings → Google Drive in dated folders
  - 📓 Notes → Obsidian with frontmatter and transcript

- **Raycast Integration:**
  - Quick launch from anywhere
  - Three commands: Record Audio, Record Screen, Stop Recording

## Prerequisites

- macOS 12.3+ (for ScreenCaptureKit)
- Python 3.9+
- Homebrew

## Installation

### 1. Install WhisperX with Compatible PyTorch

```bash
pip3 install whisperx
# WhisperX may install PyTorch 2.8+ which has diarization compatibility issues
# Downgrade to 2.5.1 for stable speaker diarization:
pip3 install torch==2.5.1 torchaudio==2.5.1
```

Verify installation:
```bash
which whisperx
# Should show your whisperx path, e.g. ~/Library/Python/3.9/bin/whisperx

pip3 show torch | grep Version
# Should show: Version: 2.5.1
```

**Set up Hugging Face for Speaker Diarization:**

1. Create account at [huggingface.co](https://huggingface.co)
2. Accept terms at [pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)
3. Create access token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
4. Add to your shell profile (~/.zshrc or ~/.bash_profile):
   ```bash
   export HF_TOKEN="your_token_here"
   ```
5. Reload shell: `source ~/.zshrc`

### 2. Install Ollama

```bash
brew install ollama
ollama pull gpt-oss:20b
```

Verify:
```bash
which ollama
# Should show: /usr/local/bin/ollama
```

### 3. Install ffmpeg

```bash
brew install ffmpeg
```

### 4. Compile WindowRecorder and WindowPicker

```bash
cd ~/Code/meeting-recorder

# Compile WindowRecorder
swiftc -o WindowRecorder WindowRecorder.swift \
  -framework ScreenCaptureKit \
  -framework AVFoundation \
  -framework AppKit

# Compile WindowPicker
swiftc -o WindowPicker WindowPickerThumbs.swift \
  -framework ScreenCaptureKit \
  -framework Cocoa

# Make executable
chmod +x WindowRecorder WindowPicker record-meeting.sh
```

### 5. Grant Screen Recording Permissions

1. Open **System Preferences** → **Security & Privacy** → **Privacy** → **Screen Recording**
2. Add and enable:
   - `Terminal` (if testing from command line)
   - `Raycast` (if using Raycast commands)
   - `WindowPicker` (the compiled binary)

### 6. Configure Paths

Edit `record-meeting.sh` if your paths differ:

```bash
GOOGLE_DRIVE_BASE="$HOME/Library/CloudStorage/GoogleDrive-you@gmail.com/My Drive/000/03 - Store"
OBSIDIAN_MEETINGS="$HOME/Code/vault/your-vault/02 - Store/Meetings"
```

### 7. Add Raycast Scripts

1. Open Raycast
2. Search: "Script Commands"
3. Click: "Add Directories"
4. Add: `~/Code/meeting-recorder/raycast`

You'll now see:
- **Record Audio Meeting** 🎙️
- **Record Screen Meeting** 🎥
- **Stop Recording** ⏹️

## Usage

### From Raycast (Recommended)

1. **Start Recording:**
   - Open Raycast
   - Type "Record Audio Meeting" OR "Record Screen Meeting"
   - For screen mode: Select window from picker (includes "Desktop" option)

2. **Stop Recording:**
   - Open Raycast
   - Type "Stop Recording"
   - Processing happens automatically (transcription + AI metadata extraction)

### From Command Line

```bash
# Start audio recording
~/Code/meeting-recorder/record-meeting.sh audio

# Start screen recording (opens window picker)
~/Code/meeting-recorder/record-meeting.sh screen

# Stop and process
~/Code/meeting-recorder/record-meeting.sh stop
```

## What Happens When You Record

### During Recording
- Audio/video saved to `/tmp/meeting-recorder/`
- PID tracked for graceful stop

### After Stopping
1. **Audio Extraction** (if screen recording)
2. **WhisperX Transcription** with speaker diarization
3. **Ollama Metadata Extraction:**
   - Meeting subject (for filename)
   - Relevant tags
   - Summary (2-3 sentences)
   - Key points
   - Action items
   - Decisions made

4. **File Organization:**
   - Recording moved to Google Drive:
     ```
     Google Drive/000/03 - Store/2026-01-17_product-demo/recording.mp4
     ```
   - Markdown note created in Obsidian:
     ```
     vault/kylnor/02 - Store/Meetings/2026-01-17_product-demo.md
     ```

### Markdown Note Format

```yaml
---
title: Product Demo with Acme Corp
date: 2026-01-17T14:30:00
attendees: []
tags: ["meeting", "product-demo", "client", "acme-corp"]
recording: "Google Drive/000/03 - Store/2026-01-17_product-demo"
---

# Product Demo with Acme Corp

**Date:** January 17, 2026 at 2:30 PM
**Recording:** [View in Google Drive](...)

## Summary
[AI-generated summary]

## Action Items
- [ ] Item 1
- [ ] Item 2

## Key Points
- Point 1
- Point 2

## Decisions Made
- Decision 1

## Transcript

[00:00] Speaker 1: Hey everyone, let's get started with today's demo
[00:32] Speaker 2: Thanks for joining, I'll walk through the new features
[01:15] Speaker 1: That looks great, can we see the dashboard next
```

## File Structure

```
~/Code/meeting-recorder/
├── WindowRecorder.swift          # Source for window recording
├── WindowRecorder                # Compiled binary
├── WindowPickerThumbs.swift      # Source for window picker GUI
├── WindowPicker                  # Compiled binary
├── record-meeting.sh             # Main orchestration script
└── raycast/
    ├── record-audio.sh           # Raycast: Start audio
    ├── record-screen.sh          # Raycast: Start screen
    └── stop-recording.sh         # Raycast: Stop & process
```

## Troubleshooting

### "No recordable windows found"
- Grant Screen Recording permission to WindowPicker
- Check: System Preferences → Security & Privacy → Privacy → Screen Recording

### "WhisperX not found"
```bash
# Find WhisperX path
which whisperx

# Update WHISPERX path in record-meeting.sh if different
```

### "No speaker labels in transcript" or "Could not download diarization model"

Speaker diarization requires a Hugging Face token:

1. Check if HF_TOKEN is set:
   ```bash
   echo $HF_TOKEN
   ```

2. If empty, set it up:
   - Get token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
   - Accept model terms at [pyannote/speaker-diarization-3.1](https://huggingface.co/pyannote/speaker-diarization-3.1)
   - Add to ~/.zshrc:
     ```bash
     export HF_TOKEN="your_token_here"
     ```
   - Reload: `source ~/.zshrc`

3. Test:
   ```bash
   echo $HF_TOKEN  # Should show your token
   ```

Without HF_TOKEN, transcription still works but without speaker identification.

### "Ollama not found"
```bash
# Verify Ollama is running
ollama list

# Pull model if missing
ollama pull gpt-oss:20b
```

### "Google Drive not mounted"
- Ensure Google Drive is syncing
- Check path exists: `ls "$HOME/Library/CloudStorage/GoogleDrive-you@gmail.com/My Drive/000/03 - Store"`

### "Recording already in progress"
```bash
# Check PID file
cat /tmp/meeting-recorder/recording.pid

# Force cleanup if stuck
rm -f /tmp/meeting-recorder/*.pid /tmp/meeting-recorder/*.mode
```

### Transcription Takes Forever
- WhisperX uses CPU by default (slow but works everywhere)
- To use GPU: Edit `record-meeting.sh` and change `--device cpu` to `--device cuda`

### AI Can't Extract Subject
- Falls back to timestamp naming: `2026-01-17_14-30-meeting.md`
- Still creates full note with transcript
- Can manually rename later

## Performance Notes

### Window Picker
- Thumbnails captured at 400x300 for smooth scrolling
- Layer-backed rendering for GPU acceleration
- Filters out system UI (Dock, Desktop, notifications)

### Processing Time
- WhisperX: ~1-2 minutes per 10 minutes of audio (CPU)
- Ollama: ~10-30 seconds for metadata extraction
- Total: Expect 2-5 minutes processing for 30-minute meeting

## Advanced Configuration

### Change Transcription Model

Edit `record-meeting.sh`:
```bash
$WHISPERX "$audio_file" \
    --model large-v2 \  # More accurate but slower
    --diarize \
    ...
```

### Change Ollama Model

Edit `record-meeting.sh`:
```bash
local response=$($OLLAMA run llama2:70b "$prompt" 2>/dev/null)  # Different model
```

### Customize Markdown Template

Edit the `create_markdown_note()` function in `record-meeting.sh`

## Credits

- **WhisperX**: https://github.com/m-bain/whisperX
- **Ollama**: https://ollama.ai
- **ScreenCaptureKit**: Apple's native screen recording API

## License

MIT
