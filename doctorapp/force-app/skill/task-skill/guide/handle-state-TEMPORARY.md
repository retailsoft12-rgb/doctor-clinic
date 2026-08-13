<!-- merged from: handle-state.md (embedded in handle-state-merge.py) -->

# LWC State Management Guide

Four categories of LWC state, each with its own storage, scope, and update rules. Use this index to find the guide that matches your situation.

---

## 📊 [Data State Guide](#data-state-guide)

**READ when:**
- You're deciding what kind of data to store (shared app context, picklists, principal data, derived values)
- Adding or modifying component data that comes from the server or localStorage
- Determining whether data should be stored in multiple places or computed on the fly
- Working with pagination metadata or server-side sync flags

**Contains:** Decision tree for picklists vs server indicators vs principal data, localStorage patterns for shared context, and detailed implementation guides for each data type.

---

## 🎛️ [Control State Guide](#lwc-control-state)

**READ when:**
- Implementing modal or drawer visibility logic
- Building drag-and-drop functionality with drop zones
- Managing UI surface visibility (panels, accordions, confirmations)
- Wiring up visual feedback for user interactions

**Contains:** Patterns for modal open/close, drag-and-drop state tracking with visual feedback, rules for clearing state after interactions, and computed getters for CSS classes.

---

## ⚡ [Communication State Guide](#lwc-communication-state)

**READ when:**
- Wiring spinners or loading indicators for Apex calls
- Handling errors from backend operations and displaying them to users
- Implementing success/failure feedback (toasts, error messages)
- Managing async operation state (in-flight, success, failure)

**Contains:** Patterns for loading spinners tied to imperative calls, error handling with ShowToastEvent, and how to structure the round-trip lifecycle from user action to backend sync.

---

## 👆 [Interaction State Guide](#interaction-state-management-guide)

**READ when:**
- Implementing drag-and-drop interaction (drag sources, targets, visual feedback)
- Building expandable/collapsible sections or accordions
- Tracking what's selected, hovered, or expanded in the UI
- Managing ephemeral transient UI state that doesn't persist

**Contains:** Drag-and-drop patterns and expanded/collapsed state management, with lifecycle rules for clearing state after interactions complete.

---

<!-- merged from: data-state/data-state-TEMPORARY.md -->

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

<!-- merged from: control-state/control-state.md -->

# LWC Control State

Control state manages the visibility of UI surfaces — modals, drawers, panels, drop zones — and interaction toggles. Two common scenarios:

---

## Example 1: Modal Visibility Control

Modal or drawer visibility is a single tracked boolean that flips when the user opens or closes it.

**JavaScript:**

```javascript
@track showBucketModal = false;
@track _showChooseWorkspace = false;

handleOpenBucketModal() {
    this.showBucketModal = true;
}

handleCloseBucketModal() {
    this.showBucketModal = false;
}

// Create item and auto-close on success
handleBucketItemCreate(event) {
    const data = event.detail;
    this.isLoading = true;
    createItemFromBucket(data)
        .then(res => {
            if (!res.success) throw new Error(res.message);
            this._enrichBucketWithAddedItem(res.data.updatedBucket, res.data.createdItem);
            this.showBucketModal = false; // ← auto-close
            this._showSuccess('Item added to bucket');
        })
        .catch(err => this._showError(err.body?.message || err.message))
        .finally(() => { this.isLoading = false; });
}
```

**HTML:**

```html
<template if:true={showBucketModal}>
    <c-ao-modal 
        header="Add Item to Bucket"
        onclose={handleCloseBucketModal}>
        <c-bucket-item-form 
            bucket-id={_activeBucketId}
            onsubmit={handleBucketItemCreate}>
        </c-bucket-item-form>
    </c-ao-modal>
</template>
```

**Rules:**
- One boolean per modal — never multiplex multiple modals onto one flag
- Named after the surface: `showBucketModal`, `_showChooseWorkspace` (not `modal1`, `isOpen`)
- Flip from handlers only — never from Apex results or computed logic
- Close on action success (auto-close) or user dismissal

---

## Example 2: Drag-and-Drop Zone Visibility

Drop zones and target indicators use multiple flags to track what's being dragged and where it can land.

**JavaScript:**

