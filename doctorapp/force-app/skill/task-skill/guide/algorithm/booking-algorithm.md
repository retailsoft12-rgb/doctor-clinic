# SCHEDULING ALGORITHM — BUSINESS & MATHEMATICAL SPECIFICATION
Source of truth: ScheduleService.createSchedule + Schedule (domain rules)
Verified against: ScheduleServiceTest (10 scenario cases + 4 unit rules)
Status: DESCRIPTIVE — this is what the system does today, written before any planning.

===============================================================================
0. PURPOSE (BUSINESS)
===============================================================================
The clinic accepts one appointment request at a time for a given calendar day.
The system must answer exactly one of three business answers:

  A) BOOKED      — the requested time is free, the appointment is persisted.
  B) BUSY + OFFER— the requested time hits another appointment; the system
                   refuses to book and returns a set of alternative start times
                   of the SAME duration on the SAME day.
  C) REFUSED     — the requested time is busy AND no alternative exists that day.

The system never moves, shortens, or overwrites an existing appointment, and
never books outside the requested calendar day.

===============================================================================
1. NOTATION AND ENTITIES
===============================================================================
An appointment  a  is the triple  a = (s_a , d_a , e_a)  where

    s_a  = start instant (date + time)
    d_a  = effective duration in minutes
    e_a  = end instant

  N  = the NEW (requested) appointment
  t  = s_N  = the requested start instant
  d  = d_N  = the effective duration of the request
  D  = the set of appointments already stored on the requested day
  n  = |D|

Occupancy interval of an appointment is CLOSED on both ends:

    I(a) = [ s_a , e_a ]

Business meaning of "closed": the last minute of an appointment is still
occupied, so an appointment may not start at the exact instant another ends.

===============================================================================
2. RULE 1 — EFFECTIVE DURATION (duration normalisation)
===============================================================================
The requested duration is normalised once, at object construction:

    d = D_req - 1     if  (D_req mod 10 = 0)  AND  (D_req mod 60 = 0)
    d = D_req         otherwise

Since 60 | D_req  implies  10 | D_req, the condition simplifies to:

    d = D_req - 1     if  D_req is a whole number of hours   (60, 120, 180, …)
    d = D_req         otherwise                              (15, 30, 45, 90, …)

Business intent: a "1 hour" appointment occupies 59 minutes, so that the
next hour-aligned slot does not touch it (see §3, closed intervals).

Examples:  30 → 30      45 → 45      60 → 59      120 → 119      90 → 90

===============================================================================
3. RULE 2 — END TIME
===============================================================================
    e_a = s_a + d_a          (minutes added to the start instant)

    e(10:00, 45) = 10:45          [unit test: End DateTime Calculation]
    e(12:00, 60) = 12:59          [60 normalised to 59 — see §2]

===============================================================================
4. RULE 3 — COLLISION PREDICATE
===============================================================================
Two appointments x and y collide when their CLOSED intervals intersect:

    Collide(x, y)  ⟺  ¬( e_x < s_y  ∨  e_y < s_x )
                   ⟺  s_x ≤ e_y  ∧  s_y ≤ e_x

Truth table of the business meaning:

    e_x <  s_y                      → free (x strictly before y)
    e_x =  s_y                      → COLLISION (touching is occupied)
    intervals overlap partially     → COLLISION
    one contains the other          → COLLISION
    identical intervals             → COLLISION

Checks:
    x = [10:00,10:30], y = [10:15,10:45]  → 10:00 ≤ 10:45 ∧ 10:15 ≤ 10:30 → TRUE
    x = [10:00,10:30], y = [11:00,12:00]  → 11:00 ≤ 10:30 is false        → FALSE

===============================================================================
5. RULE 4 — DAY SCOPE
===============================================================================
Only the requested calendar day is ever read or written.

    Day(t)   = the calendar date of t
    Window   = [ Day(t) 00:00:00 , Day(t) 23:59:59 ]
    D        = { a stored : s_a ∈ Window }

