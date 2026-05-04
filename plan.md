# soundbite plan

A working-in-public experiment: capture quotes, advice, and learnings from audio/video sources (YouTube, podcasts, interviews), produce clean attributed transcripts, and publish them as a wiki of soundbites with citation links back to the source.

Inspired by Karpathy's LLM wiki concept, but specialized for time-bounded A/V capture and audience-facing output.

## v1 scope

In:
- `/snarf` skill: pull a clip from a YouTube URL (or local file) given a time range, transcribe with timestamps, write a draft into `inbox/`.
- Optional manual edit of the inbox draft.
- `/ingest` skill: promote an inbox draft to a published wiki page, update the wiki index, archive the raw transcript.
- Optional manual edit of the published page.
- `/lint` skill: mechanical health check (orphans, missing metadata, broken Home links, citation rot) plus an LLM pass over the corpus for tag and speaker name normalization, contradiction detection, and suggested cross-links.
- GitHub repo wiki as the publishing target.
- One end-to-end POC capture of the example clip.

Out (deferred to v2+):
- Automatic speaker attribution / diarization. Annotate manually for v1.
- Keeping media artifacts. v1 deletes downloaded audio after transcription; published pages link to the original source with timestamp. Only the raw text transcript and source metadata are retained.
- Custom theming, custom domain, GH Pages migration.
- Public launch of the repo. Stays private through v1; flip when output is presentable.
- Cross-source linking heuristics (semantic suggestions for related soundbites).
- Topic/aggregation pages that combine multiple soundbites.

## Retention policy

Three classes of artifact, three retention rules:

- **Kept indefinitely (committed):** raw transcript (`archival/<slug>.transcript.md`), source metadata (`archival/<slug>.meta.json`), the published wiki page, and the wiki repo's git history. These are the citation chain.
- **Ephemeral (gitignored, deleted by `/snarf` or `/ingest`):** downloaded media files (mp3/mp4 pulled by yt-dlp). v1 does not host or commit media. If a user wants to keep a local clip for personal use (e.g. via `vcut edit`), that's a personal choice outside the repo.
- **Working drafts (gitignored, ephemeral):** `inbox/<slug>.md`. Lives only in the local working tree during the snarf-edit-ingest cycle. Never committed. Deleted by `/ingest` on successful publish. No `processed/` directory; the published wiki page is the canonical record of what got shipped.

## Architecture

Two git repos, both public eventually:

- `msnodderly/soundbite` (main): skills, scripts, prompts, raw transcript archive (`archival/`), source metadata, plan, README. The deliverable as a working-in-public artifact.
- `msnodderly/soundbite.wiki` (auto-attached): published soundbite pages and `Home.md` index.

The wiki repo doesn't exist until the first wiki page is created through the GitHub web UI. After that, it is cloneable and pushable as a normal git repo at `git@github.com:msnodderly/soundbite.wiki.git`.

## Workflow

```
source URL + time range
        |
     /snarf
        |
        +--> archival/<slug>.transcript.md   (raw transcript, kept forever)
        +--> archival/<slug>.meta.json       (source metadata, kept forever)
        +--> inbox/<slug>.md                 (gitignored draft: cleaned quote + metadata)
        |
   (optional manual edit of inbox draft: refine quote, annotate speakers, trim)
        |
     /ingest
        |
        +--> soundbite.wiki: <Slug>.md       (published page)
        +--> soundbite.wiki: Home.md         (index updated)
        +--> inbox/<slug>.md                 (deleted)
        |
   (optional manual edit of the published wiki page)
```

`/snarf` does not publish. `/ingest` does not transcribe. Each step is independently re-runnable.

## Repo layout (main)

```
soundbite/
  README.md                  project overview, working-in-public statement
  plan.md                    this file
  AGENTS.md                  conventions for Claude Code working in this repo
  skills/
    snarf/                   /snarf skill definition + prompts
    ingest/                  /ingest skill definition + prompts
  scripts/
    snarf.sh                 yt-dlp + vcut transcribe driver
    ingest.sh                inbox -> wiki promoter
  prompts/                   reusable LLM prompts (clean-up, summarize, title)
  inbox/                     in-progress drafts awaiting ingest (gitignored; deleted on /ingest)
  archival/                  raw transcripts (.transcript.md) and source metadata (.meta.json), kept forever for citation. Media files (.mp3/.mp4) are gitignored and deleted after transcription.
  .gitignore                 ignores inbox/, archival/*.mp3, archival/*.mp4, archival/*.m4a, etc.
```

