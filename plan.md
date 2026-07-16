# soundbite plan

A working-in-public experiment: capture quotes, advice, and learnings from audio/video sources (YouTube, podcasts, interviews), produce clean attributed transcripts, and publish them as a wiki of soundbites with citation links back to the source.

Inspired by Karpathy's LLM wiki concept, but specialized for time-bounded A/V capture and audience-facing output.

## v1 scope

In:
- `/snarf` skill: pull a clip from a YouTube URL (or local file) given a time range, transcribe with timestamps, write a draft into `inbox/`.
- Optional manual edit of the inbox draft.
- `/publish` skill: promote an inbox draft to a published wiki page, update the wiki index, archive the raw transcript.
- Optional manual edit of the published page.
- `/lint` skill: mechanical health check (orphans, missing metadata, broken Home links, citation rot) plus an LLM pass over the corpus for tag and speaker name normalization, contradiction detection, and suggested cross-links.
- GitHub repo wiki as the publishing target.
- One end-to-end POC capture of the example clip.

Out (deferred to v2+):
- Automatic speaker attribution / diarization. Annotate manually for v1.
- Keeping media artifacts. v1 deletes downloaded audio after transcription; published pages link to the original source with timestamp. Only the raw text transcript and source metadata are retained.
- Custom theming, custom domain, GH Pages migration.
- Cross-source linking heuristics (semantic suggestions for related soundbites).
- Topic/aggregation pages that combine multiple soundbites.

## Retention policy

Three classes of artifact, three retention rules:

- **Kept indefinitely (committed):** raw transcript (`archival/<slug>.transcript.md`), source metadata (`archival/<slug>.meta.json`), the published wiki page, and the wiki repo's git history. These are the citation chain.
- **Ephemeral (gitignored, deleted by `/snarf` or `/publish`):** downloaded media files (mp3/mp4 pulled by yt-dlp). v1 does not host or commit media. If a user wants to keep a local clip for personal use (e.g. via `vcut edit`), that's a personal choice outside the repo.
- **Working drafts (gitignored, ephemeral):** `inbox/<slug>.md`. Lives only in the local working tree during the snarf-edit-publish cycle. Never committed. Deleted by `/publish` on successful publish. No `processed/` directory; the published wiki page is the canonical record of what got shipped.

## Architecture

Two git repos, both public:

- `msnodderly/soundbite` (main): skills, scripts, prompts, raw transcript archive (`archival/`), source metadata, plan, README. The deliverable as a working-in-public artifact.
- `msnodderly/soundbite.wiki` (auto-attached): published soundbite pages and `Home.md` index.

GitHub requires a public repo to enable the wiki feature on a free account, so the main repo went public earlier than the original "flip when presentable" plan. The wiki was bootstrapped via the GitHub web UI (first stub page created); the wiki repo is now cloneable as a normal git repo at `git@github.com:msnodderly/soundbite.wiki.git`.

Implication: anything committed to either repo is immediately visible. No secrets, no draft commit messages assuming privacy. The "polish before flipping public" round in the original plan is moot; we polish in place.

## Workflow

```
source URL + time range
        |
     /snarf
        |
        +--> archival/<slug>.transcript.md   (raw transcript, kept forever)
        +--> archival/<slug>.meta.json       (source metadata, kept forever)
        +--> inbox/<slug>.md                 (gitignored draft: raw transcript + metadata footer)
        |
   (manual edit of inbox draft: shape the quote, name speakers, fill title/tags/context)
        |
     /publish
        |
        +--> soundbite.wiki: <Slug>.md       (published page)
        +--> soundbite.wiki: Home.md         (index updated)
        +--> inbox/<slug>.md                 (deleted)
        |
   (optional manual edit of the published wiki page)
```

`/snarf` does not publish. `/publish` does not transcribe. Each step is independently re-runnable.

## Repo layout (main)

