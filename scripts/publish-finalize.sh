#!/usr/bin/env bash
#
# publish-finalize.sh: clean up after a successful /publish. Deletes the
# inbox draft and the pending plan JSON. Does NOT commit. Does NOT push.
#
# Usage:
#   bash scripts/publish-finalize.sh <slug>

set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" ]]; then
  echo "usage: publish-finalize.sh <slug>" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! [[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: slug '${SLUG}' is invalid." >&2
  exit 65
fi

INBOX_PATH="inbox/${SLUG}.md"
PLAN_PATH="archival/_pending/${SLUG}.publish-plan.json"

if [[ -f "$INBOX_PATH" ]]; then
  rm -f "$INBOX_PATH"
  echo "deleted ${INBOX_PATH}"
else
  echo "note: ${INBOX_PATH} was already gone"
fi

if [[ -f "$PLAN_PATH" ]]; then
  rm -f "$PLAN_PATH"
  echo "deleted ${PLAN_PATH}"
fi
