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
