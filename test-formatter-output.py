#!/usr/bin/env python3
"""
Test script to verify enhanced formatter output from Peekaboo Agent
"""

import subprocess
import time
import sys
import json

def run_agent_command(task, max_steps=3):
    """Run peekaboo agent and capture output"""
    cmd = ["./peekaboo", "agent", task, "--max-steps", str(max_steps)]
    
    print(f"Running: {' '.join(cmd)}")
    print("-" * 60)
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # Print both stdout and stderr to see all output
        if result.stdout:
            print("STDOUT:")
            print(result.stdout)
        if result.stderr:
            print("STDERR:")
            print(result.stderr)
            
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("Command timed out after 30 seconds")
        return False
    except Exception as e:
        print(f"Error running command: {e}")
        return False

def wait_for_build():
    """Wait for Poltergeist build to complete"""
    print("Checking build status...")
    max_wait = 60  # Wait up to 1 minute
    
    for i in range(max_wait):
        try:
            result = subprocess.run(
                ["npm", "run", "poltergeist:status"],
                capture_output=True,
                text=True
            )
            
            if "✅ Success" in result.stdout:
                print("Build completed successfully!")
                return True
            elif "❌ Failed" in result.stdout and "Target: peekaboo" in result.stdout:
                print("Build failed!")
                return False
            
            print(f"Build still in progress... ({i+1}/{max_wait})")
            time.sleep(1)
            
        except Exception as e:
            print(f"Error checking build status: {e}")
            return False
    
    print("Build timeout - proceeding anyway")
    return True

def main():
    print("=" * 60)
    print("Testing Peekaboo Agent Enhanced Formatters")
    print("=" * 60)
    print()
    
    # Check if binary exists
    import os
    if not os.path.exists("./peekaboo"):
        print("Binary not found. Waiting for build...")
        if not wait_for_build():
            print("Build failed or timed out. Exiting.")
            sys.exit(1)
    
    # Test cases focused on formatter output
    test_cases = [
        ("List all running applications", 2),
        ("Take a screenshot", 2),
        ("Open Finder", 3),
    ]
    
    for i, (task, max_steps) in enumerate(test_cases, 1):
        print(f"\nTest {i}: {task}")
        print("=" * 60)
        
        success = run_agent_command(task, max_steps)
        
        if success:
            print("✅ Test completed")
        else:
            print("❌ Test failed or timed out")
        
        print()
        time.sleep(2)  # Brief pause between tests
    
    print("\n" + "=" * 60)
    print("Testing complete!")
    print("Look for enhanced formatter output patterns:")
    print("- '→' prefixed summaries")
    print("- Rich contextual information")
    print("- Structured data presentation")
    print("- Performance metrics where applicable")

if __name__ == "__main__":
    main()