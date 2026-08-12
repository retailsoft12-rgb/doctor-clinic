# Principal Data State — Case 3 Data State

**Data state type is determined by the principal method that loads it when the LWC initializes.**

If the principal load method returns multiple entity types, each becomes its own principal state. All other new features either derive from or update one of these principal states.

## Core Rule

**Each entity type returned by the principal load method is a principal state with full CRUD operations available on the frontend.**

## Characteristics of Principal State

- Loaded once at component initialization (or deliberately reloaded)
- Covers **all CRUD operations** (Create, Read, Update, Delete)
- Mutations update the frontend state directly and sync to the server
- Every change to principal state must either sync back to server or be validated to sync
- If multiple entity types are loaded, each is a **separate** principal state

## Pattern: Multiple Principal States

When the principal load method returns multiple entity types, **don't merge them**:

```javascript
export default class ManageItems extends LightningElement {
    // ❌ WRONG: Merged into one state
    @track workspaceData = {
        buckets: [],
        unassignedItems: [],
        topics: []
    };

    // ✅ CORRECT: Separate principal states
    @track buckets = [];           // Principal state 1: Can CRUD buckets
    @track unassignedItems = [];    // Principal state 2: Can CRUD unassigned items
    @track topics = [];             // Principal state 3: Can CRUD topics

    connectedCallback() {
        this.loadPrincipalData();
    }

    async loadPrincipalData() {
        const result = await loadWorkspaceData({ workspaceId: this.workspaceId });
        this.buckets = result.data.buckets;           // Principal state 1
        this.unassignedItems = result.data.items;    // Principal state 2
        this.topics = result.data.topics;               // Principal state 3
    }
}
```

## Examples

| Principal State | Loaded by | CRUD Operations |
|---|---|---|
| `buckets[]` | `loadWorkspaceData()` | Create bucket, read bucket, update bucket, delete bucket |
| `unassignedItems[]` | `loadWorkspaceData()` | Create item, read item, update item, delete item |
| `topics[]` | `loadWorkspaceData()` (if included) | Create topic, read topic, update topic, delete topic |

## When to Create a New Principal State

A new feature is principal data when:

1. **It's loaded directly from the server** (not derived from existing data)
2. **It supports full CRUD** (or a subset thereof)
3. **It's not a picklist** (Case 1: always separate, small, static)
4. **It's not a server indicator** (Case 2: pagination/sync metadata)

```javascript
// ✅ If the feature loads buckets at init time:
async connectedCallback() {
    const result = await loadBuckets({ workspaceId: this.workspaceId });
    this.buckets = result.data;  // New principal state
}

// ✅ If the user can create, update, delete buckets:
handleCreateBucket(event) {
    const newBucket = { name: event.detail.name, ... };
    createBucket(newBucket)
        .then(res => {
            this.buckets = [...this.buckets, res.data];  // Update principal state
        });
}
```

## Be Careful: Child Component Principal State

A child component may load the same entity type as its parent (e.g., bucket items), but if it's **loaded in isolation within a child flow**, it has its own principal state tracking:

```javascript
// Parent holds buckets with nested items:
// this.buckets[0] = { id: 'bucket-1', items: [...] }

// Child loads the same bucket's items in isolation:
@track bucketItems = [];  // Child's separate principal state

connectedCallback() {
    loadBucketItems({ bucketId: this.bucketId })
        .then(res => {
            this.bucketItems = res.data;  // Child's own principal state
        });
}

// IMPORTANT: Parent's buckets[0].items ≠ Child's bucketItems
// When child updates an item, ensure it signals parent OR parent re-loads
```

## Data Flow: Update Pattern

All updates to principal state flow through this pattern:

```javascript
// 1. Call Apex (server write)
// 2. On success: Update principal state from response
// 3. On error: Show toast, don't update state

handleUpdateItem(event) {
    const itemId = event.detail.itemId;
    const updates = event.detail.updates;

    updateItem({ itemId, ...updates })
        .then(res => {
            if (!res.success) throw new Error(res.message);
            
            // Update principal state from response
            this.unassignedItems = this.unassignedItems.map(t =>
                t.id === res.data.id ? res.data : t
            );
        })
        .catch(err => {
            this._toast('Error', err.body?.message || err.message, 'error');
            // Principal state NOT updated on error
        });
}
```

## Separation of Concerns

| Layer | Responsibility | Example |
|---|---|---|
| **Principal state** | Server-backed data with CRUD | `buckets`, `unassignedItems`, `topics` |
| **Derived state** | Computed getters (read-only) | `hasBuckets()`, `activeBucketName()` |
| **Control state** | UI visibility | `showBucketModal`, `isExpanded` |
| **Selection state** | What's selected/hovered | `_selectedItemIds`, `_activeBucketId` |
| **Communication state** | Async operations | `isLoading`, `isLoadingItems` |
| **Picklist state** | Reference data | `statusOptions`, `memberOptions` |
| **Server indicators** | Pagination/sync metadata | `offset`, `hasMore` |

---