Consequences (business):
  - an appointment is classified by its START only; an appointment that would
    run past midnight is still owned by its start day;
  - the candidate answer is always on Day(t): the system may not propose
    another day. (Guard: if the resolved start ever left Day(t) the request is
    refused with "Cannot schedule on a different day".)

===============================================================================
6. RULE 5 — THE TWO NEIGHBOURS (predecessor / successor)
===============================================================================
Instead of testing the request against all n stored appointments, the system
tests it against exactly two probes:

    P = PREDECESSOR = the appointment of  { a ∈ D : s_a ≤ t }
                      with the MAXIMUM end time  e_a          (⊥ if empty)

    S = SUCCESSOR   = the appointment of  { a ∈ D : s_a ≥ t }
                      with the MINIMUM start time s_a          (⊥ if empty)

Note: an appointment with  s_a = t  belongs to BOTH sets (it is simultaneously
predecessor and successor). This is the "same start time" situation.

--- WHY TWO PROBES ARE ENOUGH (correctness proof) ------------------------------
Let N = [t, t+d].

(a) Left side. For any a with s_a ≤ t:
        Collide(N,a) ⟺ s_a ≤ e_N ∧ t ≤ e_a
    The first conjunct is automatic, because s_a ≤ t ≤ t+d = e_N.
    Therefore   Collide(N,a) ⟺ e_a ≥ t.
    So a colliding left appointment exists  ⟺  max{ e_a } ≥ t  ⟺  P collides.

(b) Right side. For any a with s_a ≥ t:
        Collide(N,a) ⟺ s_a ≤ e_N ∧ t ≤ e_a
    The second conjunct is automatic, because e_a ≥ s_a ≥ t.
    Therefore   Collide(N,a) ⟺ s_a ≤ e_N.
    So a colliding right appointment exists ⟺ min{ s_a } ≤ e_N ⟺ S collides.

(c) Every a ∈ D satisfies s_a ≤ t or s_a ≥ t, so (a) ∪ (b) covers D.

CONCLUSION:  N is free  ⟺  P does not collide AND S does not collide.
The two probes are complete — no third appointment can be missed.
This is why P is selected by LATEST END (not latest start): the longest
overhang, not the nearest start, is the binding constraint.

===============================================================================
7. RULE 6 — THE BOOKING DECISION
===============================================================================
    Free(N)  ⟺  ( P = ⊥  ∨  ¬Collide(N,P) )
             ∧  ( S = ⊥  ∨  ¬Collide(N,S) )

    Free(N)  = TRUE   → persist N, answer A) BOOKED
    Free(N)  = FALSE  → do NOT persist, go to §8 (answer B or C)

The four business situations, all producing the same formula:

    CASE 1   P = ⊥ , S = ⊥      empty day               → always BOOK
    CASE 2   P = ⊥ , S ≠ ⊥      first of the day        → BOOK iff S free
    CASE 3   P ≠ ⊥ , S = ⊥      last of the day         → BOOK iff P free
    CASE 4   P ≠ ⊥ , S ≠ ⊥      inserted between two    → BOOK iff both free

Invariant: when the answer is not BOOKED, ZERO writes occur (no partial save,
no reservation, no side effect).

===============================================================================
8. RULE 7 — ALTERNATIVE SLOT GENERATION (the offer)
===============================================================================
Triggered only when Free(N) = FALSE. The offer keeps the requested duration d
and the requested day constant; only the start time moves.

Business day boundaries used for offers:
    OPEN  = Day(t) at 08:00
    CLOSE = Day(t) at 22:00

