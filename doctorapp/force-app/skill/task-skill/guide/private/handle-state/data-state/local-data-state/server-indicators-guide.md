# Server Indicators — Case 2 Data State

**Server flags and pagination metadata are grouped with their related data.**

When the server returns pagination info or status flags, they group with the data they describe — not isolated, not mixed with picklists, not mixed with communication state.

## Characteristics

- Returned alongside principal data from the server
- Describe pagination, sync status, or data freshness
- Include `hasMore`, `offset`, `limit`, `isStale`, `isLoadingItems`
- Live near (on the same object or in a parallel tracking field) their related data

## Patterns

### Single-entity pagination group

```javascript
// ✅ CORRECT: Indicator fields paired with data
this.unassignedItems = [];      // Principal data
this.unassignedOffset = 0;         // Pagination indicator
this.unassignedHasMore = false;   // Pagination indicator
```

### Nested pagination (items within arrays)

```javascript
// ✅ CORRECT: Each bucket carries its own indicators
this.buckets = [
    {
        id: 'bucket-1',
        name: 'Bucket 1',
        items: [],        // Principal data for this bucket
        offset: 0,          // Pagination indicator (paired)
        hasMore: false,     // Pagination indicator (paired)
        isLoadingItems: false  // Communication indicator (paired)
    },
    {
        id: 'bucket-2',
        name: 'Bucket 2',
        items: [],
        offset: 0,
        hasMore: false,
        isLoadingItems: false
    }
];
```

## Examples from manageItems

| Data Group | Indicators | Purpose |
|---|---|---|
| `unassignedItems` | `unassignedOffset`, `unassignedHasMore` | Unassigned pagination |
| `buckets[i].items` | `buckets[i].offset`, `buckets[i].hasMore` | Per-bucket pagination |
| Any data array | `isLoadingItems`, `isSyncing` | Whether the data is fresh |

## Anti-patterns to avoid

```javascript
// ❌ WRONG: Server indicators isolated
this.unassignedItems = [];
this.unassignedOffset = 0;
this.unassignedHasMore = false;
this.statusOptions = [];  // WRONG: picklist mixed with indicators

// ❌ WRONG: Server indicators mixed with communication state
this.state = {
    data: [...],
    offset: 0,
    hasMore: false,
    isLoading: true,  // Wrong: communication state here; use separate isLoadingItems
    error: null       // Wrong: error goes to ShowToastEvent, not here
};
```

## Correct organization

```javascript
export default class ManageItems extends LightningElement {

    // 3. SERVER INDICATORS — grouped with their data
    @track unassignedOffset = 0;      // Paired with unassignedItems
    @track unassignedHasMore = false; // Paired with unassignedItems

    async loadUnassigned() {
        isLoading = true;
        try {
            const result = await loadUnassignedItems({
                offset: this.unassignedOffset
            });
            this.unassignedItems = result.data.items;
            this.unassignedOffset = result.data.offset;
            this.unassignedHasMore = result.data.hasMore;
        } catch (err) {
            this._toast('Error', err.message, 'error');
        } finally {
            isLoading = false;
        }
    }
}
```

## Rule

**Server indicators live near their data, not mixed with picklists or communication state.**

Pairing ensures that when you update the data, the indicators move with it:

```javascript
// ✅ Correct: When data and indicators move together
const updatedBucket = {
    ...this.buckets[0],
    offset: newOffset,
    hasMore: newHasMore
};
this.buckets = [updatedBucket, ...this.buckets.slice(1)];
```

---
