---
phase: 1
title: synchronous validation — before any network call
next: phase-2-spinner-up.md
---

# Phase 1 — synchronous validation

Before any network call.

1. **User → component.html** — click / child event
2. **component.html → component.js** — `handleSomething(event)`
3. **component.js → self** — validate `event.detail`
4. **component.js → ShowToastEvent** — invalid → `toast(error)`, return

**ELSE**

→ Go to [phase-2-spinner-up.md](phase-2-spinner-up.md).
