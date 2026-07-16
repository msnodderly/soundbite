#!/usr/bin/env bash
#
# publish-validate.sh: validate an inbox draft and emit a JSON plan describing
# every wiki file /publish would touch. Does not write to the wiki, does not
# delete the inbox draft, does not commit.
#
# Usage:
#   bash scripts/publish-validate.sh <inbox-path>
#
# On success the final stdout line is the path to a JSON plan file under
# archival/_pending/. On failure exits non-zero with one error line per
# missing/invalid field on stderr.

set -euo pipefail

INBOX_PATH="${1:-}"
if [[ -z "$INBOX_PATH" ]]; then
  echo "usage: publish-validate.sh <inbox-path>" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f "$INBOX_PATH" ]]; then
  echo "ERROR: inbox file not found: $INBOX_PATH" >&2
  exit 1
fi

WIKI_DIR_RAW="${SOUNDBITE_WIKI_DIR:-$REPO_ROOT/../soundbite.wiki}"
if [[ ! -d "$WIKI_DIR_RAW" ]]; then
  echo "ERROR: wiki directory not found at: $WIKI_DIR_RAW" >&2
  echo "  Expected sibling at ../soundbite.wiki, or set SOUNDBITE_WIKI_DIR." >&2
  exit 1
fi
WIKI_DIR="$(cd "$WIKI_DIR_RAW" && pwd)"

INBOX_PATH="$(cd "$(dirname "$INBOX_PATH")" && pwd)/$(basename "$INBOX_PATH")"

mkdir -p archival/_pending

INBOX_PATH="$INBOX_PATH" REPO_ROOT="$REPO_ROOT" WIKI_DIR="$WIKI_DIR" \
python3 - <<'PY'
import json, os, re, sys
from pathlib import Path

inbox_path = Path(os.environ["INBOX_PATH"])
repo_root = Path(os.environ["REPO_ROOT"])
wiki_dir = Path(os.environ["WIKI_DIR"])

slug = inbox_path.stem
if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", slug):
    print(f"ERROR: inbox filename slug '{slug}' is not lowercase hyphen-separated", file=sys.stderr)
    sys.exit(65)

archival_transcript = repo_root / "archival" / f"{slug}.transcript.md"
archival_meta = repo_root / "archival" / f"{slug}.meta.json"
errors = []

if not archival_transcript.exists():
    errors.append(f"missing archival transcript: {archival_transcript.relative_to(repo_root)}")
if not archival_meta.exists():
    errors.append(f"missing archival meta: {archival_meta.relative_to(repo_root)}")

raw = inbox_path.read_text()
raw_no_comments = re.sub(r"<!--.*?-->", "", raw, flags=re.DOTALL)
lines = raw_no_comments.splitlines()

title = None
title_idx = None
for i, line in enumerate(lines):
    if line.startswith("# ") and not line.startswith("## "):
        title = line[2:].strip()
        title_idx = i
        break

if title_idx is None:
    errors.append("missing top-level title (# ...)")
elif not title or title.upper().startswith("TODO"):
    errors.append("title is empty or still 'TODO'")

speaker_idx = None
for i, line in enumerate(lines):
    if line.startswith("**Speaker(s):**"):
        speaker_idx = i
        break
if speaker_idx is None:
    errors.append("missing **Speaker(s):** line")

def find_field(name):
    prefix = f"**{name}:**"
    for line in lines:
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return None

speakers = find_field("Speaker(s)")
source_line = find_field("Source")
captured = find_field("Captured")
range_str = find_field("Range")
tags_line = find_field("Tags")

if speakers is None or "TODO" in (speakers or "").upper() or not speakers:
    errors.append("**Speaker(s):** is empty or contains TODO")
if source_line is None:
    errors.append("missing **Source:** line")
if captured is None or not captured:
    errors.append("missing **Captured:** line")
elif not re.fullmatch(r"\d{4}-\d{2}-\d{2}", captured):
    errors.append(f"**Captured:** is not YYYY-MM-DD: '{captured}'")
