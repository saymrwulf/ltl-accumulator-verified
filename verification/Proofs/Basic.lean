/- L1 + L2 of the accumulator pyramid: byte-level hashing shapes, domain
   separation (paper Lemma 1), the split point, and the three §5.3
   definitions (MTH, Path-dual Root, ConsRec) with their termination.

   Everything here is stated over the opaque `sha256` of gen/ — no
   property of the hash is used anywhere in this file. -/
import LTLAcc.HashExternal

namespace LTLAcc

abbrev Bytes := List UInt8

/-- Leaf hash: `H(0x00 ‖ d)` (paper §5.3). -/
noncomputable def hleaf (d : Bytes) : Hash := sha256 (0x00 :: d)

/-- Node hash: `H(0x01 ‖ x ‖ y)` (paper §5.3). Arguments are 32-byte
    hash values, so the preimage determines the argument pair — the
    load-bearing width fact of the paper's Lemma 2. -/
noncomputable def hnode (x y : Hash) : Hash := sha256 (0x01 :: (x.val ++ y.val))

/-- Preimage-level pair injectivity: equal `hnode` PREIMAGES force equal
    argument pairs, because both components are exactly 32 bytes. -/
theorem hnode_preimage_inj {x y X Y : Hash}
    (h : (0x01 : UInt8) :: (x.val ++ y.val) = 0x01 :: (X.val ++ Y.val)) :
    x = X ∧ y = Y := by
  injection h with _ happ
  have hlen : x.val.length = X.val.length := by rw [x.property, X.property]
  have := List.append_inj happ hlen
  exact ⟨Subtype.ext this.1, Subtype.ext this.2⟩

/-- **Lemma 1 (Domain separation), preimage form**: no leaf preimage
    equals a node preimage as a byte string — the first byte differs. -/
theorem domsep (d x y : Bytes) :
    (0x00 : UInt8) :: d ≠ (0x01 : UInt8) :: (x ++ y) := by
  intro h
  injection h with h0 _
  exact absurd h0 (by decide)

/-- Largest power of two STRICTLY below `n`, for `n ≥ 2` (RFC 9162's
    split point `k`; values at `n ≤ 1` are irrelevant and default to 1). -/
def kbelow (n : Nat) : Nat :=
  if n ≤ 2 then 1
  else 2 * kbelow ((n + 1) / 2)
termination_by n
decreasing_by omega

theorem kbelow_pos (n : Nat) : 0 < kbelow n := by
  induction n using kbelow.induct with
  | case1 n h => rw [kbelow]; simp [h]
  | case2 n h ih => rw [kbelow]; simp [h]; omega

theorem kbelow_lt (n : Nat) (h : 2 ≤ n) : kbelow n < n := by
  induction n using kbelow.induct with
  | case1 n hle => rw [kbelow]; simp only [if_pos hle]; omega
  | case2 n hgt ih =>
      rw [kbelow]
      simp only [if_neg hgt]
      have h2 : 2 ≤ (n + 1) / 2 := by omega
      have := ih h2
      omega

theorem le_two_kbelow (n : Nat) (h : 2 ≤ n) : n ≤ 2 * kbelow n := by
  induction n using kbelow.induct with
  | case1 n hle => rw [kbelow]; simp only [if_pos hle]; omega
  | case2 n hgt ih =>
      rw [kbelow]
      simp only [if_neg hgt]
      have h2 : 2 ≤ (n + 1) / 2 := by omega
      have := ih h2
      omega

/-- `kbelow` is a genuine power of two. Together with `kbelow_lt` and
    `le_two_kbelow` (`2^j = k < n ≤ 2k = 2^(j+1)`) this pins `kbelow n`
    as THE largest power of two strictly below `n` — the RFC 9162 split
    point, uniquely determined. -/
