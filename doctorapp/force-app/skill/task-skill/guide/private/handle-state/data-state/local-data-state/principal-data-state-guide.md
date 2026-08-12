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
        principalState1: [],
        principalState2: [],
        principalState3: []
    };

    // ✅ CORRECT: Separate principal states
    @track principalState1 = [];           // Principal state 1: Can CRUD principalState1
    @track principalState2 = [];    // Principal state 2: Can CRUD principalState2
    @track principalState3 = [];             // Principal state 3: Can CRUD principalState3

    connectedCallback() {
        this.loadPrincipalData();
    }

    async loadPrincipalData() {
        const result = await loadWorkspaceData({ workspaceId: this.workspaceId });
        this.principalState1 = result.data.principalState1;           // Principal state 1
        this.principalState2 = result.data.items;    // Principal state 2
        this.principalState3 = result.data.principalState3;               // Principal state 3
    }
}
```

## Examples

| Principal State | Loaded by | CRUD Operations |
|---|---|---|
| `principalState1[]` | `loadWorkspaceData()` | Create bucket, read bucket, update bucket, delete bucket |
| `principalState2[]` | `loadWorkspaceData()` | Create item, read item, update item, delete item |
| `principalState3[]` | `loadWorkspaceData()` (if included) | Create topic, read topic, update topic, delete topic |

## When to Create a New Principal State

A new feature is principal data when:

1. **It's loaded directly from the server** (not derived from existing data)
2. **It supports full CRUD** (or a subset thereof)
3. **It's not a picklist** (Case 1: always separate, small, static)
4. **It's not a server indicator** (Case 2: pagination/sync metadata)

```javascript
// ✅ If the feature loads principalState1 at init time:
async connectedCallback() {
    const result = await loadPrincipalState1({ workspaceId: this.workspaceId });
    this.principalState1 = result.data;  // New principal state
}

// ✅ If the user can create, update, delete principalState1:
handleCreateBucket(event) {
    const newBucket = { name: event.detail.name, ... };
    createBucket(newBucket)
        .then(res => {
            this.principalState1 = [...this.principalState1, res.data];  // Update principal state
        });
}
```

## Be Careful: Child Component Principal State

A child component may load the same entity type as its parent (e.g., bucket items), but if it's **loaded in isolation within a child flow**, it has its own principal state tracking:

```javascript
// Parent holds principalState1 with nested items:
// this.principalState1[0] = { id: 'bucket-1', items: [...] }

// Child loads the same bucket's items in isolation:
@track subDataOfPrincipalState1 = [];  // Child's separate principal state
@track principalState2 = []; // It can be also like this 
@track buckeItems = []; //working example

connectedCallback() {
    loadBucketItems({ bucketId: this.bucketId })
        .then(res => {
            this.bucketItems = res.data;  // Child's own principal state
        });
}

// IMPORTANT: Parent's principalState1[0].items ≠ Child's bucketItems
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
            this.principalState2 = this.principalState2.map(t =>
                t.id === res.data.id ? res.data : t
            );
        })
        .catch(err => {
            this._toast('Error', err.body?.message || err.message, 'error');
            // Principal state NOT updated on error
        });
}
```