Sort the day:  a(1), a(2), …, a(n)  by ascending start time.
Build the candidate set  Σ  from three generators:

  (G1) OPENING SLOT — before the first appointment
        σ0 = [ OPEN , OPEN + d ]
        accepted ⟺  OPEN + d  ≤  s_a(1)

  (G2) GAP SLOTS — between consecutive appointments, i = 1 … n-1
        σi = [ e_a(i) , e_a(i) + d ]
        accepted ⟺  e_a(i) + d  ≤  s_a(i+1)
        (business: the gap must be at least d minutes wide:
                   s_a(i+1) − e_a(i) ≥ d )

  (G3) CLOSING SLOT — after the last appointment
        σn = [ e_a(n) , e_a(n) + d ]
        accepted ⟺  e_a(n) + d  ≤  CLOSE

  Σ = set of accepted slots, de-duplicated by the pair (start, end).
  Slot ordering is NOT guaranteed — Σ is a mathematical set, not a list.

  Σ ≠ ∅  → answer B) "Requested time is not available. Here are available slots:"
  Σ = ∅  → answer C) "No available slots for the requested date"

Note the asymmetry that is deliberate business behaviour:
  - G1 anchors at the fixed clinic opening 08:00, NOT at 00:00;
  - G3 is bounded by the fixed clinic closing 22:00;
  - G2 is bounded only by the neighbours, never by 08:00/22:00.

===============================================================================
9. COST MODEL
===============================================================================
    Day read              : 1 query, returns n rows
    Neighbour selection   : 2 linear scans      → O(n)
    Decision              : 2 comparisons       → O(1)
    Offer (only on busy)  : 1 sort + 1 pass     → O(n log n)
    Writes                : 1 on BOOK, 0 otherwise
    Memory                : O(n)

===============================================================================
10. WORKED CASES — ARITHMETIC TRACE OF EVERY TEST
===============================================================================
All on 2026-04-01.  Format: name [start , end] (effective duration)

CASE 1 — empty day
  N = John  [10:00 , 10:30] (30)      D = ∅
  P = ⊥ , S = ⊥ → CASE 1 → BOOK.  e_N = 10:00 + 30 = 10:30            ✔ BOOKED

CASE 2 — successor only, free
  N = Jane  [09:00 , 09:30] (30)      D = { John [10:00 , 10:30] }
  P = ⊥ (no start ≤ 09:00) ; S = John
  Right rule: s_S ≤ e_N ?  10:00 ≤ 09:30 → false → no collision       ✔ BOOKED

CASE 3 — successor only, collision
  N = Bob   [09:45 , 10:15] (30)      D = { John [10:00 , 10:30] }
  S = John ; 10:00 ≤ 10:15 → COLLISION → offer
    G1: 08:00+30 = 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G2: none (n = 1)
    G3: 10:30+30 = 11:00 ≤ 22:00 ✔ → [10:30 , 11:00]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 4 — predecessor only, free
  N = Alice [15:00 , 15:45] (45)      D = { John [10:00 , 10:30] }
  P = John ; left rule: e_P ≥ s_N ? 10:30 ≥ 15:00 → false → free
  S = ⊥ → CASE 3 → BOOK.  e_N = 15:00 + 45 = 15:45                    ✔ BOOKED

CASE 5 — predecessor only, collision
  N = Charlie [15:30 , 16:15] (45)    D = { Alice [15:00 , 15:45] }
  P = Alice ; 15:45 ≥ 15:30 → COLLISION → offer
    G1: 08:45 ≤ 15:00 ✔ → [08:00 , 08:45]
    G3: 15:45+45 = 16:30 ≤ 22:00 ✔ → [15:45 , 16:30]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 6 — both neighbours, free (insertion)
  N = Diana [11:00 , 11:30] (30)
  D = { John [10:00 , 10:30] , Alice [15:00 , 15:45] }
  P = John : 10:30 ≥ 11:00 → false → free
  S = Alice: 15:00 ≤ 11:30 → false → free                             ✔ BOOKED

