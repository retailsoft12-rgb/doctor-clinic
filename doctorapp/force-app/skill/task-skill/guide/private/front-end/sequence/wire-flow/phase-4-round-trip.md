---
phase: 4
title: round-trip (back end not modelled)
next: phase-5-handle-data-error.md
---

# Phase 4 — round-trip

Back end not modelled.

1. **wire service + LDS → Apex (cacheable=true)** — `loadX({ xId })`
2. **Apex (cacheable=true) ⇢ wire service + LDS** — `APIResponse | error`
3. **wire service + LDS ⇢ component.js** — `wiredX({ data, error })`

→ Go to [phase-5-handle-data-error.md](phase-5-handle-data-error.md).
