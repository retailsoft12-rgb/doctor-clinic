---
name: item-order-score-guide
activation:
  mode: conditional
  applies_when: >-
    the functionality places items in a user-controlled order inside a list —
    drag-and-drop reordering, "move up / move down", or creating an item that
    must land at the bottom of an existing list. Any read, write, or test that
    touches `Score__c` reaches here first. A list the user cannot reorder
    (sorted by name, date, or weight) never uses `Score__c` and never reads this
    guide.
description: >
  How the ordering score actually works. `Score__c` is a short **text** label on
  `Item__c`; the list is returned in ascending alphabetical order of that label,
  and a reorder computes a new label that sorts between the two neighbours —
  writing exactly one row. Covers the three moments that touch the score
  (create, list, reorder), the integer-midpoint rule, the reshuffle fallback
  when no midpoint exists, and the edge cases at the top and bottom of the list.
metadata:
  type: reference
  applies_to: ordered lists of Item__c inside a Bucket__c or a Workspace__c backlog
---

# Item Order: How the `Score__c` Algorithm Works

## 1. The idea in plain language

Every item carries a short text label called `Score__c`. The list is displayed
in **alphabetical order of that label**. To place an item between two others,
the system builds a new label that sits alphabetically between their two
labels. **No other item has to change.**

Two properties make this work, and both must hold or the whole scheme breaks:

| Property | Why it matters |
|---|---|
| `Score__c` is a **Text** field, and the sort is `ORDER BY Score__c ASC` | the database does the ordering; the client never sorts |
| Every label is a **fixed-width, zero-padded** decimal string (`000200`, not `200`) | alphabetical order and numeric order are then the same string-by-string. Drop the padding and `"1000"` sorts before `"200"` |

The width is fixed at **6 characters** and the reshuffle spacing is **200**.
Both are constants of the algorithm — a label is never written at a different
width, and no code parses a score with a different assumed width.

---

## 2. Worked example

Three items exist in a bucket. At this point in the bucket's life they carry
these scores (the uneven gaps reflect earlier moves that partially consumed the
original spacing):

| Item | Score |
|---|---|
| `Item-2` | `000200` |
| `Item-3` | `000225` |
| `Item-300` | `060000` |

**Action:** the user drags `Item-300` to sit directly before `Item-2`.

**What the system does:**

1. `Item-300` is being placed before `Item-2`, which currently holds `000200`.
2. The slot before `Item-2` is the very top of the list, so the lower boundary
   is `0`.
3. The system computes the integer midpoint of the two boundaries:
   `(000000 + 000200) / 2 = 000100`.
4. That is a **whole integer** — no reshuffle needed. `Item-300` receives
   `000100`, and the database touches exactly one row.

Result, sorted by score ascending:

| Position | Item | Score |
|---|---|---|
| 1 | `Item-300` *(moved)* | `000100` |
| 2 | `Item-2` | `000200` |
| 3 | `Item-3` | `000225` |

The order is correct, the user sees the drop happen instantly, and the database
touched exactly one row.

### Contrast — the reshuffle case

If the two neighbours hold `000200` and `000225` — the gap squeezed by earlier
moves — inserting between them gives `(200 + 225) / 2 = 212.5`. **Not a whole
integer, so no slot is available.** The system triggers a reshuffle: every score
in that bucket is rewritten with the full 200 gap restored, and then the move is
applied. The final order is still correct; only the cost changed.

By contrast, two neighbours holding `000200` and `000400` give
`(200 + 400) / 2 = 300` — a whole integer — and the move completes in a single
write with no reshuffle.

---

## 3. The three moments that involve the score

There are only three, and nothing else in the system reads or writes
`Score__c`.

### 3.1 Creating a new item

The item joins the **top** of its list — its bucket, or the workspace backlog if
it has no bucket. A newly captured item is the one the user just thought of, so
it is the one they expect to see first; the list is not scrolled to the bottom to
find it.

| Step | What happens |
|---|---|
| 1 | The system looks up the **smallest** score currently in that list. |
| 2 | If the list is empty, the new score is the first spacing label (`000200`). |
| 3 | Otherwise the new score is the integer midpoint of `0` and that smallest score (`000400` → `000200`). |
| 4 | If that midpoint is not a whole integer — the smallest score is odd, or is `000001` with no room below it — the list is reshuffled per §3.3 and the midpoint is taken against the restored spacing. |