CASE 7 — both neighbours, collides with predecessor
  N = Frank [10:15 , 11:00] (45)
  D = { John [10:00 , 10:30] , Diana [11:00 , 11:30] }
  P = John : 10:30 ≥ 10:15 → COLLISION → offer
    G1: 08:45 ≤ 10:00 ✔ → [08:00 , 08:45]
    G2: 10:30+45 = 11:15 ≤ 11:00 ✘ REJECTED (gap = 30 min < 45)
    G3: 11:30+45 = 12:15 ≤ 22:00 ✔ → [11:30 , 12:15]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 8 — both neighbours, collides with successor
  N = Grace [10:45 , 11:15] (30)
  D = { John [10:00 , 10:30] , Diana [11:00 , 11:30] }
  P = John : 10:30 ≥ 10:45 → false → free
  S = Diana: 11:00 ≤ 11:15 → COLLISION → offer
    G1: 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G2: 10:30+30 = 11:00 ≤ 11:00 ✔ (equality accepted) → [10:30 , 11:00]
    G3: 11:30+30 = 12:00 ≤ 22:00 ✔ → [11:30 , 12:00]
  Σ = 3 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 9 — long appointment fits a wide gap (duration normalisation matters)
  N = Henry [12:00 , 12:59] (60 → 59)
  D = { Diana [11:00 , 11:30] , Alice [15:00 , 15:45] }
  P = Diana: 11:30 ≥ 12:00 → false → free
  S = Alice: 15:00 ≤ 12:59 → false → free                             ✔ BOOKED

CASE 10 — identical start time
  N = Ivy [10:00 , 10:30] (30)        D = { John [10:00 , 10:30] }
  John satisfies s ≤ t AND s ≥ t → John is P and S simultaneously
  P = John : 10:30 ≥ 10:00 → COLLISION → offer
    G1: 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G3: 10:30+30 = 11:00 ≤ 22:00 ✔ → [10:30 , 11:00]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

UNIT RULES
  Collision, overlapping     : [10:00,10:30] vs [10:15,10:45] → TRUE   ✔
  Collision, disjoint        : [10:00,10:30] vs [11:00,12:00] → FALSE  ✔
  End time                   : 10:00 + 45 = 10:45                      ✔
  Same-day test              : 04-01 vs 04-01 TRUE ; vs 04-02 FALSE    ✔

===============================================================================
11. INVARIANTS (must hold after any change to the algorithm)
===============================================================================
  I1  A BOOKED appointment collides with no stored appointment of that day.
  I2  A non-BOOKED request produces zero writes.
  I3  Every offered slot has exactly the requested effective duration d.
  I4  Every offered slot lies on the requested calendar day.
  I5  Offers never modify, shift, or split an existing appointment.
  I6  The decision reads at most the appointments of one calendar day.
  I7  The offered set contains no duplicate (start, end) pair.

===============================================================================
12. KNOWN GAPS IN THE CURRENT RULES (facts, not proposals)
===============================================================================
  X1  BOUNDARY CONTRADICTION. Offers accept touching (slot_end ≤ next_start,
      slot_start = previous_end) while the collision rule forbids touching
      (§4). Therefore every slot produced by G2 and G3 starts exactly at a
      previous end and would be REJECTED as a collision if the user submits
      it back. Only G1 (08:00) is re-submittable, and only when its end is
      strictly before the first start. Reconciling the two requires either
      half-open intervals [s , e) or a +1 minute offset on generated slots.
  X2  The requested start itself is never validated against 08:00 / 22:00;
      the clinic window constrains offers only. A request at 03:00 on an
      empty day is booked.
  X3  There is no past-date rule and no maximum-horizon rule.
  X4  An appointment whose end crosses midnight is stored under its start day
      and is invisible to the next day's neighbour probes (§5).
  X5  The day window ends at 23:59:59; a start within the final second is
      not read.
  X6  The "different day" guard (§5) is unreachable in the current flow,
      because the compared instant and the reference instant are the same
      value. No behaviour depends on it today.
  X7  No concurrency control: two simultaneous requests can each observe a
      free interval and both be booked (I1 holds per-request, not globally).
  X8  Duration is not validated (null, zero, or negative is not rejected).
  X9  The offer set is unordered, so the UI receives slots in arbitrary
      order and must sort them itself.
