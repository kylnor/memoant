#!/bin/bash

#==============================================================================
# Meeting Recorder with Auto-Transcription
# Supports audio-only and window-specific screen recording
# Uses WhisperX for transcription with speaker diarization
# Uses Ollama for AI metadata extraction
#==============================================================================

set -euo pipefail

# Log all output for debugging (especially when run detached from Raycast)
exec > >(tee -a /tmp/meeting-recorder/memoant.log) 2>&1

# Resolve script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/memoant/config"

# Load config (created by install.sh)
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Load credentials (HF_TOKEN, etc.)
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

# Configuration with defaults (config file values take priority)
RECORDINGS_DIR="${MEMOANT_RECORDINGS_DIR:-$HOME/Documents/Memoant/Recordings}"
NOTES_DIR="${MEMOANT_NOTES_DIR:-$HOME/Documents/Memoant/Notes}"
TEMP_DIR="/tmp/meeting-recorder"
PID_FILE="$TEMP_DIR/recording.pid"
MODE_FILE="$TEMP_DIR/recording.mode"
RECORDING_FILE="$TEMP_DIR/recording.path"
OLLAMA_MODEL="${MEMOANT_OLLAMA_MODEL:-gpt-oss:20b}"

# Tool paths (auto-detect, config overrides)
WHISPERX="${MEMOANT_WHISPERX:-$(command -v whisperx 2>/dev/null || echo "$HOME/Library/Python/3.9/bin/whisperx")}"
OLLAMA="${MEMOANT_OLLAMA:-$(command -v ollama 2>/dev/null || echo "/usr/local/bin/ollama")}"
FFMPEG="${MEMOANT_FFMPEG:-$(command -v ffmpeg 2>/dev/null || echo "/opt/homebrew/bin/ffmpeg")}"
WINDOW_RECORDER="$SCRIPT_DIR/WindowRecorder"
WINDOW_PICKER="$SCRIPT_DIR/WindowPicker"

# Hugging Face token for speaker diarization
export HF_TOKEN="${HF_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# Helper Functions
#==============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

show_window_picker() {
    # Use the GUI window picker
    local window_index=$($WINDOW_PICKER 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ -z "$window_index" ]]; then
        log_error "Recording cancelled"
        exit 1
    fi

    echo "$window_index"
}

check_recording_deps() {
    # Only what's needed to START recording
    if [[ ! -f "$FFMPEG" ]]; then
        log_error "ffmpeg not found at $FFMPEG"
        exit 1
    fi
}

check_processing_deps() {
    # What's needed to TRANSCRIBE and PROCESS after recording
    local missing=0

    if [[ ! -f "$WHISPERX" ]] && ! command -v whisperx &>/dev/null; then
        log_warning "WhisperX not found - transcription will be skipped"
    fi

    if [[ ! -f "$OLLAMA" ]]; then
        log_warning "Ollama not found at $OLLAMA - metadata extraction will be skipped"
    fi

    if ! command -v jq &>/dev/null; then
        log_warning "jq not found - metadata parsing may fail"
    fi

    # Output dirs checked at save time (see ensure_output_dirs)
}

safe_mkdir() {
    # mkdir with a 3s timeout. Any cloud-synced path can hang on any fs op.
    # Uses perl alarm to enforce timeout even on uninterruptible I/O.
    local dir="$1"
    perl -e '
        $SIG{ALRM} = sub { exit 1 };
        alarm 3;
        exec "mkdir", "-p", $ARGV[0];
    ' "$dir" 2>/dev/null
}

ensure_output_dirs() {
    local fallback_recordings="$HOME/Documents/Memoant/Recordings"
    local fallback_notes="$HOME/Documents/Memoant/Notes"

    if ! safe_mkdir "$RECORDINGS_DIR"; then
        log_warning "Cannot reach $RECORDINGS_DIR - saving locally"
        RECORDINGS_DIR="$fallback_recordings"
        mkdir -p "$RECORDINGS_DIR"
    fi

    if ! safe_mkdir "$NOTES_DIR"; then
        log_warning "Cannot reach $NOTES_DIR - saving locally"
        NOTES_DIR="$fallback_notes"
        mkdir -p "$NOTES_DIR"
    fi
}

#==============================================================================
# Start Recording
#==============================================================================

