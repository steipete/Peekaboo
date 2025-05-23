#!/usr/bin/osascript
--------------------------------------------------------------------------------
-- peekaboo.scpt - v1.0.0 "Peekaboo Pro! 👀 → 📸 → 💾"
-- Enhanced screenshot capture with multi-window support and app discovery
-- Peekaboo—screenshot got you! Now you see it, now it's saved.
--
-- IMPORTANT: This script uses non-interactive screencapture methods
-- Do NOT use flags like -o -W which require user interaction
-- Instead use -l<windowID> for specific window capture
--------------------------------------------------------------------------------

--#region Configuration Properties
property scriptInfoPrefix : "Peekaboo 👀: "
property defaultScreenshotFormat : "png"
property captureDelay : 0.3
property windowActivationDelay : 0.2
property enhancedErrorReporting : true
property verboseLogging : false
property maxWindowTitleLength : 50
-- AI Analysis Configuration  
property defaultVisionModel : "qwen2.5vl:7b"
-- Prioritized list of vision models (best to fallback)
property visionModelPriority : {"qwen2.5vl:7b", "llava:7b", "llava-phi3:3.8b", "minicpm-v:8b", "gemma3:4b", "llava:latest", "qwen2.5vl:3b", "llava:13b", "llava-llama3:8b"}
-- AI Provider Configuration
property aiProvider : "auto" -- "auto", "ollama", "claude"
property claudeModel : "sonnet" -- default Claude model alias
-- AI Analysis Timeout (90 seconds)
property aiAnalysisTimeout : 90
-- Image Resize Configuration
property defaultImageMaxDimension : 0 -- 0 means no resize, otherwise max width/height in pixels
property defaultAIResizePercent : 50 -- Default resize percentage for AI analysis (50 = 50%)
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

on sanitizeAppName(appName)
    -- Create model-friendly app names (lowercase, underscores, no spaces)
    set appName to my replaceText(appName, " ", "_")
    set appName to my replaceText(appName, ".", "_")
    set appName to my replaceText(appName, "-", "_")
    set appName to my replaceText(appName, "/", "_")
    set appName to my replaceText(appName, ":", "_")
    set appName to my replaceText(appName, "*", "_")
    set appName to my replaceText(appName, "?", "_")
    set appName to my replaceText(appName, "\"", "_")
    set appName to my replaceText(appName, "<", "_")
    set appName to my replaceText(appName, ">", "_")
    set appName to my replaceText(appName, "|", "_")
    -- Convert to lowercase using shell
    try
        set appName to do shell script "echo " & quoted form of appName & " | tr '[:upper:]' '[:lower:]'"
    on error
        -- Fallback if shell command fails
    end try
    -- Limit length for readability
    if (length of appName) > 20 then
        set appName to text 1 thru 20 of appName
    end if
    return appName
end sanitizeAppName

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

on formatCaptureOutput(outputPath, appName, mode, isQuiet)
    if isQuiet then
        return outputPath
    else
        set msg to scriptInfoPrefix & "Screenshot captured successfully! 📸" & linefeed
        set msg to msg & "• File: " & outputPath & linefeed
        set msg to msg & "• App: " & appName & linefeed
        set msg to msg & "• Mode: " & mode
        return msg
    end if
end formatCaptureOutput

on formatMultiOutput(capturedFiles, appName, isQuiet)
    if isQuiet then
        -- Just return paths separated by newlines
        set paths to ""
        repeat with fileInfo in capturedFiles
            set filePath to item 1 of fileInfo
            set paths to paths & filePath & linefeed
        end repeat
        return paths
    else
        set windowCount to count of capturedFiles
        set msg to scriptInfoPrefix & "Multi-window capture successful! Captured " & windowCount & " window(s) for " & appName & ":" & linefeed
        repeat with fileInfo in capturedFiles
            set filePath to item 1 of fileInfo
            set winTitle to item 2 of fileInfo
            set msg to msg & "  📸 " & filePath & " → \"" & winTitle & "\"" & linefeed
        end repeat
        return msg
    end if
end formatMultiOutput

on formatMultiWindowAnalysis(capturedFiles, analysisResults, appName, question, model, isQuiet)
    if isQuiet then
        -- In quiet mode, return condensed results
        set output to ""
        repeat with result in analysisResults
            set winTitle to windowTitle of result
            set answer to answer of result
            set output to output & scriptInfoPrefix & "Window \"" & winTitle & "\": " & answer & linefeed
        end repeat
        return output
    else
        -- Full formatted output
        set windowCount to count of capturedFiles
        set msg to scriptInfoPrefix & "Multi-window AI Analysis Complete! 🤖" & linefeed & linefeed
        set msg to msg & "📸 App: " & appName & " (" & windowCount & " windows)" & linefeed
        set msg to msg & "❓ Question: " & question & linefeed
        set msg to msg & "🤖 Model: " & model & linefeed & linefeed
        
        set msg to msg & "💬 Results for each window:" & linefeed & linefeed
        
        set windowNum to 1
        repeat with result in analysisResults
            set winTitle to windowTitle of result
            set winIndex to windowIndex of result
            set answer to answer of result
            set success to success of result
            
            set msg to msg & "🪟 Window " & windowNum & ": \"" & winTitle & "\"" & linefeed
            if success then
                set msg to msg & answer & linefeed & linefeed
            else
                set msg to msg & "⚠️ Analysis failed: " & answer & linefeed & linefeed
            end if
            
            set windowNum to windowNum + 1
        end repeat
        
        -- Add timing info if available
        set msg to msg & scriptInfoPrefix & "Analysis of " & windowCount & " windows complete."
        
        return msg
    end if
end formatMultiWindowAnalysis
--#endregion Helper Functions

--#region AI Analysis Functions
on checkOllamaAvailable()
    try
        -- Check if ollama command exists
        do shell script "ollama --version >/dev/null 2>&1"
        -- Check if ollama service is running by testing API
        do shell script "curl -s http://localhost:11434/api/tags >/dev/null 2>&1"
        return true
    on error
        return false
    end try
end checkOllamaAvailable

on checkClaudeAvailable()
    try
        -- Check if claude command exists
        do shell script "claude --version >/dev/null 2>&1"
        return true
    on error
        return false
    end try
end checkClaudeAvailable

on getAvailableVisionModels()
    set availableModels to {}
    try
        set ollamaList to do shell script "ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^$'"
        set modelLines to paragraphs of ollamaList
        repeat with modelLine in modelLines
            set modelName to contents of modelLine
            if modelName is not "" then
                set end of availableModels to modelName
            end if
        end repeat
    on error
        -- Return empty list if ollama list fails
    end try
    return availableModels