# SCHEDULING ALGORITHM — BUSINESS & MATHEMATICAL SPECIFICATION
Source of truth: ScheduleService.createSchedule + Schedule (domain rules)
Verified against: ScheduleServiceTest (10 scenario cases + 4 unit rules)
Status: DESCRIPTIVE — this is what the system does today, written before any planning.

===============================================================================
0. PURPOSE (BUSINESS)
===============================================================================
The clinic accepts one appointment request at a time for a given calendar day.
The system must answer exactly one of three business answers:

  A) BOOKED      — the requested time is free, the appointment is persisted.
  B) BUSY + OFFER— the requested time hits another appointment; the system
                   refuses to book and returns a set of alternative start times
                   of the SAME duration on the SAME day.
  C) REFUSED     — the requested time is busy AND no alternative exists that day.

The system never moves, shortens, or overwrites an existing appointment, and
never books outside the requested calendar day.

===============================================================================
1. NOTATION AND ENTITIES
===============================================================================
An appointment  a  is the triple  a = (s_a , d_a , e_a)  where

    s_a  = start instant (date + time)
    d_a  = effective duration in minutes
    e_a  = end instant

  N  = the NEW (requested) appointment
  t  = s_N  = the requested start instant
  d  = d_N  = the effective duration of the request
  D  = the set of appointments already stored on the requested day
  n  = |D|

Occupancy interval of an appointment is CLOSED on both ends:

    I(a) = [ s_a , e_a ]

Business meaning of "closed": the last minute of an appointment is still
occupied, so an appointment may not start at the exact instant another ends.

===============================================================================
2. RULE 1 — EFFECTIVE DURATION (duration normalisation)
===============================================================================
The requested duration is normalised once, at object construction:

    d = D_req - 1     if  (D_req mod 10 = 0)  AND  (D_req mod 60 = 0)
    d = D_req         otherwise

Since 60 | D_req  implies  10 | D_req, the condition simplifies to:

    d = D_req - 1     if  D_req is a whole number of hours   (60, 120, 180, …)
    d = D_req         otherwise                              (15, 30, 45, 90, …)

Business intent: a "1 hour" appointment occupies 59 minutes, so that the
next hour-aligned slot does not touch it (see §3, closed intervals).

Examples:  30 → 30      45 → 45      60 → 59      120 → 119      90 → 90

===============================================================================
3. RULE 2 — END TIME
===============================================================================
    e_a = s_a + d_a          (minutes added to the start instant)

    e(10:00, 45) = 10:45          [unit test: End DateTime Calculation]
    e(12:00, 60) = 12:59          [60 normalised to 59 — see §2]

===============================================================================
4. RULE 3 — COLLISION PREDICATE
===============================================================================
Two appointments x and y collide when their CLOSED intervals intersect:

    Collide(x, y)  ⟺  ¬( e_x < s_y  ∨  e_y < s_x )
                   ⟺  s_x ≤ e_y  ∧  s_y ≤ e_x

Truth table of the business meaning:

    e_x <  s_y                      → free (x strictly before y)
    e_x =  s_y                      → COLLISION (touching is occupied)
    intervals overlap partially     → COLLISION
    one contains the other          → COLLISION
    identical intervals             → COLLISION

Checks:
    x = [10:00,10:30], y = [10:15,10:45]  → 10:00 ≤ 10:45 ∧ 10:15 ≤ 10:30 → TRUE
    x = [10:00,10:30], y = [11:00,12:00]  → 11:00 ≤ 10:30 is false        → FALSE

===============================================================================
5. RULE 4 — DAY SCOPE
===============================================================================
Only the requested calendar day is ever read or written.

    Day(t)   = the calendar date of t
    Window   = [ Day(t) 00:00:00 , Day(t) 23:59:59 ]
    D        = { a stored : s_a ∈ Window }

Consequences (business):
  - an appointment is classified by its START only; an appointment that would
    run past midnight is still owned by its start day;
  - the candidate answer is always on Day(t): the system may not propose
    another day. (Guard: if the resolved start ever left Day(t) the request is
    refused with "Cannot schedule on a different day".)

