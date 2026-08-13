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


