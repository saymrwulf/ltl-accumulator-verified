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

end LTLAcc
