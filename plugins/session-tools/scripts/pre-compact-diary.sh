#!/bin/bash
# =============================================================================
# pre-compact-diary.sh - Auto-generate diary entry before compact
# =============================================================================
#
# Called by Claude Code on "PreCompact" hook events.
# Instructs Claude to create a diary entry before the conversation is compacted,
# preserving session learnings while context is still available.
#
# Based on: https://github.com/rlancemartin/claude-diary
# =============================================================================

echo "Before compacting, create a diary entry to preserve this session's learnings."
echo ""
echo "/diary"
