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
