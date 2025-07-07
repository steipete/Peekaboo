#!/bin/bash

# Read the entire content of the JSON file into a variable
json_content=$(<"/Users/steipete/Projects/CodeLooper/query_cursor_input.json")

# Extract and print the command_id from the JSON content
command_id=$(echo "$json_content" | jq -r .command_id)
echo "DEBUG: command_id from file is: $command_id"

# Remove any previous debug log file
rm -f axorc_stderr.log

# Execute axorc with the JSON content (not the file path) and debug flag
# Redirect stderr to axorc_stderr.log
./.build/arm64-apple-macosx/debug/axorc --json "$json_content" --debug 2>axorc_stderr.log

# Cat the stderr log content to stdout
cat axorc_stderr.log