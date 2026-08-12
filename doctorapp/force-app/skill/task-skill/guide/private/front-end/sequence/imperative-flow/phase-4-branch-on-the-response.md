---
phase: 4
title: branch on the response
next: phase-5-finally-clear-the-flag.md
---

# Phase 4 — branch on the response

1. **component.js → self** — success (`response.success === true`) →  
   a. **Update principal state** from `response.data`.  
      - If `data` is a single record → assign it to the corresponding `@track` array/object (e.g., `this.buckets = [newBucket, ...this.buckets]` or `this.items = response.data`).  
      - If `data` is a list → assign directly.  
      - If `data` contains multiple named pieces (map) → destructure and update each relevant principal state.
   b. **Show success toast** (optional, if the operation is user‑visible).
2. **OR** — `response.success === false` or promise rejects →  
   a. **Do NOT update state** (the server state is unchanged).  
   b. **Show error toast** using `ShowToastEvent`.
3. **Always** ensure that all state updates are **reactive** (use `@track` or immutability).`


You cannot go before check that all participant is exist
→ Go to [phase-5-finally-clear-the-flag.md](phase-5-finally-clear-the-flag.md).
