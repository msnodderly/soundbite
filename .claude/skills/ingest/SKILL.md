---
name: ingest
description: Promote a hand-edited inbox/<slug>.md soundbite draft to a published page in the sibling soundbite.wiki repo. Validates required fields, generates the wiki page from the draft, updates Home.md, creates topic page stubs for new tags, then commits both repos (without pushing) on user approval. Use when the user types /ingest or asks to publish, ship, promote, or ingest an inbox draft.
---

Base directory for this skill: /Users/mattsnodderly/src/soundbite/.claude/skills/ingest

# /ingest

Promotes an `inbox/<slug>.md` draft to a published page in the sibling
`../soundbite.wiki/` repo. Updates `Home.md` and any topic pages required
by the soundbite's tags. Stages and commits both repos with explicit user
approval. Does not push.

## Inputs

`/ingest [<inbox-path>]`

- `<inbox-path>` — path to an inbox file. If omitted, the skill picks the
  only file in `inbox/`. With zero or multiple files in `inbox/` and no
  argument, ask the user which to ingest.

## Steps

### 1. Resolve the inbox file

If the user supplied a path, validate that it exists and is under
`inbox/`. Otherwise, list `inbox/*.md`. If exactly one, use it. If zero,
report that and stop. If more than one, ask the user which to ingest.

### 2. Validate

Run `bash scripts/ingest-validate.sh <inbox-path>`. The script:

- Parses the inbox file (title, speakers, source, captured, range, tags,
  context, notes, quote body).
- Confirms `archival/<slug>.transcript.md` and `archival/<slug>.meta.json`
  exist.
- Confirms wiki sibling at `../soundbite.wiki/` (or `SOUNDBITE_WIKI_DIR`).
- On any missing/TODO field, exits non-zero with one error line per
  problem on stderr.
- On success, writes a JSON plan to `archival/_pending/<slug>.ingest-plan.json`
  and prints the plan path on stdout.

If the script exits non-zero, surface its stderr to the user and stop.
The user must edit the inbox draft to fix the listed issues before
re-running.

### 3. Read the plan

Use the Read tool to load the JSON plan. Hold these fields in mind for
the rest of the run:

- `slug` (lowercase, hyphen-separated)
- `wiki_slug` (capitalized form, e.g. `Useful-Not-Popular`)
- `title`, `speakers`, `source_label`, `source_url`, `captured`, `range`,
  `tags_line` (the verbatim line, including `[[...]]` brackets), `tags`
  (parsed list), `context`, `notes`, `quote_body`, `raw_transcript_url`
- `wiki_dir`, `wiki_page_path`, `wiki_page_exists`
- `home_path`, `home_exists`, `home_needs_bootstrap`
- `topic_pages[]`: each has `tag`, `path`, `exists`

If `wiki_page_exists` is `true`, ask the user whether to overwrite the
existing wiki page. Default is no. If they decline, stop.

### 4. Resolve missing topic pages

For each entry in `topic_pages` with `exists: false`, ask the user one
question per missing tag:

> No topic page for `<Tag>`. Create a stub? [y/N]

Default N. Track which tags the user approved for stub creation.

### 5. Generate and write the wiki page

Construct the published page using this template, filling from the plan.
Do not include the inbox file's HTML comment. The `quote_body` field is
passed through verbatim — whatever markdown the user wrote (blockquote,
prose, list) becomes the quote section unchanged. Do not add or strip
`> ` markers.

```markdown
# <title>

<quote_body verbatim>

**Speaker(s):** <speakers>
**Source:** [<source_label>](<source_url>)
**Captured:** <captured>
**Range:** <range>
**Tags:** <tags_line verbatim>

---

## Context

<context>

## Notes

<notes>   ← include only if `notes` is non-empty; otherwise omit the
                heading and the section entirely

---

[Raw transcript with timecodes](<raw_transcript_url>)
```

Write the result to `<wiki_page_path>` with the Write tool. The user
approves the diff via the standard permission prompt.

### 6. Update Home.md