## Soundbite page format (published wiki page)

GH wiki ignores YAML frontmatter. Metadata lives as visible content. Proposed template:

```markdown
# <Title: short and quotable>

> <The cleaned quote, one or more paragraphs. May include [...] for elided content.>

**Speaker(s):** <name(s) and role(s) if known>
**Source:** [<Channel/Show>: <Episode/Title>](<URL with ?t=start>)
**Captured:** <YYYY-MM-DD>
**Range:** <MM:SS> to <MM:SS>
**Tags:** [[tag1]], [[tag2]]

---

## Context

<1-3 sentences: what was being discussed, why this is worth saving>

## Notes

<optional: my commentary, related thoughts, why this matters to me>

---

[Raw transcript with timecodes](../blob/main/archival/<slug>.transcript.md)
```

The raw transcript link points back to the main repo, since wiki pages can link to repo files via relative paths in `<repo>/blob/main/...`.

## Home.md / index strategy

Hand-curated, like Karpathy's `index.md`. Categories are introduced lazily as content accumulates. Initial structure:

```markdown
# soundbite

A wiki of quotes, advice, and learnings from podcasts, interviews, talks, and other audio/video sources.

About: [What this is](About) | [How it works](How-it-works) | [Source repo](https://github.com/msnodderly/soundbite)

## Recent

- [<Title>](<Slug>): <one-line summary> (<source>, <YYYY-MM-DD>)

## By topic

(populated as content accumulates)

## By source

(populated as content accumulates)
```

`/ingest` is responsible for adding the new page to "Recent" and prompting (or autonomously deciding) whether to add it under a topic or source heading. v1 keeps this simple: always prepend to Recent, optionally add a topic line if the LLM is confident.

## Toolchain

| Concern | v1 choice | v2+ |
|---|---|---|
| Source download | `yt-dlp` with `--download-sections "*MM:SS-MM:SS"` and `-x --audio-format mp3` | same |
| Audio container | mp3 (small, transcribe-friendly) | possibly keep video for vcut clip rendering |
| Transcription | `vcut transcribe` (faster-whisper, distil-large-v3) | optionally Granite-Speech-4.1-2B-Plus for speaker attribution + word-level timestamps |
| Speaker attribution | manual during edit | Granite-Speech-4.1-2B-Plus, or `whisperx` + `pyannote` |
| Manual transcript trim | text edit of the inbox draft (no media retained in v1) | optionally `vcut edit` for trimming media if media retention returns |
| LLM cleanup pass | Claude (this skill, locally) | same |
| Publishing | git push to `soundbite.wiki.git` | same; eventually GH Pages + Astro if we outgrow wiki |

Granite-Speech-4.1-2B-Plus notes: 9-minute input cap, no punctuation/capitalization in Plus variant, transformers-native (no ollama path), Apache 2.0, ~4-6 GB BF16 weights. Worth a v2 spike when speaker attribution becomes the bottleneck.

## /snarf skill spec

Inputs:
- Source spec: a YouTube URL **or** path to a local audio/video file.
- Time range: `START` and `END` as `MM:SS` or `HH:MM:SS`. Required for URLs; optional for local files (defaults to whole file).
- Optional: a slug or short title hint. Otherwise derive from source title + start time.

Behavior:
1. If URL: `yt-dlp -x --audio-format mp3 --download-sections "*START-END" -o archival/<slug>.%(ext)s <URL>`. If local: `ffmpeg` trims the requested range into `archival/<slug>.mp3`. The audio file is gitignored.
2. Capture source metadata: title, channel, upload date, original URL, requested range. Write to `archival/<slug>.meta.json`.
3. `vcut transcribe archival/<slug>.mp3` produces `archival/<slug>.transcript.md` (timestamped lines, raw).
4. LLM cleanup pass produces a draft cleaned quote with speaker placeholders (`[Speaker A]`, `[Speaker B]`) where multiple voices are detected.
5. Write `inbox/<slug>.md` containing: draft title, draft cleaned quote, suggested tags, all metadata, and a link to the raw transcript.
6. Delete `archival/<slug>.mp3`. (v1 default: don't keep media. The user can pass `--keep-media` to override and retain the file locally; it's still gitignored.)

Does NOT:
- Publish to the wiki.
- Update Home.md.
- Attempt automatic speaker identification by name.
- Retain media past transcription.

Outputs to stdout: the path of the inbox draft and a one-line "what to do next" pointer.

## /ingest skill spec

Inputs:
- Path to an inbox file (default: only one in inbox, otherwise prompt).

