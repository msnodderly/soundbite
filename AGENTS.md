# AGENTS.md

Conventions for Claude Code (and any other coding agent) working in this repo.

## What this repo is

`soundbite` captures quotes and learnings from audio/video sources, produces
clean attributed transcripts, and publishes them as a GitHub wiki at
`msnodderly/soundbite.wiki`. See `plan.md` for the full design and the
implementation checklist.

The repo is **public from day one** (GitHub requires a public repo to
enable the wiki feature on a free account). Anything committed is
immediately visible. Treat every commit as a public commit. No secrets, no
"will clean up before flip", no stale internal-facing language.

## Layout

- `plan.md` — design doc and rolling implementation checklist. Read first.
- `README.md` — short public-facing description.
- `.claude/skills/` — Claude Code skill definitions (`snarf`, `publish`, later `lint`).
- `scripts/` — shell scripts called by skills.
- `archival/` — committed transcripts and metadata. The citation chain.
- `inbox/` — gitignored in-flight drafts; lives only in the local working tree.
- `prompts/` — reusable LLM prompts (added as needed).

## Slug rule

Slugs reflect the **topic/content** of the clip, not the source title.
Lowercase, hyphenated, 2-5 meaningful words. The slug is the stable
identifier used in:

- `archival/<slug>.transcript.md`
- `archival/<slug>.meta.json`
- `inbox/<slug>.md`
- `soundbite.wiki/<Slug>.md` (Title-Cased version for the wiki URL)

`/snarf` does not pick the slug for the user. After transcribing, the skill
proposes 3-5 content-based candidates and asks the user to approve one or
supply their own. Source-title-derived slugs are an anti-pattern: they bind
the artifact to its container instead of its meaning and collide when one
source produces multiple soundbites.

Good: `microsoft-1985-pivot`, `cohort-retention-stripe`, `npm-postinstall-supply-chain`.

Bad: `acquired-podcast-ep-127`, `joe-rogan-experience-2024-04`, `talk-with-jensen`.

On collision with an existing archival or inbox file, `/snarf` re-prompts
rather than silently bumping the slug suffix.

## Retention

- **Kept indefinitely (committed):** `archival/<slug>.transcript.md`,
  `archival/<slug>.meta.json`, the published wiki page.
- **Ephemeral (gitignored, deleted by `/snarf` or `/publish`):** downloaded
  media (mp3/mp4/etc.) and `inbox/<slug>.md` drafts.

Do not edit raw transcripts in `archival/`. They are evidence. If a
transcript is wrong, fix the published page or the inbox draft instead.

## Editorial vs. mechanical work

The user is the editor. The agent is the formatter and the courier.

The agent does **mechanical** work without asking: fill metadata fields
from `meta.json`, scaffold the inbox draft with TODO placeholders,
generate the wiki-page template wrapper around user-finalized content,
rewrite cross-repo links.

The agent does NOT do **editorial** work: cutting filler, false starts,
tangents, or repetition; reordering or reorganizing speech; deciding
what's "core" vs. "side-quest"; inserting `[...]` elision markers;
writing the title, tags, or context. Those judgments are the user's,
made by editing `inbox/<slug>.md` between `/snarf` and `/publish`.

When the agent overreaches and starts making content cuts, it produces
diffs the user can't meaningfully review (large structural rewrites
where every line is changed). The right output of `/snarf`'s cleanup
pass is a faithful canvas the user can edit, not a finished quote.

## Diff-approval rule

Any time a skill is about to write, modify, or delete a content file
(inbox drafts, published wiki pages, `Home.md`, topic pages), it must
first present the proposed change as a unified diff and wait for
explicit user approval before applying it. The user can approve, revise
(with specific feedback), or reject.

Exempt: mechanical recordings that are not edits — raw transcripts from
the transcriber, source metadata captured verbatim from yt-dlp,
slug-rename moves (slug was already approved), and deletion of the inbox
draft on successful `/publish` (the publish was already approved).

When the proposed file is new (no prior content to diff against), present
the proposed file body in full and label the diff "new file". Mark
sections that are template scaffolding distinctly from sections that are
verbatim copies of user content (the inbox draft's quote, metadata, and
context embedded in the published wiki page) so the user can verify
nothing was silently transformed.

## Style

- No emojis in source, prompts, commit messages, or PRs.
- Brief commit messages, single line.
- Keep skill instructions compact and procedural.

## Testing the workflow

The v1 POC clip is
`https://www.youtube.com/watch?v=Hy-tQlk5RTU` from `49:30` to `58:00`. Use it
for end-to-end smoke tests until v1 is closed out.