end getAvailableVisionModels

on findBestVisionModel(requestedModel)
    my logVerbose("Finding best vision model, requested: " & requestedModel)
    
    set availableModels to my getAvailableVisionModels()
    my logVerbose("Available models: " & (availableModels as string))
    
    -- If specific model requested and available, use it
    if requestedModel is not defaultVisionModel then
        repeat with availModel in availableModels
            if contents of availModel is requestedModel then
                my logVerbose("Using requested model: " & requestedModel)
                return requestedModel
            end if
        end repeat
        -- Requested model not found, will fall back to priority list
        my logVerbose("Requested model '" & requestedModel & "' not found, checking priority list")
    end if
    
    -- Find best available model from priority list
    repeat with priorityModel in visionModelPriority
        repeat with availModel in availableModels
            if contents of availModel is contents of priorityModel then
                my logVerbose("Using priority model: " & contents of priorityModel)
                return contents of priorityModel
            end if
        end repeat
    end repeat
    
    -- No priority models available, use first available vision model
    repeat with availModel in availableModels
        set modelName to contents of availModel
        if modelName contains "llava" or modelName contains "qwen" or modelName contains "gemma" or modelName contains "minicpm" then
            my logVerbose("Using first available vision model: " & modelName)
            return modelName
        end if
    end repeat
    
    -- No vision models found
    return ""
end findBestVisionModel

on getOllamaInstallInstructions()
    set instructions to scriptInfoPrefix & "AI Analysis requires Ollama with a vision model." & linefeed & linefeed
    set instructions to instructions & "🚀 Quick Setup:" & linefeed
    set instructions to instructions & "1. Install Ollama: curl -fsSL https://ollama.ai/install.sh | sh" & linefeed
    set instructions to instructions & "2. Pull a vision model: ollama pull " & defaultVisionModel & linefeed
    set instructions to instructions & "3. Models are ready to use!" & linefeed & linefeed
    set instructions to instructions & "💡 Recommended models:" & linefeed
    set instructions to instructions & "  • qwen2.5vl:7b (6GB) - Best doc/chart understanding" & linefeed
    set instructions to instructions & "  • llava:7b (4.7GB) - Solid all-rounder" & linefeed  
    set instructions to instructions & "  • llava-phi3:3.8b (2.9GB) - Tiny but chatty" & linefeed
    set instructions to instructions & "  • minicpm-v:8b (5.5GB) - Killer OCR" & linefeed & linefeed
    set instructions to instructions & "Then retry your Peekaboo command with --ask or --analyze!"
    return instructions
end getOllamaInstallInstructions

on analyzeImageWithOllama(imagePath, question, requestedModel, resizeDimension)
    my logVerbose("Analyzing image with AI: " & imagePath)
    my logVerbose("Requested model: " & requestedModel)
    my logVerbose("Question: " & question)
    
    -- Record start time
    set startTime to do shell script "date +%s"
    
    -- Check if Ollama is available
    if not my checkOllamaAvailable() then
        return my formatErrorMessage("Ollama Error", "Ollama is not installed or not in PATH." & linefeed & linefeed & my getOllamaInstallInstructions(), "ollama unavailable")
    end if
    
    -- Find best available vision model
    set modelToUse to my findBestVisionModel(requestedModel)
    if modelToUse is "" then
        return my formatErrorMessage("Model Error", "No vision models found." & linefeed & linefeed & my getOllamaInstallInstructions(), "no vision models")
    end if
    
    -- Use ollama run command with proper vision model syntax
    try
        my logVerbose("Using model: " & modelToUse)
        -- For vision models, we need to use the API approach or different command structure
        -- Let's use a simpler approach with base64 and API
        -- First check if image is too large and compress if needed
        set imageSize to do shell script "wc -c < " & quoted form of imagePath
        set imageSizeBytes to imageSize as number
        my logVerbose("Image size: " & imageSize & " bytes")
        
        set processedImagePath to imagePath
        -- Always resize for AI unless already resized by user
        set compressedPath to "/tmp/peekaboo_ai_compressed.png"
        
        -- Check if we need to resize
        set shouldResize to true
        if resizeDimension > 0 then
            -- User already specified resize, don't resize again
            set shouldResize to false
            my logVerbose("Image already resized by user to " & resizeDimension & " pixels, skipping AI resize")
        end if
        
        if shouldResize then
            if imageSizeBytes > 5000000 then -- 5MB threshold for additional compression
                my logVerbose("Image is large (" & imageSize & " bytes), applying " & defaultAIResizePercent & "% resize for AI")
                do shell script "sips -Z 2048 -s format png " & quoted form of imagePath & " --out " & quoted form of compressedPath
            else
                -- Apply default 50% resize for AI
                my logVerbose("Applying default " & defaultAIResizePercent & "% resize for AI analysis")
                -- Calculate 50% dimensions manually
                set dimensions to do shell script "sips -g pixelHeight -g pixelWidth " & quoted form of imagePath & " | grep -E 'pixelHeight|pixelWidth' | awk '{print $2}'"
                set dimensionLines to paragraphs of dimensions
                set imgHeight to (item 1 of dimensionLines) as integer
                set imgWidth to (item 2 of dimensionLines) as integer
                set newHeight to imgHeight * defaultAIResizePercent / 100
                set newWidth to imgWidth * defaultAIResizePercent / 100
                do shell script "sips -z " & newHeight & " " & newWidth & " -s format png " & quoted form of imagePath & " --out " & quoted form of compressedPath
            end if
            set processedImagePath to compressedPath
        end if
        
        set base64Image to do shell script "base64 -i " & quoted form of processedImagePath & " | tr -d '\\n'"
        set jsonPayload to "{\"model\":\"" & modelToUse & "\",\"prompt\":\"" & my escapeJSON(question) & "\",\"images\":[\"" & base64Image & "\"],\"stream\":false}"
        my logVerbose("Running API call to Ollama")
        my logVerbose("JSON payload size: " & (length of jsonPayload) & " characters")
        my logVerbose("Base64 image size: " & (length of base64Image) & " characters")
        
        -- Write JSON to temporary file using AppleScript file writing to avoid shell limitations
        set jsonTempFile to "/tmp/peekaboo_ollama_request.json"
        try
            set fileRef to open for access (POSIX file jsonTempFile) with write permission
            set eof of fileRef to 0
            write jsonPayload to fileRef
            close access fileRef
        on error
            try
                close access fileRef
            end try
        end try
        -- Add timeout to curl command (60 seconds)
        set curlCmd to "curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d @" & quoted form of jsonTempFile & " --max-time " & aiAnalysisTimeout
        
        set response to do shell script curlCmd
        
        -- Parse JSON response
        set responseStart to (offset of "\"response\":\"" in response) + 12
        if responseStart > 12 then
            set responseEnd to responseStart
            set inEscape to false
            repeat with i from responseStart to (length of response)
                set char to character i of response
                if inEscape then
                    set inEscape to false
                else if char is "\\" then
                    set inEscape to true
                else if char is "\"" then
                    set responseEnd to i - 1
                    exit repeat
                end if
            end repeat
            
            set aiResponse to text responseStart thru responseEnd of response
            -- Unescape JSON
            set aiResponse to my replaceText(aiResponse, "\\n", linefeed)
            set aiResponse to my replaceText(aiResponse, "\\\"", "\"")
            set aiResponse to my replaceText(aiResponse, "\\\\", "\\")
        else
            error "Could not parse response: " & response
        end if
        
        -- Calculate elapsed time
        set endTime to do shell script "date +%s"
        set elapsedTime to (endTime as number) - (startTime as number)
        -- Simple formatting - just show seconds
        set elapsedTimeFormatted to elapsedTime as string
        
        set resultMsg to scriptInfoPrefix & "AI Analysis Complete! 🤖" & linefeed & linefeed
        set resultMsg to resultMsg & "📸 Image: " & imagePath & linefeed
        set resultMsg to resultMsg & "❓ Question: " & question & linefeed
        set resultMsg to resultMsg & "🤖 Model: " & modelToUse & linefeed & linefeed
        set resultMsg to resultMsg & "💬 Answer:" & linefeed & aiResponse & linefeed & linefeed
        set resultMsg to resultMsg & scriptInfoPrefix & "Analysis via " & modelToUse & " took " & elapsedTimeFormatted & " sec."
        
        return resultMsg
        
    on error errMsg
        -- Calculate elapsed time even on error
        set endTime to do shell script "date +%s"
        set elapsedTime to (endTime as number) - (startTime as number)
        
        if errMsg contains "curl" and (errMsg contains "timed out" or errMsg contains "timeout" or elapsedTime ≥ aiAnalysisTimeout) then
            return my formatErrorMessage("Timeout Error", "AI analysis timed out after " & aiAnalysisTimeout & " seconds." & linefeed & linefeed & "The model '" & modelToUse & "' may be too large or slow for your system." & linefeed & linefeed & "Try:" & linefeed & "• Using a smaller model (e.g., llava-phi3:3.8b)" & linefeed & "• Checking if Ollama is responding: ollama list" & linefeed & "• Restarting Ollama service", "timeout")
        else if errMsg contains "model" and errMsg contains "not found" then
            return my formatErrorMessage("Model Error", "Model '" & modelToUse & "' not found." & linefeed & linefeed & "Install it with: ollama pull " & modelToUse & linefeed & linefeed & my getOllamaInstallInstructions(), "model not found")
        else
            return my formatErrorMessage("Analysis Error", "Failed to analyze image: " & errMsg & linefeed & linefeed & "Make sure Ollama is running and the model is available.", "ollama execution")
        end if
    end try
