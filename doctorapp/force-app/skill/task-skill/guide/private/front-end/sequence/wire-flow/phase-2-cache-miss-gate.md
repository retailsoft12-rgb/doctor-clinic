---
phase: 2
title: cache-miss gate — will this assignment reach the server?
next: phase-3-spinner-and-gating-field.md
---

# Phase 2 — cache-miss gate

Will this assignment reach the server?

1. **User → component.html** — click / expand / search
2. **component.html → component.js** — `handleXExpand(event)`
3. **component.js → self** — same id or already fetched
4. **component.js → self** — switch view, return

**OR**

5. **wire service + LDS ⇢ component.js** — served from LDS cache — no round-trip

You cannot go before check that all participant is exist

→ Go to [phase-3-spinner-and-gating-field.md](phase-3-spinner-and-gating-field.md).
