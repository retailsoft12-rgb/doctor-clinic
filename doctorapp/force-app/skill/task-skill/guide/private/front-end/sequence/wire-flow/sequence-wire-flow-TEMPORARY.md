---
flow: FLOW B — @wire with function handler (cacheable = Yes)
applies-to: every read-type task
chain: gating field → cache-miss gate → wire fires → { data, error } → flag cleared
entry: phase-1-initialization.md
---

<!-- merged from: sequence-wire-flow.md (embedded in wire-flow-merge.py) -->

# FLOW B — @wire with function handler (cacheable = Yes)

## Participants

- **User** — clicks / expands / search.
- **component.html** — renders, hosts the spinner overlay, re-renders on state change.
- **component.js** — owns the gating field, the fetched-set, `isLoading`, and the wire handler.
- **c-ao-spinner** — overlay at root template while `isLoading` is true.
- **ShowToastEvent** — surfaces `!success | error`.
- **wire service + LDS** — watches `$param`, serves from cache or calls Apex.
- **Apex (cacheable=true)** — `loadX({ xId })` → `APIResponse | error`.

## Legend

- solid arrow → call
- dashed arrow → return
- gold pill → phase
- cylinder → datastore

## Start

→ Go to [phase-1-initialization.md](#phase-1--initialization).

<!-- merged from: phase-1-initialization.md -->

# Phase 1 — initialization

The wire is dormant until its gating field is set.

**component.js → self**

- `_wiredXId = id` (data loaded at page load) | `undefined` (not)
//TODO SAY READ SCRATCHPAD tab section load time
- `fetchUsedStateValue = new Set()` — one per functionality

→ Go to [phase-2-cache-miss-gate.md](#phase-2--cache-miss-gate).

<!-- merged from: phase-2-cache-miss-gate.md -->

# Phase 2 — cache-miss gate

Will this assignment reach the server?

1. **User → component.html** — click / expand / search
2. **component.html → component.js** — `handleXExpand(event)`
3. **component.js → self** — same id or already fetched
4. **component.js → self** — switch view, return

**OR**

5. **wire service + LDS ⇢ component.js** — served from LDS cache — no round-trip

→ Go to [phase-3-spinner-and-gating-field.md](#phase-3--spinner-up-gating-field-assigned--wire-fires).

<!-- merged from: phase-3-spinner-and-gating-field.md -->

# Phase 3 — spinner up, gating field assigned → wire fires

1. **component.js → self** — `isLoading = true`
2. **component.js → self** — `fetchUsedStateValue.add(value)`
3. **component.js ⇢ component.html** — re-render
4. **component.html → c-ao-spinner** — overlay at root template
5. **component.js → wire service + LDS** — `_wiredXId = value` → `$param` changed

→ Go to [phase-4-round-trip.md](#phase-4--round-trip).

<!-- merged from: phase-4-round-trip.md -->

# Phase 4 — round-trip

Back end not modelled.

1. **wire service + LDS → Apex (cacheable=true)** — `loadX({ xId })`
2. **Apex (cacheable=true) ⇢ wire service + LDS** — `APIResponse | error`
3. **wire service + LDS ⇢ component.js** — `wiredX({ data, error })`

→ Go to [phase-5-handle-data-error.md](#phase-5--handle--data-error-).

<!-- merged from: phase-5-handle-data-error.md -->

# Phase 5 — handle { data, error }

1. **component.js → self** — guard null invocation
//TODO SET ONE SHOOT FOR guard null invocation
2. **component.js → self** — success → set `_items`

**OR**

3. **component.js → ShowToastEvent** — `!success | error` → `toast(error)`

→ Go to [phase-6-clear-the-flag.md](#phase-6--clear-the-flag).

<!-- merged from: phase-6-clear-the-flag.md -->

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
