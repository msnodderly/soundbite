---
name: snarf
description: Capture an A/V clip from a YouTube URL or local file with a time range, transcribe it with vcut, propose a content-based slug for the user to approve, and write the raw transcript plus a metadata footer into inbox/<slug>.md for the user to edit directly before /ingest. Use this skill when the user asks to grab, clip, save, or snarf a quote from a video, podcast, or interview, or types /snarf.
---

# /snarf

Pulls audio from a source, transcribes it with vcut, and writes the raw
vcut-format transcript into `inbox/<slug>.md` (plus a metadata footer with
TODO placeholders for title/tags/context). The user edits that file
directly before running `/ingest` on it.

The slug for the soundbite reflects the **topic/content of the clip**, not
the source title. The skill proposes candidate slugs after transcribing and
asks the user to pick one or supply their own.

## Inputs

`/snarf <source> <start> <end>`

- `<source>` — YouTube URL **or** path to a local audio/video file.
- `<start>`, `<end>` — `MM:SS` or `HH:MM:SS`. Required for URLs; optional
  for local files.

The skill does not accept a slug argument. Slugs are decided interactively
after transcription so the user can name the soundbite by what it is about.

## Steps

### 1. Fetch and transcribe

Run `bash scripts/snarf-fetch.sh <source> <start> <end>`. The script:

- Verifies dependencies (`vcut` and `ffmpeg` always, plus `yt-dlp` for URLs)
  and prints friendly install hints if any are missing.
- Downloads or trims the requested range of media into `archival/_pending/`.
- Captures source metadata to `archival/_pending/<temp-id>.meta.json`.
- Transcribes with vcut to `archival/_pending/<temp-id>.transcript.md` in
  vcut format (`[HH:MM:SS.mmm -> HH:MM:SS.mmm] | text`).
- Deletes the audio file.
- Prints the temp-id on stdout (last line).

If the script exits non-zero, surface the script's stderr to the user and
stop. Do not proceed.

### 2. Read the pending transcript and metadata

Read both `archival/_pending/<temp-id>.transcript.md` and
`archival/_pending/<temp-id>.meta.json` in full before proposing slugs.

### 3. Propose content-based slug candidates

Slugs name the soundbite by what it is about. They function like search
keywords: someone looking for this idea later should plausibly type the
slug words.

Generate **3-5 candidates**, ordered with your best recommendation first.
A good slug is:

- 2-5 words, lowercase, hyphen-separated.
- Built from the distinctive concept(s) in the clip plus a context word
  (subject area, person, organization, year) when it sharpens the meaning.
- Searchable: someone who already knows the idea would recognize the words.

A bad slug is:

- The source title or channel name (`acquired-microsoft-ep-127`,
  `huberman-lab-2024`). Source containers ≠ content.
- Generic genre words (`interview`, `talk`, `podcast`, `discussion`,
  `episode`, `clip`, `quote`).
- A speaker's name alone (`paul-graham`, `ben-thompson`) without a topic.
- A date format (`2024-04-15`).

Good examples (for reference, not for output):

- `microsoft-1985-pivot`
- `cohort-retention-stripe`
- `npm-postinstall-supply-chain`
- `founder-ceo-transition`
- `slow-decay-of-strong-companies`

### 4. Ask the user to approve

Present the candidates as a numbered list with one short reason for each.
Prefer using the AskUserQuestion tool if available; otherwise print the
list in chat and wait for a reply. Accept any of:

- A number (`2`).
- A free-text slug (the user's own).
- "First one", "use the second", or similar natural-language picks.

If the user supplies their own slug, validate it loosely (lowercase,
hyphen-separated alphanumerics) before passing it to the finalize script,
which will validate strictly and reject malformed slugs with an error.

### 5. Finalize

Run `bash scripts/snarf-finalize.sh <temp-id> <approved-slug>`. The script:

- Validates the slug format strictly (`[a-z0-9]+(-[a-z0-9]+)*`, 2-60 chars).
- Refuses on collision with any existing `archival/<slug>.*` or
  `inbox/<slug>.md`.
- Moves the pending transcript and meta into `archival/<slug>.*` and
  updates the slug field in `meta.json`.
- Writes `inbox/<slug>.md` containing the raw vcut-format transcript plus
  a metadata footer with TODO placeholders for title, tags, speaker(s),
  and context. The Source URL gets `?t=<seconds>` appended for YouTube
  sources, derived from `range_start`.
- Prints the final slug.

If finalize exits non-zero (bad format, collision), report the script's
stderr to the user and ask for another slug. Loop back to step 4.

The agent does **not** propose a title, tags, or context, and does not
edit the transcript. The user does all that by hand in `inbox/<slug>.md`.

### 6. Tell the user what to do next

Print one short confirmation:

```
Wrote inbox/<slug>.md.
Edit to taste, then run /ingest inbox/<slug>.md.
```

## What this skill does NOT do

- Publish to the wiki. That's `/ingest`.
- Update `Home.md`.
- Pick a slug without asking.
- Identify speakers by name automatically.
- Retain media after transcription.

## Recovery from interrupted runs

If the user abandons before approving a slug, pending files remain in
`archival/_pending/` (gitignored). They can be safely deleted, or the user
can re-run `/snarf` and the pending dir will accumulate another temp-id;
old ones are harmless until cleaned up manually.
