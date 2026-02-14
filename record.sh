#!/bin/bash

# Meeting Recorder - Audio or Screen+Audio Recording
# Usage: ./record.sh [audio|screen]

MODE="${1:-audio}"
RECORDINGS_DIR="$HOME/Code/vault/kylnor/02 - Store/Recordings"
NOTES_DIR="$HOME/Code/vault/kylnor/02 - Store/Meetings"
TEMP_DIR="/tmp/meeting-recorder"

# Ensure directories exist
mkdir -p "$RECORDINGS_DIR"
mkdir -p "$NOTES_DIR"
mkdir -p "$TEMP_DIR"

# Generate timestamp and filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
AUDIO_FILE="$RECORDINGS_DIR/${TIMESTAMP}.m4a"
VIDEO_FILE="$RECORDINGS_DIR/${TIMESTAMP}.mp4"
PID_FILE="$TEMP_DIR/recording.pid"
MODE_FILE="$TEMP_DIR/recording.mode"

# Check if already recording
if [ -f "$PID_FILE" ]; then
    echo "⏹️  Stopping recording..."
    RECORDING_PID=$(cat "$PID_FILE")
    RECORDING_MODE=$(cat "$MODE_FILE")

    # Kill the recording process
    kill "$RECORDING_PID" 2>/dev/null

    # Wait a moment for file to finalize
    sleep 2

    # Clean up PID files
    rm "$PID_FILE"
    rm "$MODE_FILE"

    # Get the actual recorded file
    if [ "$RECORDING_MODE" = "screen" ]; then
        RECORDED_FILE="$VIDEO_FILE"
        echo "✅ Screen recording saved: $RECORDED_FILE"
    else
        RECORDED_FILE="$AUDIO_FILE"
        echo "✅ Audio recording saved: $RECORDED_FILE"
    fi

    # Extract audio for transcription (if video)
    if [ "$RECORDING_MODE" = "screen" ]; then
        AUDIO_FOR_TRANSCRIPTION="$TEMP_DIR/${TIMESTAMP}_audio.wav"
        echo "🎵 Extracting audio from video..."
        ffmpeg -i "$RECORDED_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$AUDIO_FOR_TRANSCRIPTION" -y 2>/dev/null
    else
        AUDIO_FOR_TRANSCRIPTION="$RECORDED_FILE"
    fi

    # Transcribe with Whisper
    echo "📝 Transcribing with Whisper..."
    TRANSCRIPT_FILE="$TEMP_DIR/${TIMESTAMP}_transcript.txt"
    "$HOME/Library/Python/3.9/bin/whisper" "$AUDIO_FOR_TRANSCRIPTION" \
        --model base \
        --output_format txt \
        --output_dir "$TEMP_DIR" \
        --language en 2>/dev/null

    # Find the generated transcript (Whisper adds its own naming)
    WHISPER_OUTPUT=$(find "$TEMP_DIR" -name "*transcript.txt" -o -name "${TIMESTAMP}_audio.txt" | head -1)
    if [ -z "$WHISPER_OUTPUT" ]; then
        # Try finding any recent txt file
        WHISPER_OUTPUT=$(find "$TEMP_DIR" -name "*.txt" -mmin -5 | head -1)
    fi

    if [ -f "$WHISPER_OUTPUT" ]; then
        TRANSCRIPT=$(cat "$WHISPER_OUTPUT")
    else
        TRANSCRIPT="[Transcription failed - file not found]"
    fi

    # Summarize with Ollama
    echo "🤖 Generating summary with Ollama..."
    SUMMARY_PROMPT="Analyze this meeting transcript and provide:
1. A brief summary (2-3 sentences)
2. Key points discussed
3. Action items (if any)
4. Important decisions made

Transcript:
$TRANSCRIPT"

    SUMMARY=$(/usr/local/bin/ollama run gpt-oss:20b "$SUMMARY_PROMPT" 2>/dev/null)

    # Create markdown note
    NOTE_FILE="$NOTES_DIR/${TIMESTAMP}_meeting.md"

    cat > "$NOTE_FILE" << EOF
---
title: Meeting Recording
date: $(date -Iseconds)
type: ${RECORDING_MODE}
tags: [meeting, recording]
---

# Meeting - $(date +"%B %d, %Y at %I:%M %p")

**Type:** ${RECORDING_MODE} recording
**Duration:** [Check file]
**File:** [[$(basename "$RECORDED_FILE")]]

---

## Summary

$SUMMARY

---

## Full Transcript

$TRANSCRIPT

---

## Files

- Recording: \`$(basename "$RECORDED_FILE")\`
EOF

    if [ "$RECORDING_MODE" = "screen" ]; then
        echo "- Audio extraction: \`$(basename "$AUDIO_FOR_TRANSCRIPTION")\`" >> "$NOTE_FILE"
    fi

    echo ""
    echo "✅ COMPLETE!"
    echo "📄 Note created: $NOTE_FILE"
    echo "🎬 Recording: $RECORDED_FILE"

    # Cleanup temp files
    rm -f "$AUDIO_FOR_TRANSCRIPTION" "$WHISPER_OUTPUT"

    exit 0
fi

# Start new recording
echo "🎙️  Starting $MODE recording..."

if [ "$MODE" = "screen" ]; then
    # Screen + Audio Recording
    # Get list of windows and let user select
    echo "📺 Please select the window to record..."

    # Use AppleScript to get window selection
    # This will prompt user to click a window
    osascript << 'APPLESCRIPT' > "$TEMP_DIR/window_info.txt"
tell application "System Events"
    set frontApp to first application process whose frontmost is true
    set appName to name of frontApp
    set windowTitle to name of front window of frontApp
    return appName & "|" & windowTitle
end tell
APPLESCRIPT

    if [ $? -eq 0 ] && [ -f "$TEMP_DIR/window_info.txt" ]; then
        WINDOW_INFO=$(cat "$TEMP_DIR/window_info.txt")
        APP_NAME=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
        WINDOW_TITLE=$(echo "$WINDOW_INFO" | cut -d'|' -f2)

        echo "Recording: $APP_NAME - $WINDOW_TITLE"

        # Use ffmpeg to record screen with audio
        # Capture display 1 with audio from default input
        ffmpeg -f avfoundation \
            -capture_cursor 1 \
            -i "1:0" \
            -r 30 \
            -vcodec libx264 \
            -preset ultrafast \
            -acodec aac \
            "$VIDEO_FILE" &

        RECORDING_PID=$!
    else
        echo "❌ Window selection failed"
        exit 1
    fi

else
    # Audio-only recording
    # Record system audio + microphone using ffmpeg
    ffmpeg -f avfoundation \
        -i ":0" \
        -acodec aac \
        "$AUDIO_FILE" &

    RECORDING_PID=$!
fi

# Save PID and mode
echo "$RECORDING_PID" > "$PID_FILE"
echo "$MODE" > "$MODE_FILE"

echo "✅ Recording started (PID: $RECORDING_PID)"
echo "⏹️  Run './record.sh' again to stop and transcribe"
