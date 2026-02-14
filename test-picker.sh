#!/bin/bash

# Test the window picker
window_data=$(osascript << 'OSEOF'
tell application "System Events"
    set windowList to {}
    set appList to (name of every application process whose visible is true)

    repeat with appName in appList
        try
            tell application process appName
                set appWindows to (name of every window)
                repeat with winName in appWindows
                    if winName is not "" then
                        set end of windowList to (appName as text) & " - " & (winName as text)
                    end if
                end repeat
            end tell
        end try
    end repeat

    return windowList
end tell
OSEOF
)

echo "Window data: $window_data"
echo ""

# Convert and show dialog
IFS=',' read -ra WINDOWS <<< "$window_data"
applescript_list=""
index=1

for window in "${WINDOWS[@]}"; do
    window=$(echo "$window" | xargs)
    if [[ -n "$window" ]]; then
        applescript_list+="\"$index. $window\", "
        ((index++))
    fi
done
applescript_list="${applescript_list%, }"

echo "AppleScript list: $applescript_list"
echo ""

selection=$(osascript << EOF
tell application "System Events"
    activate
    set windowList to {$applescript_list}
    set selectedWindow to choose from list windowList with prompt "Select a window to record:" with title "Memoant - Window Recorder" default items (item 1 of windowList) cancel button name "Cancel" OK button name "Record"

    if selectedWindow is false then
        return ""
    else
        return selectedWindow as text
    end if
end tell
EOF
)

echo "Selection: $selection"

window_index=$(echo "$selection" | sed 's/^\([0-9]*\)\..*/\1/')
echo "Window index: $window_index"
