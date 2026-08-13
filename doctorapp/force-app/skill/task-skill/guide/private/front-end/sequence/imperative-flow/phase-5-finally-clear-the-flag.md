---
phase: 5
title: .finally — clear the flag exactly once
next: none
---

# Phase 5 — .finally — clear the flag exactly once

1. **component.js → self** — `.finally` → clear flag
2. **component.html ⇢ c-ao-spinner** — overlay unrenders

## Error handling — the only channel

- `ShowToastEvent` only — no `@track errorMessage`, no inline banner, never console-only.