```javascript
@track _dragSourceItemId = null;
@track _dragSourceBucketId = null;
@track _activeDropItemId = null;
@track _activeDropTopZone = null;

handleItemDragStart(event) {
    const { itemId, bucketId } = event.detail;
    this._dragSourceItemId = itemId;
    this._dragSourceBucketId = bucketId || 'unassigned';
}

handleDragOver(event) {
    event.preventDefault();
    const { targetItemId, targetBucketId, isTopZone } = event.detail;
    
    if (isTopZone) {
        this._activeDropTopZone = targetBucketId || 'unassigned';
        this._activeDropItemId = null;
    } else {
        this._activeDropItemId = targetItemId;
        this._activeDropTopZone = null;
    }
}

handleDrop(event) {
    event.preventDefault();
    const { targetBucketId, targetItemId } = event.detail;
    
    this.isLoading = true;
    moveItem({
        itemId: this._dragSourceItemId,
        fromBucketId: this._dragSourceBucketId,
        toBucketId: targetBucketId,
        afterItemId: targetItemId
    })
        .then(res => {
            if (!res.success) throw new Error(res.message);
            this._updateBucketAfterMove(res.data);
            this._showSuccess('Item moved');
        })
        .catch(err => this._showError(err.body?.message || err.message))
        .finally(() => {
            // Clear ALL drag state regardless of success/failure
            this._dragSourceItemId = null;
            this._dragSourceBucketId = null;
            this._activeDropItemId = null;
            this._activeDropTopZone = null;
            this.isLoading = false;
        });
}

// Computed getters for CSS
get dropIndicatorClass() {
    return this._activeDropItemId ? 'drop-indicator--active' : '';
}

get topDropZoneClass() {
    return this._activeDropTopZone ? 'drop-zone--active' : '';
}
```

**HTML:**

```html
<!-- Unassigned top drop zone -->
<template if:true={_showUnassignedTopDropZone}>
    <div class={topDropZoneClass} 
         ondragover={handleDragOver}
         ondrop={handleDropAtUnassignedTop}
         ondragleave={handleDragEnd}>
        Drop to add to the unassigned list
    </div>
</template>

<!-- Item rows with drop indicator -->
<template for:each={unassignedItems} for:item="item">
    <div key={item.id} class={dropIndicatorClass}>
        <c-item-item
            item={item}
            ondragstart={handleItemDragStart}
            ondragover={handleDragOver}
            ondrop={handleDrop}
            ondragend={handleDragEnd}>
        </c-item-item>
    </div>
</template>
```

