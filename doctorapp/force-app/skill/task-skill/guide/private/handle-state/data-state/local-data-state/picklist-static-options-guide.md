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
    @track statusOptions = [];
    @track memberOptions = [];
    @track itemTypeOptions = [];
    @track priorityOptions = [];
    _itemLinkedToTypeOptions = [];
}
```

## Examples from manageItems

| Field | Purpose |
|-------|---------|
| `statusOptions` | Status picklist |
| `memberOptions` | Team member choices |
| `itemTypeOptions` | Item type choices |
| `priorityOptions` | Priority levels |
| `_itemLinkedToTypeOptions` | Link type choices |

## Anti-patterns to avoid

```javascript
// ❌ WRONG: Merging picklist with principal data
this.bucketData = {
    id: 'bucket-123',
    name: 'Bucket 1',
    statusOptions: [{ id: 'open', label: 'Open' }],  // Don't do this
    memberOptions: [{ id: 'user-1', label: 'Alice' }] // Don't do this
};

// ❌ WRONG: Merging picklist with server indicators
this.itemState = {
    items: [...],
    offset: 0,
    hasMore: false,
    statusOptions: [...],  // Wrong layer
};
```

## Correct organization

```javascript
export default class ManageItems extends LightningElement {
    // 1. REFERENCE DATA (picklists) — isolated
    @track statusOptions = [];
    @track memberOptions = [];
    @track itemTypeOptions = [];

    // 2. PRINCIPAL DATA (server-backed) — separate
    @track buckets = [];
    @track unassignedItems = [];

    // 3. SERVER INDICATORS — grouped with related data
    unassignedOffset = 0;
    unassignedHasMore = false;

    connectedCallback() {
        this.loadReferences();  // Load picklists first
        this.loadPrincipalData(); // Then load main data
    }

    async loadReferences() {
        const result = await loadPicklistOptions();
        this.statusOptions = result.data.statuses;
        this.memberOptions = result.data.members;
        this.itemTypeOptions = result.data.itemTypes;
    }

    async loadPrincipalData() {
        const result = await loadBuckets();
        this.buckets = result.data;
    }
}
```

## Rule

**Keep in separate tracked fields. Never merge with principal data or server indicators.**

Derived state (getters) can reference picklists for lookups:

```javascript
// ✅ OK: Getter uses picklist for lookup
get itemTypeName() {
    const typeOption = this.itemTypeOptions.find(
        opt => opt.id === this.activeItem.itemTypeId
    );
    return typeOption?.label || 'Unknown';
}
```

