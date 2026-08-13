<!-- merged from: communication-state.md (embedded in communication-state-merge.py) -->

# LWC Communication State

When your LWC component needs to talk to Apex — whether handling the round-trip visually (spinner) or surfacing failures (error toasts) — pick the guide below that matches your scenario:

---

## READ [lwc-error-handling-guide](#lwc-error-handling) when:

- Your component surfaces a **failure** to the user
- You have a `.catch(err => ...)` from an Apex call that needs user visibility
- A `@wire` result carries `error` or `success === false`
- Synchronous validation fails before any Apex is dispatched

**The pattern:** Dispatch a `ShowToastEvent` with `variant: 'error'`. Never store the message in a tracked field and render it inline — the toast is the single error channel.

---

## READ [lwc-request-loading-guide](#lwc-apex-loading-spinner) when:

- A **parent** LWC handler makes an imperative Apex call via `.then(...).catch(...)`
- The call is user-initiated (a `handleXxx` method or event-driven function)
- You need to show a spinner while the round-trip is in flight

**The pattern:** Wire the handler to an `isLoading` flag (set `true` before the call, reset `false` in `.finally`), and render `<c-ao-spinner overlay>` at the component root to keep it above modals.

---

<!-- merged from: lwc-error-handling-guide.md -->

# LWC Error Handling

Every failure surfaced from an LWC goes through `ShowToastEvent`. No tracked
`errorMessage` fields, no inline error banners with a Dismiss button, no
component-local error state to clear on the next render. The toast is the
single, consistent error channel across the app.

---

## The pattern

```js
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

_toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}
```

```
ALWAYS FOR ERROR WE SHOULD USE ShowToastEvent
```

Call `this._toast('Error', message, 'error')` from:
- `.catch(err => ...)` of an imperative Apex call
- The `result.error` / `result.data.success === false` branches of a `@wire` callback
- Synchronous validation failures before any Apex is dispatched

---

<!-- merged from: lwc-request-loading-guide.md -->

# LWC Apex Loading Spinner

Every imperative Apex call in an LWC parent component is a network round-trip
the user is waiting on. Without a visible spinner, double-clicks turn into
duplicate writes, and modals close silently while the user wonders if their
action did anything. This skill enforces a single, consistent loading pattern
across the component:

1. The JS handler flips an `isLoading` flag for the lifetime of the Apex
   promise (`try` at the top, `finally` at the bottom).
2. The HTML renders `<c-ao-spinner overlay>` under `<template if:true={isLoading}>`,
   placed at the component's **root** template so it can stack above every
   other surface in the component — modals, peek panels, bulk bars, etc.
3. The overlay backdrop and its `z-index: 9999` (above modals at `9001`) are
   owned **inside** `c-ao-spinner` itself. You no longer hand-roll a
   `.loading-overlay` wrapper div or its CSS — you just keep the spinner at the
   root so its fixed overlay isn't trapped in a section's stacking context.

The third point is the trap most implementations miss: a `<c-ao-spinner overlay>`
nested inside a `<section class="panel">` that forms its own stacking context
(any `position` + `z-index` ancestor) is confined to that context, so it
disappears behind an open modal. Rendering it at the root `<template>` is what
keeps its fixed overlay on top.

---

## Instructions

### Step 1 — Confirm the handler is in scope

Before touching code, confirm ALL of the following:

| # | Check | How |
|---|-------|-----|
| 1 | The file is an LWC parent JS | Path matches `force-app/main/default/lwc/<name>/<name>.js` |
| 2 | The function imperatively calls Apex | Body contains `<importedSymbol>(...).then(...)` where `<importedSymbol>` is imported via `import ... from '@salesforce/apex/...'` |
| 3 | The function is user-initiated | Method name starts with `handle` OR is invoked from an event/onclick |
| 4 | No `@wire` is driving the same call | The promise chain is hand-written, not declarative |

If ANY of these fails, do NOT apply the skill — let the function be.

### Step 2 — Pick the loading flag

Inspect the component class for an existing loading flag, in this priority
order:

