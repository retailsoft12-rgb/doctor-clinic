---
phase: 1
title: initialization — the wire is dormant until its gating field is set
next: phase-2-cache-miss-gate.md
---

# Phase 1 — initialization

The wire is dormant until its gating field is set.

**component.js → self**

- `_wiredXId = id` (data loaded at page load) | `undefined` (not)
//TODO SAY READ SCRATCHPAD tab section load time
- `fetchUsedStateValue = new Set()` — one per functionality

→ Go to [phase-2-cache-miss-gate.md](phase-2-cache-miss-gate.md).
