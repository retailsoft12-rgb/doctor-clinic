---
phase: 5
title: handle { data, error }
next: phase-6-clear-the-flag.md
---

# Phase 5 — handle { data, error }

1. **component.js → self** — guard against null/undefined invocation (initial call without param).  
2. **Success branch** (`data` is present and `data.success === true`) →  
   a. **Update principal state** from `data.data` (the nested payload).  
   b. Optionally, update any derived getters (they compute automatically).  
3. **Error branch** (`error` or `data.success === false`) →  
   a. **Do NOT update state**.  
   b. **Show error toast** with `ShowToastEvent`.  
4. **Clear the loading flag** (`isLoading = false`) – this must happen **after** the state update so that the UI doesn’t flash an empty state while the new data is being assigned.

You cannot go before check that all participant is exist

→ Go to [phase-6-clear-the-flag.md](phase-6-clear-the-flag.md).