1. A scoped flag that already covers this exact section (e.g.
   `unassignedIsLoading` for unassigned-area handlers). **Reuse it.**
2. The conventional top-level flag `isLoading` declared on the class. Reuse
   it.
3. No flag exists. Declare `isLoading = false;` near the top of the
   `PROPERTIES & STATE` block.

NEVER introduce a new flag if a suitable one already exists — the goal is one
spinner-driving flag per visual region, not one per handler.

```

Rules:

- The `.finally` goes **after** `.catch`, never before it. Promise chains
  resolve in declared order; putting `finally` first means a synchronous
  error in `then` won't reset the flag.
- Use the arrow form `() => { this.isLoading = false; }` so `this` stays
  bound to the component instance.
- Do NOT also set `isLoading = false` inside `then` or `catch` — `finally`
  covers both paths and double-resets are noise.

### Step 3b — Wire with function handler

When the Apex call is declarative (`@wire(apexMethod, { p: '$reactiveParam' })`
with a function handler that receives `{ data, error }`), the loading
toggle is **split across two methods**:

- The user-action handler that sets the reactive parameter (`this._foo = ...`)
  owns the `isLoading = true` assignment. Setting the param is what causes the
  wire to refire, so that's the moment the network request starts conceptually.
- The wire callback itself owns the `isLoading = false` assignment — that's
  when the response (or error) actually arrives.

```js

handleItemLinkedToExpand(event) {
    this.isLoading = true;                              // ← flip ON here
   //... triggers the wire
}
```

Rules specific to the wire form:

- Do NOT try to wrap the wire in a promise chain — the framework owns the
  lifecycle. `isLoading = false` lives inside the callback, not in a `finally`.
- Reset the flag on **both** branches (`data` and `error`). A single
  assignment at the bottom of the callback (after the `if/else`) is the
  cleanest way to guarantee that.
- Guard against the initial `null`/`undefined` call the wire fires before
  the user has triggered anything — early-return so you don't toggle the
  spinner for a no-op invocation.
- If the same reactive param is set by multiple handlers (e.g. open item
  view, refresh item view), every one of them must apply the same cache-miss
  guard before flipping `isLoading = true` (see below) — the wire callback is
  the single source of truth for flipping it off.

#### Only raise the spinner on a genuine server fetch (a cache MISS)

Set `isLoading = true` **only** when the wire will actually go to the server.
There is **no request** — and therefore the spinner must **never** be raised —
in two situations:

1. **Same value.** Assigning the param the value it already holds does nothing:
   the framework skips the wire, the callback never runs, so a spinner flipped
   on here would spin **forever** (nothing ever flips it off).
2. **Previously-fetched value.** Assigning a value the wire already fetched once
   this session. Because you never `refreshApex` it, Lightning Data Service
   serves it straight from its **client-side cache** with no network
   round-trip. The callback fires, but instantly, off the cache — a spinner
   here is just a pointless flash.

So track the values you have actually fetched, and gate `isLoading = true` on a
true cache **miss**. In the two no-request branches, leave `isLoading` alone
(don't even set it `false` — a concurrent load from another handler may legitimately
own the spinner); just switch the view and return.

```js
// Values already fetched once this session. A wire param that lands back on
// any of these is served from LDS cache — no server round-trip — so it must
// NOT raise the spinner.
_fetchedWorkspaceIds = new Set();

