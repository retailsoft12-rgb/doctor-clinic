# How To Handle Wire Implementation (analysis guide)

Use this protocol whenever the parent component calls an Apex method. This guide
analyzes the recorded **cacheability**, **visibility/urgency**, and **data-load**
answers to determine the call style (`@wire` vs imperative), gating-field
selection, and wire initialization pattern.

This guide encodes the visibility-urgency decision logic and wire initialization
patterns. Follow the answer-to-action mapping below verbatim; do not invent a
fourth option for visibility/urgency or a third state for initialization.

## Inputs — read from `scratchpad-memory.md`

Every input this guide needs was already gathered by the caller and written into
**`scratchpad-memory.md`** in the session scratchpad directory. Read them from
there — not from loose context handed down by the calling skill.

| Input | Source |
|---|---|
| **Method cacheability** (Yes / No) | `scratchpad-memory.md` § 1, Tab 6a |
| **Visibility/urgency** (Very important / Important / Not important) | `scratchpad-memory.md` § 1, Tab 6c |
| **Expand-driven load** (Yes / No / `n/a`) | `scratchpad-memory.md` § 2, Tab 7 |
| **Load timing** (on-create / on-expand / `n/a`) | `scratchpad-memory.md` § 2, Tab 8 |
| **Load on page creation** (Yes / No / `n/a`) | `scratchpad-memory.md` § 2, Tab 9 |

- **Take every value verbatim.** Do not validate, second-guess, predict, or
  re-derive a recorded answer.
- **Never ask.** This guide prompts the user for nothing — the questions belong to
  the caller. If a section is missing, return control to the calling skill so its
  gate fires; do not open a prompt to fill the gap.
- **`n/a` is a present value**, not a missing one. When § 2 reads `n/a` (the
  behavior has no read operation) there is no wire to gate: skip the gating-field
  and initialization analyses entirely.

## Step 0 — Analyze cacheability gate

**Input:** Method cacheability — `scratchpad-memory.md` § 1, Tab 6a
(Yes/No, i.e. cacheable/not-cacheable).

`@wire` can only bind to an Apex method annotated `@AuraEnabled(cacheable=true)`.

- **Not cacheable** → `@wire` is impossible. Use an **imperative call** instead
  (import the method and invoke it from `connectedCallback` / an action handler,
  updating principal state in the `.then(...)`). Skip to imperative branch below.
- **Cacheable** → `@wire` is available. Proceed to visibility-urgency analysis below.

```javascript
// Not cacheable → imperative call, no @wire.
import loadItems from '@salesforce/apex/ItemController.loadItems';

connectedCallback() {
    loadItems({ bucketId: this.activeBucketId })
        .then(res => {
            if (res?.success) {
                this._items = res.data?.items || [];
            }
        });
}
```

## Visibility-Urgency Analysis

