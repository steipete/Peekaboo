#!/usr/bin/osascript
--------------------------------------------------------------------------------
-- peekaboo_enhanced.scpt - v1.0.0 "Peekaboo Pro! 👀 → 📸 → 💾"
-- Enhanced screenshot capture with multi-window support and app discovery
-- Peekaboo—screenshot got you! Now you see it, now it's saved.
--------------------------------------------------------------------------------

--#region Configuration Properties
property scriptInfoPrefix : "Peekaboo 👀: "
property defaultScreenshotFormat : "png"
property captureDelay : 1.0
property windowActivationDelay : 0.5
property enhancedErrorReporting : true
property verboseLogging : false
property maxWindowTitleLength : 50
--#endregion Configuration Properties

--#region Helper Functions
on isValidPath(thePath)
    if thePath is not "" and (thePath starts with "/") then
        return true
    end if
    return false
end isValidPath

on getFileExtension(filePath)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to "."
    set pathParts to text items of filePath
    set AppleScript's text item delimiters to oldDelims
    if (count pathParts) > 1 then
        return item -1 of pathParts
    else
        return ""
    end if
end getFileExtension

on ensureDirectoryExists(dirPath)
    try
        do shell script "mkdir -p " & quoted form of dirPath
        return true
    on error
        return false
    end try
end ensureDirectoryExists

on sanitizeFilename(filename)
    -- Replace problematic characters for filenames
    set filename to my replaceText(filename, "/", "_")
    set filename to my replaceText(filename, ":", "_")
    set filename to my replaceText(filename, "*", "_")
    set filename to my replaceText(filename, "?", "_")
    set filename to my replaceText(filename, "\"", "_")
    set filename to my replaceText(filename, "<", "_")
    set filename to my replaceText(filename, ">", "_")
    set filename to my replaceText(filename, "|", "_")
    if (length of filename) > maxWindowTitleLength then
        set filename to text 1 thru maxWindowTitleLength of filename
    end if
    return filename
end sanitizeFilename

on replaceText(theText, searchStr, replaceStr)
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to searchStr
    set textItems to text items of theText
    set AppleScript's text item delimiters to replaceStr
    set newText to textItems as text
    set AppleScript's text item delimiters to oldDelims
    return newText
end replaceText

on formatErrorMessage(errorType, errorMsg, context)
    if enhancedErrorReporting then
        set formattedMsg to scriptInfoPrefix & errorType & ": " & errorMsg
        if context is not "" then
            set formattedMsg to formattedMsg & " (Context: " & context & ")"
        end if
        return formattedMsg
    else
        return scriptInfoPrefix & errorMsg
    end if
end formatErrorMessage

on logVerbose(message)
    if verboseLogging then
        log "🔍 " & message
    end if
end logVerbose

on trimWhitespace(theText)
    set whitespaceChars to {" ", tab}
    set newText to theText
    repeat while (newText is not "") and (character 1 of newText is in whitespaceChars)
        if (length of newText) > 1 then
            set newText to text 2 thru -1 of newText
        else
            set newText to ""
        end if
    end repeat
    repeat while (newText is not "") and (character -1 of newText is in whitespaceChars)
        if (length of newText) > 1 then
            set newText to text 1 thru -2 of newText
        else
            set newText to ""
        end if
    end repeat
    return newText
end trimWhitespace
--#endregion Helper Functions

--#region App Discovery Functions
on listRunningApps()
    set appList to {}
    try
        tell application "System Events"
            repeat with proc in (every application process whose background only is false)
                try
                    set appName to name of proc
                    set bundleID to bundle identifier of proc
                    set windowCount to count of windows of proc
                    set windowTitles to {}
                    
                    if windowCount > 0 then
                        repeat with win in windows of proc
                            try
                                set winTitle to title of win
                                if winTitle is not "" then
                                    set end of windowTitles to winTitle
                                end if
                            on error
                                -- Skip windows without accessible titles
                            end try
                        end repeat
                    end if
                    
                    set end of appList to {appName:appName, bundleID:bundleID, windowCount:windowCount, windowTitles:windowTitles}
                on error
                    -- Skip apps we can't access
                end try
            end repeat
        end tell
    on error errMsg
        return my formatErrorMessage("Discovery Error", "Failed to enumerate running applications: " & errMsg, "app enumeration")
    end try
    return appList
end listRunningApps