end analyzeImageWithAI

on escapeJSON(inputText)
    set escapedText to my replaceText(inputText, "\\", "\\\\")
    set escapedText to my replaceText(escapedText, "\"", "\\\"")
    set escapedText to my replaceText(escapedText, linefeed, "\\n")
    set escapedText to my replaceText(escapedText, return, "\\n")
    set escapedText to my replaceText(escapedText, tab, "\\t")
    return escapedText
end escapeJSON

on analyzeImageWithClaude(imagePath, question, modelAlias)
    my logVerbose("Analyzing image with Claude: " & imagePath)
    my logVerbose("Model: " & modelAlias)
    my logVerbose("Question: " & question)
    
    -- Record start time
    set startTime to do shell script "date +%s"
    
    -- Check if Claude is available
    if not my checkClaudeAvailable() then
        return my formatErrorMessage("Claude Error", "Claude CLI is not installed." & linefeed & linefeed & "Install it from: https://claude.ai/code", "claude unavailable")
    end if
    
    -- Get Claude version
    set claudeVersion to ""
    try
        set claudeVersion to do shell script "claude --version 2>/dev/null | head -1"
    on error
        set claudeVersion to "unknown"
    end try
    
    try
        -- Note: Claude CLI doesn't support direct image file analysis
        -- This is a limitation of the current Claude CLI implementation
        set errorMsg to "Claude CLI currently doesn't support direct image file analysis." & linefeed & linefeed
        set errorMsg to errorMsg & "Claude can analyze images through:" & linefeed
        set errorMsg to errorMsg & "• Copy/paste images in interactive mode" & linefeed  
        set errorMsg to errorMsg & "• MCP (Model Context Protocol) integrations" & linefeed & linefeed
        set errorMsg to errorMsg & "For automated image analysis, please use Ollama with vision models instead."
        
        -- Calculate elapsed time even for error
        set endTime to do shell script "date +%s"
        set elapsedTime to (endTime as number) - (startTime as number)
        set elapsedTimeFormatted to elapsedTime as string
        
        set errorMsg to errorMsg & linefeed & linefeed & scriptInfoPrefix & "Claude " & claudeVersion & " check took " & elapsedTimeFormatted & " sec."
        
        return my formatErrorMessage("Claude Limitation", errorMsg, "feature not supported")
        
    on error errMsg
        return my formatErrorMessage("Claude Analysis Error", "Failed to analyze image with Claude: " & errMsg, "claude execution")
    end try
end analyzeImageWithClaude

