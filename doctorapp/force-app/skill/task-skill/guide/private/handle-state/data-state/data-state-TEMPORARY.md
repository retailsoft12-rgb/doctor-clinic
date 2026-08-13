<!-- merged from: data-state.md (embedded in data-state-merge.py) -->

# Data State Guide

Data in your LWC component falls into distinct categories, each with its own storage, scope, and update rules. This guide directs you to the pattern that fits your data.

---

## The Data State Decision Tree

**Start here:** What kind of data are you adding or modifying?

### 1. **Is it shared application context (workspace ID, workflow ID, user theme)?**
   → **[READ: localStorage State Guide](#localstorage-state-guide)**
   **READ WHEN:** Setting up persistent cross-component state, restoring app context on component load, or sharing context across multiple pages.

### 2. **Is it a reference picklist, dropdown list, or static options (status choices, team members, item types)?**
   → **[READ: Case 1 — Picklist & Static Options](#picklist--static-options--case-1-data-state)**
   **READ WHEN:** Adding or managing dropdown options, select lists, combobox choices, or any reference data that rarely changes.

### 3. **Is it pagination metadata, sync flags, or server indicators (`hasMore`, `offset`, `isLoading`, `isStale`)?**
   → **[READ: Case 2 — Server Indicators](#server-indicators--case-2-data-state)**
   **READ WHEN:** Loading paginated or server-returning data, handling async operations, or managing metadata about principal data.

### 4. **Is it canonical data (items, buckets, topics) that your component loads from the server and supports CRUD on?**
   → **[READ: Case 3 — Principal Data](#principal-data-state--case-3-data-state)**
   **READ WHEN:** Loading server entities, managing full create/read/update/delete lifecycle, or determining if data is principal state or derived.

### 5. **Is it a computed value derived from principal state or localStorage (UI existence checks, pagination labels, lookup names)?**
   → **[READ: Derived / Computed State Guide](#derived--computed-state-guide)**
   **READ WHEN:** Building getters instead of tracked fields, computing visibility flags, formatting display values, or avoiding manual state sync.

Cases 2–4 are indexed together in **[LWC Data State — Three Cases](#lwc-data-state--three-cases)**, and the
**[LWC State Management Checklist](#lwc-state-management-checklist)** closes the document — walk it before presenting generated code.

---

<!-- merged from: local-data-state/local-data-state-TEMPORARY.md -->

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

2. **Is it pagination info, sync metadata, or a flag that describes other data?**
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
    // 1. REFERENCE DATA (picklists) — isolated
    @track statusOptions = [];
    @track memberOptions = [];

    // 2. PRINCIPAL DATA (server-backed)
    @track unassignedItems = [];
    @track buckets = [];

    // 3. SERVER INDICATORS — grouped with their data
    @track unassignedOffset = 0;      // Paired with unassignedItems
    @track unassignedHasMore = false; // Paired with unassignedItems

    // Note: Each bucket in buckets[] has its own offset/hasMore

    // 4. CONTROL STATE
    showBucketModal = false;

    // 5. COMMUNICATION STATE — never mixed with data
    isLoading = false;  // For async operations

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

    async loadBucketItems(bucketId) {
        const bucket = this.buckets.find(s => s.id === bucketId);
        if (!bucket) return;

        bucket.isLoadingItems = true;  // Communication flag (paired)
        try {
            const result = await loadBucketItems({ bucketId });
            bucket.items = result.data.items;
            bucket.offset = result.data.offset;  // Server indicator
            bucket.hasMore = result.data.hasMore; // Server indicator
        } catch (err) {
            this._toast('Error', err.message, 'error');
        } finally {
            bucket.isLoadingItems = false;  // Clear communication flag
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

<!-- merged from: derived-state.md -->

# Derived / Computed State Guide

Derived state (computed getters) are **read-only calculations** derived from **principal state** and **localStorage**. They are never tracked fields — they are always getters that compute on read.

**Key Rule:** All derived state depends on principal state or localStorage. Never create a parallel tracked field kept in sync by hand.

---

## Pattern: Getters Over Tracked Fields

❌ **WRONG:**
```javascript
@track hasUnassignedItems = false;  // Parallel state kept manually in sync

handleLoadUnassigned() {
    this.unassignedItems = result.data;
    this.hasUnassignedItems = result.data.length > 0;  // Manual sync — breaks when state changes elsewhere
}
```

✅ **CORRECT:**
```javascript
// Getter — computed on read, always in sync
get hasUnassignedItems() {
    return this.unassignedItems.length > 0;
}
```

---

## Example 1: unassignedItems Principal State

**Principal State Definition:**
- Loaded at component init via `loadWorkspaceData()`
- Supports full CRUD (create, read, update, delete items)
- Server-backed with pagination metadata

**Associated Derived State:**

```javascript
export default class ManageItems extends LightningElement {
    // Principal state 1: unassignedItems
    @track unassignedItems = [];
    @track unassignedOffset = 0;
    @track unassignedHasMore = false;
    @track unassignedIsLoading = false;

    // --- Derived State: Getters computed from principal state ---

    // Existence check
    get hasUnassignedItems() {
        return this.unassignedItems.length > 0;
    }

    // Pagination state checks
    get unassignedIsFirstPage() {
        return this.unassignedOffset === 0;
    }

    get unassignedIsLastPage() {
        return !this.unassignedHasMore;
    }

    // Pagination offset → page number (e.g., offset 20, pageSize 10 = page 3)
    get unassignedCurrentPage() {
        const pageSize = 10; // From your config
        return Math.floor(this.unassignedOffset / pageSize) + 1;
    }

    // Pagination label (e.g., "Showing 1–10 of 47 items" or "No items")
    get unassignedOffsetLabel() {
        if (!this.hasUnassignedItems) {
            return 'No items';
        }
        const start = this.unassignedOffset + 1;
        const end = this.unassignedOffset + this.unassignedItems.length;
        const total = this.unassignedHasMore ? '?' : (this.unassignedOffset + this.unassignedItems.length);
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
<template if:false={hasUnassignedItems}>
    <p class="slds-text-body_regular">No unassigned items yet.</p>
</template>

<!-- Pagination label -->
<div class="slds-text-body_small slds-text-color_weak">
    {unassignedOffsetLabel}
</div>

<!-- Pagination controls -->
<c-ao-button
    label="Previous"
    disabled={unassignedIsFirstPage}
    onclick={handlePrevious}></c-ao-button>

<c-ao-button
    label="Next"
    disabled={unassignedIsLastPage}
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

## Dependency Graph: unassignedItems Example

```
┌─────────────────────────────────────┐
│ Principal State: unassignedItems[]   │  ← Loaded from server, CRUD operations
│ unassignedOffset, unassignedHasMore       │
└─────────────────────────────────────┘
              ↓ (read by)
┌─────────────────────────────────────┐
│ Derived State (Getters)             │  ← Computed on read
│ hasUnassignedItems()                 │
│ unassignedIsFirstPage()                │
│ unassignedIsLastPage()                 │
│ unassignedCurrentPage()                │
│ unassignedOffsetLabel()                │
└─────────────────────────────────────┘
              ↓ (used by)
┌─────────────────────────────────────┐
│ Template Rendering                  │  ← Uses getters for conditional/text
│ if:false={hasUnassignedItems}        │
│ {unassignedOffsetLabel}                │
│ disabled={unassignedIsFirstPage}       │
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

<!-- merged from: pather-lwc-state-management-checklist-guide.md -->

# LWC State Management Checklist

Before presenting the generated code, walk the checklist. If any row fails, fix
it before emitting code. 

**Prerequisites:** Read [Principal Data State](#principal-data-state--case-3-data-state) for entity separation rules, and [Derived State](#derived--computed-state-guide) for getter patterns.

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

<!-- merged from: local-storage-state/local-storage-state.md -->

# localStorage State Guide

Shared app data persisted across the full application and accessible by any component.

## When to Use localStorage

Use `localStorage` for data that:
- Must be accessible **across multiple components** and different pages
- Should persist across browser refreshes or component remounts
- Represents **shared application context** (current workspace, workflow, user, theme)
- Is rarely mutated (set once per navigation or user action)

**Examples:**
- `workspaceId` — currently selected workspace (shared across all components)
- `workflowId` — currently selected workflow
- `userId` — authenticated user ID
- `theme` — user's theme preference (light/dark)

**DO NOT use localStorage for:**
- Temporary UI state (modal visibility, selection state) — use component tracked properties
- Data that needs real-time sync — use principal/derived state with server updates
- Sensitive data (tokens, passwords) — never store in localStorage

---

## Storage Pattern

### Write to localStorage

```javascript
// Store shared context on workspace selection
handleWorkspaceSelected(workspaceId) {
  localStorage.setItem('jiraClone_workspaceId', workspaceId);
  // Notify other components or trigger re-render
}

// Store workflow selection
handleWorkflowSelected(workflowId) {
  localStorage.setItem('jiraClone_workflowId', workflowId);
}

// Store user theme preference
handleThemeChange(theme) {
  localStorage.setItem('jiraClone_theme', theme);
}
```

### Read from localStorage

```javascript
// Retrieve shared context
const workspaceId = localStorage.getItem('jiraClone_workspaceId');
const workflowId = localStorage.getItem('jiraClone_workflowId');
const theme = localStorage.getItem('jiraClone_theme') || 'light';
```

### Sync on Component Load

The most important pattern: **sync localStorage on `connectedCallback()`** to restore shared context when a component initializes.

```javascript
connectedCallback() {
  // Restore shared context from localStorage
  const workspaceId = localStorage.getItem('jiraClone_workspaceId');
  const workflowId = localStorage.getItem('jiraClone_workflowId');
  
  // Only load if both required contexts exist
  if (workspaceId && workflowId) {
    this.loadWorkspace(workspaceId);
    this.loadWorkflow(workflowId);
  } else {
    // Show workspace/workflow selector if context missing
    this._showChooseWorkspace = true;
  }
}
```

---

## Key Rules

1. **Use a consistent prefix** — all localStorage keys should start with `jiraClone_` to avoid conflicts:
   - ✅ `jiraClone_workspaceId`
   - ✅ `jiraClone_workflowId`
   - ✅ `jiraClone_theme`
   - ❌ `workspaceId` (conflicts with other apps)

2. **Handle missing keys gracefully** — always provide defaults:
   ```javascript
   const theme = localStorage.getItem('jiraClone_theme') || 'light';
   const workspaceId = localStorage.getItem('jiraClone_workspaceId');
   if (!workspaceId) {
     // Show context selector, don't crash
     this._showChooseWorkspace = true;
   }
   ```

3. **Restore on every component load** — call `connectedCallback()` to re-establish shared context:
   ```javascript
   connectedCallback() {
     this.restoreSharedContext();
   }
   
   restoreSharedContext() {
     this.workspaceId = localStorage.getItem('jiraClone_workspaceId');
     this.workflowId = localStorage.getItem('jiraClone_workflowId');
   }
   ```

4. **Sync on user actions** — update localStorage whenever shared context changes:
   ```javascript
   handleWorkspaceChange(newWorkspaceId) {
     // 1. Update localStorage immediately
     localStorage.setItem('jiraClone_workspaceId', newWorkspaceId);
     // 2. Optionally notify other components via event or state reload
   }
   ```

5. **Never mix localStorage with transient state** — keep these separate:
   - localStorage = `workspaceId`, `workflowId`, `userId`, `theme` (persistent)
   - Component state = modal visibility, selection state, form input (transient)

---

## Common Patterns

### Pattern 1: Navigation Flow with localStorage Sync

```javascript
// Parent component chooses workspace
handleWorkspaceSelection(workspaceId) {
  localStorage.setItem('jiraClone_workspaceId', workspaceId);
  // Navigate or re-render child components
  this._showChooseWorkspace = false;
}

// Child component restores on load
connectedCallback() {
  const workspaceId = localStorage.getItem('jiraClone_workspaceId');
  if (workspaceId) {
    this.loadWorkspace(workspaceId);
  }
}
```

### Pattern 2: Multi-Step Workflow Context

```javascript
// Step 1: Choose workspace
localStorage.setItem('jiraClone_workspaceId', workspaceId);

// Step 2: Choose workflow
localStorage.setItem('jiraClone_workflowId', workflowId);

// Step 3: Child component loads both
connectedCallback() {
  const workspaceId = localStorage.getItem('jiraClone_workspaceId');
  const workflowId = localStorage.getItem('jiraClone_workflowId');
  
  if (workspaceId && workflowId) {
    this.loadVisualizerData(workspaceId, workflowId);
  }
}
```

### Pattern 3: Theme/Preference Persistence

```javascript
// User selects theme
handleThemeChange(newTheme) {
  localStorage.setItem('jiraClone_theme', newTheme);
  this.applyTheme(newTheme);
  // Notify other components (optional via event bus or reload)
}

// Component initializes with user's theme
connectedCallback() {
  const theme = localStorage.getItem('jiraClone_theme') || 'light';
  this.applyTheme(theme);
}
```

---

## Relationship to Other State Types

| State Type | Storage | Scope | Example |
|-----------|---------|-------|---------|
| **localStorage** | Browser storage | App-wide (all components) | `workspaceId`, `workflowId`, `userId` |
| **Principal state** | Component tracked | Single component + children | `buckets[]`, `unassignedItems[]` |
| **Derived state** | Getters (computed) | Computed on-read | `hasBuckets()`, `activeBucketViewModel()` |
| **Control state** | Component tracked | Single component UI | `showBucketModal`, `isExpanded` |
| **Form state** | Component tracked | Form input buffer | `bucketForm`, `itemViewSearchTerm` |

**Key difference:** localStorage is the ONLY persistent shared context across the entire app. Principal state lives in a single component. If you need to share principal state between components, store the shared **reference data only** in localStorage (like `workspaceId`), and let each component load its own principal state.

---

## Testing localStorage State

```javascript
// Unit test: verify localStorage is set on user action
test('should store workspaceId in localStorage on selection', () => {
  const component = createElement('c-workspace-selector', { is: WorkspaceSelector });
  document.body.appendChild(component);
  
  component.handleWorkspaceSelected('proj-123');
  
  expect(localStorage.getItem('jiraClone_workspaceId')).toBe('proj-123');
});

// Unit test: verify component restores from localStorage
test('should restore workspaceId from localStorage on load', () => {
  localStorage.setItem('jiraClone_workspaceId', 'proj-456');
  
  const component = createElement('c-workspace-viewer', { is: WorkspaceViewer });
  document.body.appendChild(component);
  
  expect(component.workspaceId).toBe('proj-456');
});

// Unit test: verify graceful fallback when localStorage is empty
test('should show workspace selector when localStorage is empty', () => {
  localStorage.clear();
  
  const component = createElement('c-unassigned-view', { is: UnassignedView });
  document.body.appendChild(component);
  
  expect(component._showChooseWorkspace).toBe(true);
});
```

---

## Related Guides

- [principal-data-state-guide](#principal-data-state--case-3-data-state) — Single component's canonical data (buckets, items)
- [server-indicators-guide](#server-indicators--case-2-data-state) — Pagination and async flags grouped with data
- [picklist-static-options-guide](#picklist--static-options--case-1-data-state) — Reference data (options, picklists) never merged with others
- [derived-state](#derived--computed-state-guide) — Computed getters derived from principal state and localStorage