**Rules:**
- Separate flags for source (what's dragged), target (where it goes), and visual feedback
- Clear ALL drag state in the `.finally()` block — dragend always fires, even if drop fails
- Update target position on every `dragover` for real-time feedback
- Derive CSS classes from flags via getters — don't store class strings

---

## Control State Summary

| Scenario | Pattern | Example |
|----------|---------|---------|
| Modal/drawer open/close | Single `@track boolean`, flip from handlers | `showBucketModal`, `_showChooseWorkspace` |
| Drag-and-drop feedback | Multiple flags for source + target + visual, clear on dragend | `_dragSourceItemId`, `_activeDropItemId`, `dropIndicatorClass` |

---

## Anti-patterns to refuse

| Anti-pattern | Fix |
|---|---|
| Storing form data in the same field as modal visibility | Separate fields: `showBucketModal` (boolean) + `bucketForm` (data) |
| Multiple modals sharing one boolean | One flag per modal |
| Not clearing drag state after drop succeeds or fails | Always clear in `.finally()` after moveItem resolves |
| Computing modal visibility from data (`get showModal() { return this.data.length > 0 }`) | Visibility is user-driven; use separate selection state if showing context |
| Storing CSS class strings instead of deriving them | Compute via getters from boolean flags |

<!-- merged from: communication-state/communication-state-TEMPORARY.md -->

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

Call `this._toast('Error', message, 'error')` from:
- `.catch(err => ...)` of an imperative Apex call
- The `result.error` / `result.data.success === false` branches of a `@wire` callback
- Synchronous validation failures before any Apex is dispatched

---

## Worked example (from this session — `chooseWorkspace`)

The first draft of `chooseWorkspace.js` held an `@track _errorMessage` and an
inline `.splash__error` banner with a Dismiss button. The corrected version
removes that state entirely and routes every failure through a toast.

**Before** — tracked field + inline banner + dismiss handler:

```js
@track _errorMessage = null;

@wire(loadAllWorkspaces)
wiredLoadAllWorkspaces(result) {
    if (result.data) {
        if (result.data.success) {
            this._workspaces     = result.data.data || [];
            this._errorMessage = null;
        } else {
            this._errorMessage = result.data.message || 'Failed to load workspaces';
        }
    } else if (result.error) {
        this._errorMessage = result.error.body?.message || 'Error loading workspaces';
    }
}

handleCreate() {
    const name = (this._newWorkspaceName || '').trim();
    if (!name) {
        this._errorMessage = 'Workspace name is required';
        return;
    }
    this._errorMessage = null;
    createWorkspace({ name })
        .then(...)
        .catch(err => {
            this._errorMessage = err.body?.message || err.message || 'Error creating workspace';
        });
}

handleDismissError() { this._errorMessage = null; }
```

```html
<template if:true={errorMessage}>
    <div class="splash__error" role="alert">
        <span>{errorMessage}</span>
        <button onclick={handleDismissError}>Dismiss</button>
    </div>
</template>
```

**After** — toast only, no error state on the component:

```js
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

@wire(loadAllWorkspaces)
wiredLoadAllWorkspaces(result) {
    if (result.data) {
        if (result.data.success) {
            this._workspaces = result.data.data || [];
        } else {
            this._toast('Error', result.data.message || 'Failed to load workspaces', 'error');
        }
    } else if (result.error) {
        this._toast('Error', result.error.body?.message || 'Error loading workspaces', 'error');
    }
}

handleCreate() {
    const name = (this._newWorkspaceName || '').trim();
    if (!name) {
        this._toast('Error', 'Workspace name is required', 'error');
        return;
    }
    createWorkspace({ name })
        .then(...)
        .catch(err => {
            this._toast('Error', err.body?.message || err.message || 'Error creating workspace', 'error');
        });
}

_toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}
```

The `_errorMessage` field, the `errorMessage` getter, the dismiss handler,
and the entire `.splash__error` markup block are deleted — the toast carries
the message and dismisses itself.

---

## Anti-patterns to refuse

| Anti-pattern | Fix |
|---|---|
| Adding a new `@track errorMessage = null` to a new LWC | Dispatch `ShowToastEvent` from the `.catch` / wire-error branch instead |
| Inline `<div class="error-box">{errorMessage}</div>` + Dismiss button on a NEW component | Remove the banner; rely on the toast |
| Setting `errorMessage` from one handler and `_errorMessage` from another in the same file | Pick one channel (toast) — never split error state across two fields |
| Surfacing the failure ONLY by logging to the console | The user must see it; dispatch a toast |

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

### Step 3 — Patch the JS handler

Apply this exact shape to the handler body:

```js
handleSomething(event) {
    const data = event.detail;
    this.isLoading = true;                       // ← added
    apexMethod({ ...data })
        .then(res => {
            if (!res.success) throw new Error(res.message || 'Error ...');
            // ... happy path: update state, close modal, toast
        })
        .catch(err => this._showError(err.body?.message || err.message || 'Error ...'))
        .finally(() => { this.isLoading = false; }); // ← added
}
```

Rules:

- The `isLoading = true` assignment goes **after** any cheap synchronous
  validation that might `return` early. Don't flip the spinner on if the
  function is about to bail out without ever calling Apex.
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
    this._linkedToTargetItemId = event.detail.itemId; // ← triggers the wire
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
        this._topicsTargetWorkspaceId = workspaceId;   // still switch the view (cache-served)
        return;                                    // leave isLoading untouched
    }
    this.isLoading = true;                         // genuine cache miss → real fetch
    this._fetchedWorkspaceIds.add(workspaceId);
    this._topicsTargetWorkspaceId = workspaceId;
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

### Step 6 — Spot-check sibling handlers (optional cleanup)

After the new handler is wired, scan the same JS file for OTHER imperative
Apex handlers that are missing the same `isLoading` / `.finally` pair. If
you find one or two trivial omissions, mention them to the user as a
suggested follow-up — do NOT silently fix them all in the same edit, since
the user only asked about the one handler. The goal is to surface the
inconsistency, not to balloon the diff.