on analyzeImageWithAI(imagePath, question, requestedModel, requestedProvider, resizeDimension)
    my logVerbose("Starting AI analysis with smart provider selection")
    my logVerbose("Requested provider: " & requestedProvider)
    
    -- Determine which AI provider to use
    set ollamaAvailable to my checkOllamaAvailable()
    set claudeAvailable to my checkClaudeAvailable()
    
    my logVerbose("Ollama available: " & ollamaAvailable)
    my logVerbose("Claude available: " & claudeAvailable)
    
    -- If neither is available, provide helpful error
    if not ollamaAvailable and not claudeAvailable then
        set errorMsg to "Neither Ollama nor Claude CLI is installed." & linefeed & linefeed
        set errorMsg to errorMsg & "Install one of these AI providers:" & linefeed & linefeed
        set errorMsg to errorMsg & "🤖 Ollama (local, privacy-focused):" & linefeed
        set errorMsg to errorMsg & my getOllamaInstallInstructions() & linefeed & linefeed
        set errorMsg to errorMsg & "☁️ Claude CLI (cloud-based):" & linefeed
        set errorMsg to errorMsg & "Install from: https://claude.ai/code"
        return my formatErrorMessage("No AI Provider", errorMsg, "no ai provider")
    end if
    
    -- Smart selection based on availability and preference
    if requestedProvider is "ollama" and ollamaAvailable then
        return my analyzeImageWithOllama(imagePath, question, requestedModel, resizeDimension)
    else if requestedProvider is "claude" and claudeAvailable then
        return my analyzeImageWithClaude(imagePath, question, requestedModel)
    else if requestedProvider is "auto" then
        -- Auto mode: prefer Ollama, fallback to Claude
        if ollamaAvailable then
            return my analyzeImageWithOllama(imagePath, question, requestedModel, resizeDimension)
        else if claudeAvailable then
            return my analyzeImageWithClaude(imagePath, question, requestedModel)
        end if
    else
        -- Requested provider not available, try the other one
        if ollamaAvailable then
            my logVerbose("Requested provider not available, using Ollama instead")
            return my analyzeImageWithOllama(imagePath, question, requestedModel, resizeDimension)
        else if claudeAvailable then
            my logVerbose("Requested provider not available, using Claude instead")
            return my analyzeImageWithClaude(imagePath, question, requestedModel)
        end if
    end if
    
    -- Should never reach here
    return my formatErrorMessage("Provider Error", "Unable to determine AI provider", "provider selection")
end analyzeImageWithAI
--#endregion AI Analysis Functions

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
    
    -- Resolution priority order:
    -- 1. Exact app name match (running apps)
    -- 2. Fuzzy matching for running apps (case-insensitive, partial, common mappings)
    -- 3. Exact match in /Applications (not running)
    -- 4. Fuzzy match in /Applications (not running)
    -- 5. Bundle ID lookup (last resort)
    
    -- PRIORITY 1: Try as application name for running apps (exact match)
    try
        tell application "System Events"
            set nameApps to (every application process whose name is appIdentifier)
            if (count nameApps) > 0 then
                set targetApp to item 1 of nameApps
                set actualAppName to name of targetApp -- Get the actual name with correct case
                try
                    set bundleID to bundle identifier of targetApp
                on error
                    set bundleID to ""
                end try
                my logVerbose("Found running app by name: " & actualAppName)
                return {appName:actualAppName, bundleID:bundleID, isRunning:true, resolvedBy:"app_name"}
            end if
        end tell
    on error
        my logVerbose("App name lookup failed for running processes")
    end try
    
    -- PRIORITY 2: Try fuzzy matching for running apps
    try
        tell application "System Events"
            set allApps to every application process
            set appIdentifierLower to do shell script "echo " & quoted form of appIdentifier & " | tr '[:upper:]' '[:lower:]'"
            
            -- Try case-insensitive exact match first
            repeat with appProc in allApps
                set appName to name of appProc
                set appNameLower to do shell script "echo " & quoted form of appName & " | tr '[:upper:]' '[:lower:]'"
                if appNameLower is appIdentifierLower then
                    try
                        set bundleID to bundle identifier of appProc
                    on error
                        set bundleID to ""
                    end try
                    my logVerbose("Found running app by case-insensitive match: " & appName)
                    return {appName:appName, bundleID:bundleID, isRunning:true, resolvedBy:"case_insensitive"}
                end if
            end repeat
            
            -- Try partial match (app identifier is contained in app name)
            repeat with appProc in allApps
                set appName to name of appProc
                set appNameLower to do shell script "echo " & quoted form of appName & " | tr '[:upper:]' '[:lower:]'"
                if appNameLower contains appIdentifierLower then
                    try
                        set bundleID to bundle identifier of appProc
                    on error
                        set bundleID to ""
                    end try
                    my logVerbose("Found running app by partial match: " & appName & " (searched for: " & appIdentifier & ")")
                    return {appName:appName, bundleID:bundleID, isRunning:true, resolvedBy:"partial_match"}
                end if
            end repeat
            
            -- Try common variations (e.g., "Chrome" -> "Google Chrome", "Code" -> "Visual Studio Code")
            -- Only include apps that are actually running
            set commonMappings to {{"chrome", "Google Chrome"}, {"safari", "Safari"}, {"firefox", "Firefox"}, {"code", {"Visual Studio Code", "Visual Studio Code - Insiders"}}, {"vscode", {"Visual Studio Code", "Visual Studio Code - Insiders"}}, {"terminal", "Terminal"}, {"term", "Terminal"}, {"iterm", "iTerm2"}, {"iterm2", "iTerm2"}, {"slack", "Slack"}, {"zoom", "zoom.us"}, {"teams", "Microsoft Teams"}, {"outlook", "Microsoft Outlook"}, {"excel", "Microsoft Excel"}, {"word", "Microsoft Word"}, {"powerpoint", "Microsoft PowerPoint"}, {"keynote", "Keynote"}, {"pages", "Pages"}, {"numbers", "Numbers"}}
            
            repeat with mapping in commonMappings
                if appIdentifierLower is item 1 of mapping then
                    set mappedAppNames to item 2 of mapping
                    -- Handle both single string and list of strings
                    if class of mappedAppNames is text then
                        set mappedAppNames to {mappedAppNames}
                    end if
                    
                    -- Try each possible mapped name
                    repeat with mappedAppName in mappedAppNames
                        repeat with appProc in allApps
                            if name of appProc is contents of mappedAppName then
                                try
                                    set bundleID to bundle identifier of appProc
                                on error
                                    set bundleID to ""
                                end try
                                my logVerbose("Found running app by common name mapping: " & contents of mappedAppName & " (searched for: " & appIdentifier & ")")
                                return {appName:contents of mappedAppName, bundleID:bundleID, isRunning:true, resolvedBy:"common_mapping"}
                            end if
                        end repeat
                    end repeat
                end if
            end repeat
        end tell
    on error errMsg
        my logVerbose("Fuzzy matching failed: " & errMsg)
    end try
    
    -- PRIORITY 3: Try to find the app in /Applications (not running)
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
    
    -- PRIORITY 4: Try fuzzy matching in /Applications folder
    try
        set appIdentifierLower to do shell script "echo " & quoted form of appIdentifier & " | tr '[:upper:]' '[:lower:]'"
        set appFiles to do shell script "ls /Applications/ | grep -E '\\.app$' || true"
        set appFileList to paragraphs of appFiles
        
        repeat with appFile in appFileList
            set appNameOnly to text 1 thru -5 of appFile -- Remove ".app" extension
            set appNameLower to do shell script "echo " & quoted form of appNameOnly & " | tr '[:upper:]' '[:lower:]'"
            
            -- Check if fuzzy match
            if appNameLower contains appIdentifierLower or appIdentifierLower contains appNameLower then
                set appPath to "/Applications/" & appFile
                tell application "System Events"
                    if exists file appPath then
                        try
                            set bundleID to bundle identifier of file appPath
                        on error
                            set bundleID to ""
                        end try
                        my logVerbose("Found app in /Applications by fuzzy match: " & appNameOnly & " (searched for: " & appIdentifier & ")")
                        return {appName:appNameOnly, bundleID:bundleID, isRunning:false, resolvedBy:"applications_fuzzy"}
                    end if
                end tell
            end if
        end repeat
    on error errMsg
        my logVerbose("/Applications fuzzy search failed: " & errMsg)
    end try
    
    -- PRIORITY 5: Try as bundle ID for running apps (last resort)
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
        my logVerbose("Bundle ID lookup failed")
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
    
    -- Skip app focus for fullscreen mode
    if appName is "fullscreen" then
        my logVerbose("Fullscreen mode - skipping app focus")
        return ""
    end if
    
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
on captureScreenshot(outputPath, captureMode, appName, resizeDimension)
    my logVerbose("Capturing screenshot to: " & outputPath & " (mode: " & captureMode & ", resize: " & resizeDimension & ")")
    
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
    
    if captureMode is "window" and appName is not "fullscreen" then
        -- IMPORTANT: Do NOT use -o -W flags as they require user interaction!
        -- Instead, capture the window using its bounds (position and size)
        try
            tell application "System Events"
                tell process appName
                    set winPosition to position of window 1
                    set winSize to size of window 1
                end tell
            end tell
            
            set x to item 1 of winPosition
            set y to item 2 of winPosition
            set w to item 1 of winSize
            set h to item 2 of winSize
            
            -- Use -R flag to capture a specific rectangle
            set screencaptureCmd to screencaptureCmd & " -R" & x & "," & y & "," & w & "," & h
            my logVerbose("Capturing window bounds for " & appName & ": " & x & "," & y & "," & w & "," & h)
        on error errMsg
            -- Fallback to full screen if we can't get window bounds
            my logVerbose("Could not get window bounds for " & appName & ", error: " & errMsg)
            log scriptInfoPrefix & "Warning: Could not capture window bounds for " & appName & ", using full screen capture instead"
        end try
    end if
    
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
            
            -- Apply resize if requested
            if resizeDimension > 0 then
                my logVerbose("Resizing image to max dimension: " & resizeDimension)
                try
                    do shell script "sips -Z " & resizeDimension & " " & quoted form of outputPath
                    my logVerbose("Image resized successfully")
                on error resizeErr
                    my logVerbose("Failed to resize image: " & resizeErr)
                    -- Continue without resize on error
                end try
            end if
            
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

