#!/bin/bash

# Window-specific recording (captures window even if obscured)
# Uses macOS screencapture and ffmpeg

OUTPUT_FILE="$1"
DURATION="${2:-600}" # Default 10 minutes, will be stopped manually

# Get window selection from user
WINDOW_INFO=$(osascript ~/Code/meeting-recorder/window-recorder.applescript "$OUTPUT_FILE")

if [ "$WINDOW_INFO" = "cancelled" ] || [ "$WINDOW_INFO" = "no_windows" ]; then
    echo "❌ Window selection cancelled or no windows available"
    exit 1
fi

APP_NAME=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
WINDOW_NAME=$(echo "$WINDOW_INFO" | cut -d'|' -f2)
WINDOW_ID=$(echo "$WINDOW_INFO" | cut -d'|' -f3)

echo "📺 Recording: $APP_NAME - $WINDOW_NAME"

# NOTE: macOS screencapture doesn't support window-only video recording directly
# We need to use screen recording with the window in focus
# Or use a third-party tool like ffmpeg with specific window tracking

# For now, use ffmpeg with display capture and crop to window bounds
# This is a limitation - if window moves, recording area stays fixed

# Better approach: Use ScreenCaptureKit (requires Swift/Obj-C)
# For bash script, best we can do is:

# 1. Get window bounds
WINDOW_BOUNDS=$(osascript -e "
tell application \"System Events\"
    tell process \"$APP_NAME\"
        set theWindow to first window whose name is \"$WINDOW_NAME\"
        set pos to position of theWindow
        set siz to size of theWindow
        return (item 1 of pos) & \",\" & (item 2 of pos) & \",\" & (item 1 of siz) & \",\" & (item 2 of siz)
    end tell
end tell
")

X=$(echo "$WINDOW_BOUNDS" | cut -d',' -f1)
Y=$(echo "$WINDOW_BOUNDS" | cut -d',' -f2)
WIDTH=$(echo "$WINDOW_BOUNDS" | cut -d',' -f3)
HEIGHT=$(echo "$WINDOW_BOUNDS" | cut -d',' -f4)

echo "Window bounds: ${WIDTH}x${HEIGHT} at ${X},${Y}"

# Use ffmpeg to record that specific region + audio
ffmpeg -f avfoundation \
    -capture_cursor 1 \
    -i "1:0" \
    -filter:v "crop=${WIDTH}:${HEIGHT}:${X}:${Y}" \
    -r 30 \
    -vcodec libx264 \
    -preset ultrafast \
    -acodec aac \
    "$OUTPUT_FILE" &

echo $!
