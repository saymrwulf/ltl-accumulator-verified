/- Environment-derived declaration inventory (Phase 3b of check.sh).

   Review round 2 (GPT H1) proved the previous source-regex enumerator
   evadable: attributed / private / indented / `instance` declarations
   were invisible, and a nested `namespace Hidden theorem MTH` collided
   with the basename of an audited declaration. This module replaces
   source scanning entirely: the inventory is read from the compiled
   Lean ENVIRONMENT, so it sees exactly what the kernel saw.

   Design (fail-closed by construction):
   · The corpus module list below must match check.sh's compile
     manifest (check.sh verifies this textually, both directions).
     A listed module that is not actually imported is an elaboration
     ERROR here, not a silent skip.
   · EVERY constant whose originating module is a corpus module is
     emitted — fully qualified, NO filtering. Compiler-generated
     auxiliaries (equation lemmas, match/eq/induct helpers, private
     mangles) are emitted too and pinned in the allowlist; anything
     new, renamed, or removed shows up as a diff. There is no name
     shape that can hide.
   · Each constant carries its declaration KIND and its full axiom
     cone, computed by the independent walker below (not by
     #print axioms — Phase 3 still runs #print axioms separately, so
     the two cone computations cross-check each other in check.sh).
   · Output lines are prefixed `INV|` and sorted, so check.sh can
     extract them robustly from compiler chatter.

   This file is audit INFRASTRUCTURE, not corpus: it is excluded from
   the compile manifest (like AxiomCheck.lean) and its own constants
   are not inventoried (they live in the current module, which has no
   module index). It proves nothing and is imported by nothing. -/
import Lean
import LTLAcc.HashExternal
import Proofs.Basic
import Proofs.Completeness
import Proofs.Extract
import Proofs.Descent
import Proofs.Consistency
import Proofs.Binding3
import Proofs.Refactor
import Proofs.Theorem3
import Proofs.PinStore

open Lean

namespace LTLAccAudit

/-- Exactly check.sh's GEN_MODULES ++ PROOFS, as module names. -/
def corpusModules : Array Name :=
  #[`LTLAcc.HashExternal,
    `Proofs.Basic, `Proofs.Completeness, `Proofs.Extract, `Proofs.Descent,
    `Proofs.Consistency, `Proofs.Binding3, `Proofs.Refactor,
    `Proofs.Theorem3, `Proofs.PinStore]

def kindOf : ConstantInfo → String
  | .axiomInfo  _ => "axiom"
  | .defnInfo   _ => "def"
  | .thmInfo    _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo   _ => "quot"
  | .inductInfo _ => "inductive"
  | .ctorInfo   _ => "ctor"
  | .recInfo    _ => "recursor"

/-- Proof/definition body of a constant. NOTE: `ConstantInfo.value?`
    returns `none` for theorems on this toolchain (observed on
    4.30.0-rc2), which would silently truncate every cone at the first
    theorem — so we match constructors directly. The cross-check against
    core `collectAxioms` below would catch any such truncation. -/
def valueOf : ConstantInfo → Option Expr
  | .defnInfo   v => some v.value
  | .thmInfo    v => some v.value
  | .opaqueInfo v => some v.value
  | _             => none

/-- Full axiom cone of `root`: transitive closure over types AND values.
    Written independently of core's `CollectAxioms`; the `#eval` below
    insists both agree on every constant, and Phase 3 of check.sh
    additionally cross-checks the audited names against `#print axioms`
    output. -/
def axiomCone (env : Environment) (root : Name) : Array Name := Id.run do
  let mut visited : NameSet := {}
  let mut axioms  : Array Name := #[]
  let mut stack   : Array Name := #[root]
  while h : stack.size > 0 do
    let n := stack[stack.size - 1]'(by omega)
    stack := stack.pop
    unless visited.contains n do
      visited := visited.insert n
      if let some ci := env.find? n then
        if ci matches .axiomInfo _ then
          axioms := axioms.push n
        stack := stack ++ ci.type.getUsedConstants
        if let some v := valueOf ci then
          stack := stack ++ v.getUsedConstants
  return (axioms.qsort (fun a b => a.toString < b.toString))

#eval show CoreM Unit from do
  let env ← getEnv
  -- Resolve every corpus module to its index; a miss is a hard error.
  let mut idxs : Array Nat := #[]
  for m in corpusModules do
    match env.getModuleIdx? m with
    | some i => idxs := idxs.push i
    | none   => throwError "INVENTORY ERROR: corpus module {m} is not imported"
  let mut lines : Array String := #[]
  for (n, ci) in env.constants.toList do
    if let some i := env.getModuleIdxFor? n then
      if idxs.contains i then
        let cone := axiomCone env n
        -- Cross-check against core's collector (the same machinery
        -- `#print axioms` uses): any divergence is a hard error.
        let coreCone := (← collectAxioms n).qsort (fun a b => a.toString < b.toString)
        unless cone == coreCone do
          throwError "INVENTORY ERROR: cone divergence on {n}: walker={cone} core={coreCone}"
        let coneStr := ",".intercalate (cone.toList.map (·.toString))
        lines := lines.push s!"INV|{n}|{kindOf ci}|{coneStr}"
  let sorted := lines.qsort (· < ·)
  for l in sorted do
    IO.println l
  IO.println s!"INV-COUNT|{sorted.size}"

end LTLAccAudit
