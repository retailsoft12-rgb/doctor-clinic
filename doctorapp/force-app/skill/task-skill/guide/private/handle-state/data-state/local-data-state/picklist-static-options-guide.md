# Picklist & Static Options — Case 1 Data State

**These CANNOT be merged with other state types.**

Picklists and option sets are reference data that should always be stored separately from principal data and server indicators.

## Characteristics

- Are fetched once and rarely change
- Are used for dropdowns, comboboxes, and form selections
- Should NEVER be combined with item/bucket data
- Are typically small arrays of `{id, label}` objects
- Have no pagination or server-sync metadata

## Pattern

Keep picklists in separate tracked fields, named to clearly identify them as options:

```javascript
export default class ManageItems extends LightningElement {
    // ✅ CORRECT: Picklist options isolated in dedicated fields
    @track state1Options = [];
    @track state2Options = [];
    @track state3Options = [];
    @track state4Options = [];
}
```

## Examples from manageItems

| Field | Purpose |
|-------|---------|
| `state1Options` | state1 picklist |
| `state2Options` | Team member choices |
| `state3Options` | Item type choices |
| `state4Options` | Priority levels |

## Anti-patterns to avoid

```javascript
// ❌ WRONG: Merging picklist with principal data
this.bucketData = {
    id: 'bucket-123',
    name: 'Bucket 1',
    state1Options: [{ id: 'open', label: 'Open' }],  // Don't do this
    state2Options: [{ id: 'user-1', label: 'Alice' }] // Don't do this
};

// ❌ WRONG: Merging picklist with server indicators
this.itemState = {
    items: [...],
    offset: 0,
    hasMore: false,
    state1Options: [...],  // Wrong layer
};
```

## Correct organization

```javascript
export default class ManageItems extends LightningElement {
    // 1. REFERENCE DATA (picklists) — isolated
    @track state1Options = [];
    @track state2Options = [];
    @track state3Options = [];

    // 2. PRINCIPAL DATA (server-backed) — separate

    // 3. SERVER INDICATORS — grouped with related data

    connectedCallback() {
        this.loadReferences();  // Load picklists first
       // Then load main data
    }

    async loadReferences() {
        const result = await loadPicklistOptions();
        this.state1Options = result.data.statuses;
        this.state2Options = result.data.members;
        this.state3Options = result.data.itemTypes;
    }
}
```

## Rule

**Keep in separate tracked fields. Never merge with principal data or server indicators.**

Derived state (getters) can reference picklists for lookups:
