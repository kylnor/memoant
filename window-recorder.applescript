-- Window-specific screen recording using macOS APIs
-- This captures ONLY the selected window, even if it's behind other windows

on run argv
    set outputFile to item 1 of argv

    -- Prompt user to select a window
    tell application "System Events"
        set processList to every application process whose visible is true
        set processNames to name of processList
    end tell

    -- Let user choose which app
    set chosenApp to choose from list processNames with prompt "Select application to record:"
    if chosenApp is false then
        return "cancelled"
    end if

    set appName to item 1 of chosenApp

    -- Get windows from that app
    tell application "System Events"
        tell process appName
            set windowList to name of every window
        end tell
    end tell

    if (count of windowList) > 1 then
        set chosenWindow to choose from list windowList with prompt "Select window to record:"
        if chosenWindow is false then
            return "cancelled"
        end if
        set windowName to item 1 of chosenWindow
    else if (count of windowList) = 1 then
        set windowName to item 1 of windowList
    else
        return "no_windows"
    end if

    -- Start recording using screencapture with window ID
    tell application "System Events"
        tell process appName
            set theWindow to first window whose name is windowName
            set windowID to id of theWindow
        end tell
    end tell

    -- Return window info for the shell script
    return appName & "|" & windowName & "|" & windowID
end run