===============================================================================
6. RULE 5 — THE TWO NEIGHBOURS (predecessor / successor)
===============================================================================
Instead of testing the request against all n stored appointments, the system
tests it against exactly two probes:

    P = PREDECESSOR = the appointment of  { a ∈ D : s_a ≤ t }
                      with the MAXIMUM end time  e_a          (⊥ if empty)

    S = SUCCESSOR   = the appointment of  { a ∈ D : s_a ≥ t }
                      with the MINIMUM start time s_a          (⊥ if empty)

Note: an appointment with  s_a = t  belongs to BOTH sets (it is simultaneously
predecessor and successor). This is the "same start time" situation.

--- WHY TWO PROBES ARE ENOUGH (correctness proof) ------------------------------
Let N = [t, t+d].

(a) Left side. For any a with s_a ≤ t:
        Collide(N,a) ⟺ s_a ≤ e_N ∧ t ≤ e_a
    The first conjunct is automatic, because s_a ≤ t ≤ t+d = e_N.
    Therefore   Collide(N,a) ⟺ e_a ≥ t.
    So a colliding left appointment exists  ⟺  max{ e_a } ≥ t  ⟺  P collides.

(b) Right side. For any a with s_a ≥ t:
        Collide(N,a) ⟺ s_a ≤ e_N ∧ t ≤ e_a
    The second conjunct is automatic, because e_a ≥ s_a ≥ t.
    Therefore   Collide(N,a) ⟺ s_a ≤ e_N.
    So a colliding right appointment exists ⟺ min{ s_a } ≤ e_N ⟺ S collides.

(c) Every a ∈ D satisfies s_a ≤ t or s_a ≥ t, so (a) ∪ (b) covers D.

CONCLUSION:  N is free  ⟺  P does not collide AND S does not collide.
The two probes are complete — no third appointment can be missed.
This is why P is selected by LATEST END (not latest start): the longest
overhang, not the nearest start, is the binding constraint.

===============================================================================
7. RULE 6 — THE BOOKING DECISION
===============================================================================
    Free(N)  ⟺  ( P = ⊥  ∨  ¬Collide(N,P) )
             ∧  ( S = ⊥  ∨  ¬Collide(N,S) )

    Free(N)  = TRUE   → persist N, answer A) BOOKED
    Free(N)  = FALSE  → do NOT persist, go to §8 (answer B or C)

The four business situations, all producing the same formula:

    CASE 1   P = ⊥ , S = ⊥      empty day               → always BOOK
    CASE 2   P = ⊥ , S ≠ ⊥      first of the day        → BOOK iff S free
    CASE 3   P ≠ ⊥ , S = ⊥      last of the day         → BOOK iff P free
    CASE 4   P ≠ ⊥ , S ≠ ⊥      inserted between two    → BOOK iff both free

Invariant: when the answer is not BOOKED, ZERO writes occur (no partial save,
no reservation, no side effect).

===============================================================================
8. RULE 7 — ALTERNATIVE SLOT GENERATION (the offer)
===============================================================================
Triggered only when Free(N) = FALSE. The offer keeps the requested duration d
and the requested day constant; only the start time moves.

Business day boundaries used for offers:
    OPEN  = Day(t) at 08:00
    CLOSE = Day(t) at 22:00

Sort the day:  a(1), a(2), …, a(n)  by ascending start time.
Build the candidate set  Σ  from three generators:

  (G1) OPENING SLOT — before the first appointment
        σ0 = [ OPEN , OPEN + d ]
        accepted ⟺  OPEN + d  ≤  s_a(1)

  (G2) GAP SLOTS — between consecutive appointments, i = 1 … n-1
        σi = [ e_a(i) , e_a(i) + d ]
        accepted ⟺  e_a(i) + d  ≤  s_a(i+1)
        (business: the gap must be at least d minutes wide:
                   s_a(i+1) − e_a(i) ≥ d )

  (G3) CLOSING SLOT — after the last appointment
        σn = [ e_a(n) , e_a(n) + d ]
        accepted ⟺  e_a(n) + d  ≤  CLOSE

  Σ = set of accepted slots, de-duplicated by the pair (start, end).
  Slot ordering is NOT guaranteed — Σ is a mathematical set, not a list.

  Σ ≠ ∅  → answer B) "Requested time is not available. Here are available slots:"
  Σ = ∅  → answer C) "No available slots for the requested date"

