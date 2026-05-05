# soundbite

An experiment in writing software as markdown files, coding agents as the UI.  

Inspired by Karpathy's [LLM wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) concept, for audio/visual content.


## Repos

- `msnodderly/soundbite` (this repo): skills, scripts, prompts
- `msnodderly/soundbite.wiki` (GitHub wiki)
  
## Workflow

```
source URL + time range
    -> /snarf  -> archival/<slug>.transcript.md   (citation, kept forever)
                  archival/<slug>.meta.json       (citation, kept forever)
                  inbox/<slug>.md                 (gitignored draft)
    -> [edit]  inbox/<slug>.md
    -> /ingest -> soundbite.wiki/<Slug>.md        (published page)
                  soundbite.wiki/Home.md          (index updated)
```