if range_str is None or not range_str:
    errors.append("missing **Range:** line")
if tags_line is None or not tags_line or "TODO" in tags_line.upper():
    errors.append("**Tags:** is empty or contains TODO")

source_label = source_url = None
if source_line:
    m = re.match(r"\[([^\]]+)\]\(([^)]+)\)\s*$", source_line)
    if m:
        source_label = m.group(1).strip()
        source_url = m.group(2).strip()
    else:
        errors.append("**Source:** must be in [label](url) form")

tag_names = []
if tags_line and "TODO" not in tags_line.upper():
    tag_names = re.findall(r"\[\[([^\]]+)\]\]", tags_line)
    if not tag_names:
        errors.append("**Tags:** must contain at least one [[Tag-Name]]")
    else:
        for t in tag_names:
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*", t):
                errors.append(f"tag '[[{t}]]' contains characters that won't work as a wiki filename")

quote_lines = []
if title_idx is not None and speaker_idx is not None and speaker_idx > title_idx:
    raw_quote = lines[title_idx + 1:speaker_idx]
    filtered = [ln for ln in raw_quote if not ln.lstrip().startswith("# ")]
    while filtered and not filtered[0].strip():
        filtered.pop(0)
    while filtered and not filtered[-1].strip():
        filtered.pop()
    quote_lines = filtered
quote_body = "\n".join(quote_lines).strip()
if not quote_body:
    errors.append("quote body (between title and **Speaker(s):**) is empty")

context = ""
ctx_match = re.search(r"^##\s+Context\s*\n(.*?)(?=^##\s|\n---\s*$|\Z)",
                     raw_no_comments, re.M | re.DOTALL)
if ctx_match:
    context = ctx_match.group(1).strip()
if not context or context.upper() == "TODO":
    errors.append("## Context is empty or 'TODO'")

notes = ""
notes_match = re.search(r"^##\s+Notes\s*\n(.*?)(?=^##\s|\n---\s*$|\Z)",
                       raw_no_comments, re.M | re.DOTALL)
if notes_match:
    notes_raw = notes_match.group(1).strip()
    if notes_raw and notes_raw.upper() != "TODO":
        notes = notes_raw

if errors:
    print("ERROR: inbox draft is not ready for publish:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

wiki_slug = "-".join(p.capitalize() for p in slug.split("-"))
wiki_page_path = wiki_dir / f"{wiki_slug}.md"
home_path = wiki_dir / "Home.md"

existing_home = home_path.read_text() if home_path.exists() else ""
home_needs_bootstrap = "## Recent" not in existing_home

topic_pages = []
for tag in tag_names:
    tp = wiki_dir / f"{tag}.md"
    topic_pages.append({
        "tag": tag,
        "path": str(tp),
        "exists": tp.exists(),
    })

plan = {
    "slug": slug,
    "wiki_slug": wiki_slug,
    "title": title,
    "speakers": speakers,
    "source_label": source_label,
    "source_url": source_url,
    "captured": captured,
    "range": range_str,
    "tags_line": tags_line,
    "tags": tag_names,
    "context": context,
    "notes": notes,
    "quote_body": quote_body,
    "inbox_path": str(inbox_path),
    "archival_transcript": str(archival_transcript),
    "archival_meta": str(archival_meta),
    "wiki_dir": str(wiki_dir),
    "wiki_page_path": str(wiki_page_path),
    "wiki_page_exists": wiki_page_path.exists(),
    "home_path": str(home_path),
    "home_exists": home_path.exists(),
    "home_needs_bootstrap": home_needs_bootstrap,
    "topic_pages": topic_pages,
    "raw_transcript_url": f"https://github.com/msnodderly/soundbite/blob/main/archival/{slug}.transcript.md",
}

plan_path = repo_root / "archival" / "_pending" / f"{slug}.publish-plan.json"
plan_path.write_text(json.dumps(plan, indent=2) + "\n")
print(str(plan_path))
PY
