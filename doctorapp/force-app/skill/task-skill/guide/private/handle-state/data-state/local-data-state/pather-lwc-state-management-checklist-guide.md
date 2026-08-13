Before presenting the generated code, walk the checklist. If any row fails, fix
it before emitting code. 

**Prerequisites:** Read [Principal Data State](principal-data-state-guide.md) for entity separation rules, and [Derived State](../derived-state/derived-state.md) for getter patterns.

| # | Check | Fix if it fails |
|---|-------|-----------------|
| 1 | Is principal state updated from the Apex **response data**, not from optimistic local values? (Rule 0) | Move the `_patchXxx` call inside `.then()` / the wired-function body. |
| 2 | Is `@wire` used in **wired-function form** when it must update principal state? (Rule 0) | Replace `@wire(...) prop;` with `@wire(...) wiredXxx(result) { ... }`. |
| 3 | Is there one handler function per dispatched event, named `handle<Child><Event>`? (Rule 1) | Split combined handlers; rename per pattern. |
| 4 | Is the active-object ID stored separately from the principal state? (Rule 4) | Add `@track _activeXxxId = null`. |
| 5 | Are there find / update / delete / create mutators (e.g. `_patchItemEverywhere`)? (Rule 5) | Add them; never mutate state inline inside a handler. |
| 6 | On Apex failure, is a `ShowToastEvent` dispatched? (Rule 6) | Add the toast in the `.then()` failure branch. |
| 7 | When updating, are all levels on the path to the leaf spread, and is `_key` regenerated to flag the change? (Rule 7) | Apply the spread pattern; use `Id` to find, `_key` to flag. |
| 8 | Does every dispatched event from the child have a handler wired via `onxxx={handler}` in the template? | Add the missing `on<event>={handle<Child><Event>}` attribute. |

## Rule 8 — Shaping principal state on first load

On the **first page load**, build the principal state from BOTH axes at once:

- **UI display** decides how many TOP-LEVEL principal states exist — one per
  independent panel the UI shows side-by-side.
- **Entity (DB) hierarchy** decides the NESTING inside each principal state — a
  child record lives under its parent, exactly as the schema relates them.

When the two axes agree, keep one principal state. When the UI splits something
the schema keeps together (or vice-versa), the UI split wins at the top level —
but each split still nests by entity underneath, because that never contradicts
the UI. Never flatten the entity hierarchy and never duplicate a child across
levels.

### Case A — one principal state (UI and entity agree)

`manageWorkflow`: the UI shows statuses and transitions **all under one
workflow**, and the entity nests them under `Workflow__c`. → a single
`workflowData = { id, workspaceStatus:[…], workflow:{ transitions:[…] } }`.
Everything (`_statuses`, `_transitions`, `activeTransition`,
`showTransitionDetail`) is a getter off that one object.

### Case B — two principal states, still nested by entity

`manageItems`: the UI shows **Buckets** and the **Unassigned list** as two separate
panels, so two top-level states — `@track buckets = []` and
`@track unassignedItems = []`. But a bucket's items nest **under the bucket**
(`bucket.items`), mirroring the `Bucket__c → Item__c` relation, because that
nesting does not contradict the UI. Moving an item is one immutable rewrite of
both states; no item is stored in two places.

## Example: Event Handling + State Mutations

Anti-patterns to detect:

```javascript
// ❌ WRONG (Checklist rows 1–2): Optimistic mutation; wired-property form
@wire(loadItemLinkedTo, { itemId: '$activeItemViewId' }) itemLinkedTo;

handleItemSummaryUpdate(event) {
    const { itemId, summary } = event.detail;
    // Mutate BEFORE Apex returns (violates Rule 0)
    this._patchItemEverywhere(itemId, { Summary__c: summary });
    saveItemSummary({ itemId, summary }); // fire-and-forget, no toast
}
```

Correct form (per checklist):

```javascript
// ✅ CORRECT (Checklist rows 1–2): Wired-function form, update FROM response
@track _linkedToTargetItemId = null;

handleItemLinkedToExpand(event) {
    this._linkedToTargetItemId = event.detail.itemId;  // (Checklist row 4)
}

@wire(loadItemLinkedTo, { itemId: '$_linkedToTargetItemId' })
wiredItemLinkedTo(result) {
    if (result.data && result.data.success && this._linkedToTargetItemId) {
        const linkedTo = result.data.data?.itemLinkTo || [];
        // Update FROM Apex response (Checklist row 1)
        this._patchItemEverywhere(this._linkedToTargetItemId, { linkedTo });
    }
}

// ✅ CORRECT (Checklist row 3): One handler per event
handleItemSummaryUpdate(event) {
    const { itemId, summary } = event.detail;
    updateItemSummary({ itemId, summary })
        .then(res => {
            if (res?.success) {
                // Update FROM response, via mutator (Checklist rows 1 + 5)
                this._patchItemEverywhere(itemId, { Summary__c: summary });
            } else {
                // Toast on failure (Checklist row 6)
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Update failed', message: res?.message, variant: 'error'
                }));
            }
        });
}

// ✅ CORRECT (Checklist row 5): Dedicated mutator
_patchItemEverywhere(itemId, updates) {
    // Find and update in ALL principal states with immutable spread (Checklist row 7)
    this.unassignedItems = this.unassignedItems.map(t =>
        t.id === itemId ? { ...t, ...updates, _key: Date.now() } : t
    );
    this.buckets = this.buckets.map(bucket => ({
        ...bucket,
        items: bucket.items.map(t =>
            t.id === itemId ? { ...t, ...updates, _key: Date.now() } : t
        )
    }));
}

// ✅ CORRECT (Checklist row 8): Every event wired in template
// <c-child-item on:summaryupdate={handleItemSummaryUpdate}></c-child-item>
```
