/- S3.5 — the EXPLICIT collision extractor for inclusion soundness.

   Why a function and not `∃`: `Hash` is a finite type (32-byte lists),
   `sha256` has an infinite domain, so `∃ x y, x ≠ y ∧ sha256 x = sha256 y`
   is provable by pigeonhole ALONE — a bare-existential soundness theorem
   is vacuous, and even a data-carrying `{p // IsCollision p}` disjunct is
   inhabited by `Classical.choice`. The paper's Theorem 2 is an *explicit
   algorithm* 𝓔; faithfulness demands a named function `extractIncl` and a
   correctness statement ABOUT ITS OUTPUT — a claim pigeonhole cannot
   discharge, because it pins down *which* pair. -/
import Proofs.Completeness

namespace LTLAcc

/-- A specific colliding pair (predicate on concrete byte strings). -/
def IsCollision (x y : List UInt8) : Prop :=
  x ≠ y ∧ sha256 x = sha256 y

/-- The extractor 𝓔 for inclusion (paper Theorem 2). Given the honest
    leaf list `D`, a claimed index `m`, a claimed leaf `d`, and a path
    `P`, it walks the honest tree and returns the concrete preimage pair
    at the first level where the offered reconstruction diverges from the
    honest tree — a node preimage pair high up, or the leaf preimage pair
    at the bottom. Total (junk defaults on the branches the soundness
    hypothesis excludes). -/
noncomputable def extractIncl (m : Nat) (D : List Bytes) (d : Bytes)
    (P : List Hash) : List UInt8 × List UInt8 :=
  if D.length ≤ 1 then
    -- leaf level: the offered leaf `d` vs the honest leaf `D[m]`
    (0x00 :: d, 0x00 :: D.getD m [])
  else
    let k := kbelow D.length
    match P.getLast? with
    | none => ([], [])            -- excluded: composite size needs a sibling
    | some s =>
        if m < k then
          let child := (Root (hleaf d) m k P.dropLast).getD default
          if child = MTH (D.take k) ∧ s = MTH (D.drop k) then
            extractIncl m (D.take k) d P.dropLast
          else
            (0x01 :: (child.val ++ s.val),
             0x01 :: ((MTH (D.take k)).val ++ (MTH (D.drop k)).val))
        else
          let child := (Root (hleaf d) (m - k) (D.length - k) P.dropLast).getD default
          if s = MTH (D.take k) ∧ child = MTH (D.drop k) then
            extractIncl (m - k) (D.drop k) d P.dropLast
          else
            (0x01 :: (s.val ++ child.val),
             0x01 :: ((MTH (D.take k)).val ++ (MTH (D.drop k)).val))
termination_by D.length
decreasing_by
  · simp only [List.length_take]
    have h2 : 2 ≤ D.length := by omega
    have hk := kbelow_lt D.length h2
    omega
  · simp only [List.length_drop]
    have hp := kbelow_pos D.length
    omega

/-- **Theorem 2 (Inclusion soundness), explicit form** — the faithful
    replacement for the vacuous bare-existential version. If an accepting
    receipt opens position `m` to a leaf `d` different from the honest
    `D[m]`, then `extractIncl` OUTPUTS a genuine SHA-256 collision. The
    statement is about the fixed function's output, so pigeonhole cannot
    prove it: it must exhibit that THIS pair collides. -/
