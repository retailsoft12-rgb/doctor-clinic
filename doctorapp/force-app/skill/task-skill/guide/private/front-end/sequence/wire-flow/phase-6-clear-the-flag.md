---
phase: 6
title: clear the flag — one assignment, then optional refresh
next: none
---

# Phase 6 — clear the flag

One assignment, then optional refresh.

1. **component.js → self** — `isLoading = false`
2. **component.html ⇢ c-ao-spinner** — overlay unrenders
3. **component.js → wire service + LDS** *(phase 7, optional)* — `refreshApex(_wiredResult) — per visibility / urgency`
//TODO READ SCRATCHPAD-MEMORY.MD FILE Tab answer question and see the visibility / urgency importance
4. **wire service + LDS ⇢ component.js** — `wiredX` re-fires → phases 5-6

## No promise chain here

- The framework owns the lifecycle — `isLoading` is cleared once, on both branches, never in a `.finally`.
- `refreshApex` is optional — put it behind a visibility guard, and only for genuinely stale SERVER data.
