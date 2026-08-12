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

- [[principal-data-state-guide]] — Single component's canonical data (buckets, items)
- [[server-indicators-guide]] — Pagination and async flags grouped with data
- [[picklist-static-options-guide]] — Reference data (options, picklists) never merged with others
- [[derived-state]] — Computed getters derived from principal state and localStorage