theorem extractIncl_correct (m : Nat) (D : List Bytes) :
    ∀ (d : Bytes) (P : List Hash), m < D.length → d ≠ D.getD m [] →
    Root (hleaf d) m D.length P = some (MTH D) →
    IsCollision (extractIncl m D d P).1 (extractIncl m D d P).2 := by
  induction m, D using Path.induct with
  | case1 m D hle =>
      intro d P hm hd h
      have h1 : D.length = 1 := by omega
      obtain ⟨e, rfl⟩ := exists_singleton_of_length_one D h1
      have hm0 : m = 0 := by simpa using hm
      subst hm0
      rw [extractIncl]
      simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
      have hlen : ([e] : List Bytes).length = 1 := rfl
      rw [hlen] at h
      cases P with
      | nil =>
          rw [Root_one, MTH_single] at h
          simp only [Option.some.injEq] at h
          have hde : d ≠ e := by simpa using hd
          refine ⟨?_, ?_⟩
          · intro hc; injection hc with _ ht; exact hde ht
          · have hg : ([e] : List Bytes).getD 0 [] = e := rfl
            rw [hg]; exact h
      | cons p q =>
          rw [Root_one_cons] at h
          exact absurd h (by simp)
  | case2 m D hgt k hmk ih =>
      intro d P hm hd h
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hmk' : m < kbelow D.length := by rw [← hkeq]; exact hmk
      have htklen : (D.take k).length = k := by simp [List.length_take]; omega
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
          have hh := h
          rw [hsplit, Root_left _ _ _ _ _ h2 hmk', ← hkeq] at hh
          cases hR : Root (hleaf d) m k P.dropLast with
          | none => rw [hR] at hh; simp at hh
          | some x =>
              rw [hR] at hh
              simp only [Option.map_some, Option.some.injEq] at hh
              rw [MTH_split D h2, ← hkeq] at hh
              rw [extractIncl]
              simp only [if_neg hgt, hP, ← hkeq, if_pos hmk]
              have hchild : (Root (hleaf d) m k P.dropLast).getD default = x := by
                rw [hR]; rfl
              rw [hchild]
              by_cases hpair : x = MTH (D.take k) ∧ s = MTH (D.drop k)
              · simp only [if_pos hpair]
                have ihm : m < (D.take k).length := by omega
                have hgetd : (D.take k).getD m [] = D.getD m [] := getD_take D k m hmk
                have hd' : d ≠ (D.take k).getD m [] := by rw [hgetd]; exact hd
                have hrec : Root (hleaf d) m (D.take k).length P.dropLast
                    = some (MTH (D.take k)) := by rw [htklen, hR, hpair.1]
                exact ih d P.dropLast ihm hd' hrec
              · simp only [if_neg hpair]
                refine ⟨?_, ?_⟩
                · intro hc
                  injection hc with _ happ
                  have hlen : x.val.length = (MTH (D.take k)).val.length := by
                    rw [x.property, (MTH (D.take k)).property]
                  obtain ⟨hx, hs⟩ := List.append_inj happ hlen
                  exact hpair ⟨Subtype.ext hx, Subtype.ext hs⟩
                · exact hh
  | case3 m D hgt k hmk ih =>
      intro d P hm hd h
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hkp : 0 < k := by rw [hkeq]; exact kbelow_pos D.length
      have hmk' : ¬ m < kbelow D.length := by rw [← hkeq]; exact hmk
      have hdplen : (D.drop k).length = D.length - k := by simp [List.length_drop]
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
          have hh := h
          rw [hsplit, Root_right _ _ _ _ _ h2 hmk', ← hkeq] at hh
          cases hR : Root (hleaf d) (m - k) (D.length - k) P.dropLast with
          | none => rw [hR] at hh; simp at hh
          | some x =>
              rw [hR] at hh
              simp only [Option.map_some, Option.some.injEq] at hh
              rw [MTH_split D h2, ← hkeq] at hh
              rw [extractIncl]
              simp only [if_neg hgt, hP, ← hkeq, if_neg hmk]
              have hchild : (Root (hleaf d) (m - k) (D.length - k) P.dropLast).getD default = x := by
                rw [hR]; rfl
              rw [hchild]
              by_cases hpair : s = MTH (D.take k) ∧ x = MTH (D.drop k)
              · simp only [if_pos hpair]
                have ihm : m - k < (D.drop k).length := by omega
                have hidx : k + (m - k) = m := by omega
                have hgetd : (D.drop k).getD (m - k) [] = D.getD m [] := by
                  rw [getD_drop, hidx]
                have hd' : d ≠ (D.drop k).getD (m - k) [] := by rw [hgetd]; exact hd
                have hrec : Root (hleaf d) (m - k) (D.drop k).length P.dropLast
                    = some (MTH (D.drop k)) := by rw [hdplen, hR, hpair.2]
                exact ih d P.dropLast ihm hd' hrec
              · simp only [if_neg hpair]
                refine ⟨?_, ?_⟩
                · intro hc
                  injection hc with _ happ
                  have hlen : s.val.length = (MTH (D.take k)).val.length := by
                    rw [s.property, (MTH (D.take k)).property]
                  obtain ⟨hs, hx⟩ := List.append_inj happ hlen
                  exact hpair ⟨Subtype.ext hs, Subtype.ext hx⟩
                · exact hh

/-- **Permanent non-vacuity witness** (re-audit F1): on a NON-forgery
    input (the offered leaf IS the honest leaf), the extractor's output
    is provably NOT a collision. Hence `extractIncl_correct`'s conclusion
    is false for some inputs — it cannot be discharged by pigeonhole or
    choice, and only the forgery hypotheses make it hold. This theorem
    guards the corpus against any future drift back into vacuity. -/
theorem extractIncl_nonvacuous :
    ¬ IsCollision (extractIncl 0 [([7] : List UInt8)] [7] []).1
                  (extractIncl 0 [([7] : List UInt8)] [7] []).2 := by
  rw [extractIncl]
  simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
  intro hcol
  exact hcol.1 rfl

/-- Inclusion soundness through the named acceptance predicate (review F1):
    if `acceptIncl` holds for a wrong leaf, `extractIncl` outputs a
    collision. Ties the object the harness tests to the security theorem.
    The range fact `m < |D|` is `hacc.1` — acceptance carries it, so the
    caller owes nothing beyond acceptance and the wrong-leaf premise
    (review round 2, L1/NEW-2). -/
theorem acceptIncl_sound (m : Nat) (D : List Bytes)
    (d : Bytes) (P : List Hash) (hd : d ≠ D.getD m [])
    (hacc : acceptIncl d m D.length P (MTH D)) :
    IsCollision (extractIncl m D d P).1 (extractIncl m D d P).2 :=
  extractIncl_correct m D d P hacc.1 hd hacc.2

end LTLAcc