on formatAppList(appList)
    if appList starts with scriptInfoPrefix then
        return appList -- Error message
    end if
    
    set output to scriptInfoPrefix & "Running Applications:" & linefeed & linefeed
    
    repeat with appInfo in appList
        set appName to appName of appInfo
        set bundleID to bundleID of appInfo
        set windowCount to windowCount of appInfo
        set windowTitles to windowTitles of appInfo
        
        set output to output & "• " & appName & " (" & bundleID & ")" & linefeed
        set output to output & "  Windows: " & windowCount
        
        if windowCount > 0 and (count of windowTitles) > 0 then
            set output to output & linefeed
            repeat with winTitle in windowTitles
                set output to output & "    - \"" & winTitle & "\"" & linefeed
            end repeat
        else
            set output to output & linefeed
        end if
        set output to output & linefeed
    end repeat
    
    return output
end formatAppList
--#endregion App Discovery Functions

--#region App Resolution Functions
on resolveAppIdentifier(appIdentifier)
    my logVerbose("Resolving app identifier: " & appIdentifier)
    
    -- First try as bundle ID
    try
        tell application "System Events"
            set bundleApps to (every application process whose bundle identifier is appIdentifier)
            if (count bundleApps) > 0 then
                set targetApp to item 1 of bundleApps
                set appName to name of targetApp
                my logVerbose("Found running app by bundle ID: " & appName)
                return {appName:appName, bundleID:appIdentifier, isRunning:true, resolvedBy:"bundle_id"}
            end if
        end tell
    on error
        my logVerbose("Bundle ID lookup failed, trying as app name")
    end try
    
    -- Try as application name for running apps
    try
        tell application "System Events"
            set nameApps to (every application process whose name is appIdentifier)
            if (count nameApps) > 0 then
                set targetApp to item 1 of nameApps
                try
                    set bundleID to bundle identifier of targetApp
                on error
                    set bundleID to ""
                end try
                my logVerbose("Found running app by name: " & appIdentifier)
                return {appName:appIdentifier, bundleID:bundleID, isRunning:true, resolvedBy:"app_name"}
            end if
        end tell
    on error
        my logVerbose("App name lookup failed for running processes")
    end try
    
    -- Try to find the app in /Applications (not running)
    try
        set appPath to "/Applications/" & appIdentifier & ".app"
        tell application "System Events"
            if exists file appPath then
                try
                    set bundleID to bundle identifier of file appPath
                on error
                    set bundleID to ""
                end try
                my logVerbose("Found app in /Applications: " & appIdentifier)
                return {appName:appIdentifier, bundleID:bundleID, isRunning:false, resolvedBy:"applications_folder"}
            end if
        end tell
    on error
        my logVerbose("/Applications lookup failed")
    end try
    
    -- If it looks like a bundle ID, try launching it directly
    if appIdentifier contains "." then
        try
            tell application "System Events"
                launch application id appIdentifier
                delay windowActivationDelay
                set bundleApps to (every application process whose bundle identifier is appIdentifier)
                if (count bundleApps) > 0 then
                    set targetApp to item 1 of bundleApps
                    set appName to name of targetApp
                    my logVerbose("Successfully launched app by bundle ID: " & appName)
                    return {appName:appName, bundleID:appIdentifier, isRunning:true, resolvedBy:"bundle_id_launch"}
                end if
            end tell
        on error errMsg
            my logVerbose("Bundle ID launch failed: " & errMsg)
        end try
    end if
    
    return missing value
end resolveAppIdentifier

on getAppWindows(appName)
    set windowInfo to {}
    set windowCount to 0
    set accessibleWindows to 0
    
    try
        tell application "System Events"
            tell process appName
                set windowCount to count of windows
                repeat with i from 1 to windowCount
                    try
                        set win to window i
                        set winTitle to title of win
                        if winTitle is "" then set winTitle to "Untitled Window " & i
                        set end of windowInfo to {winTitle, i}
                        set accessibleWindows to accessibleWindows + 1
                    on error
                        set end of windowInfo to {("Window " & i), i}
                    end try
                end repeat
            end tell
        end tell
    on error errMsg
        my logVerbose("Failed to get windows for " & appName & ": " & errMsg)
        return {windowInfo:windowInfo, totalWindows:0, accessibleWindows:0, errorMsg:errMsg}
    end try
    
    return {windowInfo:windowInfo, totalWindows:windowCount, accessibleWindows:accessibleWindows, errorMsg:""}
