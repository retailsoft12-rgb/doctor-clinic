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
