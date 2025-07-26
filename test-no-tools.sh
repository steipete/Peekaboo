#!/bin/bash

# Test agent without tools first

./Apps/CLI/.build/debug/peekaboo agent "Say hello" --verbose 2>&1 | head -100