end getAppWindows

on getAppWindowStatus(appName)
    set windowStatus to my getAppWindows(appName)
    set windowInfo to windowInfo of windowStatus
    set totalWindows to totalWindows of windowStatus
    set accessibleWindows to accessibleWindows of windowStatus
    set windowError to errorMsg of windowStatus
    
    if windowError is not "" then
        return my formatErrorMessage("Window Access Error", "Cannot access windows for app '" & appName & "': " & windowError & ". The app may not be running or may not have accessibility permissions.", "window enumeration")
    end if
    
    if totalWindows = 0 then
        return my formatErrorMessage("No Windows Error", "App '" & appName & "' is running but has no windows open. Peekaboo needs at least one window to capture. Please open a window in " & appName & " and try again.", "zero windows")
    end if
    
    if accessibleWindows = 0 and totalWindows > 0 then
        return my formatErrorMessage("Window Access Error", "App '" & appName & "' has " & totalWindows & " window(s) but none are accessible. This may require accessibility permissions in System Preferences > Security & Privacy > Accessibility.", "accessibility required")
    end if
    
    -- Success case
    set statusMsg to "App '" & appName & "' has " & totalWindows & " window(s)"
    if accessibleWindows < totalWindows then
        set statusMsg to statusMsg & " (" & accessibleWindows & " accessible)"
    end if
    
    return {status:"success", message:statusMsg, windowInfo:windowInfo, totalWindows:totalWindows, accessibleWindows:accessibleWindows}
end getAppWindowStatus

on bringAppToFront(appInfo)
    set appName to appName of appInfo
    set isRunning to isRunning of appInfo
    
    my logVerbose("Bringing app to front: " & appName & " (running: " & isRunning & ")")
    
    if not isRunning then
        try
            tell application appName to activate
            delay windowActivationDelay
        on error errMsg
            return my formatErrorMessage("Activation Error", "Failed to launch app '" & appName & "': " & errMsg, "app launch")
        end try
    else
        try
            tell application "System Events"
                tell process appName
                    set frontmost to true
                end tell
            end tell
            delay windowActivationDelay
        on error errMsg
            return my formatErrorMessage("Focus Error", "Failed to bring app '" & appName & "' to front: " & errMsg, "app focus")
        end try
    end if
    
    return ""
end bringAppToFront
--#endregion App Resolution Functions

--#region Screenshot Functions
on captureScreenshot(outputPath, captureMode, appName)
    my logVerbose("Capturing screenshot to: " & outputPath & " (mode: " & captureMode & ")")
    
    -- Ensure output directory exists
    set outputDir to do shell script "dirname " & quoted form of outputPath
    if not my ensureDirectoryExists(outputDir) then
        return my formatErrorMessage("Directory Error", "Could not create output directory: " & outputDir, "directory creation")
    end if
    
    -- Wait for capture delay
    delay captureDelay
    
    -- Determine screenshot format
    set fileExt to my getFileExtension(outputPath)
    if fileExt is "" then
        set fileExt to defaultScreenshotFormat
        set outputPath to outputPath & "." & fileExt
    end if
    
    -- Build screencapture command based on mode
    set screencaptureCmd to "screencapture -x"
    
    if captureMode is "window" then
        -- Use frontmost window without interaction
        set screencaptureCmd to screencaptureCmd & " -o -W"
    end if
    -- Remove interactive mode - not suitable for unattended operation
    
    -- Add format flag if not PNG (default)
    if fileExt is not "png" then
        set screencaptureCmd to screencaptureCmd & " -t " & fileExt
    end if
    
    -- Add output path
    set screencaptureCmd to screencaptureCmd & " " & quoted form of outputPath
    
    -- Capture screenshot
    try
        my logVerbose("Running: " & screencaptureCmd)
        do shell script screencaptureCmd
        
        -- Verify file was created
        try
            do shell script "test -f " & quoted form of outputPath
            return outputPath
        on error
            return my formatErrorMessage("Capture Error", "Screenshot file was not created at: " & outputPath, "file verification")
        end try
        
    on error errMsg number errNum
        -- Enhanced error handling for common screencapture issues
        if errMsg contains "not authorized" or errMsg contains "Screen Recording" then
            return my formatErrorMessage("Permission Error", "Screen Recording permission required. Please go to System Preferences > Security & Privacy > Screen Recording and add your terminal app to the allowed list. Then restart your terminal and try again.", "screen recording permission")
        else if errMsg contains "No such file" then
            return my formatErrorMessage("Path Error", "Cannot create screenshot at '" & outputPath & "'. Check that the directory exists and you have write permissions.", "file creation")
        else if errMsg contains "Permission denied" then
            return my formatErrorMessage("Permission Error", "Permission denied writing to '" & outputPath & "'. Check file/directory permissions or try a different location like /tmp/", "write permission")
        else
            return my formatErrorMessage("Capture Error", "screencapture failed: " & errMsg & ". This may be due to permissions, disk space, or system restrictions.", "error " & errNum)
        end if
    end try