```
soundbite/
  README.md                  project overview, working-in-public statement
  plan.md                    this file
  AGENTS.md                  conventions for Claude Code working in this repo
  .claude/skills/
    snarf/SKILL.md           /snarf skill definition
    publish/SKILL.md         /publish skill definition
  scripts/
    snarf-fetch.sh           yt-dlp/ffmpeg + vcut: fetch, trim, transcribe into archival/_pending/
    snarf-finalize.sh        validate approved slug, move pending files into place, write inbox draft
    publish-validate.sh      validate inbox draft, emit JSON plan of wiki files to touch
    publish-finalize.sh      post-publish cleanup: delete inbox draft and plan JSON
  inbox/                     in-progress drafts awaiting publish (gitignored; deleted on /publish)
  archival/                  raw transcripts (.transcript.md) and source metadata (.meta.json), kept forever for citation. Media files (.mp3/.mp4) are gitignored and deleted after transcription.
  .gitignore                 ignores inbox/, archival/_pending/, media extensions, etc.
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

`/publish` is responsible for adding the new page to "Recent" and prompting (or autonomously deciding) whether to add it under a topic or source heading. v1 keeps this simple: always prepend to Recent, optionally add a topic line if the LLM is confident.

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
- No slug argument. The skill proposes content-based slug candidates after transcription and asks the user to pick or supply their own.

Slug rule: slugs reflect the **topic/content of the clip**, not the source title. Source-title-derived slugs are an anti-pattern (they bind the artifact to its container instead of its meaning, and they collide when the same source produces multiple soundbites). See SKILL.md for examples.

Behavior:
1. Fetch into a pending area. URL: `yt-dlp -x --audio-format mp3 --download-sections "*START-END" -o archival/_pending/<temp-id>.%(ext)s <URL>`. Local file: `ffmpeg` trims into `archival/_pending/<temp-id>.mp3`. Audio is gitignored.
2. Capture source metadata to `archival/_pending/<temp-id>.meta.json` (title, channel, upload date, original URL, requested range, transcriber).
3. Transcribe to `archival/_pending/<temp-id>.transcript.md` (timestamped, raw).
4. Delete the pending audio file.
5. **Slug approval.** The skill reads the pending transcript, proposes 3-5 content-based slug candidates, and prompts the user. User approves one or supplies an override.
6. Finalize: move `archival/_pending/<temp-id>.{transcript.md,meta.json}` to `archival/<slug>.{transcript.md,meta.json}`, updating the slug field in the meta JSON.
7. Write `inbox/<slug>.md` containing the raw vcut-format transcript verbatim plus a metadata footer: Speaker(s)/Source/Captured/Range filled from `meta.json` (with `?t=<seconds>` appended to YouTube URLs), TODO placeholders for title, tags, and context. The agent does NOT cut, reword, or reorganize speech content, and does NOT propose the title, tags, or context — those are the user's, written by editing the draft (cuts, prose-shaping, `[...]` elision markers, commenting out cue lines with `# `) before running `/publish`.

Pending artifacts stay in `archival/_pending/` (gitignored) if the user abandons the run before approving a slug. They are safe to delete manually.

Does not:
- Publish to the wiki.
- Update Home.md.
- Attempt automatic speaker identification by name.
- Retain media past transcription.

Outputs to stdout: the path of the inbox draft and a one-line "what to do next" pointer.

## /publish skill spec

Inputs:
- Path to an inbox file (default: only one in inbox, otherwise prompt).

