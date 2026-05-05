#!/usr/bin/env bash
#
# snarf-finalize.sh: take a pending fetch and a user-approved slug, validate
# the slug, move the pending files into archival/<slug>.{transcript.md,
# meta.json}, and update the slug field in the meta JSON.
#
# Usage:
#   bash scripts/snarf-finalize.sh <temp-id> <slug>
#
# Exits non-zero with an explanatory message on bad slug or collision so the
# /snarf skill can re-prompt the user.

set -euo pipefail

TEMP_ID="${1:-}"
SLUG="${2:-}"

if [[ -z "$TEMP_ID" || -z "$SLUG" ]]; then
  echo "usage: snarf-finalize.sh <temp-id> <slug>" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

PENDING_PREFIX="archival/_pending/${TEMP_ID}"
PENDING_TRANSCRIPT="${PENDING_PREFIX}.transcript.md"
PENDING_META="${PENDING_PREFIX}.meta.json"

if [[ ! -f "$PENDING_TRANSCRIPT" || ! -f "$PENDING_META" ]]; then
  echo "ERROR: pending files not found for temp-id '${TEMP_ID}'." >&2
  echo "  expected: $PENDING_TRANSCRIPT" >&2
  echo "  expected: $PENDING_META" >&2
  exit 1
fi

# Slug validation: lowercase alnum tokens joined by single hyphens, 2-60 chars.
if ! python3 - "$SLUG" <<'PY' >/dev/null 2>&1
import re, sys
s = sys.argv[1]
if not (2 <= len(s) <= 60):
    sys.exit(1)
if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", s):
    sys.exit(1)
PY
then
  echo "ERROR: slug '${SLUG}' is invalid." >&2
  echo "  Slugs must be lowercase, hyphen-separated alphanumeric tokens," >&2
  echo "  2-60 characters, no leading/trailing/consecutive hyphens." >&2
  exit 65
fi

FINAL_TRANSCRIPT="archival/${SLUG}.transcript.md"
FINAL_META="archival/${SLUG}.meta.json"
FINAL_INBOX="inbox/${SLUG}.md"

if [[ -e "$FINAL_TRANSCRIPT" || -e "$FINAL_META" || -e "$FINAL_INBOX" ]]; then
  echo "ERROR: slug '${SLUG}' is already in use." >&2
  [[ -e "$FINAL_TRANSCRIPT" ]] && echo "  exists: $FINAL_TRANSCRIPT" >&2
  [[ -e "$FINAL_META" ]] && echo "  exists: $FINAL_META" >&2
  [[ -e "$FINAL_INBOX" ]] && echo "  exists: $FINAL_INBOX" >&2
  echo "  Pick a different slug or remove the existing files first." >&2
  exit 66
fi

# Move transcript first (idempotent rename), then update + move meta, then
# write the inbox file (raw transcript + metadata footer; user edits this).
mv "$PENDING_TRANSCRIPT" "$FINAL_TRANSCRIPT"

mkdir -p inbox

SLUG="$SLUG" PENDING_META="$PENDING_META" FINAL_META="$FINAL_META" \
  FINAL_TRANSCRIPT="$FINAL_TRANSCRIPT" FINAL_INBOX="$FINAL_INBOX" \
python3 - <<'PY'
import json, os, re

slug = os.environ["SLUG"]
src = os.environ["PENDING_META"]
dst = os.environ["FINAL_META"]
transcript_path = os.environ["FINAL_TRANSCRIPT"]
inbox_path = os.environ["FINAL_INBOX"]

with open(src) as f:
    meta = json.load(f)
meta["slug"] = slug
meta.pop("temp_id", None)
with open(dst, "w") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
os.remove(src)

with open(transcript_path) as f:
    transcript = f.read().rstrip("\n")

def ts_to_seconds(ts):
    if not ts:
        return None
    parts = ts.split(":")
    try:
        parts = [int(p) for p in parts]
    except ValueError:
        return None
    if len(parts) == 2:
        return parts[0] * 60 + parts[1]
    if len(parts) == 3:
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    return None

source = meta.get("source") or ""
is_url = bool(meta.get("is_url"))
channel = meta.get("channel") or ""
title = meta.get("title") or ""
captured = meta.get("captured") or ""
range_start = meta.get("range_start") or ""
range_end = meta.get("range_end") or ""

source_url = source
if is_url and "youtube.com" in source and range_start:
    secs = ts_to_seconds(range_start)
    if secs is not None:
        sep = "&" if "?" in source else "?"
        source_url = f"{source}{sep}t={secs}"

if channel and title:
    source_label = f"{channel}: {title}"
elif title:
    source_label = title
else:
    source_label = source_url or "source"

if range_start and range_end:
    range_str = f"{range_start} to {range_end}"
elif range_start:
    range_str = range_start
else:
    range_str = ""

lines = [
    "<!--",
    "Edit this file to produce your soundbite, then run /ingest on it.",
    "- Lines beginning with `# ` are skipped during /ingest.",
    "- Comment out filler/tangents by prefixing the cue line with `# `.",
    "- Edit transcript text directly to fix transcription errors.",
    "- Fill in the title, tags, speaker(s), and context below.",
    "- Remove these instruction comments before /ingest.",
    "-->",
    "",
    "# TODO: title",
    "",
    transcript,
    "",
    "**Speaker(s):** TODO: name speakers",
    f"**Source:** [{source_label}]({source_url})",
    f"**Captured:** {captured}",
    f"**Range:** {range_str}",
    "**Tags:** TODO",
    "",
    "---",
    "",
    "## Context",
    "",
    "TODO",
    "",
    "## Notes",
    "",
    "",
    "",
    "---",
    "",
    f"[Raw transcript with timecodes](../archival/{slug}.transcript.md)",
    "",
]
with open(inbox_path, "w") as f:
    f.write("\n".join(lines))
PY

echo "$SLUG"
