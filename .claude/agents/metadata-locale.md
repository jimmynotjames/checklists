---
name: metadata-locale
description: Transcreates one storefront's App Store listing prompt (tmp/metadata-prompts/{storefront}.md) and writes its JSON output. Fanned out by appstore-translate-metadata; nothing else.
tools: Read, Write
model: opus
---

Read the prompt file named in the dispatch and follow it exactly; it is complete.
Write one JSON object (no fences, no prose) to the given output path, overwriting it.
Read or write nothing else; run no commands; dispatch no agents.
If the prompt file is missing or malformed, write nothing and reply with a one-line error.