Behavior:
1. Validate inbox file has required sections (title, quote, source, range, captured date).
2. Confirm `archival/<slug>.transcript.md` exists; if not, fail loudly.
3. Generate the published page at `soundbite.wiki/<Slug>.md` using the template above.
4. Update `soundbite.wiki/Home.md`: prepend an entry to Recent. If the inbox draft has confident topic tags and the topic section already exists in Home, add an entry there too.
5. Delete `inbox/<slug>.md` from the working tree (it was gitignored, so this leaves no trace).
6. Commit to both repos with messages of the form `ingest: <slug>` (main) and `publish: <Slug>` (wiki).

Does NOT:
- Touch the source file in archival/.
- Re-transcribe.
- Push automatically. The user reviews and pushes.

## /lint skill spec

Runs on demand against the current state of `archival/`, `inbox/`, and the local clone of the wiki. Produces a report; does not auto-fix.

Mechanical checks:
1. **Bidirectional orphans.** Every published wiki page has a matching `archival/<slug>.transcript.md`. Every `archival/<slug>.transcript.md` has either a wiki page or an in-flight `inbox/<slug>.md` draft.
2. **Home.md integrity.** Every wiki page is linked from `Home.md`. Every link in `Home.md` resolves to a real wiki page.
3. **Required metadata.** Every wiki page has Speaker(s), Source, Captured, Range, and Tags lines. Flag missing or empty fields.
4. **Citation rot.** HTTP HEAD on each Source URL. Flag 4xx/5xx. For YouTube URLs, also flag responses that return 200 but the page indicates the video is private, removed, or age-restricted (string match on the response body). Citation rot is real and uniquely a soundbite problem; the archived raw transcript is the receipt that survives source deletion.
5. **Slug consistency.** Slug used in archival, inbox, and wiki page filenames must match.
6. **No stray media.** Flag any `archival/*.mp3`, `*.mp4`, `*.m4a` etc. that survived `/snarf`. v1 default is no media in the working tree.

LLM-assisted checks (single Claude prompt over the collected corpus):
7. **Tag normalization.** Collect all tags across all pages. Flag near-duplicates and casing variants (`leadership`/`Leadership`/`leaders`). Suggest a canonical form per cluster.
8. **Speaker name normalization.** Same idea over Speaker(s) values.
9. **Contradiction detection.** Across pages with overlapping topics or speakers, flag claims that appear to contradict each other. Low-precision is fine; this is a prompt for the human to review, not auto-resolve.
10. **Suggested cross-links.** For each page, suggest up to three other pages that should probably be linked from it (same speaker, same topic, related claim). Output as a diff-shaped suggestion.

Output: a single `lint-report.md` at the repo root, with sections per check class. Each finding is one line, severity-tagged (`fail` for orphans/missing metadata/dead URLs, `warn` for citation soft-failures, `info` for LLM suggestions).

Does NOT:
- Auto-fix anything. The human reviews and applies.
- Modify wiki pages, Home.md, or archival.
- Run as part of `/snarf` or `/ingest`.

## POC test case (v1 done definition)

End-to-end run on:
- URL: `https://www.youtube.com/watch?v=Hy-tQlk5RTU`
- Range: `49:30` to `58:00`

v1 ships when this command sequence works and produces a published wiki page that a stranger could read without confusion:

```
/snarf https://www.youtube.com/watch?v=Hy-tQlk5RTU 49:30 58:00
# (manual edit of inbox/<slug>.md)
/ingest inbox/<slug>.md
git push (main)
git push (wiki)
```

## Working-in-public principles

- Repo (eventually) public. Skills, prompts, and scripts are checked in, not hidden.
- Commit messages describe the iteration honestly; no rewriting history to hide false starts.
- What is public: the published wiki pages, the raw transcript archive (citation chain), source metadata, and the workflow itself (skills, prompts, scripts). What is not public: in-flight drafts in `inbox/` (gitignored, local-only) and downloaded media (gitignored, deleted after transcription).
- Raw transcripts are kept verbatim in `archival/` as evidence of chain of custody. The published page is a curated artifact; the archive is the receipt.

## Open questions

- Handling of multi-speaker clips before Granite-Speech v2: how aggressive to be about identifying speakers by name in the LLM cleanup pass vs leaving it as `[Speaker A/B]` for the human to fill in.
- When to flip the repo public. Probably after the second or third successful soundbite is published and the workflow is stable.
- Topic/category taxonomy: emergent or seeded. v1 emergent.