Prepending deliberately halves the gap above the list each time, so repeated
creates converge on the reshuffle rather than staying a single write forever:
`000400` → `000200` → `000100` → `000050` → … The cost is bounded — the gap can
only halve about eight times from `000200` before the reshuffle in §3.3 restores
the full spacing — and it is the trade this ordering makes for putting the new
item where the user is looking.

The **boundary lookup is still one query**, `ORDER BY Score__c ASC LIMIT 1`, not
a full list read.

### 3.2 Listing items for the user

| Step | What happens |
|---|---|
| 1 | The database returns items ordered by `Score__c` **ascending**. |
| 2 | The user sees them in that order. **No client-side sorting is needed.** |

The `ORDER BY Score__c ASC` belongs in the Dao query, with the soft-delete
filter alongside it — see [soql-exclude-deleted-guide.md](../soql-exclude-deleted-guide.md)
and [back-end/sequence/sequence.md](../private/back-end/sequence/sequence.md) → `dbAccessRule`. The LWC
renders the list in the order it receives and never re-sorts it; re-sorting in
JavaScript is the bug this whole design exists to remove.

### 3.3 Reordering by drag-and-drop

The user interface sends **two ids**: the *moved* item, and the *before* item —
the item that should appear just before the moved one in the new order.

| Case | What happens |
|---|---|
| Dropped **after** another item | The system finds the item currently sitting just after the *before* item, takes the two scores as the lower and upper boundary, and computes the integer midpoint. |
| Dropped at the **top** of the list (no *before*) | The lower boundary is `0` and the upper boundary is the current first item's score. The midpoint of those two sorts before every existing label. |
| The *before* item is the **last** in the list | There is no upper boundary. The moved item takes the last item's score with its **last character bumped up by one** (`…200` → `…201`). This is the only place that rule still applies — §3.1 creates at the top and never uses it. |

In every case, **only the moved item is updated** — unless no midpoint exists.

#### When no midpoint exists

The midpoint is unusable when `(lower + upper) / 2` is not a whole integer —
i.e. the two boundaries are adjacent or differ by an odd amount that leaves no
room. Then, and only then:

1. Read every item in that list, ordered by `Score__c ASC`.
2. Rewrite the scores at the full 200 spacing (`000200`, `000400`, `000600`, …).
3. Apply the requested move against the restored spacing — which now always has
   a midpoint.
4. Persist the rewritten list in **one** DML statement.

The reshuffle is the slow path and is correct, not exceptional; it is what keeps
the fast path a single write for every other move.

---

## 4. What this costs, and the rules that keep it cheap

| Rule | Why |
|---|---|
| The reorder writes **one row** on the fast path | that is the entire point of the design — never re-number a list to move one item |
| The reshuffle writes the **whole list in one `update`**, never one row at a time | a per-row DML inside a loop hits the DML governor limit as soon as a list grows — see [apex-governor-limit-guard.md](../../../guard/apex-governor-limit-guard.md) |
| The boundary lookup is **one query**, bounded by `LIMIT`, not a full list read | see [apex-bulk-soql.md](../../../performance/apex-bulk-soql.md) |
| Score arithmetic lives in the **Service**, the queries and the `update` in the **Dao** | the phase split in [back-end/sequence/sequence.md](../private/back-end/sequence/sequence.md); the controller passes the two ids through and computes nothing |
| The `Score__c` value is **never shown to the user** and never entered by hand | it is an implementation detail of the order, not data |

---

## 5. Invariants to assert in tests

A test for ordering asserts the **order**, not the literal labels — except for
the invariants below, which are the algorithm itself:

1. After any create, the new item is **first** in `ORDER BY Score__c ASC`.
2. After a move, the moved item sits **immediately after** the *before* item,
   and every other item's relative order is unchanged.
3. A move that has a midpoint updates **exactly one** row.
4. A move that has no midpoint leaves the list correctly ordered anyway — the
   reshuffle path is asserted on the resulting order, never on the specific
   numbers it produced.
5. Every stored label is the same fixed width; no label is ever written
   unpadded.
6. Moving the first item to the top, and the last item to the bottom, are both
   no-ops in terms of resulting order.