Note the asymmetry that is deliberate business behaviour:
  - G1 anchors at the fixed clinic opening 08:00, NOT at 00:00;
  - G3 is bounded by the fixed clinic closing 22:00;
  - G2 is bounded only by the neighbours, never by 08:00/22:00.

===============================================================================
9. COST MODEL
===============================================================================
    Day read              : 1 query, returns n rows
    Neighbour selection   : 2 linear scans      → O(n)
    Decision              : 2 comparisons       → O(1)
    Offer (only on busy)  : 1 sort + 1 pass     → O(n log n)
    Writes                : 1 on BOOK, 0 otherwise
    Memory                : O(n)

===============================================================================
10. WORKED CASES — ARITHMETIC TRACE OF EVERY TEST
===============================================================================
All on 2026-04-01.  Format: name [start , end] (effective duration)

CASE 1 — empty day
  N = John  [10:00 , 10:30] (30)      D = ∅
  P = ⊥ , S = ⊥ → CASE 1 → BOOK.  e_N = 10:00 + 30 = 10:30            ✔ BOOKED

CASE 2 — successor only, free
  N = Jane  [09:00 , 09:30] (30)      D = { John [10:00 , 10:30] }
  P = ⊥ (no start ≤ 09:00) ; S = John
  Right rule: s_S ≤ e_N ?  10:00 ≤ 09:30 → false → no collision       ✔ BOOKED

CASE 3 — successor only, collision
  N = Bob   [09:45 , 10:15] (30)      D = { John [10:00 , 10:30] }
  S = John ; 10:00 ≤ 10:15 → COLLISION → offer
    G1: 08:00+30 = 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G2: none (n = 1)
    G3: 10:30+30 = 11:00 ≤ 22:00 ✔ → [10:30 , 11:00]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 4 — predecessor only, free
  N = Alice [15:00 , 15:45] (45)      D = { John [10:00 , 10:30] }
  P = John ; left rule: e_P ≥ s_N ? 10:30 ≥ 15:00 → false → free
  S = ⊥ → CASE 3 → BOOK.  e_N = 15:00 + 45 = 15:45                    ✔ BOOKED

CASE 5 — predecessor only, collision
  N = Charlie [15:30 , 16:15] (45)    D = { Alice [15:00 , 15:45] }
  P = Alice ; 15:45 ≥ 15:30 → COLLISION → offer
    G1: 08:45 ≤ 15:00 ✔ → [08:00 , 08:45]
    G3: 15:45+45 = 16:30 ≤ 22:00 ✔ → [15:45 , 16:30]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 6 — both neighbours, free (insertion)
  N = Diana [11:00 , 11:30] (30)
  D = { John [10:00 , 10:30] , Alice [15:00 , 15:45] }
  P = John : 10:30 ≥ 11:00 → false → free
  S = Alice: 15:00 ≤ 11:30 → false → free                             ✔ BOOKED