end captureScreenshot

on captureMultipleWindows(appName, baseOutputPath)
    -- Get detailed window status first
    set windowStatus to my getAppWindowStatus(appName)
    
    -- Check if it's an error
    if (windowStatus starts with scriptInfoPrefix) then
        return windowStatus -- Return the descriptive error
    end if
    
    -- Extract window info from successful status
    set windowInfo to windowInfo of windowStatus
    set totalWindows to totalWindows of windowStatus
    set accessibleWindows to accessibleWindows of windowStatus
    set capturedFiles to {}
    
    my logVerbose("Multi-window capture: " & totalWindows & " total, " & accessibleWindows & " accessible")
    
    if (count of windowInfo) = 0 then
        return my formatErrorMessage("Multi-Window Error", "App '" & appName & "' has no accessible windows for multi-window capture. Try using single screenshot mode instead, or ensure the app has open windows.", "no accessible windows")
    end if
    
    -- Get base path components
    set outputDir to do shell script "dirname " & quoted form of baseOutputPath
    set baseName to do shell script "basename " & quoted form of baseOutputPath
    set fileExt to my getFileExtension(baseName)
    if fileExt is not "" then
        set baseNameNoExt to text 1 thru -((length of fileExt) + 2) of baseName
    else
        set baseNameNoExt to baseName
        set fileExt to defaultScreenshotFormat
    end if
    
    my logVerbose("Capturing " & (count of windowInfo) & " windows for " & appName)
    
    repeat with winInfo in windowInfo
        set winTitle to item 1 of winInfo
        set winIndex to item 2 of winInfo
        set sanitizedTitle to my sanitizeFilename(winTitle)
        
        set windowFileName to baseNameNoExt & "_window_" & winIndex & "_" & sanitizedTitle & "." & fileExt
        set windowOutputPath to outputDir & "/" & windowFileName
        
        -- Focus the specific window first
        try
            tell application "System Events"
                tell process appName
                    set frontmost to true
                    tell window winIndex
                        perform action "AXRaise"
                    end tell
                end tell
            end tell
            delay 0.3
        on error
            my logVerbose("Could not focus window " & winIndex & ", continuing anyway")
        end try
        
        -- Capture the frontmost window
        set captureResult to my captureScreenshot(windowOutputPath, "window", appName)
        if captureResult starts with scriptInfoPrefix then
            -- Error occurred, but continue with other windows
            my logVerbose("Failed to capture window " & winIndex & ": " & captureResult)
        else
            set end of capturedFiles to {captureResult, winTitle, winIndex}
        end if
    end repeat
    
    return capturedFiles
end captureMultipleWindows
--#endregion Screenshot Functions

