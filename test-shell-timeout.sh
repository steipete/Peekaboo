#!/bin/bash

# Test script for shell command timeout functionality

echo "Testing shell command timeout implementation..."
echo

# Test 1: Normal command should work
echo "Test 1: Normal command (should succeed)"
./scripts/peekaboo-wait.sh agent 'Run the shell command: echo "Hello from shell"' --quiet

# Test 2: Command with sleep should timeout
echo -e "\nTest 2: Long-running command with default timeout (should timeout after 30s)"
./scripts/peekaboo-wait.sh agent 'Run the shell command: sleep 60' --quiet

# Test 3: Command with custom timeout
echo -e "\nTest 3: Command with custom short timeout (should timeout after 5s)"
./scripts/peekaboo-wait.sh agent 'Run the shell command with timeout 5: sleep 10' --quiet

# Test 4: Interactive command should timeout
echo -e "\nTest 4: Interactive command (should timeout, not wait for input)"
./scripts/peekaboo-wait.sh agent 'Run the shell command: read -p "Enter something: " input && echo "You entered: $input"' --quiet

# Test 5: Git command without message (would be interactive)
echo -e "\nTest 5: Git command without message (should timeout or fail)"
cd /tmp && mkdir -p test-repo && cd test-repo && git init >/dev/null 2>&1
echo "test" > file.txt && git add file.txt >/dev/null 2>&1
cd /Users/steipete/Projects/Peekaboo
./scripts/peekaboo-wait.sh agent 'Run the shell command in /tmp/test-repo: git commit' --quiet
rm -rf /tmp/test-repo

# Test 6: Command that would prompt for password
echo -e "\nTest 6: SSH command (should fail fast, not hang waiting for password)"
./scripts/peekaboo-wait.sh agent 'Run the shell command: ssh nonexistent@example.com "echo test"' --quiet

echo -e "\nAll tests completed!"