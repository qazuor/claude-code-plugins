#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# stop-beep.sh - Main session stop beep for Claude Code
# =============================================================================
#
# Called by Claude Code on "Stop" hook events (main session ends).
# Plays a distinctive beep to alert the user that Claude has finished.
#
# Audio: 1000Hz sine wave for 0.2 seconds
#
# Platform support:
#   - Linux:  speaker-test (from alsa-utils)
#   - macOS:  afplay with Glass.aiff system sound
#   - WSL:    powershell.exe beep
#   - All:    terminal bell as final fallback
# =============================================================================

# ---------------------------------------------------------------------------
# OS Detection
# ---------------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

OS="$(detect_os)"

# ---------------------------------------------------------------------------
# Play Stop Beep
# ---------------------------------------------------------------------------
# 1000Hz sine wave for 0.2s - a clear, noticeable tone indicating
# the main Claude session has completed.
play_beep() {
    case "$OS" in
        linux)
            # speaker-test generates a sine wave; timeout limits duration
            if command -v speaker-test &>/dev/null; then
                timeout 0.2 speaker-test -t sine -f 1000 -l 1 &>/dev/null || true
                return 0
            fi
            # paplay with a generated beep via sox
            if command -v sox &>/dev/null && command -v paplay &>/dev/null; then
                sox -n -t wav - synth 0.2 sine 1000 vol 0.5 | paplay 2>/dev/null
                return 0
            fi
            ;;
        macos)
            # macOS system sound: Glass (a clean, recognizable chime)
            if command -v afplay &>/dev/null && [[ -f /System/Library/Sounds/Glass.aiff ]]; then
                afplay /System/Library/Sounds/Glass.aiff
                return 0
            fi
            ;;
        wsl)
            # WSL: use powershell's console beep (1000Hz for 200ms)
            if command -v powershell.exe &>/dev/null; then
                powershell.exe -c "[console]::beep(1000,200)" 2>/dev/null
                return 0
            fi
            # WSL with speaker-test (if PulseAudio/ALSA is set up)
            if command -v speaker-test &>/dev/null; then
                timeout 0.2 speaker-test -t sine -f 1000 -l 1 &>/dev/null || true
                return 0
            fi
            ;;
    esac

    # Final fallback: terminal bell character
    printf "\a"
    return 0
}

play_beep
