#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# on-notification.sh - Desktop notification + TTS audio for Claude Code
# =============================================================================
#
# Called by Claude Code on "Notification" hook events.
# Reads a JSON payload from stdin with the notification message.
#
# Features:
#   - Desktop notification (notify-send / terminal-notifier / osascript)
#   - Text-to-speech via piper TTS, with fallback to say (macOS) or espeak
#   - Cross-platform: Linux, macOS, WSL auto-detection
#   - Logs all notifications to .claude/.log/notifications.log
#
# JSON stdin format: { "message": "..." }
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PIPER_MODEL="${HOME}/.local/share/piper/voices/en_US-hfc_male-medium.onnx"
PIPER_CONFIG="${PIPER_MODEL}.json"
LENGTH_SCALE=0.8
VOLUME=0.3
LOG_DIR=".claude/.log"
LOG_FILE="${LOG_DIR}/notifications.log"

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
# Read JSON payload from stdin (official Claude Code hook format)
# ---------------------------------------------------------------------------
payload="$(cat)"
message="$(echo "$payload" | jq -r '.message // empty')"

# If jq failed or message is empty, try using the raw payload as the message
if [[ -z "$message" ]]; then
    message="${payload:-Claude needs your attention}"
fi

# ---------------------------------------------------------------------------
# Desktop Notification
# ---------------------------------------------------------------------------
# Try platform-appropriate notification tools in order of preference.
send_desktop_notification() {
    local msg="$1"

    case "$OS" in
        linux)
            if command -v notify-send &>/dev/null; then
                notify-send "Claude Code" "$msg" \
                    --icon=dialog-information \
                    --urgency=normal
                return 0
            fi
            ;;
        macos)
            if command -v terminal-notifier &>/dev/null; then
                terminal-notifier -title "Claude Code" -message "$msg"
                return 0
            elif command -v osascript &>/dev/null; then
                # Escape message for safe AppleScript interpolation
                local escaped_msg
                escaped_msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
                osascript -e "display notification \"$escaped_msg\" with title \"Claude Code\""
                return 0
            fi
            ;;
        wsl)
            # WSL: try notify-send first (if running an X server), then powershell
            if command -v notify-send &>/dev/null; then
                notify-send "Claude Code" "$msg" \
                    --icon=dialog-information \
                    --urgency=normal 2>/dev/null
                return 0
            elif command -v powershell.exe &>/dev/null; then
                # Escape message for safe PowerShell interpolation
                local ps_msg
                ps_msg=$(printf '%s' "$msg" | sed "s/'/\\\\'/g")
                powershell.exe -c "
                    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null;
                    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02);
                    \$textNodes = \$template.GetElementsByTagName('text');
                    \$textNodes.Item(0).AppendChild(\$template.CreateTextNode('Claude Code')) | Out-Null;
                    \$textNodes.Item(1).AppendChild(\$template.CreateTextNode('$ps_msg')) | Out-Null;
                    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template);
                    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast);
                " 2>/dev/null
                return 0
            fi
            ;;
    esac

    # Final fallback: no desktop notification available
    return 1
}

send_desktop_notification "$message" || true

# ---------------------------------------------------------------------------
# Audio Notification (Text-to-Speech)
# ---------------------------------------------------------------------------
# Preferred: piper TTS with specific voice model piped to aplay.
# Fallbacks: say (macOS), espeak (Linux), or silent failure.
speak_message() {
    local msg="$1"

    # Piper TTS (Linux preferred - high quality offline TTS)
    if command -v piper &>/dev/null && [[ -f "$PIPER_MODEL" ]]; then
        if command -v aplay &>/dev/null; then
            echo "$msg" | piper \
                -m "$PIPER_MODEL" \
                -c "$PIPER_CONFIG" \
                --output-raw \
                --length-scale "$LENGTH_SCALE" \
                --volume "$VOLUME" \
                | aplay -f S16_LE -r 22050 -t raw - 2>/dev/null
            return 0
        fi
    fi

    # macOS: built-in say command
    if command -v say &>/dev/null; then
        say "$msg"
        return 0
    fi

    # espeak fallback (available on most Linux distros)
    if command -v espeak &>/dev/null; then
        espeak "$msg" 2>/dev/null
        return 0
    fi

    # espeak-ng fallback (newer replacement for espeak)
    if command -v espeak-ng &>/dev/null; then
        espeak-ng "$msg" 2>/dev/null
        return 0
    fi

    # No TTS engine found - silent failure
    return 1
}

speak_message "$message" || true

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "$LOG_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOTIFICATION: $message" >> "$LOG_FILE"