handleTopicsForWorkspace(workspaceId) {
    // No real request in either of these — never raise the spinner:
    //   (1) same value the param already holds → wire won't refire at all
    //   (2) a value already fetched once       → LDS serves it from cache
    if (workspaceId === this._topicsTargetWorkspaceId || this._fetchedWorkspaceIds.has(workspaceId)) {
         // still switch the view (cache-served)
        return;                                    // leave isLoading untouched
    }
    this.isLoading = true;                         // genuine cache miss → real fetch
  
}
```

Do NOT reach for `refreshApex` to force the wire to re-run on a same or
already-cached value. `refreshApex` exists to re-fetch fresh data from the
**server** (the backend changed), not to re-render UI you already have. Using
it as a way to "retrigger the spinner" round-trips to Apex for data you already
hold and masks the real bug, which is toggling the spinner for a wire that was
never going to make a request.

### Step 4 — Ensure the HTML renders the spinner

In `<name>.html`, look for an existing render of the loading flag. Three
cases:

**Case A — no spinner exists yet.** Add this block once at the root
`<template>` so the overlay covers the whole component (including any open
modal):

```html
<template if:true={isLoading}>
    <c-ao-spinner overlay size="medium" alternative-text="Loading..."></c-ao-spinner>
</template>
```

`overlay` makes `c-ao-spinner` render its own fixed, full-viewport backdrop
(navy at 70% transparency, `z-index: 9999`) — there is no wrapper div to add.

**Case B — a bare spinner / hand-rolled overlay exists** (`<lightning-spinner ...>`,
or a `<div class="loading-overlay"><lightning-spinner></div>` wrapper, under an
`if:true={isLoading}` template). Replace the whole thing with `<c-ao-spinner overlay>`:

```html
<!-- BEFORE -->
<template if:true={isLoading}>
    <div class="loading-overlay">
        <lightning-spinner alternative-text="Loading..." size="medium"></lightning-spinner>
    </div>
</template>

<!-- AFTER -->
<template if:true={isLoading}>
    <c-ao-spinner overlay size="medium" alternative-text="Loading..."></c-ao-spinner>
</template>
```

**Case C — `<c-ao-spinner overlay>` already present.** Leave it untouched.

### Step 5 — Stacking & CSS cleanup

The overlay backdrop and its `z-index: 9999` live **inside** `c-ao-spinner`'s
own shadow DOM, so there is no `.loading-overlay` rule to add to `<name>.css`.
Two things to verify instead:

- **Placement.** `<c-ao-spinner overlay>` must sit at the component's root
  `<template>`, not nested inside a `position` + `z-index` section — otherwise
  its fixed overlay is confined to that ancestor's stacking context and hides
  behind a modal. (This is the trap from the intro.)
- **Cleanup.** If you replaced an old `<div class="loading-overlay">` wrapper
  in Step 4, delete the now-orphaned `.loading-overlay` rule from `<name>.css`.
- **z-index sanity.** The spinner's overlay is fixed at `9999`. Grep the same
  CSS for `z-index:`; modals/peek-panels are typically `9000` / `9001`, which
  sit below it. If a surface in this file uses `>= 9999`, lower it to the
  conventional `9001` rather than leaving it to fight the spinner.

The overlay also dims the page behind it — that's intentional; it both signals
"the app is busy" and blocks click-throughs on whatever the user was just
interacting with (modal buttons, item rows, drag handles).

---

## Completion checklist

Before reporting the task as done, confirm:

**Imperative Apex case:**
- [ ] `this.isLoading = true;` appears **after** any synchronous early-return validation, **before** the Apex call.
- [ ] `.finally(() => { this.isLoading = false; })` is the **last** link in the promise chain.
- [ ] No `isLoading = false` assignment exists inside `.then` or `.catch`.

**`@wire` with function handler case:**
- [ ] Every user-action handler that mutates the reactive parameter sets `this.isLoading = true;` **only on a genuine cache miss** (a new, never-fetched value).
- [ ] Same-value and already-fetched (cache-served) assignments leave `isLoading` untouched and just switch the view — they never raise the spinner.
- [ ] The wire callback contains a single `this.isLoading = false;` reached on **both** the `data` and `error` branches.
- [ ] The wire callback guards against the initial null/undefined call before flipping any state.

**Shared (both cases):**
- [ ] The HTML renders `<c-ao-spinner overlay>` under `<template if:true={isLoading}>`, at the component's root template.
- [ ] No hand-rolled `.loading-overlay` div/CSS remains; any surface in the same CSS file uses `z-index < 9999`.
- [ ] The same loading flag is used (not a new per-handler boolean).
