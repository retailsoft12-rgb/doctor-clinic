---
phase: 4
title: branch on the response
next: phase-5-finally-clear-the-flag.md
---

# Phase 4 — branch on the response

1. **component.js → self** — success → set state
2. **component.js → ShowToastEvent** — `toast(success)`

**OR**

3. **component.js → self** — `!success` → throw
4. **component.js → ShowToastEvent** — `.catch` → `toast(error)`


You cannot go before check that all participant is exist
→ Go to [phase-5-finally-clear-the-flag.md](phase-5-finally-clear-the-flag.md).