---

## Anti-patterns to refuse

| Anti-pattern | Why it's wrong | Fix |
|--------------|----------------|-----|
| Setting `isLoading = false` in BOTH `.then` and `.catch` | `.finally` already covers both — duplicates drift apart when one is edited | Use `.finally` only |
| Putting `.finally` before `.catch` | A handler in `.then` that throws skips straight to `.catch`, and `.finally` only sees the post-catch state — order matters for readability and tooling | `.then` → `.catch` → `.finally` |
| Hand-rolling a `<lightning-spinner>` + `.loading-overlay` div | Re-implements what `c-ao-spinner overlay` already owns (backdrop + z-index), and a bare spinner inherits the parent stacking context, hiding behind modals | Use `<c-ao-spinner overlay>` at the root template |
| Nesting `<c-ao-spinner overlay>` inside a `position`/`z-index` section | Its fixed overlay is confined to that ancestor's stacking context and hides behind modals | Render it at the component's root `<template>` |
| New per-handler boolean (`isSavingComment`, `isDeletingThing`) | One spinner-driving flag per visual region is enough; per-handler flags multiply state | Reuse the existing `isLoading` (or the region-scoped flag) |
| Flipping `isLoading = true` BEFORE early-return validation | Spinner flashes and clears for actions that never hit the network | Do validation first, then flip the flag |
| Leaving a surface at `z-index >= 9999` in the same file | It fights `c-ao-spinner`'s overlay (fixed at `9999`) | Lower that surface to the conventional `9001` |
| Flipping `isLoading = true` before assigning a reactive `@wire` param without checking the value first | If the new value equals the current one the wire never refires and the spinner stays on forever; if it's a value already fetched, LDS serves it from cache and the spinner just flashes | Only flip on for a genuine cache **miss** (new, never-fetched value); leave `isLoading` untouched for same / already-fetched values |
| Calling `refreshApex` just to re-trigger the spinner on a same or already-cached value | `refreshApex` re-fetches from the server — it's for stale **backend** data, not for re-rendering UI you already hold; it hides the real toggle bug | Guard the assignment instead; reserve `refreshApex` for genuine server-side refreshes |

---

## Worked example (from this codebase)

`manageItems.handleBucketItemCreate` was added to dispatch
`createItemFromBucket` but did not toggle `isLoading`. Three coordinated
edits made it correct:

**JS** (`manageItems.js`):

```js
handleBucketItemCreate(event) {
    const data = event.detail;
    this.isLoading = true;
    createItemFromBucket(data)
        .then(res => {
            if (!res.success) throw new Error(res.message || 'Error creating item from bucket');
            const item        = formatItem(res.data.createdItem, this.itemTypeOptions, data.itemTypeId);
            const updatedBucket = formatBucket(res.data.updatedBucket);
            this._enrichBucketWithAddedItem(updatedBucket, item);
            this.showBucketItemModal = false;
            this._showSuccess('Item added to bucket');
        })
        .catch(err => this._showError(err.body?.message || err.message || 'Error creating item from bucket'))
        .finally(() => { this.isLoading = false; });
}
```

**HTML** (`manageItems.html`):

```html
<template if:true={isLoading}>
    <c-ao-spinner overlay size="medium" alternative-text="Loading..."></c-ao-spinner>
</template>
```

**CSS** (`manageItems.css`): nothing to add. `c-ao-spinner overlay` carries
its own fixed backdrop and `z-index: 9999` inside its shadow DOM. The modal
sits at `z-index: 9001`; the spinner's overlay at `9999` covers it.

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

<!-- merged from: interaction-state/interaction-state-TEMPORARY.md -->

<!-- merged from: interaction-state.md (embedded in interaction-state-merge.py) -->

# Interaction State Management Guide

Interaction state is **ephemeral, transient UI state** that reflects what the user is currently doing in the UI — dragging, hovering, expanding, selecting. It is **never persisted** and **never sent to the server**; it exists only for the current session's UX.

---

## 📋 Reference Guides

