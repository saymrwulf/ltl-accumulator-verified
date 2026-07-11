/- S5 (stage 1) — infrastructure for consistency soundness (paper Theorem 3,
   steps 1-2). The binding argument needs one non-obvious arithmetic fact and
   two list-surgery facts, isolated and proven here before the main proof.

   Arithmetic: when the pinned prefix of size n₀ spills past the left subtree
   (k < n₀ ≤ n, k = kbelow n), the honest tree of `D₁.take n₀` splits at the
   SAME point k. That is `kbelow n₀ = k`, and it holds because k is a power of
   two with k < n₀ ≤ 2k, which pins kbelow uniquely. -/
import Proofs.Descent

namespace LTLAcc

/-- Two powers of two both lying in `(m/2, m]` (i.e. `2^a < m ≤ 2^(a+1)`)
    have the same exponent. -/
theorem pow2_exp_unique {a j m : Nat}
    (ha : 2^a < m) (ha2 : m ≤ 2^(a+1)) (hj : 2^j < m) (hj2 : m ≤ 2^(j+1)) :
    a = j := by
  rcases Nat.lt_trichotomy a j with h | h | h
  · -- a < j ⇒ a+1 ≤ j ⇒ 2^(a+1) ≤ 2^j < m, contradicting m ≤ 2^(a+1)
    have : a + 1 ≤ j := h
    have hle : 2^(a+1) ≤ 2^j := Nat.pow_le_pow_right (by omega) this
    omega
  · exact h
  · have : j + 1 ≤ a := h
    have hle : 2^(j+1) ≤ 2^a := Nat.pow_le_pow_right (by omega) this
    omega

/-- `kbelow` is pinned by its defining inequalities: a power of two `p`
    with `p < m ≤ 2p` IS `kbelow m`. -/
theorem kbelow_eq_of_pow2_between {p m : Nat} (j : Nat) (hp : p = 2^j)
    (h1 : p < m) (h2 : m ≤ 2 * p) : kbelow m = p := by
  have hm2 : 2 ≤ m := by
    have : 1 ≤ p := by rw [hp]; exact Nat.one_le_two_pow
    omega
  obtain ⟨a, ha⟩ := kbelow_pow2 m
  have hlt := kbelow_lt m hm2
  have hle := le_two_kbelow m hm2
  -- kbelow m = 2^a with 2^a < m ≤ 2^(a+1); p = 2^j with 2^j < m ≤ 2^(j+1)
  rw [ha] at hlt hle
  have hj2 : m ≤ 2^(j+1) := by rw [Nat.pow_succ]; omega
  have ha2 : m ≤ 2^(a+1) := by rw [Nat.pow_succ]; omega
  have hja : 2^j < m := by omega
  have : a = j := pow2_exp_unique hlt ha2 hja hj2
  rw [ha, this, ← hp]

/-- The specialization used in the binding: with `k = kbelow n`, `2 ≤ n`,
    and `k < n₀ ≤ n`, the prefix tree splits at the same `k`. -/
theorem kbelow_prefix_eq {n n₀ : Nat} (hn : 2 ≤ n)
    (hk : k = kbelow n) (hlo : k < n₀) (hhi : n₀ ≤ n) :
    kbelow n₀ = k := by
  obtain ⟨j, hj⟩ := kbelow_pow2 n
  rw [← hk] at hj
  have hle := le_two_kbelow n hn
  rw [← hk] at hle
  exact kbelow_eq_of_pow2_between j hj hlo (by omega)

/-! ### list surgery -/

theorem take_take_le (l : List Bytes) (k n₀ : Nat) (h : k ≤ n₀) :
    (l.take n₀).take k = l.take k := by
  rw [List.take_take]; congr 1; omega

theorem take_drop_prefix (l : List Bytes) (k n₀ : Nat) :
    (l.take n₀).drop k = (l.drop k).take (n₀ - k) := by
  rw [List.drop_take]

/-! ### the consistency collision extractor (paper Theorem 3, steps 1-2) -/

/-- Walk the `ConsRec` fold in parallel with the honest size-`n` tree of
    `D₁`. At each level the new-root component builds `hnode` of a left and
    a right value; compare that argument pair against the honest node
    `hnode (MTH (D₁.take k)) (MTH (D₁.drop k))`. Return `some` concrete
    colliding preimage pair at the first mismatch (steps 1-2 of Theorem 3),
    or `none` if the fold is genuine all the way down — in which case the
    binding `x = MTH (D₁.take n₀)` holds (proven in stage 3). -/
noncomputable def extractConsNode (n₀ n : Nat) (C : List Hash) (b : Bool)
    (r : Hash) (D₁ : List Bytes) : Option (List UInt8 × List UInt8) :=
  if n₀ = n then none
  else if n₀ > n ∨ n₀ = 0 ∨ n ≤ 1 then none
  else
    match C.getLast? with
    | none => none
    | some s =>
        let k := kbelow n
        if n₀ ≤ k then
          let y' := ((ConsRec n₀ k C.dropLast b r).map Prod.snd).getD default
          if y' = MTH (D₁.take k) ∧ s = MTH (D₁.drop k) then
            extractConsNode n₀ k C.dropLast b r (D₁.take k)
          else
            some (0x01 :: (y'.val ++ s.val),
                  0x01 :: ((MTH (D₁.take k)).val ++ (MTH (D₁.drop k)).val))
        else
          let y' := ((ConsRec (n₀ - k) (n - k) C.dropLast false r).map Prod.snd).getD default
          if s = MTH (D₁.take k) ∧ y' = MTH (D₁.drop k) then
            extractConsNode (n₀ - k) (n - k) C.dropLast false r (D₁.drop k)
          else
            some (0x01 :: (s.val ++ y'.val),
                  0x01 :: ((MTH (D₁.take k)).val ++ (MTH (D₁.drop k)).val))
termination_by n
decreasing_by
  · have h2 : 2 ≤ n := by omega
    exact kbelow_lt n h2
  · have := kbelow_pos n
    omega

end LTLAcc
