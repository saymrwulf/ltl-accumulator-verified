/- S4 — the DESCENT extractor: two equal-length leaf lists with the same
   Merkle root yield an explicit SHA-256 collision.

   This is step 3 of the paper's Theorem 3 ("descend"), and it also
   restores — in explicit, non-vacuous form — the receipt-uniqueness
   content that the S3.5 cleanup deleted with `root_binding` (re-audit
   F2): the honest fold is injective up to a collision. Built as a named
   function `extractMTH` with a correctness statement about ITS OUTPUT,
   so pigeonhole/choice cannot discharge it (guarded by
   `extractMTH_nonvacuous`). -/
import Proofs.Extract

namespace LTLAcc

/-- The descent extractor. Given two leaf lists of equal length with
    equal Merkle roots but differing data, walk the (shared-shape) tree
    to the first divergence and return the concrete colliding preimage
    pair — a node preimage pair, or a leaf preimage pair at the bottom. -/
noncomputable def extractMTH (D D' : List Bytes) : List UInt8 × List UInt8 :=
  if D.length ≤ 1 then
    (0x00 :: D.headD [], 0x00 :: D'.headD [])
  else
    let k := kbelow D.length
    if MTH (D.take k) = MTH (D'.take k) ∧ MTH (D.drop k) = MTH (D'.drop k) then
      if D.take k ≠ D'.take k then extractMTH (D.take k) (D'.take k)
      else extractMTH (D.drop k) (D'.drop k)
    else
      (0x01 :: ((MTH (D.take k)).val ++ (MTH (D.drop k)).val),
       0x01 :: ((MTH (D'.take k)).val ++ (MTH (D'.drop k)).val))
termination_by D.length
decreasing_by
  · simp only [List.length_take]
    have h2 : 2 ≤ D.length := by omega
    have hk := kbelow_lt D.length h2
    omega
  · simp only [List.length_drop]
    have hp := kbelow_pos D.length
    omega

/-- Take/drop reconstruct the whole list (self-contained). -/
theorem take_append_drop (l : List Bytes) (k : Nat) :
    l.take k ++ l.drop k = l := List.take_append_drop k l

/-- **Descent correctness** (paper Theorem 3, step 3; and the restored
    receipt-uniqueness content of Lemma 2 in explicit form): for equal-
    length lists with equal roots but differing data, `extractMTH`
    outputs a genuine SHA-256 collision. -/
theorem extractMTH_correct (D D' : List Bytes) :
    D.length = D'.length → D ≠ D' → MTH D = MTH D' →
    IsCollision (extractMTH D D').1 (extractMTH D D').2 := by
  induction D, D' using extractMTH.induct with
  | case1 D D' hle =>
      intro hlen hne hroot
      rw [extractMTH]; simp only [hle, if_pos]
      have hd1 : D.length = 1 := by
        rcases Nat.eq_zero_or_pos D.length with h0 | hp
        · exfalso; apply hne
          have hD : D = [] := List.length_eq_zero_iff.mp h0
          have hD' : D' = [] := List.length_eq_zero_iff.mp (by omega)
          rw [hD, hD']
        · omega
      obtain ⟨a, rfl⟩ := exists_singleton_of_length_one D hd1
      obtain ⟨b, rfl⟩ := exists_singleton_of_length_one D' (by omega)
      have hab : a ≠ b := by intro h; exact hne (by rw [h])
      rw [MTH_single, MTH_single] at hroot
      refine ⟨?_, ?_⟩
      · intro hc; injection hc with _ ht; exact hab ht
      · simpa using hroot
  | case2 D D' hgt k hhalves htake ih =>
      intro hlen hne hroot
      have hk : kbelow D.length = k := rfl
      rw [extractMTH, if_neg hgt, hk, if_pos hhalves, if_pos htake]
      apply ih
      · simp only [List.length_take]; omega
      · exact htake
      · exact hhalves.1
  | case3 D D' hgt k hhalves htake ih =>
      intro hlen hne hroot
      have hk : kbelow D.length = k := rfl
      rw [extractMTH, if_neg hgt, hk, if_pos hhalves, if_neg htake]
      apply ih
      · simp only [List.length_drop]; omega
      · intro hdrop
        apply hne
        have ht : D.take k = D'.take k := Decidable.of_not_not htake
        calc D = D.take k ++ D.drop k := (take_append_drop D k).symm
          _ = D'.take k ++ D'.drop k := by rw [ht, hdrop]
          _ = D' := take_append_drop D' k
      · exact hhalves.2
  | case4 D D' hgt k hhalves =>
      intro hlen hne hroot
      have h2 : 2 ≤ D.length := by omega
      have h2' : 2 ≤ D'.length := by omega
      have hkeq : kbelow D'.length = k := by rw [← hlen]
      have hk : kbelow D.length = k := rfl
      rw [extractMTH, if_neg hgt, hk, if_neg hhalves]
      have hsD : MTH D = hnode (MTH (D.take k)) (MTH (D.drop k)) := MTH_split D h2
      have hsD' : MTH D' = hnode (MTH (D'.take k)) (MTH (D'.drop k)) := by
        have := MTH_split D' h2'; rw [hkeq] at this; exact this
      refine ⟨?_, ?_⟩
      · intro hc
        injection hc with _ happ
        have hln : (MTH (D.take k)).val.length = (MTH (D'.take k)).val.length := by
          rw [(MTH (D.take k)).property, (MTH (D'.take k)).property]
        obtain ⟨e1, e2⟩ := List.append_inj happ hln
        exact hhalves ⟨Subtype.ext e1, Subtype.ext e2⟩
      · show sha256 _ = sha256 _
        have e1 : sha256 (0x01 :: ((MTH (D.take k)).val ++ (MTH (D.drop k)).val)) = MTH D :=
          hsD.symm
        have e2 : sha256 (0x01 :: ((MTH (D'.take k)).val ++ (MTH (D'.drop k)).val)) = MTH D' :=
          hsD'.symm
        rw [e1, e2]; exact hroot

/-- Permanent non-vacuity witness (re-audit discipline): on EQUAL lists
    the extractor's output is not a collision (both sides identical), so
    `extractMTH_correct`'s conclusion is false for some inputs and cannot
    be discharged by pigeonhole/choice. -/
theorem extractMTH_nonvacuous :
    ¬ IsCollision (extractMTH [([7] : List UInt8)] [([7] : List UInt8)]).1
                  (extractMTH [([7] : List UInt8)] [([7] : List UInt8)]).2 := by
  rw [extractMTH]
  simp only [List.length_singleton, if_pos (by omega : (1:Nat) ≤ 1)]
  intro hcol
  exact hcol.1 rfl

end LTLAcc