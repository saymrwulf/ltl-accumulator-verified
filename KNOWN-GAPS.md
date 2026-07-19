# Known gaps and scope boundaries (honest ledger)

**Numbering note (2026-07-19):** "paper §N" references in this ledger
use the archived system report's numbering ("The Lean Transparency
Log", https://ltl.zkdefi.org/paper/v0.2), which this corpus was built
against. The current paper at /paper has a different structure; in
particular its §5.3/§5.4 are unrelated to the §5.3/§5.4 cited in gap
14/15 below.

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
14. **Deployed `verify_consistency` accepts strictly more than the
   mechanized `ConsRec` on lied-size inputs** (round-3 Claude addendum
   F1*, reproduced by the operator against deployed pacta). Witness:
   for the honest proof P between sizes 2→3, `verify_consistency(1, 3,
   R2, R3, P)` returns True — a semantically false claim ("R2 is the
   root of a size-1 prefix") — while `ConsRec` rejects; 3,405 such
   divergences exist for n < 60, ALL one-sided (the mechanized model
   never accepts anything the deployed verifier rejects; inclusion
   shows zero divergences under identical abuse). Mechanism: when the
   claimed old size is a power of two, the deployed RFC 9162 iterative
   algorithm seeds the walk with the old root and uses the sizes only
   as bit-navigation state, so several size claims navigate one proof
   identically. Consequences: (a) fidelity between the two consistency
   verifiers is agreement over the pinned case families, NOT
   extensional equality — the harness's lied-size family pins the
   boundary (73,573 cases: lied old size exhaustive for n < 60, lied
   new size at fixed offsets n−1/n+1/n+7; 3,867 expected divergences,
   direction asserted one-sided per case); (b) Theorem 3 /
   `acceptCons_sound` cover the MECHANIZED accept set. The exhibited
   divergence is outside the intended pin-store input invariant;
   applying the mechanized soundness result to the deployed flow
   therefore additionally ASSUMES that the deployed state machine
   always binds each root to its authentic size and exposes no
   alternate invocation path — an invariant that is NOT mechanized in
   this corpus (gap 15). Where the invariant's witnesses live: paper
   §5.3 (the signed head binds `(n₁, r₁)` together under one
   signature) and §5.4 (the pin `(n₀, r₀)` comes from the consumer's
   own store, never from the peer), implemented in the pacta repo at
   `src/pacta/sthstore.py` and `src/pacta/logclient.py` — code OUTSIDE
   the supplied fidelity target (review R4-3/GPT-4). No exploitability
   against that flow is claimed or ruled out here; assessing it
   requires the signature/STH layer (gap 4). No pacta code change is
   made (deployed behavior matches upstream RFC 9162 implementations).
15. **Deployment refinement invariant unmechanized** (round-4 GPT, its
   principal finding — split out from gap 14 because it carries the
   deployed-soundness claim). The corpus proves soundness of the
   mechanized `acceptCons`; it does NOT prove the refinement
   `AuthenticPair(n₀,r₀,D₀) ∧ AuthenticPair(n₁,r₁,D₁) ∧
   verify_consistency(…) → acceptCons(…)`. The operational invariant
   (authentic-size/root binding via the signed-head + pin-store flow)
   is relied upon but unverified, and the consumer flow implementing it
   is not in the supplied fidelity target. Consequently any attestation
   of this corpus must be scoped to the MECHANIZED model: "the deployed
   consistency verifier is formally verified" is NOT a claim this
   corpus supports. Closure paths (roadmap, operator decision, post
   paper-freeze): (A) make the deployed verifier adopt
   ConsRec-equivalent acceptance; or (B) mechanize the signed-head +
   pin-store state machine and prove the refinement; or (C) keep the
   boundary and this scoped claim permanently.