### [drag-drop-guide](#drag-and-drop-interaction-state-guide)
**Read when:** Implementing or editing drag-and-drop functionality in lists, the unassigned list, or buckets.

Covers:
- Drag source and target state variables
- Drop zone tracking and visual feedback
- Lifecycle: dragstart → dragover → drop → dragend
- Clearing state on interaction end

### [expanded-collapsed-guide](#expandedcollapsed-state-guide)
**Read when:** Implementing or editing accordion, collapsible section, or expandable container functionality.

Covers:
- Single expandable section (boolean)
- Multiple independent sections (Set-based)
- Mutually exclusive sections (one active at a time)
- Toggle patterns and computed getters

---

<!-- merged from: drag-drop-guide.md -->

# Drag-and-Drop Interaction State Guide

Drag-and-drop state manages what is being dragged, where it's coming from, and where it can be dropped.

## State Variables

All drag-and-drop variables are **private** and **transient**:

| Variable | Type | Purpose |
|----------|------|---------|
| `_dragSourceBucketId` | String/null | Which bucket the drag started from |
| `_dragSourceItemId` | String/null | Which item is being dragged |
| `_dragSourceContainer` | String/null | Container type: `'unassigned'` or bucketId |
| `_dragTargetBucketId` | String/null | Which bucket is currently under cursor |
| `_activeDropItemId` | String/null | Which item shows the drop indicator |
| `_activeDropTopZone` | String/null | Which container's top zone shows drop indicator |
| `_isUnassignedDragOver` | Boolean | Is mouse over unassigned drop target |

---

## Drag-and-Drop Lifecycle

### 1. Drag Starts (onDragStart)

Capture the drag source and mark what's being dragged:

```javascript
handleItemDragStart(event) {
  const itemId = event.currentTarget.dataset.itemId;
  const bucketId = event.currentTarget.dataset.bucketId; // null = unassigned
  
  // Set drag source
  this._dragSourceItemId = itemId;
  this._dragSourceBucketId = bucketId || null;
  this._dragSourceContainer = bucketId || 'unassigned';
  
  // Set drag image (optional)
  event.dataTransfer.effectAllowed = 'move';
}
```

### 2. Drag Over (onDragOver)

Track what's under the cursor; update drop indicators:

```javascript
handleDragOver(event) {
  event.preventDefault(); // Allow drop
  event.dataTransfer.dropEffect = 'move';
  
  // Identify drop target
  const dropZoneElement = event.target.closest('[data-drop-zone]');
  if (dropZoneElement) {
    const targetBucketId = dropZoneElement.dataset.bucketId || null;
    const isTopZone = dropZoneElement.dataset.isTopZone === 'true';
    
    if (isTopZone) {
      this._activeDropTopZone = targetBucketId || 'unassigned';
    } else {
      const itemId = dropZoneElement.dataset.itemId;
      this._activeDropItemId = itemId;
    }
    
    this._dragTargetBucketId = targetBucketId;
  }
}
```

### 3. Drag Leave (onDragLeave)

Clear drop indicators when mouse leaves a zone:

```javascript
handleDragLeave(event) {
  // Only clear if actually leaving the zone
  if (event.target === event.currentTarget) {
    this._activeDropItemId = null;
    this._activeDropTopZone = null;
  }
}
```

### 4. Drop (onDrop)

Execute the move operation; clear all drag state:

```javascript
async handleDrop(event) {
  event.preventDefault();
  
  const targetBucketId = event.currentTarget.dataset.bucketId || null;
  
  // Perform move
  await this.moveItem(
    this._dragSourceItemId,
    this._dragSourceContainer,
    targetBucketId
  );
  
  // Clear all drag state
  this.clearDragState();
}

clearDragState() {
  this._dragSourceItemId = null;
  this._dragSourceBucketId = null;
  this._dragSourceContainer = null;
  this._dragTargetBucketId = null;
  this._activeDropItemId = null;
  this._activeDropTopZone = null;
  this._isUnassignedDragOver = false;
}
```

### 5. Drag End (onDragEnd)

Ensure state is cleared regardless of drop success:

```javascript
handleDragEnd(event) {
  // Always clear state, even if drop failed
  this.clearDragState();
}
```

---

## Visual Feedback Getters

**Never read drag state directly in templates.** Always use getters to compute CSS classes:

