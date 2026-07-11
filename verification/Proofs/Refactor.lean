/- S5.3 Fable re-audit artifact (permanent, not a throwaway probe): the
   S5.3 change of ConsRec's base from list-match to decidable `if` must be
   SEMANTICS-PRESERVING — Opus's only evidence was "the chain recompiled".
   These two theorems machine-check the equivalence against the exact
   list-match forms that were replaced, so the refactor's faithfulness is
   a permanent, cone-audited guarantee.

   PROVENANCE (verified against git history, not memory): the RHS forms
   below are verbatim the base of `ConsRec` at commit cfde9b2 (pre-
   refactor), and `git diff cfde9b2 8795e82 -- Proofs/Basic.lean` shows
   the refactor touched ONLY those eight base lines. Unchanged remainder
   (git) + equal base (kernel) = the whole function is unchanged. -/
import Proofs.Basic

namespace LTLAcc

/-- b=false base: decidable-if form = the original `[s]` list-match. -/
theorem consRec_base_false_eq (C : List Hash) :
    (if C.length = 1 then some ((C.getLastD default, C.getLastD default) : Hash × Hash) else none)
    = (match C with | [s] => some (s, s) | _ => none) := by
  cases C with
  | nil => rfl
  | cons a t => cases t with | nil => rfl | cons b u => simp

/-- b=true base: decidable-if form = the original `[]` list-match. -/
theorem consRec_base_true_eq (C : List Hash) (r : Hash) :
    (if C = [] then some ((r, r) : Hash × Hash) else none)
    = (match C with | [] => some (r, r) | _ => none) := by
  cases C with
  | nil => rfl
  | cons a t => rfl

end LTLAcc