on captureWindowByIndex(outputPath, appName, winIndex, resizeDimension)
    my logVerbose("Capturing window " & winIndex & " of " & appName & " to: " & outputPath & " (resize: " & resizeDimension & ")")
    
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
    
    -- Build screencapture command
    set screencaptureCmd to "screencapture -x"
    
    -- Get window bounds for specific window
    try
        tell application "System Events"
            tell process appName
                set winPosition to position of window winIndex
                set winSize to size of window winIndex
            end tell
        end tell
        
        set x to item 1 of winPosition
        set y to item 2 of winPosition
        set w to item 1 of winSize
        set h to item 2 of winSize
        
        -- Use -R flag to capture a specific rectangle
        set screencaptureCmd to screencaptureCmd & " -R" & x & "," & y & "," & w & "," & h
        my logVerbose("Capturing window " & winIndex & " bounds: " & x & "," & y & "," & w & "," & h)
    on error errMsg
        -- Fallback to full screen if we can't get window bounds
        my logVerbose("Could not get bounds for window " & winIndex & ", error: " & errMsg)
        return my formatErrorMessage("Window Error", "Could not get bounds for window " & winIndex & " of " & appName, "window bounds")
    end try
    
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
            
            -- Apply resize if requested
            if resizeDimension > 0 then
                my logVerbose("Resizing image to max dimension: " & resizeDimension)
                try
                    do shell script "sips -Z " & resizeDimension & " " & quoted form of outputPath
                    my logVerbose("Image resized successfully")
                on error resizeErr
                    my logVerbose("Failed to resize image: " & resizeErr)
                    -- Continue without resize on error
                end try
            end if
            
            return outputPath
        on error
            return my formatErrorMessage("Capture Error", "Screenshot file was not created at: " & outputPath, "file verification")
        end try
        
    on error errMsg
        return my formatErrorMessage("Capture Error", "Failed to capture window: " & errMsg, "screencapture")
    end try
end captureWindowByIndex

