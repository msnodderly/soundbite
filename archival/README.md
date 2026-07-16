# archival/

The citation chain. For each published soundbite:

- `<slug>.transcript.md` — the raw, timestamped transcript, verbatim from
  the transcriber. Never edited. If a transcript is wrong, fix the
  published wiki page or the inbox draft instead.
- `<slug>.meta.json` — source metadata (title, channel, URL, requested
  range, capture date, transcriber).

Both are committed and kept indefinitely: they are the receipt that
survives if the source video disappears.

Not committed (gitignored): downloaded media (deleted after
transcription) and `_pending/`, the staging area for fetches awaiting
slug approval.