--#region Main Script Logic (on run)
on run argv
    set appSpecificErrorOccurred to false
    try
        my logVerbose("Starting Screenshotter Enhanced v2.0.0")
        
        set argCount to count argv
        
        -- Handle special commands
        if argCount = 1 then
            set command to item 1 of argv
            if command is "list" or command is "--list" or command is "-l" then
                set appList to my listRunningApps()
                return my formatAppList(appList)
            else if command is "help" or command is "--help" or command is "-h" then
                return my usageText()
            end if
        end if
        
        if argCount < 1 then return my usageText()
        
        set appIdentifier to item 1 of argv
        
        -- Use default tmp path if no output path provided
        if argCount >= 2 then
            set outputPath to item 2 of argv
        else
            set timestamp to do shell script "date +%Y%m%d_%H%M%S"
            set outputPath to "/tmp/peekaboo_" & timestamp & ".png"
        end if
        set captureMode to "screen" -- default
        set multiWindow to false
        
        -- Parse additional options
        if argCount > 2 then
            repeat with i from 3 to argCount
                set arg to item i of argv
                if arg is "--window" or arg is "-w" then
                    set captureMode to "window"
                -- Remove interactive mode option
                else if arg is "--multi" or arg is "-m" then
                    set multiWindow to true
                else if arg is "--verbose" or arg is "-v" then
                    set verboseLogging to true
                end if
            end repeat
        end if
        
        -- Validate arguments
        if appIdentifier is "" then
            return my formatErrorMessage("Argument Error", "App identifier cannot be empty." & linefeed & linefeed & my usageText(), "validation")
        end if
        
        if argCount >= 2 and not my isValidPath(outputPath) then
            return my formatErrorMessage("Argument Error", "Output path must be an absolute path starting with '/'." & linefeed & linefeed & my usageText(), "validation")
        end if
        
        -- Resolve app identifier with detailed diagnostics
        set appInfo to my resolveAppIdentifier(appIdentifier)
        if appInfo is missing value then
            set errorDetails to "Could not resolve app identifier '" & appIdentifier & "'."
            
            -- Provide specific guidance based on identifier type
            if appIdentifier contains "." then
                set errorDetails to errorDetails & " This appears to be a bundle ID. Common issues:" & linefeed
                set errorDetails to errorDetails & "• Bundle ID may be incorrect (try 'com.apple.' prefix for system apps)" & linefeed
                set errorDetails to errorDetails & "• App may not be installed" & linefeed
                set errorDetails to errorDetails & "• Use 'osascript peekaboo_enhanced.scpt list' to see available apps"
            else
                set errorDetails to errorDetails & " This appears to be an app name. Common issues:" & linefeed
                set errorDetails to errorDetails & "• App name may be incorrect (case-sensitive)" & linefeed
                set errorDetails to errorDetails & "• App may not be installed or running" & linefeed
                set errorDetails to errorDetails & "• Try the full app name (e.g., 'Activity Monitor' not 'Activity')" & linefeed
                set errorDetails to errorDetails & "• Use 'osascript peekaboo_enhanced.scpt list' to see running apps"
            end if
            
            return my formatErrorMessage("App Resolution Error", errorDetails, "app resolution")
        end if
        
        set resolvedAppName to appName of appInfo
        set resolvedBy to resolvedBy of appInfo
        my logVerbose("App resolved: " & resolvedAppName & " (method: " & resolvedBy & ")")
        
        -- Bring app to front
        set frontError to my bringAppToFront(appInfo)
        if frontError is not "" then return frontError
        
        -- Pre-capture window validation for better error messages
        if multiWindow or captureMode is "window" then
            set windowStatus to my getAppWindowStatus(resolvedAppName)
            if (windowStatus starts with scriptInfoPrefix) then
                -- Add context about what the user was trying to do
                if multiWindow then
                    set contextError to "Multi-window capture failed: " & windowStatus
                    set contextError to contextError & linefeed & "💡 Suggestion: Try basic screenshot mode without --multi flag"
                else
                    set contextError to "Window capture failed: " & windowStatus  
                    set contextError to contextError & linefeed & "💡 Suggestion: Try full-screen capture mode without --window flag"
                end if
                return contextError
            end if
            
            -- Log successful window detection
            set statusMsg to message of windowStatus
            my logVerbose("Window validation passed: " & statusMsg)
        end if
        
        -- Handle multi-window capture
        if multiWindow then
            set capturedFiles to my captureMultipleWindows(resolvedAppName, outputPath)
            if capturedFiles starts with scriptInfoPrefix then
                return capturedFiles -- Error message
            else
                set windowCount to count of capturedFiles
                set resultMsg to scriptInfoPrefix & "Multi-window capture successful! Captured " & windowCount & " window(s) for " & resolvedAppName & ":" & linefeed
                repeat with fileInfo in capturedFiles
                    set filePath to item 1 of fileInfo
                    set winTitle to item 2 of fileInfo
                    set resultMsg to resultMsg & "  📸 " & filePath & " → \"" & winTitle & "\"" & linefeed
                end repeat
                set resultMsg to resultMsg & linefeed & "💡 All windows captured with descriptive filenames. Each file shows a different window of " & resolvedAppName & "."
                return resultMsg
            end if
        else
            -- Single capture
            set screenshotResult to my captureScreenshot(outputPath, captureMode, resolvedAppName)
            if screenshotResult starts with scriptInfoPrefix then
                return screenshotResult -- Error message
            else
                set modeDescription to "full screen"
                if captureMode is "window" then set modeDescription to "front window only"
                
                return scriptInfoPrefix & "Screenshot captured successfully! 📸" & linefeed & "• File: " & screenshotResult & linefeed & "• App: " & resolvedAppName & linefeed & "• Mode: " & modeDescription & linefeed & "💡 The " & modeDescription & " of " & resolvedAppName & " has been saved."
            end if
        end if
        
    on error generalErrorMsg number generalErrorNum
        if appSpecificErrorOccurred then error generalErrorMsg number generalErrorNum
        return my formatErrorMessage("Execution Error", generalErrorMsg, "error " & generalErrorNum)
    end try
