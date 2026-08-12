---
name: pocker-method-guide
activation:
  mode: conditional
  applies_when: >-
    the functionality sets, displays, validates, or aggregates the estimate of
    an `Item__c` — a planning-poker session, an estimate picker, a "set weight"
    action, or any roll-up of `Weight__c` over a bucket or a workspace. Any
    read, write, or test that touches `Weight__c` reaches here first. A list
    that only orders items never uses `Weight__c` and reads
    [item-order-score-algorithm.md](item-order-score-algorithm.md) instead.
description: >
  How the poker estimation method works. `Weight__c` on `Item__c` holds the
  agreed estimate, and the only values it may ever hold are the cards of a
  fixed deck — `0, 1, 2, 3, 5, 8, 13, 21`. **21 is the maximum**: no item is
  ever estimated above it, and an item that feels bigger than 21 is split
  rather than given a larger number. Covers the deck, the ceiling rule, the
  three moments that touch the estimate (vote, agree, roll up), and the
  invariants a test asserts.
metadata:
  type: reference
  applies_to: estimation of Item__c inside a Bucket__c or a Workspace__c backlog
---

# Poker Method: How Item Estimation Works

## 1. The idea in plain language

Every item can carry an estimate in `Weight__c`. The estimate is **not** a free
number — it is one card drawn from a fixed deck. Everyone estimating an item
picks a card at the same time, the picks are revealed together, and the group
converges on a single card that becomes the item's `Weight__c`.

The deck is deliberately coarse. Gaps between the cards grow as the numbers
grow, because a large item cannot be estimated precisely enough to justify a
fine-grained value. Offering `14` and `15` as separate options would invite an
argument that the estimate is not accurate enough to settle.

---

## 2. The deck

| Card | Meaning |
|---|---|
| `0` | nothing to do — already done, or absorbed by another item |
| `1` | trivial |
| `2` | small |
| `3` | small, with a wrinkle |
| `5` | medium |
| `8` | large |
| `13` | very large — usually worth splitting |
| `21` | **the maximum** — too large to plan against; split it |

Two rules define the deck, and both must hold or the method breaks:

| Rule | Why it matters |
|---|---|
| A stored estimate is **always one of the eight cards above** — never an off-deck number such as `4`, `6`, `10`, or `20` | the deck is what keeps the conversation about relative size instead of about arithmetic |
| **`21` is the maximum.** No estimate above `21` is ever offered, entered, or stored | an item bigger than `21` is not an estimate problem, it is a splitting problem — see §4 |

The ceiling is a constant of the method. No screen offers a card above `21`, no
validation accepts a value above `21`, and no code assumes a larger card might
appear.

---

## 3. Worked example

Three people estimate `Item-42`.

| Person | Card revealed |
|---|---|
| A | `3` |
| B | `5` |
| C | `13` |

**What happens:**

1. All three cards are revealed at once. Nobody sees another pick first — the
   simultaneous reveal is the entire point, because a number said out loud
   early anchors everyone else's estimate.
2. The lowest and the highest — `3` and `13` — explain their reasoning. The gap
   is where the missing information lives.
3. C mentions a migration step A and B had not considered. Everyone re-picks.
4. The second round comes back `8`, `8`, `8`. The item's `Weight__c` becomes
   `8`.

The estimate that gets stored is the **agreed** card, never an average of the
picks. Averaging `3`, `5`, and `13` gives `7`, which is not a card in the deck
and hides the disagreement instead of resolving it.

### Contrast — the ceiling case

The same three people estimate `Item-77` and come back `13`, `21`, `21`. They
agree on `21`. That agreement is a **signal, not a result**: `21` is the top of
the deck, so the group has said "this is at least as big as anything we are
willing to plan against."

The item is split into smaller items, each estimated on its own. `Item-77`
itself keeps no estimate; the pieces carry the numbers. What the group must
never do is invent `34` — the deck ends at `21`, and reaching for a bigger
number is how estimates stop meaning anything.

---

## 4. The three moments that involve the estimate

There are only three, and nothing else in the system reads or writes
`Weight__c`.

### 4.1 Voting on an item

| Step | What happens |
|---|---|
| 1 | Each participant picks one card from the deck. The choice is hidden. |
| 2 | Picks are revealed **simultaneously**. |
| 3 | If every pick is the same card, that card is the estimate. |
| 4 | Otherwise the extremes explain, and the round repeats from step 1. |

Nothing is written to `Weight__c` during voting. A round in progress is not an
estimate.

### 4.2 Agreeing and storing the estimate

| Step | What happens |
|---|---|
| 1 | The agreed card is validated against the deck. |
| 2 | A value that is not a card — including any value **above `21`** — is rejected. It is never rounded to the nearest card, and never clamped down to `21`. |
| 3 | The accepted card is written to `Weight__c` in a single update. |

Rejecting rather than clamping is deliberate: a `34` arriving at the service is
a bug in the caller, and silently storing `21` would hide it.

### 4.3 Rolling up estimates

| Step | What happens |
|---|---|
| 1 | The estimates of the items in a bucket or workspace are summed. |
| 2 | Items with **no** estimate are excluded from the total and reported separately as unestimated. |

A roll-up is a plain sum. It is **not** re-fitted to the deck — the deck
constrains individual estimates, not totals, so a bucket summing to `37` is
perfectly normal.

---

## 5. What this costs, and the rules that keep it cheap

| Rule | Why |
|---|---|
| The deck and the `21` ceiling live in **one** place, shared by the picker and the validation | two copies drift, and the day they disagree the UI offers a card the service rejects |
| Deck validation lives in the **Service**, the `update` in the **Dao** | the phase split in [back-end/sequence/sequence.md](../private/back-end/sequence/sequence.md); the controller passes the chosen card through and computes nothing |
| A roll-up is **one aggregate query**, never a per-item read in a loop | see [apex-bulk-soql.md](../../../performance/apex-bulk-soql.md) and [apex-governor-limit-guard.md](../../../guard/apex-governor-limit-guard.md) |
| An item estimated at `21` is **split**, not re-estimated higher | the ceiling only works if nothing is allowed above it |

---

## 6. Invariants to assert in tests

1. Every stored `Weight__c` is one of `0, 1, 2, 3, 5, 8, 13, 21`.
2. **No stored `Weight__c` exceeds `21`.**
3. A value above `21` is **rejected**, not clamped to `21` and not rounded.
4. An off-deck value inside the range — `4`, `6`, `10`, `20` — is rejected too.
5. An unestimated item is excluded from a roll-up total and counted as
   unestimated, rather than being treated as `0`.
6. A roll-up total is a plain sum and is **not** asserted to be a deck value.
7. Storing an estimate updates **exactly one** row.