theorem kbelow_pow2 (n : Nat) : ∃ j, kbelow n = 2 ^ j := by
  induction n using kbelow.induct with
  | case1 n hle => exact ⟨0, by rw [kbelow]; simp only [if_pos hle]⟩
  | case2 n hgt ih =>
      obtain ⟨j, hj⟩ := ih
      refine ⟨j + 1, ?_⟩
      rw [kbelow]
      simp only [if_neg hgt]
      rw [hj, Nat.pow_succ, Nat.mul_comm]

/-- `MTH` (paper §5.3): the RFC 9162 tree head over a leaf-data list.
    `MTH [] = H(ε)`, `MTH [d] = hleaf d`, and for `n ≥ 2` the split at
    `k = kbelow n`. -/
noncomputable def MTH (D : List Bytes) : Hash :=
  if _h0 : D.length = 0 then sha256 []
  else if _h1 : D.length = 1 then hleaf (D.headD [])
  else
    hnode (MTH (D.take (kbelow D.length))) (MTH (D.drop (kbelow D.length)))
termination_by D.length
decreasing_by
  · -- take-branch: k < n
    simp only [List.length_take]
    have h2 : 2 ≤ D.length := by omega
    have hk := kbelow_lt D.length h2
    omega
  · -- drop-branch: n - k < n
    simp only [List.length_drop]
    have h2 : 2 ≤ D.length := by omega
    have hk := kbelow_lt D.length h2
    have hp := kbelow_pos D.length
    omega

/-- `Root` (paper §5.3 / Appendix B): the consumer's root reconstruction.
    `none` = rejection on any length mismatch, exactly as deployed. -/
noncomputable def Root (v : Hash) (m n : Nat) (P : List Hash) : Option Hash :=
  if n = 1 then
    (if P = [] then some v else none)
  else if n = 0 then none
  else
    match P.getLast? with
    | none => none
    | some s =>
        let k := kbelow n
        if m < k then
          match Root v m k P.dropLast with
          | none => none
          | some x => some (hnode x s)
        else
          match Root v (m - k) (n - k) P.dropLast with
          | none => none
          | some x => some (hnode s x)
termination_by n
decreasing_by
  · have h2 : 2 ≤ n := by omega
    exact kbelow_lt n h2
  · have := kbelow_pos n
    omega

/-- `ConsRec` (paper §5.3): the recursive consistency verifier. Returns
    the reconstructed pair (old root, new root); `none` = shape
    mismatch. The flag `b` records whether the size-`n₀` subtree root is
    carried implicitly (the pinned root `r`) or explicitly in `C`. -/
noncomputable def ConsRec (n₀ n : Nat) (C : List Hash) (b : Bool) (r : Hash) :
    Option (Hash × Hash) :=
  if n₀ = n then
    if b then
      (if C = [] then some (r, r) else none)
    else
      (if C.length = 1 then some (C.getLastD default, C.getLastD default) else none)
  else if n₀ > n ∨ n₀ = 0 ∨ n ≤ 1 then none
  else
    match C.getLast? with
    | none => none
    | some s =>
        let k := kbelow n
        if n₀ ≤ k then
          match ConsRec n₀ k C.dropLast b r with
          | none => none
          | some (x, y) => some (x, hnode y s)
        else
          match ConsRec (n₀ - k) (n - k) C.dropLast false r with
          | none => none
          | some (x, y) => some (hnode s x, hnode s y)
termination_by n
decreasing_by
  · have h2 : 2 ≤ n := by omega
    exact kbelow_lt n h2
  · have := kbelow_pos n
    omega

/-- The consumer's acceptance predicate for a consistency proof between
    pinned head `(n₀, r₀)` and offered head `(n₁, r₁)` (paper §5.3). -/
def acceptCons (n₀ n₁ : Nat) (r₀ r₁ : Hash) (C : List Hash) : Prop :=
  n₀ = 0 ∨ ConsRec n₀ n₁ C true r₀ = some (r₀, r₁)

end LTLAcc
