#!/bin/bash
# Signal to Poltergeist that a manual build has fixed the issues
# This resets Poltergeist's backoff timer

RECOVERY_SIGNAL="/tmp/peekaboo-build-recovery"

# Create recovery signal
touch "$RECOVERY_SIGNAL"

echo "✅ Recovery signal sent to Poltergeist"
echo "   Poltergeist will reset its backoff timer on next file change"