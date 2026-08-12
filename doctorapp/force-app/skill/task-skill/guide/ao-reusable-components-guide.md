# Reusable `ao*` Base Components

The `ao*` prefix marks the project's design-system layer: presentation-only
components that never call Apex, never mutate their `@api` inputs, and dispatch
`CustomEvent`s upward. Reusing them is what keeps new UI visually and
behaviorally consistent without re-deriving the design language.

## Rule — this catalog is predefined, never built at run time

The `ao*` layer is authored deliberately, ahead of any feature work. **A row in
this catalog asserts that the component already exists. It is never a work item
for the current run.**

- A feature run **reuses** catalog components. It never creates one.
- Creating a new `ao*` component is its own deliberate task, followed by the
  "Adding to this catalog" step at the bottom of this file.
- If a row names a component that is **not on disk**, that is a **defect in this
  catalog** — not an instruction to build it. Say which row is stale, hand-roll
  the markup for that element per rule 2 below, and let the catalog be corrected
  out of band.

Building a missing component mid-feature silently converts a pather-only run
(Flow A) into a child + pather shape (Flow B): the new component arrives with its
own template, its own `@api` surface, and — if the row mentions one — its own
`Validator.js`. That contradicts the flow
[create-new-functionality](../create-new-functionality.md) → Step 2c already
decided, and it puts validation in the child when Flow A assigns it to the
pather. **The flow decides the shape; this catalog only decides the markup.**

## Rule — analyze, never ask

Choosing a base component is an **AI analysis step, not an interview question**.
Read the catalog, match each UI element in the behavior spec against it, and
record the decision. Do not ask the user which base component to use.

For every UI element to be emitted:

1. Find the catalog row whose purpose covers it → reuse that component.
2. No row covers it → hand-roll the markup, and state in the iteration message
   which element had no catalog match and why.
3. A row covers it but the component is missing from disk → treat it as case 2
   (hand-roll), and additionally report the stale row. Never fill the gap by
   creating the component.

Never re-implement a catalog entry inline (a raw `<input type="checkbox">`
instead of `c-ao-checkbox`, a raw `<button>` instead of `c-ao-btn`).

---

## Catalog

| Component | Tag | Purpose |
|---|---|---|
| **aoBtn** | `c-ao-btn` | Every clickable action button in the app. |
| **aoInput** | `c-ao-input` | Single-line text / number / date input with label. |
| **aoCheckbox** | `c-ao-checkbox` | Labeled checkbox for boolean or row-selection toggles. |
| **aoCombobox** | `c-ao-combobox` | Dropdown select over a fixed `{label, value}` option list. |
| **autoCompleteComboBox** | `c-auto-complete-combo-box` | Dropdown with a type-ahead search box that dispatches the term upward. |
| **aoSpinner** | `c-ao-spinner` | Loading indicator, inline or full-screen overlay. |
| **aoCardButton** | `c-ao-card-button` | Large selectable card (image + heading + description). |
| **aoItemRow** | `c-ao-item-row` | Full record row/card with inline edit and sub-item section. |
| **aoCreateItemModal** | `c-ao-create-item-modal` | Modal form that collects a new record and dispatches it upward. |

---

## Detail

### `aoBtn` — `c-ao-btn`

Every clickable action button. Do not use raw `<button>` or
`lightning-button` / `lightning-button-icon`.

- **`@api`**: `label`, `iconName`, `variant`, `size`, `disabled`, `type`, `title`
- **`variant`**: `primary` (single most important action — Create / Save /
  Confirm) · `secondary` (default, neutral action) · `danger` (destructive) ·
  `ghost` (low-priority — Cancel / Dismiss) · `bare` (icon-only in dense rows)
- **`size`**: `sm` (dense rows) · `md` (default) · `lg` (modal footers, hero CTAs)
- **Events**: none — bind `onclick` on the tag itself.

### `aoInput` — `c-ao-input`

Labeled single-line input. Covers text, number, date, and search fields.

- **`@api`**: `label`, `value`, `type`, `placeholder`, `required`, `disabled`,
  `readonly`, `min`, `max`, `step`, `variant`
- **Events**: `change` → `detail: { value }`

