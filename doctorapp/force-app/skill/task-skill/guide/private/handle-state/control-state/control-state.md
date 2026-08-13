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
