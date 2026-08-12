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