> Re-dispatched on every keystroke (it is bound to the native `input` event), so
> a consumer that must not act per character holds a draft and commits it on
> `keydown` Enter or on `focusout`. Note `focusout`, not `blur` — `blur` does not
> cross the shadow boundary.

### `aoCheckbox` — `c-ao-checkbox`

Labeled checkbox. Use for boolean fields and for row-selection toggles in lists.

- **`@api`**: `label`, `checked`, `disabled`
- **Events**: `change` → `detail: { checked }`

### `aoCombobox` — `c-ao-combobox`

Dropdown over a known option list. Use whenever the choices are already loaded
(statuses, priorities, members, item types).

- **`@api`**: `label`, `placeholder`, `value`, `options` (`Array<{label, value}>`),
  `disabled`, `variant`
- **Events**: `change` → `detail: { value }`; also `click`, `focus`

### `autoCompleteComboBox` — `c-auto-complete-combo-box`

Dropdown with a type-ahead input. Use when the option list is filtered by a
search term (server-side search, or a long client-side list).

- **`@api`**: `label`, `placeholder`, `value`, `options`, `disabled`, `variant`
- **Events**: `search` → `detail: { searchTerm }`; `change` → `detail: { value }`;
  also `click`, `focus`

### `aoSpinner` — `c-ao-spinner`

Loading indicator. Per `lwc-request-loading-guide`, the overlay form must sit at
the component's **root** template so its fixed backdrop is not trapped in a
section's stacking context.

- **`@api`**: `size` (`small` | `medium` | `large`), `overlay` (boolean),
  `alternativeText`
- **Events**: none

### `aoCardButton` — `c-ao-card-button`

Large selectable card. Use for pick-one splash screens (e.g. a workspace
chooser), not for dense lists.

- **`@api`**: `value`, `heading`, `description`, `imageUrl`
- **Events**: `select` → `detail: { value }`

### `aoItemRow` — `c-ao-item-row`

Full record row/card: inline summary edit, status / priority / assignee / topic
comboboxes, weight, selection checkbox, and an expandable sub-item section.
Reuse it wherever a record is rendered as a list row — do not rebuild a record
row by hand.

- **`@api`**: `item`, `variant` (default `row`), `statusOptions`,
  `priorityOptions`, `memberOptions`, `topics`, `workspaceId`
- **Events** (all `bubbles: true, composed: true`):
  `itemsummaryupdate`, `itempriorityupdate`, `itemweightupdate`,
  `itemstatechange`, `itemassigneechange`, `itemtopicupdate`,
  `itemdelete`, `itemselect` (`detail: { itemId, selected }`),
  `itemviewopen`, `topiccreateforitem`, `subitemsexpand`, `subitemcreate`,
  `subitemsummaryupdate`, `subitemassigneechange`, `subitemdelete`,
  `subitemsbulkdelete`

### `aoCreateItemModal` — `c-ao-create-item-modal`

Modal that collects a new record's fields and dispatches the result upward. Use
as the reference shape for any page-level modal or slide-in panel: the modal owns
UI and input collection only; the pather handles the event and calls Apex.

- **`@api`**: `bucketId`, `statusOptions`, `itemTypeOptions`, `priorityOptions`,
  plus an error setter fed by the parent after a failed Apex call
- **Events**: `itemcreate` → `detail: { ...record fields }`; `cancel`

> Where its validation lives is decided by the **flow**, not by this row.
> Flow A (pather-only) keeps the input rules in `<patherName>Validator.js`;
> only Flow B (a genuine child + pather split) puts them in a sibling
> `<childName>Validator.js`. See
> [create-new-functionality](../create-new-functionality.md) → Step 4a.

---

## Adding to this catalog

Adding an `ao*` component is a deliberate task of its own — never a side effect
of building a feature (see "this catalog is predefined" above).

When a new `ao*` component is created, add its row to the table and a Detail
section with its `@api` surface and dispatched events, in the same shape as the
entries above. A component missing from this catalog will be re-implemented by
hand on the next task — the catalog is the only thing that prevents that.

Keep the catalog honest in both directions: a row whose component no longer
exists is worse than no row at all, because it sends the next run off to rebuild
something the flow never authorised.