CASE 7 — both neighbours, collides with predecessor
  N = Frank [10:15 , 11:00] (45)
  D = { John [10:00 , 10:30] , Diana [11:00 , 11:30] }
  P = John : 10:30 ≥ 10:15 → COLLISION → offer
    G1: 08:45 ≤ 10:00 ✔ → [08:00 , 08:45]
    G2: 10:30+45 = 11:15 ≤ 11:00 ✘ REJECTED (gap = 30 min < 45)
    G3: 11:30+45 = 12:15 ≤ 22:00 ✔ → [11:30 , 12:15]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 8 — both neighbours, collides with successor
  N = Grace [10:45 , 11:15] (30)
  D = { John [10:00 , 10:30] , Diana [11:00 , 11:30] }
  P = John : 10:30 ≥ 10:45 → false → free
  S = Diana: 11:00 ≤ 11:15 → COLLISION → offer
    G1: 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G2: 10:30+30 = 11:00 ≤ 11:00 ✔ (equality accepted) → [10:30 , 11:00]
    G3: 11:30+30 = 12:00 ≤ 22:00 ✔ → [11:30 , 12:00]
  Σ = 3 slots, 0 writes                                        ✔ BUSY + OFFER

CASE 9 — long appointment fits a wide gap (duration normalisation matters)
  N = Henry [12:00 , 12:59] (60 → 59)
  D = { Diana [11:00 , 11:30] , Alice [15:00 , 15:45] }
  P = Diana: 11:30 ≥ 12:00 → false → free
  S = Alice: 15:00 ≤ 12:59 → false → free                             ✔ BOOKED

CASE 10 — identical start time
  N = Ivy [10:00 , 10:30] (30)        D = { John [10:00 , 10:30] }
  John satisfies s ≤ t AND s ≥ t → John is P and S simultaneously
  P = John : 10:30 ≥ 10:00 → COLLISION → offer
    G1: 08:30 ≤ 10:00 ✔ → [08:00 , 08:30]
    G3: 10:30+30 = 11:00 ≤ 22:00 ✔ → [10:30 , 11:00]
  Σ = 2 slots, 0 writes                                        ✔ BUSY + OFFER

UNIT RULES
  Collision, overlapping     : [10:00,10:30] vs [10:15,10:45] → TRUE   ✔
  Collision, disjoint        : [10:00,10:30] vs [11:00,12:00] → FALSE  ✔
  End time                   : 10:00 + 45 = 10:45                      ✔
  Same-day test              : 04-01 vs 04-01 TRUE ; vs 04-02 FALSE    ✔

===============================================================================
11. INVARIANTS (must hold after any change to the algorithm)
===============================================================================
  I1  A BOOKED appointment collides with no stored appointment of that day.
  I2  A non-BOOKED request produces zero writes.
  I3  Every offered slot has exactly the requested effective duration d.
  I4  Every offered slot lies on the requested calendar day.
  I5  Offers never modify, shift, or split an existing appointment.
  I6  The decision reads at most the appointments of one calendar day.
  I7  The offered set contains no duplicate (start, end) pair.

===============================================================================
12. KNOWN GAPS IN THE CURRENT RULES (facts, not proposals)
===============================================================================
  X1  BOUNDARY CONTRADICTION. Offers accept touching (slot_end ≤ next_start,
      slot_start = previous_end) while the collision rule forbids touching
      (§4). Therefore every slot produced by G2 and G3 starts exactly at a
      previous end and would be REJECTED as a collision if the user submits
      it back. Only G1 (08:00) is re-submittable, and only when its end is
      strictly before the first start. Reconciling the two requires either
      half-open intervals [s , e) or a +1 minute offset on generated slots.
  X2  The requested start itself is never validated against 08:00 / 22:00;
      the clinic window constrains offers only. A request at 03:00 on an
      empty day is booked.
  X3  There is no past-date rule and no maximum-horizon rule.
  X4  An appointment whose end crosses midnight is stored under its start day
      and is invisible to the next day's neighbour probes (§5).
  X5  The day window ends at 23:59:59; a start within the final second is
      not read.
  X6  The "different day" guard (§5) is unreachable in the current flow,
      because the compared instant and the reference instant are the same
      value. No behaviour depends on it today.
  X7  No concurrency control: two simultaneous requests can each observe a
      free interval and both be booked (I1 holds per-request, not globally).
  X8  Duration is not validated (null, zero, or negative is not rejected).
  X9  The offer set is unordered, so the UI receives slots in arbitrary
      order and must sort them itself.