on captureMultipleWindows(appName, baseOutputPath, resizeDimension)
    -- Get detailed window status first
    set windowStatus to my getAppWindowStatus(appName)
    
    -- Check if it's an error (string) or success (record)
    try
        set statusClass to class of windowStatus
        if statusClass is text or statusClass is string then
            -- It's an error message
            return windowStatus
        end if
    on error
        -- Assume it's a record and continue
    end try
    
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
        set sanitizedTitle to my sanitizeAppName(winTitle)
        
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
            delay 0.1
        on error
            my logVerbose("Could not focus window " & winIndex & ", continuing anyway")
        end try
        
        -- Capture the specific window using a custom method
        set captureResult to my captureWindowByIndex(windowOutputPath, appName, winIndex, resizeDimension)
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
        my logVerbose("Starting Peekaboo v2.0.0")
        
        set argCount to count argv
        
        -- Initialize all variables
        set command to "" -- "capture", "analyze", "list", "help"
        set appIdentifier to ""
        set outputPath to ""
        set outputSpecified to false
        set captureMode to "" -- will be determined
        set forceFullscreen to false
        set multiWindow to false
        set analyzeMode to false
        set analysisQuestion to ""
        set visionModel to defaultVisionModel
        set requestedProvider to aiProvider
        set outputFormat to ""
        set quietMode to false
        set resizeDimension to defaultImageMaxDimension
        
        -- Handle no arguments - default to fullscreen
        if argCount = 0 then
            set command to "capture"
            set forceFullscreen to true
        else
            -- Check first argument for commands
            set firstArg to item 1 of argv
            if firstArg is "list" or firstArg is "ls" then
                return my formatAppList(my listRunningApps())
            else if firstArg is "help" or firstArg is "-h" or firstArg is "--help" then
                return my usageText()
            else if firstArg is "analyze" then
                set command to "analyze"
                -- analyze command requires at least image and question
                if argCount < 3 then
                    return my formatErrorMessage("Argument Error", "analyze command requires: analyze <image> \"question\"" & linefeed & linefeed & my usageText(), "validation")
                end if
                set appIdentifier to item 2 of argv -- actually the image path
                set analysisQuestion to item 3 of argv
                set analyzeMode to true
            else
                -- Regular capture command
                set command to "capture"
                -- Check if first arg is a flag or app name
                if not (firstArg starts with "-") then
                    set appIdentifier to firstArg
                end if
            end if
        end if
        
        -- Parse remaining arguments
        set i to 1
        if command is "analyze" then set i to 4 -- Skip "analyze image question"
        if command is "capture" and appIdentifier is not "" then set i to 2 -- Skip app name
        
        repeat while i ≤ argCount
            set arg to item i of argv
            
            -- Handle flags with values
            if arg is "--output" or arg is "-o" then
                if i < argCount then
                    set i to i + 1
                    set outputPath to item i of argv
                    set outputSpecified to true
                else
                    return my formatErrorMessage("Argument Error", arg & " requires a path parameter", "validation")
                end if
            else if arg is "--ask" or arg is "-a" then
                if i < argCount then
                    set i to i + 1
                    set analysisQuestion to item i of argv
                    set analyzeMode to true
                else
                    return my formatErrorMessage("Argument Error", arg & " requires a question parameter", "validation")
                end if
            else if arg is "--model" then
                if i < argCount then
                    set i to i + 1
                    set visionModel to item i of argv
                else
                    return my formatErrorMessage("Argument Error", "--model requires a model name parameter", "validation")
                end if
            else if arg is "--provider" then
                if i < argCount then
                    set i to i + 1
                    set requestedProvider to item i of argv
                    if requestedProvider is not "auto" and requestedProvider is not "ollama" and requestedProvider is not "claude" then
                        return my formatErrorMessage("Argument Error", "--provider must be 'auto', 'ollama', or 'claude'", "validation")
                    end if
                else
                    return my formatErrorMessage("Argument Error", "--provider requires a provider name parameter", "validation")
                end if
            else if arg is "--format" then
                if i < argCount then
                    set i to i + 1
                    set outputFormat to item i of argv
                    if outputFormat is not "png" and outputFormat is not "jpg" and outputFormat is not "pdf" then
                        return my formatErrorMessage("Argument Error", "--format must be 'png', 'jpg', or 'pdf'", "validation")
                    end if
                else
                    return my formatErrorMessage("Argument Error", "--format requires a format parameter", "validation")
                end if
            else if arg is "--resize" or arg is "-r" then
                if i < argCount then
                    set i to i + 1
                    try
                        set resizeDimension to (item i of argv) as integer
                        if resizeDimension < 0 then
                            return my formatErrorMessage("Argument Error", "--resize value must be a positive number or 0 (no resize)", "validation")
                        end if
                    on error
                        return my formatErrorMessage("Argument Error", "--resize requires a numeric value (max dimension in pixels)", "validation")
                    end try
                else
                    return my formatErrorMessage("Argument Error", "--resize requires a dimension parameter", "validation")
                end if
            
            -- Handle boolean flags
            else if arg is "--fullscreen" or arg is "-f" then
                set forceFullscreen to true
            else if arg is "--window" or arg is "-w" then
                set captureMode to "window"
            else if arg is "--multi" or arg is "-m" then
                set multiWindow to true
            else if arg is "--verbose" or arg is "-v" then
                set verboseLogging to true
            else if arg is "--quiet" or arg is "-q" then
                set quietMode to true
            
            -- Handle positional argument (output path for old-style compatibility)
            else if not (arg starts with "-") and command is "capture" and not outputSpecified then
                set outputPath to arg
                set outputSpecified to true
            end if
            
            set i to i + 1
        end repeat
        
        -- Handle analyze command
        if command is "analyze" then
            -- For analyze command, appIdentifier contains the image path
            return my analyzeImageWithAI(appIdentifier, analysisQuestion, visionModel, requestedProvider, resizeDimension)
        end if
        
        -- For capture command, determine capture mode
        if captureMode is "" then
            if forceFullscreen or appIdentifier is "" then
                set captureMode to "screen"
            else
                -- App specified, default to window capture
                set captureMode to "window"
            end if
        end if
        
        -- Set default output path if none provided
        if outputPath is "" then
            set timestamp to do shell script "date +%Y%m%d_%H%M%S"
            -- Create model-friendly filename with app name
            if appIdentifier is "" or appIdentifier is "fullscreen" then
                set appNameForFile to "fullscreen"
            else
                set appNameForFile to my sanitizeAppName(appIdentifier)
            end if
            
            -- Determine extension based on format
            set fileExt to outputFormat
            if fileExt is "" then set fileExt to defaultScreenshotFormat
            
            set outputPath to "/tmp/peekaboo_" & appNameForFile & "_" & timestamp & "." & fileExt
        else
            -- Check if user specified a directory for multi-window mode
            if multiWindow and outputPath ends with "/" then
                set timestamp to do shell script "date +%Y%m%d_%H%M%S"
                set appNameForFile to my sanitizeAppName(appIdentifier)
                set fileExt to outputFormat
                if fileExt is "" then set fileExt to defaultScreenshotFormat
                set outputPath to outputPath & "peekaboo_" & appNameForFile & "_" & timestamp & "." & fileExt
            else if outputFormat is not "" and not (outputPath ends with ("." & outputFormat)) then
                -- Apply format if specified but not in path
                set outputPath to outputPath & "." & outputFormat
            end if
        end if
        
        -- Validate output path
        if outputSpecified and not my isValidPath(outputPath) then
            return my formatErrorMessage("Argument Error", "Output path must be an absolute path starting with '/'.", "validation")
        end if
        
        -- Resolve app identifier with detailed diagnostics
        if appIdentifier is "" or appIdentifier is "fullscreen" then
            set appInfo to {appName:"fullscreen", bundleID:"fullscreen", isRunning:true, resolvedBy:"fullscreen"}
        else
            set appInfo to my resolveAppIdentifier(appIdentifier)
        end if
        if appInfo is missing value then
            set errorDetails to "Could not resolve app identifier '" & appIdentifier & "'."
            
            -- Provide specific guidance based on identifier type
            if appIdentifier contains "." then
                set errorDetails to errorDetails & " This appears to be a bundle ID. Common issues:" & linefeed
                set errorDetails to errorDetails & "• Bundle ID may be incorrect (try 'com.apple.' prefix for system apps)" & linefeed
                set errorDetails to errorDetails & "• App may not be installed" & linefeed
                set errorDetails to errorDetails & "• Use 'osascript peekaboo.scpt list' to see available apps"
            else
                set errorDetails to errorDetails & " Fuzzy matching tried but no matches found." & linefeed
                set errorDetails to errorDetails & "• Partial names are supported (e.g., 'Chrome' for 'Google Chrome')" & linefeed
                set errorDetails to errorDetails & "• Common abbreviations work (e.g., 'Code' for 'Visual Studio Code')" & linefeed
                set errorDetails to errorDetails & "• App may not be installed or running" & linefeed
                set errorDetails to errorDetails & "• Use 'osascript peekaboo.scpt list' to see running apps"
            end if
            
            return my formatErrorMessage("App Resolution Error", errorDetails, "app resolution")
        end if
        
        set resolvedAppName to appName of appInfo
        set resolvedBy to resolvedBy of appInfo
        my logVerbose("App resolved: " & resolvedAppName & " (method: " & resolvedBy & ")")
        
        -- Bring app to front
        set frontError to my bringAppToFront(appInfo)
        if frontError is not "" then return frontError
        
        -- Smart multi-window detection for AI analysis
        if analyzeMode and resolvedAppName is not "fullscreen" and not forceFullscreen then
            -- Check how many windows the app has
            set windowStatus to my getAppWindowStatus(resolvedAppName)
            try
                set statusClass to class of windowStatus
                if statusClass is not text and statusClass is not string then
                    -- It's a success record
                    set totalWindows to totalWindows of windowStatus
                    if totalWindows > 1 and not multiWindow and captureMode is not "screen" then
                        -- Automatically enable multi-window mode for AI analysis
                        set multiWindow to true
                        my logVerbose("Auto-enabling multi-window mode for AI analysis (app has " & totalWindows & " windows)")
                    end if
                end if
            on error
                -- Continue without auto-enabling
            end try
        end if
        
        -- Pre-capture window validation for better error messages
        if (multiWindow or captureMode is "window") and resolvedAppName is not "fullscreen" then
            set windowStatus to my getAppWindowStatus(resolvedAppName)
            -- Check if it's an error (string starting with prefix) or success (record)
            try
                set statusClass to class of windowStatus
                if statusClass is text or statusClass is string then
                    -- It's an error message
                    if multiWindow then
                        set contextError to "Multi-window capture failed: " & windowStatus
                        set contextError to contextError & linefeed & "💡 Suggestion: Try basic screenshot mode without --multi flag"
                    else
                        set contextError to "Window capture failed: " & windowStatus  
                        set contextError to contextError & linefeed & "💡 Suggestion: Try full-screen capture mode without --window flag"
                    end if
                    return contextError
                else
                    -- It's a success record
                    set statusMsg to message of windowStatus
                    my logVerbose("Window validation passed: " & statusMsg)
                end if
            on error
                -- Fallback if type check fails
                my logVerbose("Window validation status check bypassed")
            end try
        end if
        
        -- Handle multi-window capture
        if multiWindow then
            set capturedFiles to my captureMultipleWindows(resolvedAppName, outputPath, resizeDimension)
            -- Check if it's an error (string) or success (list)
            try
                set capturedClass to class of capturedFiles
                if capturedClass is text or capturedClass is string then
                    return capturedFiles -- Error message
                end if
            on error
                -- Continue with list processing
            end try
            
            -- If AI analysis requested, analyze all captured windows
            if analyzeMode and (count of capturedFiles) > 0 then
                set analysisResults to {}
                set allSuccess to true
                
                repeat with fileInfo in capturedFiles
                    set filePath to item 1 of fileInfo
                    set windowTitle to item 2 of fileInfo
                    set windowIndex to item 3 of fileInfo
                    
                    set analysisResult to my analyzeImageWithAI(filePath, analysisQuestion, visionModel, requestedProvider, resizeDimension)
                    
                    if analysisResult starts with scriptInfoPrefix and analysisResult contains "Analysis Complete" then
                        -- Extract just the answer part from the analysis
                        set answerStart to (offset of "💬 Answer:" in analysisResult) + 10
                        set answerEnd to (offset of (scriptInfoPrefix & "Analysis via") in analysisResult) - 1
                        if answerStart > 10 and answerEnd > answerStart then
                            set windowAnswer to text answerStart thru answerEnd of analysisResult
                        else
                            set windowAnswer to analysisResult
                        end if
                        set end of analysisResults to {windowTitle:windowTitle, windowIndex:windowIndex, answer:windowAnswer, success:true}
                    else
                        set allSuccess to false
                        set end of analysisResults to {windowTitle:windowTitle, windowIndex:windowIndex, answer:analysisResult, success:false}
                    end if
                end repeat
                
                -- Format multi-window AI analysis results
                return my formatMultiWindowAnalysis(capturedFiles, analysisResults, resolvedAppName, analysisQuestion, visionModel, quietMode)
            else
                -- Process successful capture without AI
                return my formatMultiOutput(capturedFiles, resolvedAppName, quietMode)
            end if
        else
            -- Single capture
            set screenshotResult to my captureScreenshot(outputPath, captureMode, resolvedAppName, resizeDimension)
            if screenshotResult starts with scriptInfoPrefix then
                return screenshotResult -- Error message
            else
                set modeDescription to "full screen"
                if captureMode is "window" then set modeDescription to "front window only"
                
                -- If AI analysis requested, analyze the screenshot
                if analyzeMode then
                    set analysisResult to my analyzeImageWithAI(screenshotResult, analysisQuestion, visionModel, requestedProvider, resizeDimension)
                    if analysisResult starts with scriptInfoPrefix and analysisResult contains "Analysis Complete" then
                        -- Successful analysis
                        return analysisResult
                    else
                        -- Analysis failed, return screenshot success + analysis error
                        return scriptInfoPrefix & "Screenshot captured successfully! 📸" & linefeed & "• File: " & screenshotResult & linefeed & "• App: " & resolvedAppName & linefeed & "• Mode: " & modeDescription & linefeed & linefeed & "⚠️ AI Analysis failed:" & linefeed & analysisResult
                    end if
                else
                    -- Regular screenshot without analysis
                    return my formatCaptureOutput(screenshotResult, resolvedAppName, modeDescription, quietMode)
                end if
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
    set scriptName to "peekaboo.scpt"
    
    set outText to "Peekaboo v1.0.0 - Screenshot automation that actually works! 👀 → 📸 → 💾" & LF & LF
    
    set outText to outText & "USAGE:" & LF
    set outText to outText & "  peekaboo [app] [options]                    # Screenshot app or fullscreen" & LF
    set outText to outText & "  peekaboo analyze <image> \"question\" [opts]  # Analyze existing image" & LF
    set outText to outText & "  peekaboo list                               # List running apps" & LF
    set outText to outText & "  peekaboo help                               # Show this help" & LF & LF
    
    set outText to outText & "COMMANDS:" & LF
    set outText to outText & "  [app]        App name or bundle ID (optional, defaults to fullscreen)" & LF
    set outText to outText & "  analyze      Analyze existing image with AI vision" & LF
    set outText to outText & "  list, ls     List all running apps with window info" & LF
    set outText to outText & "  help, -h     Show this help message" & LF & LF
    
    set outText to outText & "OPTIONS:" & LF
    set outText to outText & "  -o, --output <path>      Output file or directory path" & LF
    set outText to outText & "  -f, --fullscreen         Force fullscreen capture" & LF
    set outText to outText & "  -w, --window             Single window capture (default with app)" & LF
    set outText to outText & "  -m, --multi              Capture all app windows separately" & LF
    set outText to outText & "  -a, --ask \"question\"     AI analysis of screenshot" & LF
    set outText to outText & "  --model <model>          AI model (e.g., llava:7b)" & LF
    set outText to outText & "  --provider <provider>    AI provider: auto|ollama|claude" & LF
    set outText to outText & "  --format <fmt>           Output format: png|jpg|pdf" & LF
    set outText to outText & "  -r, --resize <pixels>    Resize to max dimension (faster AI)" & LF
    set outText to outText & "  -v, --verbose            Enable debug output" & LF
    set outText to outText & "  -q, --quiet              Minimal output (just file path)" & LF & LF
    
    set outText to outText & "EXAMPLES:" & LF
    set outText to outText & "  # Basic captures" & LF
    set outText to outText & "  peekaboo                                    # Fullscreen" & LF
    set outText to outText & "  peekaboo Safari                             # Safari window" & LF
    set outText to outText & "  peekaboo Safari -o ~/Desktop/safari.png     # Specific path" & LF
    set outText to outText & "  peekaboo -f -o screenshot.jpg --format jpg  # Fullscreen as JPG" & LF & LF
    
    set outText to outText & "  # Multi-window capture" & LF
    set outText to outText & "  peekaboo Chrome -m                          # All Chrome windows" & LF
    set outText to outText & "  peekaboo Safari -m -o ~/screenshots/        # To directory" & LF & LF
    
    set outText to outText & "  # AI analysis" & LF
    set outText to outText & "  peekaboo Safari -a \"What's on this page?\"   # Screenshot + analyze" & LF
    set outText to outText & "  peekaboo -f -a \"Any errors visible?\"        # Fullscreen + analyze" & LF
    set outText to outText & "  peekaboo analyze photo.png \"What is this?\"  # Analyze existing" & LF
    set outText to outText & "  peekaboo Terminal -a \"Show the error\" --model llava:13b" & LF
    set outText to outText & "  peekaboo Safari -a \"What's shown?\" -r 1024  # Resize for faster AI" & LF & LF
    
    set outText to outText & "  # Other commands" & LF
    set outText to outText & "  peekaboo list                               # Show running apps" & LF
    set outText to outText & "  peekaboo help                               # This help" & LF & LF
    
    set outText to outText & "Note: When using with osascript, quote arguments and escape as needed:" & LF
    set outText to outText & "  osascript peekaboo.scpt Safari -a \"What's shown?\"" & LF & LF
    
    set outText to outText & "AI Analysis Features:" & LF
    set outText to outText & "  • Smart provider detection: auto-detects Ollama or Claude CLI" & LF
    set outText to outText & "  • Smart multi-window: Automatically analyzes ALL windows for multi-window apps" & LF
    set outText to outText & "    - App has 3 windows? Analyzes all 3 and reports on each" & LF
    set outText to outText & "    - Use -w flag to force single window analysis" & LF
    set outText to outText & "  • Ollama: Local inference with vision models (recommended)" & LF
    set outText to outText & "    - Supports direct image file analysis" & LF
    set outText to outText & "    - Priority: qwen2.5vl:7b > llava:7b > llava-phi3:3.8b > minicpm-v:8b" & LF
    set outText to outText & "  • Claude: Limited support (CLI doesn't analyze image files)" & LF
    set outText to outText & "    - Claude CLI detected but can't process image files directly" & LF
    set outText to outText & "    - Use Ollama for automated image analysis" & LF
    set outText to outText & "  • One-step: Screenshot + analysis in single command" & LF
    set outText to outText & "  • Two-step: Analyze existing images separately" & LF
    set outText to outText & "  • Timeout protection: 90-second timeout prevents hanging" & LF & LF
    
    set outText to outText & "Multi-Window Features:" & LF
    set outText to outText & "  • --multi creates separate files with descriptive names" & LF
    set outText to outText & "  • Window titles are sanitized for safe filenames" & LF
    set outText to outText & "  • Files named as: basename_window_N_title.ext" & LF
    set outText to outText & "  • Each window is focused before capture for accuracy" & LF & LF
    
    set outText to outText & "Notes:" & LF
    set outText to outText & "  • Default behavior: App specified = window capture, No app = full screen" & LF
    set outText to outText & "  • Requires Screen Recording permission in System Preferences" & LF
    set outText to outText & "  • Accessibility permission may be needed for window enumeration" & LF
    set outText to outText & "  • Window titles longer than " & maxWindowTitleLength & " characters are truncated" & LF
    set outText to outText & "  • Default capture delay: " & (captureDelay as string) & " second(s) (optimized for speed)" & LF
    
    return outText
end usageText
--#endregion Usage Function