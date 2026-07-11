/- S6 — **Proposition 1 (Pin-store safety)**, the Merkle-layer contribution.

   The consumer pin store (§5.4) as a transition predicate; monotonicity is
   definitional, and prefix-ordering — the substantive part — reduces to
   Theorem 3 (grow) and the whole-tree Lemma 2 (same-size), stated as an
   explicit named-extractor collision (non-vacuous), never a bare ∃.

   SCOPE: Ed25519 EUF-CMA is NOT in this corpus (signatures are abstract).
   Part (2) of the paper's Prop 1 — that two conflicting signed heads are
   *transferable* evidence — is a signature-layer fact; the Merkle layer
   contributes only that different roots at equal size commit to different
   content (fork_distinct). This boundary is documented, not smuggled. -/
import Proofs.Theorem3

namespace LTLAcc

/-- The pin-store accept predicate (§5.4): same size ⇒ root must match;
    smaller ⇒ reject (rollback); larger ⇒ a consistency proof from the
    pinned head must verify. Mirrors sthstore.py. -/
def pinAccept (n : Nat) (r : Hash) (n' : Nat) (r' : Hash) (C : List Hash) : Prop :=
  if n' = n then r' = r
  else if n' < n then False
  else ConsRec n n' C true r = some (r, r')

/-- **Monotonicity (size)**: an accepted step never shrinks the pin. -/
theorem pinAccept_monotone (n : Nat) (r : Hash) (n' : Nat) (r' : Hash)
    (C : List Hash) (h : pinAccept n r n' r' C) : n ≤ n' := by
  unfold pinAccept at h
  by_cases he : n' = n
  · omega
  · by_cases hl : n' < n
    · simp [he, hl] at h
    · omega

/-- The pin-store collision extractor: whole-tree descent at equal size,
    else the consistency extractor. -/
noncomputable def pinExtract (n n' : Nat) (C : List Hash)
    (D D' : List Bytes) : List UInt8 × List UInt8 :=
  if n' = n then extractMTH D D' else extractCons n C D D'

/-- **Prefix-ordering (monotonicity, content)**: if the pin advances from an
    honest head of `D` to an honest head of `D'` but `D` is NOT the prefix
    of `D'` of its length, then `pinExtract` outputs a genuine collision.
    (Explicit form ⇒ non-vacuous; this is the paper's Prop 1(1).) -/
theorem pin_prefix_correct (n n' : Nat) (r r' : Hash) (C : List Hash)
    (D D' : List Bytes)
    (hstep : pinAccept n r n' r' C)
    (hDlen : D.length = n) (hDr : MTH D = r)
    (hD'len : D'.length = n') (hD'r : MTH D' = r')
    (hn0 : 0 < n) (hne : D ≠ D'.take n) :
    IsCollision (pinExtract n n' C D D').1 (pinExtract n n' C D D').2 := by
  unfold pinAccept at hstep
  by_cases he : n' = n
  · -- same size: r' = r ⇒ MTH D' = MTH D; D ≠ D'.take n = D' (len n)
    simp only [if_pos he] at hstep
    rw [pinExtract]; simp only [if_pos he]
    have hlen : D.length = D'.length := by rw [hDlen, hD'len, he]
    have hroot : MTH D = MTH D' := by rw [hDr, hD'r, hstep]
    have hne' : D ≠ D' := by
      intro h; apply hne; rw [h]
      have hta : D'.take n = D' := by apply take_all; rw [hD'len]; exact he
      rw [hta]
    exact extractMTH_correct D D' hlen hne' hroot
  · by_cases hl : n' < n
    · simp [he, hl] at hstep
    · -- grow: ConsRec n n' C true r = some (r, r')
      have hgrow : ConsRec n n' C true r = some (r, r') := by
        simp only [he, hl, if_false] at hstep; exact hstep
      rw [pinExtract]; simp only [if_neg he]
      have hle : n ≤ D'.length := by omega
      have hacc : ConsRec n D'.length C true (MTH D) = some (MTH D, MTH D') := by
        rw [hDr, hD'r, hD'len]; exact hgrow
      exact extractCons_correct n C D D' hDlen hn0 hle hne hacc

/-- **Fork observation (Merkle-layer share of Prop 1(2))**: two honest
    heads of equal size with different roots commit to different content.
    (Transferable-evidence via EUF-CMA is signature-layer, out of scope.) -/
theorem fork_distinct (n : Nat) (r r' : Hash) (D D' : List Bytes)
    (hDlen : D.length = n) (hD'len : D'.length = n)
    (hDr : MTH D = r) (hD'r : MTH D' = r') (hrne : r ≠ r') : D ≠ D' := by
  intro h; apply hrne; rw [← hDr, ← hD'r, h]

/-- Permanent non-vacuity witness for pin_prefix_correct: on an honest
    non-fork step (D IS the prefix), the extractor output is not a
    collision. Uses the same-size identity D = D' = [[7]]. -/
theorem pin_prefix_nonvacuous :
    ¬ IsCollision (pinExtract 1 1 [] [([7] : List UInt8)] [([7] : List UInt8)]).1
                  (pinExtract 1 1 [] [([7] : List UInt8)] [([7] : List UInt8)]).2 := by
  rw [pinExtract]; simp only [if_pos rfl]
  rw [extractMTH]; simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
  intro hcol; exact hcol.1 rfl

end LTLAcc