Compute the new "Recent" entry:

```
- [<title>](<wiki_slug>): <one-line context>. (<source_label>, <captured>)
```

`<one-line context>` is the first sentence of `context` (split on `". "`,
take the first part, trim trailing period). Keep it brief.

If `home_needs_bootstrap` is true, replace Home.md entirely with this
template (Write tool):

```markdown
# soundbite

A wiki of quotes, advice, and learnings from podcasts, interviews, talks,
and other audio/video sources.

About: [Source repo](https://github.com/msnodderly/soundbite)

## Recent

<recent entry>

## By topic

(populated as content accumulates)

## By source

(populated as content accumulates)
```

Otherwise, use Edit to insert the new entry as the first list item under
`## Recent` (above any existing entries, with one blank line between the
heading and the first list item).

### 7. Write topic pages

For each tag in `tags` (in order):

- **Page exists**: use Edit to append `- [<title>](<wiki_slug>)` as a new
  bullet at the end of the bullet list. Skip silently if that exact line
  already appears in the file.
- **Page does not exist AND user approved in step 4**: use Write with this
  stub:
  ```markdown
  # <Tag>

  Soundbites tagged `<Tag>`:

  - [<title>](<wiki_slug>)
  ```
- **Page does not exist AND user declined**: skip. The tag still appears
  on the soundbite page; the orphan is intentional and `/lint` will flag
  it later.

### 8. Show the user what changed

In the main repo, run `git status --short` and show the output. In the
wiki repo, run `git -C <wiki_dir> status --short` and show the output.

State explicitly: "ready to commit `ingest: <slug>` (main) and `publish:
<wiki_slug>` (wiki). Push will not happen. Commit both? [y/N]"

### 9. Commit (only if user said yes)

If the user approved:

- In the main repo: `git add -A archival/_pending/` is unnecessary (the
  pending plan is gitignored), but stage every wiki-related artifact in
  the main repo only if /ingest touched main-repo files. /ingest does not
  modify any main-repo content other than deleting the inbox draft (which
  is gitignored). Therefore, the main-repo commit only makes sense if
  there are staged or unstaged changes; if `git status --short` is empty,
  skip the main commit and tell the user.
- In the wiki repo: `git -C <wiki_dir> add -A`, then `git -C <wiki_dir>
  commit -m "publish: <wiki_slug>"`.
- If the main repo had changes, `git add -A` and `git commit -m "ingest:
  <slug>"`.

Do not pass `--no-verify`. Do not include any co-author trailer. Do not
push.

If the user declined, leave both working trees as-is. The inbox draft
will not be deleted in step 10 in that case — see below.

### 10. Finalize (only if user committed)

If the wiki commit succeeded, run `bash scripts/ingest-finalize.sh <slug>`.
The script removes `inbox/<slug>.md` and the plan JSON.

If the user declined to commit, do NOT run finalize. Tell the user the
inbox draft and plan JSON are still in place; they can re-run `/ingest
inbox/<slug>.md` to retry, or manually clean up.

### 11. Confirm to the user

Print one short confirmation:

```
Published <wiki_slug> to the wiki. Pending pushes:
- main: git push
- wiki: git -C <wiki_dir> push
```

## What this skill does NOT do

- Touch `archival/<slug>.transcript.md` or `archival/<slug>.meta.json`.
- Re-transcribe.
- Push to either remote.
- Auto-resolve tag normalization (that's `/lint`).
- Add entries to the "By topic" or "By source" Home.md sections.

## Recovery from interrupted runs

If the agent is killed mid-run:

- Pending plan: `archival/_pending/<slug>.ingest-plan.json` may exist.
  Safe to delete; re-running `/ingest` regenerates it.
- Wiki working tree: may have uncommitted changes. The user can review
  with `git -C <wiki_dir> status` and either commit or `git -C <wiki_dir>
  checkout -- .` to discard.
- Inbox draft: only deleted at the very end (step 10). If the run was
  interrupted before step 10, the draft is still present and re-runnable.