```javascript
get dropIndicatorClass() {
  return this._activeDropItemId === this.itemId
    ? 'drop-indicator--active'
    : '';
}

get topDropZoneClass() {
  const isActive = this._activeDropTopZone === (this.bucketId || 'unassigned');
  return isActive ? 'top-drop-zone--active' : '';
}

get draggedItemClass() {
  return this._dragSourceItemId === this.itemId
    ? 'item--dragging'
    : '';
}
```

---

## Template Example

```html
<div class="bucket-container" 
     data-bucket-id={bucketId}
     data-drop-zone
     ondragover={handleDragOver}
     ondragleave={handleDragLeave}
     ondrop={handleDrop}
     ondragend={handleDragEnd}>
  
  <!-- Top drop zone -->
  <div class="top-drop-zone {topDropZoneClass}" 
       data-drop-zone
       data-bucket-id={bucketId}
       data-is-top-zone="true"></div>
  
  <!-- Items -->
  <template for:each={items} for:item="item">
    <div key={item.Id}
         class="item {draggedItemClass}"
         data-item-id={item.Id}
         data-bucket-id={bucketId}
         draggable="true"
         ondragstart={handleItemDragStart}>
      
      <!-- Drop indicator -->
      <div class="drop-indicator {dropIndicatorClass}"></div>
      
      {item.Name}
    </div>
  </template>
</div>
```

---

## CSS Example

```css
.item--dragging {
  opacity: 0.5;
  cursor: grabbing;
}

.top-drop-zone {
  height: 0;
  transition: height 0.2s;
}

.top-drop-zone--active {
  height: 8px;
  background: #0070D2;
  border-radius: 4px;
}

.drop-indicator {
  display: none;
  height: 2px;
  background: #0070D2;
}

.drop-indicator--active {
  display: block;
}
```

---

## Key Rules

1. **Clear state in all exit paths** — `handleDrop()`, `handleDragEnd()`, even in error cases
2. **Use dataset for drop zones** — Avoid parsing DOM; use `data-*` attributes
3. **Check target validity** — Before accepting a drop, verify the target bucket/unassigned exists
4. **No manual tracking** — Don't duplicate drag state in other variables
5. **Getters for rendering** — Templates never read `_dragSourceItemId` directly; only via computed getters

<!-- merged from: expanded-collapsed-guide.md -->

# Expanded/Collapsed State Guide

Expanded/collapsed state manages which accordion sections, detail panels, or collapsible containers are open or closed.

## State Variables

Expansion state can be tracked three ways depending on the component's scope:

### Single Expandable Section

For a single section that is either expanded or collapsed:

```javascript
isExpanded = false; // Accordion open/closed
```

### Multiple Independent Sections

For multiple sections where each can expand independently:

```javascript
_expandedSections = new Set(); // Set of section IDs that are expanded

// Add section
_expandedSections.add(sectionId);

// Remove section
_expandedSections.delete(sectionId);

// Check if expanded
isExpanded(sectionId) {
  return this._expandedSections.has(sectionId);
}
```

### One Active Section (Mutually Exclusive)

For tabs or radio-like accordions where only one can be active:

```javascript
_activeSectionId = null; // Which section is currently open (only one at a time)
```

---

## Single Expandable Section Pattern

### State

```javascript
@track
isExpanded = false;
```

### Toggle Method

```javascript
handleToggleExpand() {
  this.isExpanded = !this.isExpanded;
}
```

### Template

```html
<div class="bucket-accordion">
  <div class="accordion-header" onclick={handleToggleExpand}>
    <lightning-icon 
      icon-name={chevronIcon}
      alternative-text="Toggle"></lightning-icon>
    <span>{bucketName}</span>
  </div>
  
  <div class="accordion-content" lwc:if={isExpanded}>
    <!-- Content shown when expanded -->
    <div class="items-list">
      <template for:each={items} for:item="item">
        <c-item-item key={item.Id} item={item}></c-item-item>
      </template>
    </div>
  </div>
</div>
```

### Computed Chevron Icon

```javascript
get chevronIcon() {
  return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
}
```

---

## Multiple Independent Sections Pattern

### State

```javascript
_expandedSections = new Set();
```

