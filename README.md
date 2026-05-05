# soundbite

A working-in-public experiment: capture quotes, advice, and learnings from
audio/video sources (YouTube, podcasts, interviews), produce clean attributed
transcripts, and publish them as a wiki of soundbites with citation links
back to the source.

Inspired by Karpathy's LLM wiki concept, specialized for time-bounded A/V
capture and audience-facing output.

## Repos

- `msnodderly/soundbite` (this repo): skills, scripts, prompts, raw
  transcript archive, source metadata, plan, README.
- `msnodderly/soundbite.wiki` (auto-attached GitHub wiki): published
  soundbite pages.

## Workflow

```
source URL + time range
    -> /snarf  -> archival/<slug>.transcript.md   (citation, kept forever)
                  archival/<slug>.meta.json       (citation, kept forever)
                  inbox/<slug>.md                 (gitignored draft)
    -> [edit]  inbox/<slug>.md
    -> /ingest -> soundbite.wiki/<Slug>.md        (published page)
                  soundbite.wiki/Home.md          (index updated)
                  inbox/<slug>.md                 (deleted)
```

`/snarf` does not publish. `/ingest` does not transcribe. Each step is
independently re-runnable.

## Status

v1 in progress. Working in public from day one (GitHub requires public
repos to enable the wiki feature). See `plan.md` for design and the rolling
implementation checklist. v1 ships when the POC clip
(`https://www.youtube.com/watch?v=Hy-tQlk5RTU`, `49:30`-`58:00`) flows
end-to-end and produces a published wiki page a stranger can read without
confusion.
