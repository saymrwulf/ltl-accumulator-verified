/- L3 of the accumulator pyramid: the prover-side Path function and
   **Theorem 1 (inclusion completeness)** — honest receipts always verify:

     Root (hleaf D[m]) m |D| (Path m D) = some (MTH D)

   No hash property is used anywhere (the theorem is about shapes). -/
import Proofs.Basic

namespace LTLAcc

/-- `Path` (paper §5.3): the operator's inclusion path for index `m`.
    Sibling subtree heads, leaf-to-root order (the paper's `‖ [s]`). -/
noncomputable def Path (m : Nat) (D : List Bytes) : List Bytes :=
  if D.length ≤ 1 then []
  else
    let k := kbelow D.length
    if m < k then Path m (D.take k) ++ [MTH (D.drop k)]
    else Path (m - k) (D.drop k) ++ [MTH (D.take k)]
termination_by D.length
decreasing_by
  · simp only [List.length_take]
    have h2 : 2 ≤ D.length := by omega
    have hk := kbelow_lt D.length h2
    omega
  · simp only [List.length_drop]
    have hp := kbelow_pos D.length
    omega

/-! ### List helper lemmas (self-contained; no stdlib-name dependence) -/

theorem getD_take (l : List Bytes) (k m : Nat) (h : m < k) :
    (l.take k).getD m [] = l.getD m [] := by
  induction l generalizing k m with
  | nil => simp
  | cons a t ih =>
      cases k with
      | zero => omega
      | succ k' =>
          cases m with
          | zero => simp
          | succ m' =>
              simp only [List.take_succ_cons, List.getD_cons_succ]
              exact ih k' m' (by omega)

theorem getD_drop (l : List Bytes) (k i : Nat) :
    (l.drop k).getD i [] = l.getD (k + i) [] := by
  induction l generalizing k with
  | nil => simp
  | cons a t ih =>
      cases k with
      | zero => simp
      | succ k' =>
          have hidx : k' + 1 + i = (k' + i) + 1 := by omega
          simp only [List.drop_succ_cons, hidx, List.getD_cons_succ]
          exact ih k'

theorem exists_singleton_of_length_one (l : List Bytes)
    (h : l.length = 1) : ∃ d, l = [d] := by
  cases l with
  | nil => simp at h
  | cons a t =>
      cases t with
      | nil => exact ⟨a, rfl⟩
      | cons b u => simp at h

/-! ### Equation lemmas -/

theorem MTH_single (d : Bytes) : MTH [d] = hleaf d := by
  rw [MTH]; rfl

theorem MTH_split (D : List Bytes) (h : 2 ≤ D.length) :
    MTH D = hnode (MTH (D.take (kbelow D.length)))
                  (MTH (D.drop (kbelow D.length))) := by
  rw [MTH]
  have h0 : ¬ D.length = 0 := by omega
  have h1 : ¬ D.length = 1 := by omega
  simp only [h0, h1, dite_false]

theorem Root_one (v : Bytes) (m : Nat) : Root v m 1 [] = some v := by
  rw [Root]; rfl

/-- `Root` at a composite size, left branch (`m < k`). -/
theorem Root_left (v : Bytes) (m n : Nat) (P : List Bytes) (s : Bytes)
    (hn : 2 ≤ n) (hm : m < kbelow n) :
    Root v m n (P ++ [s]) = (Root v m (kbelow n) P).map (hnode · s) := by
  have h1 : ¬ n = 1 := by omega
  have h0 : ¬ n = 0 := by omega
  have hne : ¬ (P ++ [s] = []) := by simp
  cases hR : Root v m (kbelow n) P with
  | none =>
      rw [Root]; simp [h0, h1, hm, hR]
      exact fun hh => absurd hh hne
  | some x =>
      rw [Root]; simp [h0, h1, hm, hR]
      exact fun hh => absurd hh hne

/-- `Root` at a composite size, right branch (`m ≥ k`). -/
theorem Root_right (v : Bytes) (m n : Nat) (P : List Bytes) (s : Bytes)
    (hn : 2 ≤ n) (hm : ¬ m < kbelow n) :
    Root v m n (P ++ [s]) =
      (Root v (m - kbelow n) (n - kbelow n) P).map (hnode s ·) := by
  have h1 : ¬ n = 1 := by omega
  have h0 : ¬ n = 0 := by omega
  have hne : ¬ (P ++ [s] = []) := by simp
  cases hR : Root v (m - kbelow n) (n - kbelow n) P with
  | none =>
      rw [Root]; simp [h0, h1, hm, hR]
      exact fun hh => absurd hh hne
  | some x =>
      rw [Root]; simp [h0, h1, hm, hR]
      exact fun hh => absurd hh hne

/-! ### Theorem 1 -/

/-- **Theorem 1 (Inclusion completeness)**, paper §6: for every non-empty
    leaf list `D` and every `m < |D|`, the honestly produced receipt
    verifies to the honest root. -/
theorem incl_complete (m : Nat) (D : List Bytes) (hm : m < D.length) :
    Root (hleaf (D.getD m [])) m D.length (Path m D) = some (MTH D) := by
  induction m, D using Path.induct with
  | case1 m D hle =>
      -- |D| ≤ 1 and m < |D| force D = [d], m = 0
      have h1 : D.length = 1 := by omega
      obtain ⟨d, rfl⟩ := exists_singleton_of_length_one D h1
      have hm0 : m = 0 := by simpa using hm
      subst hm0
      rw [Path]
      simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
      rw [MTH_single]
      simpa using Root_one (hleaf d) 0
  | case2 m D hgt k hmk ih =>
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hmk' : m < kbelow D.length := by rw [← hkeq]; exact hmk
      rw [Path]
      simp only [if_neg hgt, ← hkeq, if_pos hmk]
      rw [Root_left _ _ _ _ _ h2 hmk', ← hkeq]
      have htklen : (D.take k).length = k := by
        simp [List.length_take]; omega
      have ihm : m < (D.take k).length := by omega
      have hrec := ih ihm
      rw [getD_take D k m hmk, htklen] at hrec
      rw [hrec, MTH_split D h2, ← hkeq]
      rfl
  | case3 m D hgt k hmk ih =>
      have h2 : 2 ≤ D.length := by omega
      have hkeq : k = kbelow D.length := rfl
      have hkl : k < D.length := by rw [hkeq]; exact kbelow_lt D.length h2
      have hkp : 0 < k := by rw [hkeq]; exact kbelow_pos D.length
      have hmk' : ¬ m < kbelow D.length := by rw [← hkeq]; exact hmk
      rw [Path]
      simp only [if_neg hgt, ← hkeq, if_neg hmk]
      rw [Root_right _ _ _ _ _ h2 hmk', ← hkeq]
      have hidx : k + (m - k) = m := by omega
      have hget : (D.drop k).getD (m - k) [] = D.getD m [] := by
        rw [getD_drop, hidx]
      have hdplen : (D.drop k).length = D.length - k := by
        simp [List.length_drop]
      have ihm : m - k < (D.drop k).length := by omega
      have hrec := ih ihm
      rw [hget, hdplen] at hrec
      rw [hrec, MTH_split D h2, ← hkeq]
      rfl

end LTLAcc