start_recording() {
    local mode="$1"

    # Check if already recording
    if [[ -f "$PID_FILE" ]]; then
        log_error "Recording already in progress (PID: $(cat "$PID_FILE"))"
        exit 1
    fi

    # Create temp directory
    mkdir -p "$TEMP_DIR"

    # Generate timestamp
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local temp_file=""

    case "$mode" in
        audio)
            log_info "Starting audio recording..."
            temp_file="$TEMP_DIR/recording_${timestamp}.m4a"

            # Record system audio + microphone using ffmpeg
            nohup $FFMPEG -f avfoundation -i ":0" -ac 2 -ar 48000 -ab 128k "$temp_file" > "$TEMP_DIR/ffmpeg.log" 2>&1 &
            local pid=$!
            disown $pid
            ;;

        screen)
            log_info "Starting screen recording..."
            temp_file="$TEMP_DIR/recording_${timestamp}.mp4"

            # Show graphical window picker
            log_info "Opening window selector..."
            local window_index=$(show_window_picker)

            if [[ -z "$window_index" ]] || [[ ! "$window_index" =~ ^[0-9]+$ ]]; then
                log_error "No valid window index selected"
                exit 1
            fi

            # Check if desktop (full screen) was selected
            if [[ "$window_index" == "1" ]]; then
                log_info "Recording entire desktop..."
                # Record full desktop with ffmpeg
                nohup $FFMPEG -f avfoundation -i "1:0" -r 30 -s 1920x1080 -c:v libx264 -preset ultrafast "$temp_file" > "$TEMP_DIR/ffmpeg.log" 2>&1 &
                local pid=$!
                disown $pid
            else
                # Adjust index for WindowRecorder (since Desktop is first option)
                local adjusted_index=$((window_index - 1))
                log_info "Recording window $adjusted_index..."
                log_info "Command: $WINDOW_RECORDER $temp_file $adjusted_index"
                nohup $WINDOW_RECORDER "$temp_file" "$adjusted_index" > "$TEMP_DIR/recorder.log" 2>&1 &
                local pid=$!
                disown $pid
                log_info "Started WindowRecorder with PID: $pid"
                sleep 1
                if kill -0 "$pid" 2>/dev/null; then
                    log_info "Process is running"
                else
                    log_error "Process died immediately - check $TEMP_DIR/recorder.log"
                    cat "$TEMP_DIR/recorder.log" 2>/dev/null || echo "No log file"
                    exit 1
                fi
            fi
            ;;

        *)
            log_error "Invalid mode: $mode (use 'audio' or 'screen')"
            exit 1
            ;;
    esac

    # Save PID and mode for stop command
    echo "$pid" > "$PID_FILE"
    echo "$mode" > "$MODE_FILE"
    echo "$temp_file" > "$RECORDING_FILE"

    log_success "Recording started (PID: $pid, Mode: $mode)"
    log_info "Run 'record-meeting.sh stop' to finish recording"
}

#==============================================================================
# Stop Recording
#==============================================================================

stop_recording() {
    # Check if recording exists
    if [[ ! -f "$PID_FILE" ]]; then
        log_error "No recording in progress"
        exit 1
    fi

    check_processing_deps

    local pid=$(cat "$PID_FILE")
    local mode=$(cat "$MODE_FILE")
    local recording_file=$(cat "$RECORDING_FILE")

    log_info "Stopping recording (PID: $pid)..."

    # Send interrupt signal to stop recording
    kill -INT "$pid" 2>/dev/null || true

    # Wait for process to finish (max 10 seconds)
    local wait_count=0
    while kill -0 "$pid" 2>/dev/null && [[ $wait_count -lt 10 ]]; do
        sleep 1
        wait_count=$((wait_count + 1))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        log_warning "Force stopping recording..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    # Clean up PID files
    rm -f "$PID_FILE" "$MODE_FILE"

    # Wait for file to be fully written
    sleep 2

    if [[ ! -f "$recording_file" ]]; then
        log_error "Recording file not found: $recording_file"
        exit 1
    fi

    log_success "Recording stopped: $recording_file"

    # Process the recording
    process_recording "$recording_file" "$mode"
}

#==============================================================================
# Process Recording
#==============================================================================

