---
phase: 2
title: raise the loading flag, render the overlay
next: phase-3-round-trip.md
---

# Phase 2 — raise the loading flag, render the overlay

1. **component.js → self** — `this.isLoading = true`
2. **component.js ⇢ component.html** — re-render
3. **component.html → c-ao-spinner** — overlay at root template


You cannot go before check that all participant is exist
→ Go to [phase-3-round-trip.md](phase-3-round-trip.md).
