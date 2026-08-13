<!-- merged from: sequence-fe-desicion.md (embedded in sequence-fe-merge.py) -->

# Front-end sequence — choosing the Apex call flow

**First — read the object data you are about to work on.** Open
`force-app/main/default/objects/<Object>__c/fields/` and take each field's type,
required flag, picklist values and lookup target before deciding anything.

<!-- TODO  -->
<!-- ANALYSE THE SCRATCHPAD TAB ANSWER :
IF METHOD IS OF TYPE READ SO  USE THE WIRE-FLOW ELSE IMPERATIVE-FLOW  -->

Then pick the flow the task belongs to:

- Read-type method (`cacheable = true`) → **[FLOW B — @wire with function handler](#flow-b--wire-with-function-handler-cacheable--yes)**
- Write-type method (`cacheable = false`) → **[FLOW A — imperative Apex call](#flow-a--imperative-apex-call-cacheable--no)**

Each flow carries its own phases; a phase hands off to the next one at the end of its section.

<!-- merged from: imperative-flow/sequence-imperative-flow-TEMPORARY.md -->

```yaml
flow: FLOW A — imperative Apex call (cacheable = No)
applies-to: every write-type task
chain: user action → validate → spinner up → Apex → branch → toast → spinner down
entry: phase-1-synchronous-validation.md
```

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


You cannot go before check that all participant is exist
→ Go to [phase-2-spinner-up.md](#phase-2--raise-the-loading-flag-render-the-overlay).

<!-- merged from: phase-2-spinner-up.md -->

# Phase 2 — raise the loading flag, render the overlay

1. **component.js → self** — `this.isLoading = true`
2. **component.js ⇢ component.html** — re-render
3. **component.html → c-ao-spinner** — overlay at root template


You cannot go before check that all participant is exist
→ Go to [phase-3-round-trip.md](#phase-3--apex-round-trip).

<!-- merged from: phase-3-round-trip.md -->

# Phase 3 — Apex round-trip

Back end not modelled.

1. **component.js → Apex @AuraEnabled** — `apexMethod({ params })`
2. **Apex @AuraEnabled ⇢ component.js** — `APIResponse | rejection`


You cannot go before check that all participant is exist
→ Go to [phase-4-branch-on-the-response.md](#phase-4--branch-on-the-response).

<!-- merged from: phase-4-branch-on-the-response.md -->

# Phase 4 — branch on the response

1. **component.js → self** — success (`response.success === true`) →  
   a. **Update principal state** from `response.data`.  
      - If `data` is a single record → assign it to the corresponding `@track` array/object (e.g., `this.buckets = [newBucket, ...this.buckets]` or `this.items = response.data`).  
      - If `data` is a list → assign directly.  
      - If `data` contains multiple named pieces (map) → destructure and update each relevant principal state.
   b. **Show success toast** (optional, if the operation is user‑visible).
2. **OR** — `response.success === false` or promise rejects →  
   a. **Do NOT update state** (the server state is unchanged).  
   b. **Show error toast** using `ShowToastEvent`.
3. **Always** ensure that all state updates are **reactive** (use `@track` or immutability).`


You cannot go before check that all participant is exist
→ Go to [phase-5-finally-clear-the-flag.md](#phase-5--finally--clear-the-flag-exactly-once).

<!-- merged from: phase-5-finally-clear-the-flag.md -->

# Phase 5 — .finally — clear the flag exactly once

1. **component.js → self** — `.finally` → clear flag
2. **component.html ⇢ c-ao-spinner** — overlay unrenders

## Error handling — the only channel


You cannot go before check that all participant is exist
- `ShowToastEvent` only — no `@track errorMessage`, no inline banner, never console-only.

<!-- merged from: wire-flow/sequence-wire-flow-TEMPORARY.md -->

```yaml
flow: FLOW B — @wire with function handler (cacheable = Yes)
applies-to: every read-type task
chain: gating field → cache-miss gate → wire fires → { data, error } → flag cleared
entry: phase-1-initialization.md
```

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
- `fetchUsedStateValue = new Set()` — one per functionality


You cannot go before check that all participant is exist
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

You cannot go before check that all participant is exist

→ Go to [phase-3-spinner-and-gating-field.md](#phase-3--spinner-up-gating-field-assigned--wire-fires).

<!-- merged from: phase-3-spinner-and-gating-field.md -->

# Phase 3 — spinner up, gating field assigned → wire fires

1. **component.js → self** — `isLoading = true`
2. **component.js → self** — `fetchUsedStateValue.add(value)`
3. **component.js ⇢ component.html** — re-render
4. **component.html → c-ao-spinner** — overlay at root template
5. **component.js → wire service + LDS** — `_wiredXId = value` → `$param` changed

You cannot go before check that all participant is exist

→ Go to [phase-4-round-trip.md](#phase-4--round-trip).

<!-- merged from: phase-4-round-trip.md -->

# Phase 4 — round-trip

Back end not modelled.

1. **wire service + LDS → Apex (cacheable=true)** — `loadX({ xId })`
2. **Apex (cacheable=true) ⇢ wire service + LDS** — `APIResponse | error`
3. **wire service + LDS ⇢ component.js** — `wiredX({ data, error })`

You cannot go before check that all participant is exist

→ Go to [phase-5-handle-data-error.md](#phase-5--handle--data-error-).

<!-- merged from: phase-5-handle-data-error.md -->

# Phase 5 — handle { data, error }

1. **component.js → self** — guard against null/undefined invocation (initial call without param).  
2. **Success branch** (`data` is present and `data.success === true`) →  
   a. **Update principal state** from `data.data` (the nested payload).  
   b. Optionally, update any derived getters (they compute automatically).  
3. **Error branch** (`error` or `data.success === false`) →  
   a. **Do NOT update state**.  
   b. **Show error toast** with `ShowToastEvent`.  
4. **Clear the loading flag** (`isLoading = false`) – this must happen **after** the state update so that the UI doesn’t flash an empty state while the new data is being assigned.

You cannot go before check that all participant is exist

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
