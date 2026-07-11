# Response to reviewers — round 3

Corpus: `ltl-accumulator-verified`. Round-2 reviews received against the
round-2 freeze `260ad64` (GPT-5.6 second adversarial review; second
Claude round-2 findings). Every finding was independently re-verified
against the corpus before any change; all confirmed findings are fixed
in this freeze. No theorem statement changed except the one interface
tightening both reviewers requested (L1/NEW-2).

## Disposition of round-2 findings

### GPT H1 / Claude NEW-1 — coverage gate evadable (CONFIRMED, fixed structurally)

Both reviewers were right, and GPT's namespace-collision attack
(`LTLAcc.Hidden.MTH` classified against `CONES[LTLAcc.MTH]`) showed that
regex hardening (Claude's proposed fix) would not have closed the class.
We adopted GPT's required correction in full — the inventory is now
derived from the Lean environment, not from source:

- **`Proofs/Inventory.lean`** imports every corpus module and emits
  EVERY constant whose originating module is a corpus module: fully
  qualified name, declaration kind, and axiom cone. There is **no
  filtering** — compiler-generated auxiliaries and `_private.*` mangles
  are emitted and pinned too, so there is no name shape that can hide.
  A corpus module missing from the import list is an elaboration error.
- The axiom cone is computed by our own walker AND cross-checked
  in-process against core `collectAxioms` (the machinery `#print axioms`
  uses) for every constant — divergence is a hard error. (This caught a
  real toolchain subtlety during development: `ConstantInfo.value?`
  returns `none` for theorems on 4.30.0-rc2, which would have silently
  truncated cones; the direct constructor match avoids it, and the
  cross-check would have refused to ship it.)
- **`verification/inventory-allowlist.txt`** pins all 218 constants;
  **`inventory_gate.sh`** diffs environment vs allowlist fail-closed in
  BOTH directions (UNCLASSIFIED / STALE), requires the INV-COUNT
  trailer (a truncated Lean run cannot pass as an empty diff), and
  asserts the whole corpus contains exactly one axiom-kind constant:
  `LTLAcc.sha256`.
- check.sh Phase 3b additionally verifies: the inventory's module list
  == the compile manifest (both directions), every CONES entry appears
  in the allowlist **with an identical cone** (two independent cone
  computations must agree), and every CONES entry is queried by
  AxiomCheck.
- **GPT release condition 2 (adversarial tests) is met by
  `verification/selftest_audit.sh`**, which attacks the exact production
  gate: attributed, indented, private, and instance declarations, the
  nested-namespace basename collision, a smuggled axiom, a deleted
  declaration (STALE direction), and unmanifested `Proofs/` and `gen/`
  modules through the full check.sh — plus a positive control so the
  self-test cannot pass vacuously. Transcript in the kit
  (`selftest-transcript.txt`).

### GPT H2 — fidelity target could not run (CONFIRMED, fixed)

Reproduced exactly (`ModuleNotFoundError: pacta.postquantum`). The
round-3 `pacta-fidelity-target` ships the complete **load-time import
closure** of `pacta.transparency` (`__init__`, `transparency`,
`postquantum`, `signing`, `yamlio`) — all stdlib-only, so a bare
Python 3 runs it with no pip installs — content-addressed in
`MANIFEST.sha256` against pacta commit `3d81d538…` with verification
instructions (`TARGET-PROVENANCE.md`). The kit includes the complete
terminal transcript AND exit code of `run_fidelity.py` executed from a
clean extraction: exit 0, `230,271 + 230,016`, zero mismatches
(`fidelity-clean-run-transcript.txt`), plus the full green `check.sh`
transcript ending in `ATTESTATION GREEN` with fidelity not skipped
(`check-transcript.txt`) — GPT release conditions 3 and 5.

### GPT M1 — audit narrower outside Proofs/ (CONFIRMED, fixed)

- Orphan-olean guard is now recursive over the whole tree (it caught a
  stray development artifact on its first run).
- gen/ has the same unmanifested-source ("dead file") check as Proofs/.
- The axiom surface is pinned corpus-wide twice: textually (exactly one
  `axiom` line under gen/, none under Proofs/) and semantically (the
  inventory admits exactly one axiom-kind constant anywhere).
- Declaration discovery under gen/ now goes through the environment
  inventory like everything else.

### GPT M2 — stale fidelity counts in STATEMENT-MAP (CONFIRMED, fixed)

The row now reads 230,271 + 230,016 with the expanded families named.
Process note: the round-2 Claude review certified this row as already
fixed; it was not. Consistent with this project's experience, "verified"
claims by reviewers are themselves re-verified now.

### GPT M3 — "not choice-dischargeable" overclaims (CONFIRMED, fixed)

STATEMENT-MAP now uses (essentially) GPT's safer wording: the guards
show each named extractor returns a non-collision on at least one
canonical honest input, ruling out the globally-inhabited-existential
degeneration; they do NOT establish logical dependence on every
hypothesis, nor exclude other classical arguments on restricted domains.

### GPT L1 / Claude NEW-2 — redundant `hm` in `acceptIncl_sound` (CONFIRMED, fixed)

The hypothesis is gone; the range fact is derived from `hacc.1`, so the
theorem is stated purely in terms of acceptance + wrong-leaf premise.
Cone unchanged (`propext, Classical.choice, LTLAcc.sha256, Quot.sound`),
re-verified by `#print axioms` and the inventory.

### GPT ledger additions (adopted, as history)

KNOWN-GAPS gains gap 12 (audit-gate lineage: the round-2 gate was
evadable, what replaced it, and the residual limits of an
environment-derived inventory — it cannot see never-compiled source,
which the dead-file checks cover, nor defeat a hostile toolchain) and
gap 13 (the round-2 kit's fidelity target was not self-contained).

## Found in round-3 self-review (neither reviewer caught)

- **README layer table was still stale at `260ad64`**: L4 carried
  "queued for S4 restoration" and the pin-store row said "pending",
  despite round-1 F2 being certified as fixed by the round-2 Claude
  review. The table now matches the frozen state (all layers done,
  L4 explicitly "done as specializations" per gap 3).
- KNOWN-GAPS gap 2 still cited the old 164,224 count; updated.

## Round-2 Claude review, remaining notes

NEW-1 was correct in direction; we implemented the stronger
environment-based fix rather than the proposed regex broadening, since
the namespace collision defeats any basename-keyed source scan. The
round-2 Claude claim that the fidelity harness was "confirmed green
against the real pacta code" was obtained by hand-stubbing the missing
modules — with the round-3 self-contained target, that result is now
reproducible by anyone from the kit alone.

## What did NOT change

All theorem statements and proofs except the `acceptIncl_sound`
signature tightening; the axiom boundary (single opaque `sha256`); the
pinned CONES table (59 entries, all cones byte-identical to round 2);
the fidelity counts. The live transparency log remains frozen at
12 leaves (root `bcd15f9d…`) and is untouched by this round;
attestation remains blocked pending the ePrint decision, author
review, and an explicit operator order.
