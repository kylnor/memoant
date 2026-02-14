# Memoant Setup Checklist

Quick reference for getting speaker diarization working.

## ✅ What We Fixed

- **Downgraded PyTorch** from 2.8.0 → 2.5.1 for pyannote compatibility
- **Re-enabled diarization** in record-meeting.sh
- **Updated README** with installation instructions

## 🔧 What You Need to Do

### 1. Set Up Hugging Face Token (Required for Speaker Labels)

```bash
# 1. Go to https://huggingface.co and create account
# 2. Accept terms at https://huggingface.co/pyannote/speaker-diarization-3.1
# 3. Get token from https://huggingface.co/settings/tokens
# 4. Add to your shell profile:

echo 'export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxx"' >> ~/.zshrc
source ~/.zshrc

# 5. Verify:
echo $HF_TOKEN  # Should show your token
```

### 2. Grant Screen Recording Permissions

System Preferences → Security & Privacy → Privacy → Screen Recording

Enable for:
- ✅ Terminal (if testing from command line)
- ✅ Raycast (if using Raycast commands)
- ✅ WindowPicker (the compiled binary)

### 3. Add Raycast Scripts

1. Open Raycast
2. Search: "Script Commands"
3. Click: "Add Directories"
4. Add: `~/Code/meeting-recorder/raycast`

## 🎯 Quick Test

```bash
# Start audio recording
~/Code/meeting-recorder/record-meeting.sh audio

# Let it record for 10 seconds (talk, play audio, etc.)

# Stop and process
~/Code/meeting-recorder/record-meeting.sh stop
```

Expected output:
- Recording saved to Google Drive: `2026-01-17_<ai-subject>/recording.m4a`
- Note created in Obsidian: `2026-01-17_<ai-subject>.md`
- Transcript with speaker labels: `[00:00] Speaker 1: ...`

## 📦 Current Versions

```bash
pip3 show torch | grep Version
# Version: 2.5.1

pip3 show whisperx | grep Version
# Version: 3.7.4

pip3 show pyannote-audio | grep Version
# Version: 3.4.0
```

## ⚠️ Important Notes

- **Don't upgrade PyTorch** beyond 2.5.1 (breaks diarization)
- **HF_TOKEN is required** - without it, transcription works but no speaker labels
- **First transcription is slow** (downloads models, ~500MB)
- **Subsequent runs are faster** (models cached locally)

## 🔗 Useful Links

- WhisperX Repo: https://github.com/m-bain/whisperX
- PyAnnote Diarization Model: https://huggingface.co/pyannote/speaker-diarization-3.1
- Hugging Face Tokens: https://huggingface.co/settings/tokens
