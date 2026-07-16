# soundbite
An experiment in writing software as markdown files, coding agents as the UI.

Inspired by Karpathy's LLM wiki concept, for audio/visual content.


Capture the best moments from podcasts, talks, and interviews, and publish
them as a wiki of attributed, citable quotes.

Point it at a YouTube URL and a time range. It downloads the clip,
transcribes it, and archives the raw transcript as a permanent citation.
You shape the transcript into a quote worth keeping; it publishes the
result to [the wiki](https://github.com/msnodderly/soundbite/wiki) with a
link back to the exact moment in the source.

This an experiment in writing software as markdown: the "program"
is a pair of [Claude Code](https://claude.com/claude-code) skills plus a
few small shell scripts, and the coding agent is the UI.

## How it works

```
source URL + time range
    -> /snarf   -> archival/<slug>.transcript.md   (raw transcript, kept forever)
                   archival/<slug>.meta.json       (source metadata, kept forever)
                   inbox/<slug>.md                 (gitignored working draft)
    -> [edit]      inbox/<slug>.md                 (you shape the quote, add title/tags/context)
    -> /publish -> soundbite.wiki/<Slug>.md        (published page)
                   soundbite.wiki/Home.md          (index updated)
```

Three stages, cleanly separated:

1. **`/snarf <url|file> <start> <end>`** — downloads and trims the clip,
   transcribes it, proposes content-based slugs for you to approve, then
   writes the verbatim transcript into an inbox draft. Media is deleted
   after transcription; only text is kept.
2. **Edit** — you are the editor. Cut filler, name speakers, fix
   transcription errors, write the title, tags, and context. The agent
   never makes editorial decisions about what a quote should say.
3. **`/publish [inbox/<slug>.md]`** — validates the draft, generates the
   wiki page, updates the index and topic pages, and commits (never
   pushes) with your approval at every step.

Every published quote links back to its source with a timestamp, and the
raw transcript stays committed in `archival/` — the receipt that survives
even if the source video disappears.

## Usage

Prerequisites:

- [Claude Code](https://claude.com/claude-code) (the skills run in it)
- `ffmpeg` and `yt-dlp` (`brew install ffmpeg yt-dlp`)
- [`vcut`](https://github.com/msnodderly/vcut) for transcription
- A sibling clone of the wiki: `git clone git@github.com:msnodderly/soundbite.wiki.git ../soundbite.wiki`
  (or set `SOUNDBITE_WIKI_DIR`)

Then, inside Claude Code:

```
/snarf https://www.youtube.com/watch?v=Hy-tQlk5RTU 49:30 58:00
# edit inbox/<slug>.md to taste
/publish
# review, approve, then push both repos
```

## Repo layout

- `.claude/skills/` — the skill definitions (`snarf`, `publish`; `lint` planned)
- `scripts/` — deterministic shell scripts the skills call
- `archival/` — committed raw transcripts and source metadata; the citation chain
- `inbox/` — gitignored in-flight drafts, deleted on publish
- `plan.md` — design doc and rolling implementation checklist
- `AGENTS.md` — conventions for coding agents working in this repo

## Principles

- **The archive is the receipt.** Raw transcripts are never edited; the
  published page is the curated artifact, the archive is the evidence.
- **The human is the editor.** Agents do mechanical work (fetch,
  transcribe, format, file); all editorial judgment stays with the user.
- **Nothing is written or committed without approval.** Every content
  change is shown as a diff first, and nothing is ever pushed
  automatically.
- **Working in public.** Skills, scripts, prompts, and false starts are
  all in the open. See `plan.md` for design decisions and status.
