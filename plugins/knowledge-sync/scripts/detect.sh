#!/bin/bash
# =============================================================================
# detect.sh - Analyze project dependencies and suggest knowledge components
# =============================================================================
#
# Reads package.json (or equivalent) and compares dependencies against the
# catalog's detectors to suggest relevant components.
# =============================================================================

set -euo pipefail

KNOWLEDGE_DIR="${HOME}/.claude/knowledge-sync"
CACHE_DIR="${KNOWLEDGE_DIR}/cache"
CATALOG_FILE="${CACHE_DIR}/catalog.json"
PROJECT_PATH="${1:-$(pwd)}"

# Validate setup
if [[ ! -f "$CATALOG_FILE" ]]; then
    echo "ERROR: knowledge-sync not set up. Run /knowledge-sync setup first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required. Install it with: sudo apt install jq"
    exit 1
fi

# Detect project dependencies
DEPS=""
PKG_FILE="${PROJECT_PATH}/package.json"

if [[ -f "$PKG_FILE" ]]; then
    DEPS=$(jq -r '(.dependencies // {} | keys[]), (.devDependencies // {} | keys[])' "$PKG_FILE" 2>/dev/null | sort -u)
fi

# Get all components from catalog
COMPONENTS=$(jq -c '.components[]' "$CATALOG_FILE")

# Match components
echo "=== DETECTED COMPONENTS ==="
echo ""
echo "Based on project dependencies at: $PROJECT_PATH"
echo ""

DETECTED_AGENTS=()
DETECTED_SKILLS=()
DETECTED_COMMANDS=()
DETECTED_DOCS=()
DETECTED_TEMPLATES=()

while IFS= read -r comp; do
    [[ -z "$comp" ]] && continue

    name=$(echo "$comp" | jq -r '.name')
    type=$(echo "$comp" | jq -r '.type')
    detectors=$(echo "$comp" | jq -r '.detectors[]' 2>/dev/null)

    matched=false

    # Check if any detector matches a dependency
    if [[ -n "$detectors" ]]; then
        for detector in $detectors; do
            if echo "$DEPS" | grep -qx "$detector" 2>/dev/null; then
                matched=true
                break
            fi
        done
    fi

    # Also include full-stack tagged components (universal)
    if echo "$comp" | jq -e '.tags | index("full-stack")' &>/dev/null; then
        matched=true
    fi

    if [[ "$matched" == "true" ]]; then
        case "$type" in
            agent)    DETECTED_AGENTS+=("$name") ;;
            skill)    DETECTED_SKILLS+=("$name") ;;
            command)  DETECTED_COMMANDS+=("$name") ;;
            doc)      DETECTED_DOCS+=("$name") ;;
            template) DETECTED_TEMPLATES+=("$name") ;;
        esac
    fi
done <<< "$COMPONENTS"

# Output results
if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
    echo "Agents (${#DETECTED_AGENTS[@]}):"
    for a in "${DETECTED_AGENTS[@]}"; do echo "  - $a"; done
    echo ""
fi

if [[ ${#DETECTED_SKILLS[@]} -gt 0 ]]; then
    echo "Skills (${#DETECTED_SKILLS[@]}):"
    for s in "${DETECTED_SKILLS[@]}"; do echo "  - $s"; done
    echo ""
fi

if [[ ${#DETECTED_COMMANDS[@]} -gt 0 ]]; then
    echo "Commands (${#DETECTED_COMMANDS[@]}):"
    for c in "${DETECTED_COMMANDS[@]}"; do echo "  - $c"; done
    echo ""
fi

if [[ ${#DETECTED_DOCS[@]} -gt 0 ]]; then
    echo "Docs (${#DETECTED_DOCS[@]}):"
    for d in "${DETECTED_DOCS[@]}"; do echo "  - $d"; done
    echo ""
fi

if [[ ${#DETECTED_TEMPLATES[@]} -gt 0 ]]; then
    echo "Templates (${#DETECTED_TEMPLATES[@]}):"
    for t in "${DETECTED_TEMPLATES[@]}"; do echo "  - $t"; done
    echo ""
fi

TOTAL=$((${#DETECTED_AGENTS[@]} + ${#DETECTED_SKILLS[@]} + ${#DETECTED_COMMANDS[@]} + ${#DETECTED_DOCS[@]} + ${#DETECTED_TEMPLATES[@]}))
echo "Total suggested: $TOTAL components"
