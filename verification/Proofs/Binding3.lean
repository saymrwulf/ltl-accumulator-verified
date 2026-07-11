/- S5.3 — consRecBinding: the paper's Theorem 3 steps 1-2, as a statement
   about the extractor's output. Under the maintained value-equality
   invariant `y = MTH D₁`, an accepting ConsRec fold either makes
   `extractConsNode` output a genuine collision, or its first component is
   the honest prefix root `MTH (D₁.take n₀)`. -/
import Proofs.Consistency

namespace LTLAcc

theorem take_all (l : List Bytes) (n : Nat) (h : l.length = n) : l.take n = l := by
  subst h; exact List.take_length

theorem consRecBinding (r : Hash) :
    ∀ (n₀ n : Nat) (C : List Hash) (b : Bool) (D₁ : List Bytes) (x y : Hash),
      D₁.length = n → 0 < n₀ → n₀ ≤ n →
      ConsRec n₀ n C b r = some (x, y) → y = MTH D₁ →
      (match extractConsNode n₀ n C b r D₁ with
       | some c => IsCollision c.1 c.2
       | none => x = MTH (D₁.take n₀)) := by
  intro n₀ n C b
  induction n₀, n, C, b using ConsRec.induct r with
  | case1 n =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons; simp at hcons
      obtain ⟨hx, hyr⟩ := hcons
      have hext : extractConsNode n n [] true r D₁ = none := by rw [extractConsNode]; simp
      simp only [hext]
      rw [← hx, hyr, hy, take_all D₁ n hlen]
  | case2 n C hCne =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons; simp [hCne] at hcons
  | case3 n C b hb hC1 =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons; simp [hb, hC1] at hcons
      obtain ⟨hx, hyr⟩ := hcons
      have hext : extractConsNode n n C b r D₁ = none := by rw [extractConsNode]; simp
      simp only [hext]
      rw [← hx, hyr, hy, take_all D₁ n hlen]
  | case4 n C b hb hC1 =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons; simp [hb, hC1] at hcons
  | case5 n₀ n C b hne hrej =>
      intro D₁ x y hlen hn0 hle hcons hy
      exfalso; omega
  | case6 n₀ n C b hne hrej hgl =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons
      simp only [if_neg hne, if_neg hrej, hgl] at hcons
      exact absurd hcons (by simp)
  | case7 n₀ n C b hne hrej s hgl k hle2 hsubnone _ih =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons
      have hk : kbelow n = k := rfl
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_pos hle2, hsubnone] at hcons
      exact absurd hcons (by simp)
  | case8 n₀ n C b hne hrej s hgl k hle2 xx yy hsub ih =>
      intro D₁ x y hlen hn0 hle hcons hy
      have h2 : 2 ≤ n := by omega
      have hk : kbelow n = k := rfl
      have hkl : k < n := by rw [← hk]; exact kbelow_lt n h2
      rw [ConsRec] at hcons
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_pos hle2, hsub,
        Option.some.injEq, Prod.mk.injEq] at hcons
      obtain ⟨hx, hyv⟩ := hcons
      have hsplit : MTH D₁ = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := by
        have := MTH_split D₁ (by omega); rw [hlen, hk] at this; exact this
      have hnodeeq : hnode yy s = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := by
        rw [hyv, hy, hsplit]
      have htklen : (D₁.take k).length = k := by rw [List.length_take, hlen]; omega
      rw [extractConsNode]
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_pos hle2]
      have hy' : (Option.map Prod.snd (ConsRec n₀ k C.dropLast b r)).getD default = yy := by
        rw [hsub]; rfl
      rw [hy']
      by_cases hpair : yy = MTH (D₁.take k) ∧ s = MTH (D₁.drop k)
      · simp only [if_pos hpair]
        have hih := ih (D₁.take k) xx yy htklen hn0 hle2 hsub hpair.1
        cases hrec : extractConsNode n₀ k C.dropLast b r (D₁.take k) with
        | some c => rw [hrec] at hih; exact hih
        | none =>
            rw [hrec] at hih
            have htt : (D₁.take k).take n₀ = D₁.take n₀ := by
              rw [List.take_take]; congr 1; omega
            rw [← hx, hih, htt]
      · simp only [if_neg hpair]
        refine ⟨?_, ?_⟩
        · intro hc
          injection hc with _ happ
          have hln : yy.val.length = (MTH (D₁.take k)).val.length := by
            rw [yy.property, (MTH (D₁.take k)).property]
          obtain ⟨e1, e2⟩ := List.append_inj happ hln
          exact hpair ⟨Subtype.ext e1, Subtype.ext e2⟩
        · show sha256 _ = sha256 _
          have el : sha256 (0x01 :: (yy.val ++ s.val)) = hnode yy s := rfl
          have er : sha256 (0x01 :: ((MTH (D₁.take k)).val ++ (MTH (D₁.drop k)).val))
              = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := rfl
          rw [el, er, hnodeeq]
  | case9 n₀ n C b hne hrej s hgl k hle2 hsubnone _ih =>
      intro D₁ x y hlen hn0 hle hcons hy
      rw [ConsRec] at hcons
      have hk : kbelow n = k := rfl
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_neg hle2, hsubnone] at hcons
      exact absurd hcons (by simp)
  | case10 n₀ n C b hne hrej s hgl k hle2 xx yy hsub ih =>
      intro D₁ x y hlen hn0 hle hcons hy
      have h2 : 2 ≤ n := by omega
      have hk : kbelow n = k := rfl
      have hkl : k < n := by rw [← hk]; exact kbelow_lt n h2
      have hkp : 0 < k := by rw [← hk]; exact kbelow_pos n
      rw [ConsRec] at hcons
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_neg hle2, hsub,
        Option.some.injEq, Prod.mk.injEq] at hcons
      obtain ⟨hx, hyv⟩ := hcons
      have hsplit : MTH D₁ = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := by
        have := MTH_split D₁ (by omega); rw [hlen, hk] at this; exact this
      have hnodeeq : hnode s yy = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := by
        rw [hyv, hy, hsplit]
      have hdklen : (D₁.drop k).length = n - k := by rw [List.length_drop, hlen]
      rw [extractConsNode]
      simp only [if_neg hne, if_neg hrej, hgl, hk, if_neg hle2]
      have hy' : (Option.map Prod.snd (ConsRec (n₀ - k) (n - k) C.dropLast false r)).getD default = yy := by
        rw [hsub]; rfl
      rw [hy']
      by_cases hpair : s = MTH (D₁.take k) ∧ yy = MTH (D₁.drop k)
      · simp only [if_pos hpair]
        have hih := ih (D₁.drop k) xx yy hdklen (by omega) (by omega) hsub hpair.2
        cases hrec : extractConsNode (n₀ - k) (n - k) C.dropLast false r (D₁.drop k) with
        | some c => rw [hrec] at hih; exact hih
        | none =>
            rw [hrec] at hih
            have hn2 : 2 ≤ n₀ := by omega
            have hkbn0 : kbelow n₀ = k := kbelow_prefix_eq h2 hk.symm (by omega) hle
            have htn0len : (D₁.take n₀).length = n₀ := by rw [List.length_take, hlen]; omega
            have hspn0 : MTH (D₁.take n₀)
                = hnode (MTH ((D₁.take n₀).take k)) (MTH ((D₁.take n₀).drop k)) := by
              have := MTH_split (D₁.take n₀) (by omega); rw [htn0len, hkbn0] at this; exact this
            rw [take_take_le D₁ k n₀ (by omega), take_drop_prefix D₁ k n₀] at hspn0
            rw [← hx, hspn0, hpair.1, hih]
      · simp only [if_neg hpair]
        refine ⟨?_, ?_⟩
        · intro hc
          injection hc with _ happ
          have hln : s.val.length = (MTH (D₁.take k)).val.length := by
            rw [s.property, (MTH (D₁.take k)).property]
          obtain ⟨e1, e2⟩ := List.append_inj happ hln
          exact hpair ⟨Subtype.ext e1, Subtype.ext e2⟩
        · show sha256 _ = sha256 _
          have el : sha256 (0x01 :: (s.val ++ yy.val)) = hnode s yy := rfl
          have er : sha256 (0x01 :: ((MTH (D₁.take k)).val ++ (MTH (D₁.drop k)).val))
              = hnode (MTH (D₁.take k)) (MTH (D₁.drop k)) := rfl
          rw [el, er, hnodeeq]

end LTLAcc