**Input:** Visibility/urgency — `scratchpad-memory.md` § 1, Tab 6c ("How important
is it for this value to be visible to other users as soon as possible?") — one of:
- Very important
- Important  
- Not important

## Branches

### Very important → `@wire` + `refreshApex` on **every** applicable request

The freshest possible view: call `refreshApex(this.wiredResult)` after **every**
applicable request the child dispatches, so any concurrent write by another user
is pulled back immediately. Update principal state from the wired-function body
(Rule 0), never optimistically.

```javascript
// Very important: re-pull on every child request so other users' writes
// surface ASAP. Store the wired result so refreshApex can re-fire it.
_wiredItems;

@wire(loadItems, { bucketId: '$activeBucketId' })
wiredItems(result) {
    this._wiredItems = result;                 // keep for refreshApex
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
}

handleItemStatusChange(event) {
    const { itemId, status } = event.detail;
    updateItemStatus({ itemId, status })
        .then(res => {
            if (res?.success) {
                return refreshApex(this._wiredItems);   // every request
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Update failed', message: res?.message, variant: 'error'
            }));
        });
}
```

### Important → `@wire` + `refreshApex` only on actions **related to this data**

Refresh selectively: call `refreshApex` only when the dispatched event actually
touches this data set, and skip it for unrelated child events. Cheaper than
"very important", still coherent for the writes that matter.

```javascript
// Important: refreshApex only on actions related to THIS data
// (status changes affect the list; a summary edit on one row does not).
_wiredItems;

@wire(loadItems, { bucketId: '$activeBucketId' })
wiredItems(result) {
    this._wiredItems = result;
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
}

handleItemStatusChange(event) {        // related → refresh
    const { itemId, status } = event.detail;
    updateItemStatus({ itemId, status })
        .then(res => {
            if (res?.success) {
                return refreshApex(this._wiredItems);
            }
            this.dispatchEvent(new ShowToastEvent({
                title: 'Update failed', message: res?.message, variant: 'error'
            }));
        });
}

handleItemSummaryUpdate(event) {       // unrelated to the list → no refresh
    const { itemId, summary } = event.detail;
    updateItemSummary({ itemId, summary })
        .then(res => {
            if (res?.success) {
                this._patchItemEverywhere(itemId, { Summary__c: summary });
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Update failed', message: res?.message, variant: 'error'
                }));
            }
        });
}
```

### Not important → `@wire` **without** `refreshApex`

Stale-tolerant: wire the load once and let it re-fire only when its gating field
changes. No `refreshApex` — concurrent writes by others are not pulled back
until the wire naturally re-runs.

```javascript
// Not important: plain wired-function form, no refreshApex. The wire re-fires
// only when activeBucketId changes; concurrent edits by others are tolerated.
@wire(loadItems, { bucketId: '$activeBucketId' })
wiredItems(result) {
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
}
```

## Analysis — gating-field selection

**Inputs:** Expand-driven load — `scratchpad-memory.md` § 2, Tab 7; load timing —
§ 2, Tab 8.

Pick the field the `@wire` reacts to:

- **Not expand-driven** (Tab 7 = No) → use `activeObjectId` as the gating field
- **Expand-driven with on-expand timing** (Tab 7 = Yes, Tab 8 = on-expand) → use
  `_expandTargetId` as the gating field
- **Expand-driven with on-create timing** (Tab 7 = Yes, Tab 8 = on-create) → use
  `activeObjectId`
- **`n/a`** (no read operation) → no wire to gate; skip this analysis and the
  initialization analysis below

Whichever field is chosen, keep it separate from the principal active id per the
`wiredState` rule at the end of this guide.

## Analysis — wire initialization based on load timing

After the visibility-urgency branch and gating field are chosen, **analyze**
whether data should load on page creation or on user action.

**Input:** Load on page creation — `scratchpad-memory.md` § 2, Tab 9 ("Should this
data load when the page loads?"):

> **Yes** — initialize gating field with a defined value

The `@wire` fires immediately on first render because its gating field is defined.
Use this when the parent loads the data on page creation.

```javascript
// Yes: data loads on first render. Gating parameter starts with a value,
// so loadItems is called immediately when connectedCallback fires.
_wiredBucketId = this.activeBucketId;  // defined → wire fires on first render

@wire(loadItems, { bucketId: '$_wiredBucketId' })
wiredItems(result) {
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
}
```

> **No** — initialize gating field as `undefined`

The `@wire` stays dormant on first render. A reactive `@wire` fires as soon as
**all** of its `'$gating'` parameters are defined. If you do not want it to run
on first render, declare the gating parameter as `undefined` (do **not** seed it
with a value). The wire stays dormant until a real user action assigns a defined
value to the gating field.

```javascript
// No: do not let the wire fire on connect. Gating parameter starts undefined,
// so loadItems is NOT called until something sets _wiredBucketId.
_wiredBucketId;            // undefined → wire dormant on first render

@wire(loadItems, { bucketId: '$_wiredBucketId' })
wiredItems(result) {
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
}
```

## Rule — separate `wiredState` from the principal active id

**Always use a separate `wired<State>` field to drive the wire's reactivity.**
When a state change must trigger an Apex call, do **not** set the gating field
inside the wired function, and do **not** reuse the principal `active…Id` as the
wire parameter. Instead:

- The principal `active…Id` is for **UI update only** — it reflects selection /
  highlight and is set wherever the user interacts.
- A **separate** `_wired…Id` is the wire's gating parameter. It is assigned
  **only in the actual method that needs the wire to run**, not in the wired
  callback and not as a side effect of the UI selection.

Keeping the two apart means the wire fires exactly when the work that needs the
data happens — not every time the UI selection changes — and prevents the wired
function from feeding its own gating field (which would re-trigger itself).

For initialization (from `scratchpad-memory.md` § 2, Tab 9 — load on page creation):
- **Yes** → set the gating field to a defined value in the class field declaration
  or `connectedCallback`, so the wire fires immediately
- **No** → leave the gating field `undefined`, so the wire stays dormant until
  a user action assigns it a value

```javascript
// Principal state: UI only. Selecting a bucket highlights it, no Apex call.
@track activeBucketId;

// Separate wire gate. Initialized from § 2, Tab 9 (load on page creation).
// If Yes → set to a value; if No → leave undefined
_wiredBucketId;  // No → wire dormant on first render

@wire(loadItems, { bucketId: '$_wiredBucketId' })
wiredItems(result) {
    this._wiredItems = result;
    if (result.data && result.data.success) {
        this._items = result.data.data?.items || [];
    }
    // NOTE: never assign this._wiredBucketId here.
}

handleBucketSelect(event) {
    // UI update only — does NOT load items.
    this.activeBucketId = event.detail.bucketId;
}

openBucketBoard() {
    // The method that actually needs the data sets the wire gate here (if No).
    // If Yes, _wiredBucketId was already set and wire already ran.
    this._wiredBucketId = this.activeBucketId;
}
```