end run
--#endregion Main Script Logic (on run)

--#region Usage Function
on usageText()
    set LF to linefeed
    set scriptName to "peekaboo_enhanced.scpt"
    
    set outText to scriptName & " - v1.0.0 \"Peekaboo Pro! 👀 → 📸 → 💾\" – Enhanced AppleScript Screenshot Utility" & LF & LF
    set outText to outText & "Peekaboo—screenshot got you! Now you see it, now it's saved." & LF
    set outText to outText & "Takes unattended screenshots with multi-window support and app discovery." & LF & LF
    
    set outText to outText & "Usage:" & LF
    set outText to outText & "  osascript " & scriptName & " \"<app_name_or_bundle_id>\" [\"<output_path>\"] [options]" & LF
    set outText to outText & "  osascript " & scriptName & " list" & LF
    set outText to outText & "  osascript " & scriptName & " help" & LF & LF
    
    set outText to outText & "Parameters:" & LF
    set outText to outText & "  app_name_or_bundle_id: Application name (e.g., 'Safari') or bundle ID (e.g., 'com.apple.Safari')" & LF
    set outText to outText & "  output_path:          Optional absolute path for screenshot file(s)" & LF
    set outText to outText & "                        If not provided, saves to /tmp/peekaboo_TIMESTAMP.png" & LF & LF
    
    set outText to outText & "Options:" & LF
    set outText to outText & "  --window, -w:         Capture frontmost window only" & LF
    set outText to outText & "  --interactive, -i:    Interactive window selection" & LF
    set outText to outText & "  --multi, -m:          Capture all windows with descriptive names" & LF
    set outText to outText & "  --verbose, -v:        Enable verbose logging" & LF & LF
    
    set outText to outText & "Commands:" & LF
    set outText to outText & "  list:                 List all running apps with window titles" & LF
    set outText to outText & "  help:                 Show this help message" & LF & LF
    
    set outText to outText & "Examples:" & LF
    set outText to outText & "  # List running applications:" & LF
    set outText to outText & "  osascript " & scriptName & " list" & LF
    set outText to outText & "  # Screenshot Safari to /tmp with timestamp:" & LF
    set outText to outText & "  osascript " & scriptName & " \"Safari\"" & LF
    set outText to outText & "  # Full screen capture with custom path:" & LF
    set outText to outText & "  osascript " & scriptName & " \"Safari\" \"/Users/username/Desktop/safari.png\"" & LF
    set outText to outText & "  # Front window only:" & LF
    set outText to outText & "  osascript " & scriptName & " \"TextEdit\" \"/tmp/textedit.png\" --window" & LF
    set outText to outText & "  # All windows with descriptive names:" & LF
    set outText to outText & "  osascript " & scriptName & " \"Safari\" \"/tmp/safari_windows.png\" --multi" & LF & LF
    
    set outText to outText & "Multi-Window Features:" & LF
    set outText to outText & "  • --multi creates separate files with descriptive names" & LF
    set outText to outText & "  • Window titles are sanitized for safe filenames" & LF
    set outText to outText & "  • Files named as: basename_window_N_title.ext" & LF
    set outText to outText & "  • Each window is focused before capture for accuracy" & LF & LF
    
    set outText to outText & "Notes:" & LF
    set outText to outText & "  • Requires Screen Recording permission in System Preferences" & LF
    set outText to outText & "  • Accessibility permission may be needed for window enumeration" & LF
    set outText to outText & "  • Window titles longer than " & maxWindowTitleLength & " characters are truncated" & LF
    set outText to outText & "  • Default capture delay: " & (captureDelay as string) & " second(s)" & LF
    
    return outText
end usageText
--#endregion Usage Function