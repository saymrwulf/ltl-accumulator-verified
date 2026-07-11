/- L4 (first instance) of the accumulator pyramid: **root binding for the
   inclusion fold** — the Path instance of the paper's Lemma 2 — and
   **Theorem 2 (inclusion soundness)** as a constructive statement:
   an accepting receipt for a wrong leaf EXHIBITS a SHA-256 collision.

   No collision-resistance assumption appears anywhere: `HasCollision`
   is the conclusion, never a hypothesis. -/
import Proofs.Completeness

namespace LTLAcc

/-- Two distinct preimages with equal hash — the jackpot. Constructively
    exhibited by the soundness theorems; believing it cannot be found is
    the reader's interpretation of SHA-256, exactly as in the paper. -/
def HasCollision : Prop :=
  ∃ x y : List UInt8, x ≠ y ∧ sha256 x = sha256 y

/-- Either two hash values have equal preimage pairs, or their equality
    is itself a collision (the paper's case dichotomy at one node). -/
theorem hnode_inj_or_collision {x y X Y : Hash}
    (h : hnode x y = hnode X Y) :
    (x = X ∧ y = Y) ∨ HasCollision := by
  by_cases hpre :
      (0x01 : UInt8) :: (x.val ++ y.val) = 0x01 :: (X.val ++ Y.val)
  · exact Or.inl (hnode_preimage_inj hpre)
  · exact Or.inr ⟨_, _, hpre, h⟩

/-- Likewise at a leaf: equal leaf hashes with distinct data collide. -/
theorem hleaf_inj_or_collision {d e : Bytes}
    (h : hleaf d = hleaf e) : d = e ∨ HasCollision := by
  by_cases hde : d = e
  · exact Or.inl hde
  · refine Or.inr ⟨0x00 :: d, 0x00 :: e, ?_, h⟩
    intro hc; injection hc with _ ht; exact hde ht

/-- A non-empty list is its `dropLast` plus its last element
    (self-contained; no stdlib-name dependence). -/
theorem eq_dropLast_append_of_getLast? (l : List Hash) (s : Hash)
    (h : l.getLast? = some s) : l = l.dropLast ++ [s] := by
  induction l with
  | nil => simp at h
  | cons a t ih =>
      cases t with
      | nil =>
          simp at h
          subst h
          rfl
      | cons b u =>
          have hh : (b :: u).getLast? = some s := by
            simpa using h
          have := ih hh
          calc a :: b :: u = a :: (b :: u) := rfl
            _ = a :: ((b :: u).dropLast ++ [s]) := by rw [← this]
            _ = (a :: b :: u).dropLast ++ [s] := by simp

/-- **Root binding** (the Path instance of the paper's Lemma 2): if any
    reconstruction from `(v, P)` hits the honest root, then either
    `(v, P)` IS the honest receipt — leaf hash and every consumed
    sibling — or a collision is exhibited. -/
theorem root_binding (m : Nat) (D : List Bytes) :
    ∀ (v : Hash) (P : List Hash), m < D.length →
    Root v m D.length P = some (MTH D) →
    (v = hleaf (D.getD m []) ∧ P = Path m D) ∨ HasCollision := by
  induction m, D using Path.induct with
  | case1 m D hle =>
      intro v P hm h
      have h1 : D.length = 1 := by omega
      obtain ⟨d, rfl⟩ := exists_singleton_of_length_one D h1
      have hm0 : m = 0 := by simpa using hm
      subst hm0
      have hlen : ([d] : List Bytes).length = 1 := rfl
      rw [hlen] at h
      cases P with
      | nil =>
          rw [Root_one, MTH_single] at h
          simp only [Option.some.injEq] at h
          left
          refine ⟨?_, by rw [Path]; simp⟩
          have hg : ([d] : List Bytes).getD 0 [] = d := rfl
          rw [hg]; exact h
      | cons p q =>
          rw [Root_one_cons] at h
          simp at h
  | case2 m D hgt k hmk ih =>
      intro v P hm h
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hmk' : m < kbelow D.length := by rw [← hkeq]; exact hmk
      have htklen : (D.take k).length = k := by
        simp [List.length_take]; omega
      cases hP : P.getLast? with
      | none =>
          have hPnil : P = [] := by
            cases P with
            | nil => rfl
            | cons a t => simp at hP
          subst hPnil
          rw [Root] at h
          have hn1 : ¬ D.length = 1 := by omega
          have hn0 : ¬ D.length = 0 := by omega
          simp [hn1, hn0] at h
      | some s =>
          obtain hsplit := eq_dropLast_append_of_getLast? P s hP
          rw [hsplit] at h
          rw [Root_left _ _ _ _ _ h2 hmk', ← hkeq] at h
          cases hR : Root v m k P.dropLast with
          | none => rw [hR] at h; simp at h
          | some x =>
              rw [hR] at h
              simp only [Option.map_some, Option.some.injEq] at h
              rw [MTH_split D h2, ← hkeq] at h
              rcases hnode_inj_or_collision h with ⟨hx, hs⟩ | hc
              · have ihm : m < (D.take k).length := by omega
                have hR' : Root v m (D.take k).length P.dropLast
                    = some (MTH (D.take k)) := by rw [htklen, hR, hx]
                rcases ih v P.dropLast ihm hR' with ⟨hv, hPd⟩ | hc
                · left
                  refine ⟨?_, ?_⟩
                  · rw [hv]; exact congrArg hleaf (getD_take D k m hmk)
                  · have hRHS : Path m D = Path m (D.take k) ++ [MTH (D.drop k)] := by
                      rw [Path]; simp only [if_neg hgt, ← hkeq, if_pos hmk]
                    rw [hRHS, hsplit, hPd, hs]
                · exact Or.inr hc
              · exact Or.inr hc
  | case3 m D hgt k hmk ih =>
      intro v P hm h
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hkp : 0 < k := by rw [hkeq]; exact kbelow_pos D.length
      have hmk' : ¬ m < kbelow D.length := by rw [← hkeq]; exact hmk
      have hdplen : (D.drop k).length = D.length - k := by
        simp [List.length_drop]
      cases hP : P.getLast? with
      | none =>
          have hPnil : P = [] := by
            cases P with
            | nil => rfl
            | cons a t => simp at hP
          subst hPnil
          rw [Root] at h
          have hn1 : ¬ D.length = 1 := by omega
          have hn0 : ¬ D.length = 0 := by omega
          simp [hn1, hn0] at h
      | some s =>
          obtain hsplit := eq_dropLast_append_of_getLast? P s hP
          rw [hsplit] at h
          rw [Root_right _ _ _ _ _ h2 hmk', ← hkeq] at h
          cases hR : Root v (m - k) (D.length - k) P.dropLast with
          | none => rw [hR] at h; simp at h
          | some x =>
              rw [hR] at h
              simp only [Option.map_some, Option.some.injEq] at h
              rw [MTH_split D h2, ← hkeq] at h
              rcases hnode_inj_or_collision h with ⟨hs, hx⟩ | hc
              · have ihm : m - k < (D.drop k).length := by omega
                have hR' : Root v (m - k) (D.drop k).length P.dropLast
                    = some (MTH (D.drop k)) := by rw [hdplen, hR, hx]
                rcases ih v P.dropLast ihm hR' with ⟨hv, hPd⟩ | hc
                · left
                  have hidx : k + (m - k) = m := by omega
                  refine ⟨?_, ?_⟩
                  · rw [hv]
                    have hh : (D.drop k).getD (m - k) [] = D.getD m [] := by
                      rw [getD_drop, hidx]
                    exact congrArg hleaf hh
                  · have hRHS : Path m D = Path (m - k) (D.drop k) ++ [MTH (D.take k)] := by
                      rw [Path]; simp only [if_neg hgt, ← hkeq, if_neg hmk]
                    rw [hRHS, hsplit, hPd, hs]
                · exact Or.inr hc
              · exact Or.inr hc

/-- **Theorem 2 (Inclusion soundness: position binding)**, paper §6,
    constructive form: an accepting receipt whose leaf differs from the
    honest leaf at position `m` exhibits a SHA-256 collision. -/
theorem incl_sound (m : Nat) (D : List Bytes) (hm : m < D.length)
    (d : Bytes) (P : List Hash)
    (h : Root (hleaf d) m D.length P = some (MTH D)) :
    d = D.getD m [] ∨ HasCollision := by
  rcases root_binding m D (hleaf d) P hm h with ⟨hv, _⟩ | hc
  · exact hleaf_inj_or_collision hv
  · exact Or.inr hc

end LTLAcc
