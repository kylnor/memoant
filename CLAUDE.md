# Memoant

Unified audio pipeline: record meetings, transcribe voice memos, structure everything into Oracle DB + Obsidian notes.

## Quick Reference

```bash
# Record audio (default device)
uv run memoant record
uv run memoant record --device "krisp microphone" --mode meeting

# Record screen (window picker GUI)
uv run memoant record --screen
uv run memoant record --screen --mode meeting

# Check recording status
uv run memoant status

# Stop recording and auto-process
uv run memoant stop
uv run memoant stop --no-process  # just save the file

# List audio devices
uv run memoant devices

# Process a single file
uv run memoant process ~/path/to/recording.m4a

# Process without diarization (faster, single-speaker)
uv run memoant process --skip-diarization ~/path/to/recording.m4a

# Process as meeting explicitly
uv run memoant process --mode meeting ~/path/to/recording.m4a

# Start the watcher daemon
uv run memoant watch

# Drop a file in the inbox
cp recording.m4a ~/.memoant/inbox/

# Show config
uv run memoant config

# Direct script execution (no install needed)
uv run python scripts/process_file.py ~/path/to/recording.m4a
uv run python scripts/watch.py
```

## Architecture

```
Audio: .m4a -> ffmpeg WAV -> silero VAD -> chunker -> mlx-whisper -> pyannote diarize -> merge -> Ollama structure -> calendar match -> Oracle DB -> Obsidian note -> archive
Screen: .mp4 -> ffmpeg WAV (extract audio) -> same pipeline
```

- **Graceful degradation**: diarization failure proceeds without speakers, Ollama failure writes transcript without structure
- **Dedup**: SHA256 file hash as `file_id`, `INSERT OR REPLACE`
- **Watched folders**: Voice Memos (iCloud sync) + `~/.memoant/inbox/`
- **Config**: `~/.config/memoant/config.toml` (TOML, all paths expandable)

## DB Table

`os_audio_logs` in `~/.oracle/oracle.db` (same conventions as other `os_*` tables)

## Dependencies

- Python 3.12 (3.14 incompatible with torch/pyannote)
- ffmpeg (via Homebrew)
- Ollama running locally (llama3.1:8b)
- HuggingFace token for pyannote (HUGGINGFACE_TOKEN in ~/.env)
- macOS 12.3+ for screen recording (ScreenCaptureKit)

## Key Paths

- Project: `/Users/kylenorthup/Code/memoant/`
- Config: `~/.config/memoant/config.toml`
- Archive: `~/.memoant/archive/`
- Inbox: `~/.memoant/inbox/`
- State: `~/.memoant/state/`
- Notes: `~/Code/vault/kylnor/02 - Store/Meetings/`
- Voice Memos: `~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/`
- Oracle DB: `~/.oracle/oracle.db`
- Swift binaries: `swift/` (WindowPicker, WindowRecorder)
- Raycast scripts: `raycast/` (record-audio, record-screen, stop-recording)
- launchd plist: `launchd/com.memoant.plist`

## Modes

- `auto` (default): LLM determines conversation_type
- `meeting`: forces conversation_type=meeting, enables diarization
- `dictation`: forces conversation_type=dictation, skips diarization

## Project History

Unified from three tools: memoant (recording), Lifelogger (pipeline), Typeant (archived stubs). Lifelogger's pipeline is the engine, memoant is the brand.