### Toggle Method

```javascript
handleToggleSection(event) {
  const sectionId = event.currentTarget.dataset.sectionId;
  
  if (this._expandedSections.has(sectionId)) {
    this._expandedSections.delete(sectionId);
  } else {
    this._expandedSections.add(sectionId);
  }
  
  // Trigger reactivity (if needed)
  this.dispatchEvent(new CustomEvent('expandedchange', {
    detail: { expandedSections: Array.from(this._expandedSections) }
  }));
}
```

### Template

```html
<template for:each={sections} for:item="section">
  <div key={section.id} class="accordion-section">
    <div class="section-header" 
         data-section-id={section.id}
         onclick={handleToggleSection}>
      <lightning-icon 
        icon-name={getSectionChevron(section.id)}
        alternative-text="Toggle"></lightning-icon>
      <span>{section.label}</span>
    </div>
    
    <div class="section-content" lwc:if={isSectionExpanded(section.id)}>
      {section.content}
    </div>
  </div>
</template>
```

### Helper Methods

```javascript
getSectionChevron(sectionId) {
  return this._expandedSections.has(sectionId) 
    ? 'utility:chevrondown' 
    : 'utility:chevronright';
}

isSectionExpanded(sectionId) {
  return this._expandedSections.has(sectionId);
}
```

---

## Mutually Exclusive Section Pattern (Tabs/Radio)

### State

```javascript
_activeSectionId = null;
```

### Toggle Method

```javascript
handleSelectSection(event) {
  const sectionId = event.currentTarget.dataset.sectionId;
  
  // Toggle: if already active, close it; otherwise open it
  this._activeSectionId = this._activeSectionId === sectionId 
    ? null 
    : sectionId;
}
```

### Template

```html
<template for:each={sections} for:item="section">
  <div key={section.id} class="accordion-section">
    <div class="section-header"
         data-section-id={section.id}
         class:section-header--active={isActiveSectionId(section.id)}
         onclick={handleSelectSection}>
      {section.label}
    </div>
    
    <div class="section-content" 
         lwc:if={isActiveSectionId(section.id)}>
      {section.content}
    </div>
  </div>
</template>
```

### Helper Methods

```javascript
isActiveSectionId(sectionId) {
  return this._activeSectionId === sectionId;
}

get activeSectionChevron() {
  return this._activeSectionId ? 'utility:chevrondown' : 'utility:chevronright';
}
```

---

## Common Patterns

### Controlled Collapse (Parent Controls Child)

Parent passes expansion state to child:

```javascript
// Parent
@track expandedBucketIds = new Set();

// Child
@api bucketId;
@api isExpanded;

handleToggle() {
  this.dispatchEvent(new CustomEvent('toggle', {
    detail: { bucketId: this.bucketId }
  }));
}
```

### Expand on Load

Auto-expand first section when component loads:

```javascript
connectedCallback() {
  if (this.sections && this.sections.length > 0) {
    this._activeSectionId = this.sections[0].id;
  }
}
```

### Collapse All

Clear expansion state:

```javascript
collapseAll() {
  this._expandedSections.clear();
  this._activeSectionId = null;
}
```

### Expand All (Multiple Sections Only)

```javascript
expandAll() {
  this._expandedSections = new Set(
    this.sections.map(s => s.id)
  );
}
```

---

## CSS Example

```css
.accordion-header {
  cursor: pointer;
  padding: 12px;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: background-color 0.2s;
}

.accordion-header:hover {
  background-color: #f3f4f6;
}

.section-header--active {
  background-color: #eff6ff;
  border-left: 3px solid #0070D2;
  padding-left: 9px;
}

.accordion-content {
  padding: 16px;
  background-color: #fafbfc;
  animation: slideDown 0.2s ease-out;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

---

## Key Rules

1. **Choose one pattern** — Single boolean, Set, or one active ID; don't mix
2. **No persistence** — Expansion state is transient; don't save to localStorage
3. **Clear on unmount** — Reset state in `disconnectedCallback()`
4. **Use computed getters** — Templates call helper methods, never read state directly
5. **Animate transitions** — Use CSS transitions when expanding/collapsing for better UX
6. **Announce changes** — Use `dispatchEvent()` to notify parents of expansion changes