Behavior:
1. Validate inbox file has required sections (title, quote, source, range, captured date).
2. Confirm `archival/<slug>.transcript.md` exists; if not, fail loudly.
3. Generate the proposed published page at `soundbite.wiki/<Slug>.md` using the template above (in memory; not written yet). Rewrite the raw-transcript link from `../archival/<slug>.transcript.md` to the cross-repo `../blob/main/archival/<slug>.transcript.md` form.
4. Resolve tags interactively. For each `[[Tag-Name]]`, check whether `soundbite.wiki/<Tag-Name>.md` already exists. If not, prompt the user: "no topic page for `Tag-Name` — create? [y/N]". On yes, generate a stub topic page in memory; otherwise skip the tag.
5. Generate the proposed `Home.md` update (prepend an entry to Recent; if the topic section exists for any of the soundbite's tags, prepend there too) in memory.
6. **Diff approval.** Present each proposed file change as a unified diff against the existing file (or "new file" with full body for new pages). Wait for explicit approval per change. Apply approved changes only; loop on revision feedback.
7. Delete `inbox/<slug>.md` from the working tree (it was gitignored, so this leaves no trace).
8. Commit to both repos with messages of the form `publish: <slug>` (main, only if it has changes) and `publish: <Slug>` (wiki).

Does not:
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

Does not:
- Auto-fix anything. The human reviews and applies.
- Modify wiki pages, Home.md, or archival.
- Run as part of `/snarf` or `/publish`.

## POC test case (v1 done definition)

End-to-end run on:
- URL: `https://www.youtube.com/watch?v=Hy-tQlk5RTU`
- Range: `49:30` to `58:00`

v1 ships when this command sequence works and produces a published wiki page that a stranger could read without confusion:

```
/snarf https://www.youtube.com/watch?v=Hy-tQlk5RTU 49:30 58:00
# (manual edit of inbox/<slug>.md)
/publish inbox/<slug>.md
git push (main)
git push (wiki)
```

## Working-in-public principles

- Repo is public from the start (forced by GitHub's wiki-requires-public rule; no longer a v1 milestone).
- Skills, prompts, and scripts are checked in, not hidden.
- Commit messages describe the iteration honestly; no rewriting history to hide false starts.
- What is public: the published wiki pages, the raw transcript archive (citation chain), source metadata, and the workflow itself (skills, prompts, scripts). What is not public: in-flight drafts in `inbox/` (gitignored, local-only) and downloaded media (gitignored, deleted after transcription).
- Raw transcripts are kept verbatim in `archival/` as evidence of chain of custody. The published page is a curated artifact; the archive is the receipt.

## v1 implementation checklist

Round 1 — scaffold + `/snarf` + manual POC:
- [x] Fold `Does NOT:` → `Does not:` consistency across skill specs in this file.
- [x] Add this checklist to `plan.md`.
- [x] Scaffold: `.gitignore`, `README.md`, `AGENTS.md`, `archival/README.md`.
- [x] `.claude/skills/snarf/SKILL.md` (with content-based slug approval step).
- [x] `scripts/snarf-fetch.sh` (dependency check, download/trim, transcribe into `archival/_pending/`, delete media).
- [x] `scripts/snarf-finalize.sh` (validate user-approved slug, move pending files into place).
- [x] Manual: bootstrap GitHub wiki via web UI (done; first stub page created).
- [ ] Manual: clone `../soundbite.wiki/` as a sibling working tree.
- [ ] Manual: install `yt-dlp` and one of `vcut`/`whisper`.
- [ ] Manual: run POC `/snarf https://www.youtube.com/watch?v=Hy-tQlk5RTU 49:30 58:00`; approve a content-based slug; review the inbox draft.

Round 2 — `/publish`:
- [x] `.claude/skills/publish/SKILL.md`, `scripts/publish-validate.sh`, `scripts/publish-finalize.sh`.
- [x] Diff-approval gate before each file write (wiki page, topic pages, Home.md) via the harness's Write/Edit permission prompts.
- [x] Interactive topic-page creation in `/publish` (pulls "topic pages" forward from v2 as opt-in only).
- [ ] Update `plan.md` v1/v2 lists once topic pages land.
- [ ] Manual: edit `inbox/useful-not-popular.md` (title, cleaned quote, speakers, tags, context) and run `/publish inbox/useful-not-popular.md`; verify wiki page + Home.md update; push both repos.

Round 3 — `/lint`:
- [ ] `.claude/skills/lint/SKILL.md` and `scripts/lint.sh`.
- [ ] Mechanical checks (orphans, Home integrity, missing metadata, citation rot, slug consistency, stray media).
- [ ] LLM corpus pass (tag/speaker normalization, contradiction detection, suggested cross-links).
- [ ] Run lint against the published corpus once 2-3 soundbites exist.

Round 4 — polish:
- [x] README polish, working-in-public statement.
- [x] Rename `/ingest` to `/publish` (skill, scripts, docs). "Ingest" implied taking data in; the step ships content out to the wiki.
- [x] `archival/README.md` (was checked off in Round 1 but never actually written).
- [x] ~~Flip `msnodderly/soundbite` and the wiki public~~ — already public (GitHub wiki feature requires public repos on free accounts).

## Open questions

- Handling of multi-speaker clips before Granite-Speech v2: how aggressive to be about identifying speakers by name in the LLM cleanup pass vs leaving it as `[Speaker A/B]` for the human to fill in.
- ~~When to flip the repo public.~~ Resolved: already public (forced by the wiki-requires-public rule). Question becomes: how loud to make it (cross-post, link from elsewhere) and when.
- Topic/category taxonomy: emergent or seeded. v1 emergent.
