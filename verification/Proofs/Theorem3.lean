/- S5.4 — **Theorem 3 (Consistency soundness)**, assembled: the explicit
   extractor 𝓔′ for history rewrites. Joins consRecBinding (steps 1-2,
   S5.3) to extractMTH (step 3, S4).

   Statement design per the corpus discipline: a NAMED function whose
   correctness is about ITS OUTPUT (pigeonhole/choice cannot discharge
   it), guarded by a permanent non-vacuity witness. -/
import Proofs.Binding3

namespace LTLAcc

/-- The consistency extractor 𝓔′ (paper Theorem 3). On a claimed rewrite
    — an accepted consistency proof `C` between the pinned root of `D₀`
    and the head of `D₁`, where `D₀` is NOT the real prefix — return the
    node collision found while walking the fold, or descend into the two
    same-root prefix trees. -/
noncomputable def extractCons (n₀ : Nat) (C : List Hash)
    (D₀ D₁ : List Bytes) : List UInt8 × List UInt8 :=
  match extractConsNode n₀ D₁.length C true (MTH D₀) D₁ with
  | some c => c
  | none => extractMTH D₀ (D₁.take n₀)

/-- **Theorem 3 (Consistency soundness), explicit form**: if the
    consumer's verifier accepts `C` between the pinned head `MTH D₀`
    (size `n₀`) and the offered head `MTH D₁`, but `D₀` is not the real
    prefix of `D₁`, then `extractCons` outputs a genuine SHA-256
    collision. -/
theorem extractCons_correct (n₀ : Nat) (C : List Hash) (D₀ D₁ : List Bytes)
    (hlen0 : D₀.length = n₀) (hn0 : 0 < n₀) (hle : n₀ ≤ D₁.length)
    (hne : D₀ ≠ D₁.take n₀)
    (hacc : ConsRec n₀ D₁.length C true (MTH D₀) = some (MTH D₀, MTH D₁)) :
    IsCollision (extractCons n₀ C D₀ D₁).1 (extractCons n₀ C D₀ D₁).2 := by
  have hbind := consRecBinding (MTH D₀) n₀ D₁.length C true D₁
    (MTH D₀) (MTH D₁) rfl hn0 hle hacc rfl
  rw [extractCons]
  cases hrec : extractConsNode n₀ D₁.length C true (MTH D₀) D₁ with
  | some c =>
      rw [hrec] at hbind
      exact hbind
  | none =>
      rw [hrec] at hbind
      -- hbind : MTH D₀ = MTH (D₁.take n₀); descend
      have htklen : (D₁.take n₀).length = n₀ := by
        rw [List.length_take]; omega
      exact extractMTH_correct D₀ (D₁.take n₀) (by omega) hne hbind

/-- Permanent non-vacuity witness: on a NON-rewrite input (the pinned
    list IS the real prefix), the extractor's output is provably NOT a
    collision — so the correctness conclusion is false for some inputs
    and cannot be discharged by pigeonhole or choice. Uses the honest
    n₀ = n base: D₀ = D₁ = [[7]], C = [], where ConsRec accepts and
    extractConsNode returns none, so extractCons = extractMTH D₀ D₀ =
    the equal leaf pair. -/
theorem extractCons_nonvacuous :
    ¬ IsCollision (extractCons 1 [] [([7] : List UInt8)] [([7] : List UInt8)]).1
                  (extractCons 1 [] [([7] : List UInt8)] [([7] : List UInt8)]).2 := by
  rw [extractCons]
  have hrec : extractConsNode 1 ([([7] : List UInt8)]).length [] true
      (MTH [([7] : List UInt8)]) [([7] : List UInt8)] = none := by
    rw [extractConsNode]; simp
  rw [hrec]
  rw [extractMTH]
  simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
  intro hcol
  exact hcol.1 rfl

/-- Theorem 3 at the paper's exact quantifiers (review M4): `n₀ ≤ n₁`
    without a separate `0 < n₀`. The `n₀ = 0` case is discharged: `D₀`
    has length 0 so `D₀ = [] = D₁.take 0`, contradicting `hne`. -/
theorem extractCons_correct_paper (n₀ : Nat) (C : List Hash) (D₀ D₁ : List Bytes)
    (hlen0 : D₀.length = n₀) (hle : n₀ ≤ D₁.length)
    (hne : D₀ ≠ D₁.take n₀)
    (hacc : ConsRec n₀ D₁.length C true (MTH D₀) = some (MTH D₀, MTH D₁)) :
    IsCollision (extractCons n₀ C D₀ D₁).1 (extractCons n₀ C D₀ D₁).2 := by
  rcases Nat.eq_zero_or_pos n₀ with h0 | hpos
  · exfalso; apply hne
    have hD0 : D₀ = [] := List.length_eq_zero_iff.mp (by omega)
    rw [hD0, h0]; simp
  · exact extractCons_correct n₀ C D₀ D₁ hlen0 hpos hle hne hacc

/-- `ConsRec` acceptance implies the size bound: the `n₀ > n` branch
    returns `none`, so a `some` forces `n₀ ≤ n`. Lets `acceptCons_sound`
    owe no separate range hypothesis (mirrors `acceptIncl_sound`
    deriving `m < n` from `hacc.1` — review round 3, F2). -/
theorem consRec_some_le {n₀ n : Nat} {C : List Hash} {b : Bool} {r : Hash}
    {p : Hash × Hash} (h : ConsRec n₀ n C b r = some p) : n₀ ≤ n := by
  rcases Nat.lt_or_ge n n₀ with hgt | hge
  · rw [ConsRec, if_neg (by omega : ¬ n₀ = n),
        if_pos (Or.inl hgt : n₀ > n ∨ n₀ = 0 ∨ n ≤ 1)] at h
    simp at h
  · exact hge

/-- Consistency soundness through the named acceptance predicate
    (review round 3, F2 — the consistency twin of `acceptIncl_sound`):
    if `acceptCons` holds between the pinned head of `D₀` and the head
    of `D₁` but `D₀` is not the real prefix, `extractCons` outputs a
    collision. The `n₀ = 0` disjunct of `acceptCons` is impossible under
    `hne` (`D₀ = [] = D₁.take 0`); the size bound comes from acceptance
    itself (`consRec_some_le`).

    SCOPE (gap 14): this covers the MECHANIZED accept predicate. The
    deployed `verify_consistency` accepts strictly more on inputs whose
    claimed sizes are not the authentic sizes of the trees behind the
    roots; soundness transfers to deployment only under the pinned-pair
    side condition documented in KNOWN-GAPS gap 14. -/
theorem acceptCons_sound (n₀ : Nat) (C : List Hash) (D₀ D₁ : List Bytes)
    (hlen0 : D₀.length = n₀)
    (hne : D₀ ≠ D₁.take n₀)
    (hacc : acceptCons n₀ D₁.length (MTH D₀) (MTH D₁) C) :
    IsCollision (extractCons n₀ C D₀ D₁).1 (extractCons n₀ C D₀ D₁).2 := by
  rcases hacc with h0 | hcons
  · exfalso; apply hne
    have hD0 : D₀ = [] := List.length_eq_zero_iff.mp (by omega)
    rw [hD0, h0]; simp
  · exact extractCons_correct_paper n₀ C D₀ D₁ hlen0
      (consRec_some_le hcons) hne hcons

end LTLAcc
