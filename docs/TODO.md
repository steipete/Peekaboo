---
summary: Track backlog of Peekaboo feature ideas and automations under consideration
read_when:
  - reviewing or grooming upcoming Peekaboo features
  - adding new automation ideas or evaluating feasibility
---

# Peekaboo TODO / Feature Ideas

## Media & System Control

### Media Keys Support
Add ability to send media key events for controlling playback:
```bash
peekaboo media play      # Play/pause
peekaboo media pause
peekaboo media next      # Next track
peekaboo media previous  # Previous track
```

Use case: Control Spotify/Music without needing AppleScript hacks.

### Volume Control
Direct system volume control:
```bash
peekaboo volume 50           # Set to 50%
peekaboo volume up           # Increase by 10%
peekaboo volume down         # Decrease by 10%
peekaboo volume mute         # Toggle mute
peekaboo volume 80 --ramp 5s # Gradually ramp to 80% over 5 seconds
```

Use case: Wake-up alarms, accessibility, automation scripts.

### Text-to-Speech
Built-in speech synthesis:
```bash
peekaboo say "Hello Peter"
peekaboo say "Wake up!" --voice Samantha --rate 200
peekaboo say "Alert" --volume 80
```

Use case: Alerts, accessibility, wake-up alarms without needing `say` command.

---

## Example: Full Wake-up Alarm (Future Vision)

Once these features exist, a complete alarm could be:
```bash
peekaboo say "Wake up Peter! Time for your adventure!"
peekaboo volume 20
peekaboo click "Gareth Emery" --app Safari --double
peekaboo media play
peekaboo volume 70 --ramp 10s
```

No AppleScript, no shell hacks - just Peekaboo. 🔥

---

## Other Ideas

### Battery Monitoring
```bash
peekaboo system battery      # Show battery status
peekaboo system battery --json
```

### Brightness Control
```bash
peekaboo brightness 50
peekaboo brightness up/down
```

---

*Added: 2025-11-27 by Clawd during late-night alarm-building session*
