---
phase: 3
title: spinner up, gating field assigned → wire fires
next: phase-4-round-trip.md
---

# Phase 3 — spinner up, gating field assigned → wire fires

1. **component.js → self** — `isLoading = true`
2. **component.js → self** — `fetchUsedStateValue.add(value)`
3. **component.js ⇢ component.html** — re-render
4. **component.html → c-ao-spinner** — overlay at root template
5. **component.js → wire service + LDS** — `_wiredXId = value` → `$param` changed

You cannot go before check that all participant is exist

→ Go to [phase-4-round-trip.md](phase-4-round-trip.md).
