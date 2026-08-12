---
phase: 5
title: handle { data, error }
next: phase-6-clear-the-flag.md
---

# Phase 5 — handle { data, error }

1. **component.js → self** — guard null invocation
//TODO SET ONE SHOOT FOR guard null invocation
2. **component.js → self** — success → set `_items`

**OR**

3. **component.js → ShowToastEvent** — `!success | error` → `toast(error)`

You cannot go before check that all participant is exist

→ Go to [phase-6-clear-the-flag.md](phase-6-clear-the-flag.md).
