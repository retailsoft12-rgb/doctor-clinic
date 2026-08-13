---
flow: FLOW A — imperative Apex call (cacheable = No)
applies-to: every write-type task
chain: user action → validate → spinner up → Apex → branch → toast → spinner down
entry: phase-1-synchronous-validation.md
---

<!-- merged from: sequence-imperative-flow.md (embedded in imperative-flow-merge.py) -->

# FLOW A — imperative Apex call (cacheable = No)

## Participants

- **User** — clicks / fires a child event.
- **component.html** — renders, hosts the spinner overlay, re-renders on state change.
- **component.js** — validates, owns `isLoading`, calls Apex, branches on the response.
- **c-ao-spinner** — overlay at root template while `isLoading` is true.
- **ShowToastEvent** — surfaces `success` and `!success | rejection`.
- **Apex @AuraEnabled** — `apexMethod({ params })` → `APIResponse | rejection`.

## Legend

- solid arrow → call
- dashed arrow → return
- gold pill → phase
- cylinder → datastore

## Start

→ Go to [phase-1-synchronous-validation.md](#phase-1--synchronous-validation).

<!-- merged from: phase-1-synchronous-validation.md -->

# Phase 1 — synchronous validation

Before any network call.

1. **User → component.html** — click / child event
2. **component.html → component.js** — `handleSomething(event)`
3. **component.js → self** — validate `event.detail`
4. **component.js → ShowToastEvent** — invalid → `toast(error)`, return

**ELSE**

→ Go to [phase-2-spinner-up.md](#phase-2--raise-the-loading-flag-render-the-overlay).

<!-- merged from: phase-2-spinner-up.md -->

# Phase 2 — raise the loading flag, render the overlay

1. **component.js → self** — `this.isLoading = true`
2. **component.js ⇢ component.html** — re-render
3. **component.html → c-ao-spinner** — overlay at root template

→ Go to [phase-3-round-trip.md](#phase-3--apex-round-trip).

<!-- merged from: phase-3-round-trip.md -->

# Phase 3 — Apex round-trip

Back end not modelled.

1. **component.js → Apex @AuraEnabled** — `apexMethod({ params })`
2. **Apex @AuraEnabled ⇢ component.js** — `APIResponse | rejection`

→ Go to [phase-4-branch-on-the-response.md](#phase-4--branch-on-the-response).

<!-- merged from: phase-4-branch-on-the-response.md -->

# Phase 4 — branch on the response

1. **component.js → self** — success → set state
2. **component.js → ShowToastEvent** — `toast(success)`

**OR**

3. **component.js → self** — `!success` → throw
4. **component.js → ShowToastEvent** — `.catch` → `toast(error)`

→ Go to [phase-5-finally-clear-the-flag.md](#phase-5--finally--clear-the-flag-exactly-once).

<!-- merged from: phase-5-finally-clear-the-flag.md -->

# Phase 5 — .finally — clear the flag exactly once

1. **component.js → self** — `.finally` → clear flag
2. **component.html ⇢ c-ao-spinner** — overlay unrenders

## Error handling — the only channel

- `ShowToastEvent` only — no `@track errorMessage`, no inline banner, never console-only.
