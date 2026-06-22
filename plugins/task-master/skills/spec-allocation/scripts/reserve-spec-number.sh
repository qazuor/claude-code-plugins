#!/usr/bin/env bash
# Atomically reserve the next free SPEC number using a git tag pushed to the remote.
#
# WHY a tag: `git push` of a tag that ALREADY EXISTS on the remote fails by default
# (tags are immutable without --force). That gives us a distributed, atomic
# compare-and-set with zero custom locking:
#
#     "create spec-reserved-SPEC-N on the remote; if someone already took it,
#      the push fails — advance to N+1 and try again."
#
# This is what engram could never provide: engram is a semantic store with
# last-writer-wins upserts and non-deterministic recall, so two parallel agents
# could both 'reserve' the same number and silently clobber each other. The remote
# ref namespace, by contrast, is a single source of truth with server-side atomic
# ref creation. The tag is permanent (it costs nothing and guarantees the number is
# never reused) — there is no release step.
#
# The tag points at an anchor commit that ALREADY exists on the remote (origin's
# default/staging/main head), NOT at local HEAD — so pushing the tag uploads only
# the ref, never any local work-in-progress commits.
#
# Usage: reserve-spec-number.sh <candidate> [remote]
#   <candidate> — first number to try (typically scan-spec-numbers.sh output + 1)
#   [remote]    — git remote (default: origin)
# Output (stdout): the integer number actually reserved (>= candidate).
# Exit codes:
#   0  reserved — number printed to stdout
#   2  bad usage
#   3  remote unreachable — caller should fall back to scan-only allocation + warn
#   4  exhausted MAX_TRIES without reserving (should never happen in practice)
set -uo pipefail

CANDIDATE="${1:?usage: reserve-spec-number.sh <candidate> [remote]}"
REMOTE="${2:-origin}"
PREFIX="spec-reserved-SPEC-"
MAX_TRIES=200

case "$CANDIDATE" in
  ''|*[!0-9]*) echo "reserve-spec-number.sh: candidate must be a positive integer" >&2; exit 2 ;;
esac

# Remote reachable? If not, bail with a distinct code so the caller can fall back
# to scan-only allocation (a safe lower bound) instead of blocking spec creation.
if ! git ls-remote --exit-code "$REMOTE" >/dev/null 2>&1; then
  echo "NO_REMOTE" >&2
  exit 3
fi

# Anchor: a commit guaranteed to exist on the remote, so the tag push carries no
# local objects. Try the remote's default head, then staging, then main, then any
# remote head; fall back to HEAD only as a last resort.
ANCHOR="$(git rev-parse --verify -q "refs/remotes/${REMOTE}/HEAD" \
       || git rev-parse --verify -q "refs/remotes/${REMOTE}/staging" \
       || git rev-parse --verify -q "refs/remotes/${REMOTE}/main" \
       || git ls-remote "$REMOTE" HEAD 2>/dev/null | awk '{print $1; exit}' \
       || git rev-parse --verify -q HEAD)"
if [ -z "${ANCHOR:-}" ]; then
  echo "NO_ANCHOR" >&2
  exit 3
fi

N="$CANDIDATE"
tries=0
while [ "$tries" -lt "$MAX_TRIES" ]; do
  tag="${PREFIX}${N}"

  # Fast local skip: if this clone (or a sibling worktree sharing the object store)
  # already has the tag, the number is taken locally — advance without a network hop.
  if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1; then
    N=$((N + 1)); tries=$((tries + 1)); continue
  fi

  # Create the local tag at the remote-safe anchor (name is the lock; sha is inert).
  git tag "$tag" "$ANCHOR" >/dev/null 2>&1 || { N=$((N + 1)); tries=$((tries + 1)); continue; }

  # THE atomic step. Succeeds only if the remote tag did not exist.
  if git push "$REMOTE" "refs/tags/${tag}" >/dev/null 2>&1; then
    echo "$N"
    exit 0
  fi

  # Lost the race for N (someone else holds the remote tag). Clean up and advance.
  git tag -d "$tag" >/dev/null 2>&1 || true
  N=$((N + 1)); tries=$((tries + 1))
done

echo "EXHAUSTED" >&2
exit 4
