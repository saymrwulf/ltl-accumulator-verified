# Known gaps and scope boundaries (honest ledger)

Deliberate, documented, and none silent. Reviewers should verify this
list is COMPLETE, not merely that the items are acceptable.

1. **SHA-256 is opaque** — the single boundary axiom (`LTLAcc.sha256`),
   by design identical to the paper's posture: soundness theorems
   construct collisions, never assume collision resistance.
2. **No consistency-completeness theorem** (honest ConsRec acceptance).
   Matches the paper (its Theorem 1 is inclusion-only); honest
   consistency behavior is covered by the fidelity harness's honest
   cases (within the 230,016-case consistency agreement with the
   deployed verifier).
3. **Lemma 2 is mechanized as specializations, not as one general
   theorem.** The paper's Lemma 2 is a single statement quantified over
   an abstract hash-fold `F` and a connected subtree `S`. The corpus has
   no hash-fold datatype/predicate; it proves the needed instances
   directly — whole-tree (`extractMTH_correct`), ConsRec
   (`consRecBinding`), inclusion (`extractIncl_correct`), and the width
   fact (`hnode_preimage_inj`). These suffice for Theorems 2–3. Two
   consequences: (a) the abstract lemma itself is not a mechanized
   object; (b) the path-instance receipt-uniqueness for `Root` (removed
   with the vacuous `root_binding`) is not restored — optional, unused.
   Any paper claim that "Lemma 2 is mechanized" must read "its
   specializations sufficient for Theorems 2–3 are mechanized." 
4. **Signature layer abstract** — Ed25519 EUF-CMA, the poison/evidence
   retention state, and transferability of fork evidence (paper Prop
   1(2)) are not modeled; `fork_distinct` is the Merkle-layer share only.
5. **Transliteration bridge** — `fidelity/lean_defs.py` mirrors the Lean
   definitions by quoted-source inspection (the Lean defs are
   noncomputable over the opaque hash, so the bridge cannot be #eval'd
   closed). Same inspection bridge the paper's own harness uses.
6. **Proposition 2 (verdict integrity) out of scope** — per paper §10's
   mechanization list (i–v). It is a property of the consumer tooling's
   construction, enforced and regression-tested in the pacta repo.
7. **Multi-step pin monotonicity** — mechanized per-step
   (`pinAccept_monotone`); the paper's multi-step chain is its
   reflexive-transitive iterate, not separately mechanized.
8. **Process history** (candor): three cone pins were guessed (not read)
   during S5.3–S6 and the audit's failure went unnoticed until S7
   because green was claimed from tailed output rather than the exit
   code. No theorem was affected (kernel-checked throughout); pins were
   corrected, the audit surface defined, and the standing rule is now:
   exit code + ALL GREEN, cones read from #print axioms only.

9. **Asymptotic cost not mechanized.** Paper Theorems 2 and 3 assert the
   extractors run in `O(n)` / `O(n₁)` hash evaluations. The mechanization
   proves functional correctness of the named extractors only — no cost
   semantics, recurrence, or computability-after-hash-instantiation. (The
   extractors are `noncomputable` over the opaque `sha256`.)
10. **Pin-store initialization from the empty pin not modeled**, and
   `pin_prefix_correct` assumes `0 < n`. Trust-on-first-use / the size-0
   initial state is a separate operation; the theorems cover transitions
   from a positive-size pin. (Related to gap 7's per-step scoping.)
11. **acceptIncl now named (was review F1).** The consumer's inclusion
   acceptance `m < n ∧ Root … = some r` is now the Lean object
   `acceptIncl`, with `acceptIncl_complete`/`acceptIncl_sound` routing
   completeness/soundness through it, and the fidelity harness exercises
   the out-of-range families (`m ≥ n`). `Root` alone still accepts
   out-of-range `m`; that is by design (it is the reconstruction, not the
   accept predicate).
12. **Audit-gate lineage** (candor; was round-2 GPT H1 / Claude NEW-1,
   both round-1 "fail-closed" claims were overclaims). The round-2
   coverage gate enumerated declarations with a source regex and was
   evadable (attributes, indentation, private/protected, `instance`,
   nested-namespace basename collisions). Round 3 replaced it with an
   environment-derived inventory (`Proofs/Inventory.lean` +
   `inventory-allowlist.txt`, fully-qualified names, no filtering) and
   `selftest_audit.sh`, which runs the published evasion table plus a
   namespace collision, an axiom smuggle, a stale-entry case, and two
   unmanifested-module cases against the exact production gate.
   Residual honesty: the inventory sees what the compiled environment
   contains; it cannot see source that is never compiled (which the
   dead-file checks cover) or defeat a hostile Lean toolchain.
13. **Review-kit fidelity target was not self-contained in round 2**
   (GPT H2: missing load-time imports made `run_fidelity.py` unrunnable
   from the kit). Round 3 ships the complete stdlib-only import closure
   of `pacta.transparency`, content-addressed against pacta commit
   `3d81d53`, plus the clean-extraction transcript with exit code.
