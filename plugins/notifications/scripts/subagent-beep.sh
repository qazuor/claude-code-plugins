#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# subagent-beep.sh - Subagent stop beep for Claude Code
# =============================================================================
#
# Called by Claude Code on "SubagentStop" hook events.
# Plays a shorter, lower-pitched beep than the main stop beep to distinguish
# subagent completion from main session completion.
#
# Audio: 800Hz sine wave for 0.1 seconds (shorter and lower than stop-beep.sh)
#
# Platform support:
#   - Linux:  speaker-test (from alsa-utils)
#   - macOS:  afplay with Pop.aiff system sound
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
# Play Subagent Beep
# ---------------------------------------------------------------------------
# 800Hz sine wave for 0.1s - a subtle, quick tone indicating
# a subagent task has completed. Intentionally shorter and lower-pitched
# than the main stop beep (1000Hz / 0.2s) so users can tell them apart.
play_beep() {
    case "$OS" in
        linux)
            # speaker-test generates a sine wave; timeout limits duration
            if command -v speaker-test &>/dev/null; then
                timeout 0.1 speaker-test -t sine -f 800 -l 1 &>/dev/null || true
                return 0
            fi
            # sox + paplay fallback
            if command -v sox &>/dev/null && command -v paplay &>/dev/null; then
                sox -n -t wav - synth 0.1 sine 800 vol 0.5 | paplay 2>/dev/null
                return 0
            fi
            ;;
        macos)
            # macOS system sound: Pop (a short, subtle sound)
            if command -v afplay &>/dev/null && [[ -f /System/Library/Sounds/Pop.aiff ]]; then
                afplay /System/Library/Sounds/Pop.aiff
                return 0
            fi
            ;;
        wsl)
            # WSL: use powershell's console beep (800Hz for 100ms)
            if command -v powershell.exe &>/dev/null; then
                powershell.exe -c "[console]::beep(800,100)" 2>/dev/null
                return 0
            fi
            # WSL with speaker-test (if PulseAudio/ALSA is set up)
            if command -v speaker-test &>/dev/null; then
                timeout 0.1 speaker-test -t sine -f 800 -l 1 &>/dev/null || true
                return 0
            fi
            ;;
    esac

    # Final fallback: terminal bell character
    printf "\a"
    return 0
}

play_beep