process_recording() {
    local recording_file="$1"
    local mode="$2"

    log_info "Processing recording..."

    # Extract audio if video file
    local audio_file=""
    if [[ "$mode" == "screen" ]]; then
        log_info "Extracting audio from video..."
        audio_file="${recording_file%.mp4}.m4a"
        $FFMPEG -i "$recording_file" -vn -acodec copy "$audio_file" -y 2>/dev/null
        log_success "Audio extracted: $audio_file"
    else
        audio_file="$recording_file"
    fi

    # Transcribe with WhisperX
    log_info "Transcribing with WhisperX (this may take a while)..."
    local transcript_dir="$TEMP_DIR/transcript"
    rm -rf "$transcript_dir"
    mkdir -p "$transcript_dir"

    # Speaker diarization: enabled by default if HF_TOKEN is set
    # To disable completely (100% offline, no HF dependency), set NO_DIARIZATION=1
    local diarize_args=""
    local hf_token_arg=""

    if [[ -z "${NO_DIARIZATION:-}" ]] && [[ -n "${HF_TOKEN:-}" ]]; then
        # Diarization enabled
        diarize_args="--diarize --vad_method pyannote"
        hf_token_arg="--hf_token $HF_TOKEN"
    else
        # Diarization disabled - uses Silero VAD (no HF required)
        diarize_args="--vad_method silero"
    fi

    $WHISPERX "$audio_file" \
        --model base.en \
        $diarize_args \
        --compute_type int8 \
        $hf_token_arg \
        --output_dir "$transcript_dir" \
        --output_format json \
        --language en \
        --device cpu 2>/dev/null

    local transcript_json="$transcript_dir/$(basename "${audio_file%.*}").json"

    if [[ ! -f "$transcript_json" ]]; then
        log_error "Transcription failed - JSON file not found"
        exit 1
    fi

    log_success "Transcription complete"

    # Format transcript with speaker labels
    local formatted_transcript=$(format_transcript "$transcript_json")

    # Extract metadata with Ollama
    log_info "Extracting metadata with Ollama..."
    local metadata=$(extract_metadata "$formatted_transcript")

    # Parse metadata JSON
    local subject=$(echo "$metadata" | jq -r '.subject // empty')
    local title=$(echo "$metadata" | jq -r '.title // empty')
    local tags=$(echo "$metadata" | jq -r '.tags // [] | join(", ")')
    local summary=$(echo "$metadata" | jq -r '.summary // ""')
    local key_points=$(echo "$metadata" | jq -r '.key_points // [] | map("- " + .) | join("\n")')
    local action_items=$(echo "$metadata" | jq -r '.action_items // [] | map("- [ ] " + .) | join("\n")')
    local decisions=$(echo "$metadata" | jq -r '.decisions // [] | map("- " + .) | join("\n")')

    # Use fallback naming if subject extraction failed
    local date=$(date +"%Y-%m-%d")
    local time=$(date +"%H-%M")
    if [[ -z "$subject" ]]; then
        subject="${date}_${time}-meeting"
        title="Meeting at $(date +"%I:%M %p")"
        log_warning "Could not extract subject, using fallback: $subject"
    fi

    # Sanitize subject for filename (lowercase, replace spaces with hyphens)
    subject=$(echo "$subject" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

    # Ensure output dirs exist (with timeout fallback for cloud paths)
    ensure_output_dirs

    # Create recordings folder
    local recording_folder="$RECORDINGS_DIR/${date}_${subject}"
    mkdir -p "$recording_folder"
    log_success "Created folder: $recording_folder"

    # Move recording to output folder
    if [[ "$mode" == "screen" ]]; then
        mv "$recording_file" "$recording_folder/recording.mp4"
        rm -f "$audio_file"  # Clean up extracted audio
        log_success "Moved video to: $recording_folder/recording.mp4"
    else
        mv "$recording_file" "$recording_folder/recording.m4a"
        log_success "Moved audio to: $recording_folder/recording.m4a"
    fi

    # Create markdown note
    local markdown_file="$NOTES_DIR/${date}_${subject}.md"
    create_markdown_note "$markdown_file" "$title" "$date" "$tags" "$summary" \
        "$key_points" "$action_items" "$decisions" "$formatted_transcript" \
        "${date}_${subject}"

    log_success "Created note: $markdown_file"

    # Clean up temp files
    rm -rf "$transcript_dir"
    rm -f "$RECORDING_FILE"

    log_success "Processing complete! ✨"
    log_info "Recording: $gdrive_folder"
    log_info "Note: $markdown_file"
}

#==============================================================================
# Format Transcript
#==============================================================================

format_transcript() {
    local json_file="$1"

    # Extract segments with speaker labels and timestamps
    python3 - "$json_file" << 'EOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    data = json.load(f)

segments = data.get('segments', [])
formatted = []

for seg in segments:
    start = seg.get('start', 0)
    text = seg.get('text', '').strip()
    speaker = seg.get('speaker', None)

    # Format timestamp as [MM:SS]
    mins = int(start // 60)
    secs = int(start % 60)
    timestamp = f"[{mins:02d}:{secs:02d}]"

    # Include speaker label only if diarization was enabled
    if speaker:
        formatted.append(f"{timestamp} {speaker}: {text}")
    else:
        formatted.append(f"{timestamp} {text}")

print('\n'.join(formatted))
EOF
}

#==============================================================================
# Extract Metadata with Ollama
#==============================================================================

extract_metadata() {
    local transcript="$1"

    # Create prompt for Ollama
    local prompt="You are analyzing a meeting transcript. Extract the following information and return ONLY valid JSON (no markdown, no code blocks, just raw JSON):

{
  \"subject\": \"brief-descriptive-subject-in-kebab-case\",
  \"title\": \"Full Meeting Title\",
  \"tags\": [\"tag1\", \"tag2\", \"tag3\"],
  \"summary\": \"2-3 sentence summary of the meeting\",
  \"key_points\": [\"point 1\", \"point 2\"],
  \"action_items\": [\"item 1\", \"item 2\"],
  \"decisions\": [\"decision 1\", \"decision 2\"]
}

Guidelines:
- subject: short, descriptive, kebab-case (e.g., \"product-demo-with-acme-corp\")
- title: human-readable title
- tags: relevant tags (always include \"meeting\")
- summary: concise overview
- key_points: main discussion points
- action_items: tasks that need to be done
- decisions: decisions that were made

Transcript:
$transcript

Return ONLY the JSON object, nothing else:"

    # Call Ollama and extract JSON
    local response=$($OLLAMA run "$OLLAMA_MODEL" "$prompt" 2>/dev/null)

    # Try to extract JSON from response (in case it's wrapped in markdown)
    local json=$(echo "$response" | sed -n '/^{/,/^}/p')

    if [[ -z "$json" ]]; then
        # Fallback if JSON extraction failed
        echo '{"subject":"","title":"Meeting","tags":["meeting"],"summary":"","key_points":[],"action_items":[],"decisions":[]}'
    else
        echo "$json"
    fi
}

#==============================================================================
# Create Markdown Note
#==============================================================================

create_markdown_note() {
    local file="$1"
    local title="$2"
    local date="$3"
    local tags="$4"
    local summary="$5"
    local key_points="$6"
    local action_items="$7"
    local decisions="$8"
    local transcript="$9"
    local folder_name="${10}"

    # Convert tags to YAML array format
    local tags_yaml=$(echo "$tags" | sed 's/, /", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    if [[ -z "$tags" ]]; then
        tags_yaml='["meeting"]'
    fi

    # Get current date/time for frontmatter
    local datetime=$(date +"%Y-%m-%dT%H:%M:%S")
    local human_date=$(date +"%B %d, %Y at %I:%M %p")

    cat > "$file" << EOF
---
title: $title
date: $datetime
attendees: []
tags: $tags_yaml
recording: "$RECORDINGS_DIR/$folder_name"
---

# $title

**Date:** $human_date
**Recording:** [View in Google Drive](x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture)

## Summary
$summary

## Action Items
$action_items

## Key Points
$key_points

## Decisions Made
$decisions

## Transcript

$transcript
EOF
}

#==============================================================================
# Main Entry Point
#==============================================================================

show_status() {
    echo -e "${BOLD:-}Memoant Configuration${NC}"
    echo "  Config:      $CONFIG_FILE"
    echo "  Recordings:  $RECORDINGS_DIR"
    echo "  Notes:       $NOTES_DIR"
    echo "  WhisperX:    $WHISPERX"
    echo "  Ollama:      $OLLAMA ($OLLAMA_MODEL)"
    echo "  ffmpeg:      $FFMPEG"
    echo ""
    if [[ -f "$PID_FILE" ]]; then
        echo -e "  Status:      ${GREEN}Recording (PID: $(cat "$PID_FILE"), Mode: $(cat "$MODE_FILE"))${NC}"
    else
        echo "  Status:      Idle"
    fi
}

main() {
    case "${1:-}" in
        audio|screen)
            check_recording_deps
            start_recording "$1"
            ;;
        stop)
            stop_recording
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {audio|screen|stop|status}"
            echo ""
            echo "Commands:"
            echo "  audio  - Start audio-only recording"
            echo "  screen - Start screen recording with window selection"
            echo "  stop   - Stop current recording and process"
            echo "  status - Show configuration and recording status"
            exit 1
            ;;
    esac
}

main "$@"
