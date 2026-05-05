#!/usr/bin/env bash
#
# snarf-fetch.sh: download/trim a clip, transcribe, archive metadata into a
# pending location. Does NOT pick a slug. The /snarf skill reads the pending
# transcript, proposes content-based slug candidates to the user, and then
# calls snarf-finalize.sh to rename the pending files.
#
# Usage:
#   bash scripts/snarf-fetch.sh <url|path> <start> <end>
#
# On success the final stdout line is the temp-id, which the caller passes
# to snarf-finalize.sh together with the user-approved slug.

set -euo pipefail

SOURCE="${1:-}"
START="${2:-}"
END="${3:-}"

if [[ -z "$SOURCE" ]]; then
  echo "usage: snarf-fetch.sh <url|path> <start> <end>" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

have() { command -v "$1" >/dev/null 2>&1; }

require() {
  local cmd="$1" hint="$2"
  if ! have "$cmd"; then
    echo "ERROR: required command '$cmd' is not installed." >&2
    echo "  $hint" >&2
    exit 1
  fi
}

require ffmpeg "Install: brew install ffmpeg"
require python3 "Install: brew install python3 (or use the system python3)"
require vcut "Install: https://github.com/msnodderly/vcut"

IS_URL=false
if [[ "$SOURCE" =~ ^https?:// ]]; then
  IS_URL=true
  require yt-dlp "Install: brew install yt-dlp"
  if [[ -z "$START" || -z "$END" ]]; then
    echo "ERROR: time range (START END) is required for URL sources." >&2
    exit 64
  fi
elif [[ ! -f "$SOURCE" ]]; then
  echo "ERROR: '$SOURCE' is neither a URL nor an existing file." >&2
  exit 66
fi

mkdir -p archival/_pending

TEMP_ID="t-$(date -u +%Y%m%d-%H%M%S)-${RANDOM}"
PENDING_PREFIX="archival/_pending/${TEMP_ID}"
AUDIO="${PENDING_PREFIX}.mp3"
META="${PENDING_PREFIX}.meta.json"
TRANSCRIPT="${PENDING_PREFIX}.transcript.md"

echo ">>> snarf-fetch: temp-id=${TEMP_ID}" >&2

# Resolve source-side metadata up front (used in meta.json).
TITLE=""
CHANNEL=""
UPLOAD_DATE=""

if $IS_URL; then
  TITLE="$(yt-dlp --get-title "$SOURCE" 2>/dev/null || true)"
  CHANNEL="$(yt-dlp --print uploader "$SOURCE" 2>/dev/null || true)"
  UPLOAD_DATE="$(yt-dlp --print upload_date "$SOURCE" 2>/dev/null || true)"
  if [[ -z "$TITLE" ]]; then
    echo "ERROR: yt-dlp could not resolve a title for $SOURCE" >&2
    exit 1
  fi
else
  TITLE="$(basename "${SOURCE%.*}")"
fi

# Step 1: get audio.
if $IS_URL; then
  yt-dlp -x --audio-format mp3 \
    --download-sections "*${START}-${END}" \
    -o "${PENDING_PREFIX}.%(ext)s" \
    "$SOURCE" >&2
else
  if [[ -n "$START" && -n "$END" ]]; then
    ffmpeg -y -hide_banner -loglevel error -i "$SOURCE" \
      -ss "$START" -to "$END" -vn -c:a libmp3lame "$AUDIO" >&2
  else
    ffmpeg -y -hide_banner -loglevel error -i "$SOURCE" \
      -vn -c:a libmp3lame "$AUDIO" >&2
  fi
fi

if [[ ! -f "$AUDIO" ]]; then
  echo "ERROR: expected $AUDIO after download/trim, but it is missing." >&2
  exit 1
fi

# Step 2: write pending meta.json.
CAPTURED="$(date -u +%Y-%m-%d)"
TEMP_ID="$TEMP_ID" TITLE="$TITLE" SOURCE_ARG="$SOURCE" \
  CHANNEL="${CHANNEL:-}" UPLOAD_DATE="${UPLOAD_DATE:-}" \
  CAPTURED="$CAPTURED" START="${START:-}" END="${END:-}" \
  IS_URL="$($IS_URL && echo true || echo false)" \
python3 - <<'PY' > "$META"
import json, os
def opt(k):
    v = os.environ.get(k, "")
    return v if v else None
meta = {
    "slug": None,
    "temp_id": os.environ["TEMP_ID"],
    "title": os.environ["TITLE"],
    "source": os.environ["SOURCE_ARG"],
    "is_url": os.environ["IS_URL"] == "true",
    "channel": opt("CHANNEL"),
    "upload_date": opt("UPLOAD_DATE"),
    "captured": os.environ["CAPTURED"],
    "range_start": opt("START"),
    "range_end": opt("END"),
    "transcriber": "vcut",
}
print(json.dumps(meta, indent=2))
PY

# Step 3: transcribe with vcut. vcut writes vcut-format lines
# (`[HH:MM:SS.mmm -> HH:MM:SS.mmm] | text`) to stdout.
vcut transcribe "$AUDIO" > "$TRANSCRIPT"

if [[ ! -s "$TRANSCRIPT" ]]; then
  echo "ERROR: transcript is empty: $TRANSCRIPT" >&2
  exit 1
fi

# Step 4: delete pending audio. Slug approval can take a while; no need to
# keep the audio around.
rm -f "$AUDIO"

# Final stdout line: the temp-id.
echo "$TEMP_ID"
