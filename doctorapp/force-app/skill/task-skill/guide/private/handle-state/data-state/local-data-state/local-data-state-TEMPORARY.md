<!-- merged from: local-data-state.md (embedded in local-data-state-merge.py) -->

# LWC Data State — Three Cases

Data in your LWC falls into exactly **three categories**. Each has its own rules for how to structure and organize it. Pick the right category for each piece of data and follow its pattern.

## The Three Cases at a Glance

| Case | Name | What It Is | Example |
|------|------|-----------|---------|
| **1** | Picklist & Static Options | Reference data that rarely changes | Status choices, team member list, item type options |
| **2** | Server Indicators | Pagination and sync metadata | `hasMore`, `offset`, `isStale` |
| **3** | Principal Data | Server-backed entities with CRUD | Items, buckets, topics |

---

## Entry Point: What Kind of Data Are You Adding?

Start with this question: **Is this data loaded from the server, or is it a reference?**

1. **Is it a picklist, dropdown list, or static reference set?**
   → **[READ Case 1: Picklist & Static Options](#case-1-picklist--static-options)**

2. **Is it pagination info, sync metadata, or a flag that describes other data? (!! Server indicators live near their data, not mixed with picklists or communication state.)**
   → **[READ Case 2: Server Indicators](#case-2-server-indicators)**

3. **Is it an entity (like an item or bucket) that your component loads and can modify?**
   → **[READ Case 3: Principal Data](#case-3-principal-data)**

---

## Case 1: Picklist & Static Options

**READ WHEN:** Creating or editing any LWC component that uses picklists, dropdowns, comboboxes, or option sets.

**Key Rule:** Picklist options are **always isolated** in their own tracked fields. Never merge them with principal data or server indicators.

[→ Read full guide: Picklist & Static Options](#picklist--static-options--case-1-data-state)

---

## Case 2: Server Indicators

**READ WHEN:** Loading paginated or server-returning data with status flags, `hasMore`, offsets, or other metadata from the backend.

**Key Rule:** Server indicators **always live near their data**, not isolated or mixed with picklists.

[→ Read full guide: Server Indicators](#server-indicators--case-2-data-state)

---

## Case 3: Principal Data

**READ WHEN:** Loading server data into an LWC component — determining whether data is principal state or derived.

**Key Rule:** Each entity type loaded by the principal method is a principal state with full CRUD operations available on the frontend.

[→ Read full guide: Principal Data State](#principal-data-state--case-3-data-state)

---

## Also In This Document

- **[Derived / Computed State](#derived--computed-state-guide)** — read-only getters computed from principal state; never a parallel tracked field.
- **[LWC State Management Checklist](#lwc-state-management-checklist)** — walk it before presenting generated code.

---

<!-- merged from: picklist-static-options-guide.md -->

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

}
```

## Rule

**Keep in separate tracked fields. Never merge with principal data or server indicators.**

Derived state (getters) can reference picklists for lookups:

<!-- merged from: server-indicators-guide.md -->

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

<!-- merged from: principal-data-state-guide.md -->

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

<!-- merged from: derived-state.md -->

# Derived / Computed State Guide

Derived state (computed getters) are **read-only calculations** derived from **principal state** and **localStorage**. They are never tracked fields — they are always getters that compute on read.

**Key Rule:** All derived state depends on principal state or localStorage. Never create a parallel tracked field kept in sync by hand.

---

## Pattern: Getters Over Tracked Fields

❌ **WRONG:**
```javascript
@track hasprincipalState1 = false;  // Parallel state kept manually in sync

handleLoadPrincipal() {
    this.principalState1 = result.data;
    this.principalState1 = result.data.length > 0;  // Manual sync — breaks when state changes elsewhere
}
```

✅ **CORRECT:**
```javascript
// Getter — computed on read, always in sync
get hasprincipalState1() {
    return this.principalState1.length > 0;
}
```

---

## Example 1: principalState1 Principal State

**Principal State Definition:**
- Loaded at component init via `loadWorkspaceData()`
- Supports full CRUD (create, read, update, delete items)
- Server-backed with pagination metadata

**Associated Derived State:**

```javascript
export default class ManageItems extends LightningElement {
    // Principal state 1: principalState1 principalState1
    @track principalState1 = [];
    @track principaleOffset = 0;
    @track principalHasMore = false;

    // --- Derived State: Getters computed from principal state ---

    // Existence check
    get hasPrincipalState1() {
        return this.principalState1.length > 0;
    }

    // Pagination state checks
    get principalIsFirstPage() {
        return this.principaleOffset === 0;
    }

    get principalIsLastPage() {
        return !this.principalHasMore;
    }

    // Pagination offset → page number (e.g., offset 20, pageSize 10 = page 3)
    get principalCurrentPage() {
        const pageSize = 10; // From your config
        return Math.floor(this.principaleOffset / pageSize) + 1;
    }

    // Pagination label (e.g., "Showing 1–10 of 47 items" or "No items")
    get principaleOffsetLabel() {
        if (!this.hasPrincipalState1) {
            return 'No items';
        }
        const start = this.principaleOffset + 1;
        const end = this.principaleOffset + this.principalState1.length;
        const total = this.principalHasMore ? '?' : (this.principaleOffset + this.principalState1.length);
        return `Showing ${start}–${end} ${total > 0 ? `of ${total} items` : ''}`;
    }

    // Responsive card variant (e.g., desktop vs mobile layout)
    get itemVariant() {
        return this._isSmallScreen ? 'bare' : 'bordered';
    }
}
```

**In Template:**
```html
<!-- Existence checks -->
<template if:false={hasPrincipalState1}>
    <p class="slds-text-body_regular">No principal items yet.</p>
</template>

<!-- Pagination label -->
<div class="slds-text-body_small slds-text-color_weak">
    {principaleOffsetLabel}
</div>

<!-- Pagination controls -->
<c-ao-button
    label="Previous"
    disabled={principalIsFirstPage}
    onclick={handlePrevious}></c-ao-button>

<c-ao-button
    label="Next"
    disabled={principalIsLastPage}
    onclick={handleNext}></c-ao-button>

<!-- Responsive rendering -->
<c-ao-item-card
    item={item}
    variant={itemVariant}></c-ao-item-card>
```

---

## Example 2: buckets Principal State

**Principal State Definition:**
- Loaded at component init via `loadWorkspaceData()`
- Supports full CRUD (create, read, update, delete buckets)
- Each bucket contains pagination metadata

**Associated Derived State:**

```javascript
export default class ManageItems extends LightningElement {
    // Principal state 2: buckets
    @track buckets = [];

    // --- Derived State: Computed getters from principal state ---

    get hasBuckets() {
        return this.buckets.length > 0;
    }

    // Computed properties for each bucket (in a loop or template):
    getBucketChevronIcon(bucketId) {
        const bucket = this.buckets.find(s => s.id === bucketId);
        return bucket?.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    getBucketOffsetLabel(bucket) {
        if (!bucket.items || bucket.items.length === 0) {
            return 'No items';
        }
        const start = bucket.offset + 1;
        const end = bucket.offset + bucket.items.length;
        const total = bucket.hasMore ? '?' : bucket.items.length;
        return `Showing ${start}–${end} ${total > 0 ? `of ${total}` : ''}`;
    }

    getBucketIsFirstPage(bucket) {
        return bucket.offset === 0;
    }

    getBucketIsLastPage(bucket) {
        return !bucket.hasMore;
    }
}
```

**In Template:**
```html
<!-- Bucket existence check -->
<template if:false={hasBuckets}>
    <div class="slds-box slds-m-top_large">
        <p>No buckets created yet.</p>
    </div>
</template>

<!-- Bucket iteration with computed properties -->
<template for:each={buckets} for:item="bucket">
    <div key={bucket.id}>
        <!-- Chevron icon for expand/collapse -->
        <lightning-icon 
            icon-name={getBucketChevronIcon(bucket.id)}
            size="small">
        </lightning-icon>
        
        <!-- Bucket name -->
        <span class="slds-text-heading_small">{bucket.name}</span>

        <!-- Bucket items iteration -->
        <template for:each={bucket.items} for:item="item">
            <div key={item.id}>
                <!-- Item title -->
                <span class="slds-text-heading_small">{item.title}</span>
            </div>
        </template>

        <!-- Pagination label for this bucket -->
        <div class="slds-text-body_small slds-text-color_weak">
            {getBucketOffsetLabel(bucket)}
        </div>
    </div>
</template>
```

---

## Key Observations

1. **Getters are always safe** — They compute on every read from current principal state. No manual sync needed.

2. **Pagination label is complex derived state** — It reads `offset`, `hasMore`, and item count, then formats a user-friendly string. Computed at render time.

3. **No @track for computed values** — Computed getters are always on-demand; they're never stored in `@track` fields.

---

## Dependency Graph: principalState1 Example

```
┌─────────────────────────────────────┐
│ Principal State: principalState1[]   │  ← Loaded from server, CRUD operations
│ principaleOffset, principalHasMore       │
└─────────────────────────────────────┘
              ↓ (read by)
┌─────────────────────────────────────┐
│ Derived State (Getters)             │  ← Computed on read
│ hasPrincipalState1()                 │
│ principalIsFirstPage()                │
│ principalIsLastPage()                 │
│ principalCurrentPage()                │
│ principaleOffsetLabel()                │
└─────────────────────────────────────┘
              ↓ (used by)
┌─────────────────────────────────────┐
│ Template Rendering                  │  ← Uses getters for conditional/text
│ if:false={hasPrincipalState1}        │
│ {principaleOffsetLabel}                │
│ disabled={principalIsFirstPage}       │
└─────────────────────────────────────┘
```

---

## Dependency Graph: buckets Example

```
┌─────────────────────────────────────┐
│ Principal State: buckets[]          │  ← Loaded from server, CRUD operations
└─────────────────────────────────────┘
              ↓ (read by)
┌─────────────────────────────────────┐
│ Derived State (Getters)             │  ← Computed on read
│ hasBuckets()                        │
│ getBucketChevronIcon(bucketId)      │
│ getBucketOffsetLabel(bucket)        │
│ getBucketIsFirstPage(bucket)        │
│ getBucketIsLastPage(bucket)         │
└─────────────────────────────────────┘
              ↓ (used by)
┌─────────────────────────────────────┐
│ Template Rendering                  │  ← Uses getters for conditional/text
│ if:false={hasBuckets}               │
│ {getBucketChevronIcon(bucket.id)}   │
│ {getBucketOffsetLabel(bucket)}      │
└─────────────────────────────────────┘
```
