# ltl-accumulator-verified

Lean 4 mechanization of the security analysis (§6) of the paper
"The Lean Transparency Log" (https://ltl.zkdefi.org/paper): the Merkle
accumulator's own correctness and soundness theorems, kernel-checked, in
the same discipline as the four `*-ed25519-verified` subject corpora.

## Status: layer scaffold (work in progress — honest ledger below)

| layer | content | status |
|---|---|---|
| L1 | bytes, hleaf/hnode, domain separation (Lemma 1) | **done** (domsep: axiom-free) |
| L2 | MTH, Root, ConsRec definitions + termination | **done** (cones: propext, LTLAcc.sha256, Quot.sound) |
| L3 | inclusion completeness (Theorem 1) | **done** (incl_complete: propext, Classical.choice, LTLAcc.sha256, Quot.sound) |
| L4 | frontier binding content (Lemma 2) | **inlined in the extractor walk** (extractIncl); standalone receipt-uniqueness theorem queued for S4 restoration in extractor form |
| L5 | inclusion soundness = EXPLICIT extractor `extractIncl` (Theorem 2) **done, non-vacuous** |
| L6a | descent extractor `extractMTH` (Theorem 3 step 3 = Lemma 2, WHOLE-TREE instance) **done, non-vacuous** |
| — | Lemma 2, PATH instance (receipt-uniqueness of `Root`): deleted with the vacuous `root_binding` in S3.5 and **not yet restored**; optional, not needed for Theorem 3 |
| L6b | ConsRec binding + Theorem 3 assembly (extractCons) | pending (S5) |
| L6 | pin-store state machine safety (Proposition 1) | pending |

## Discipline (identical to the subject corpora)

- `verification/Proofs/` contains ZERO `axiom` declarations; the single
  sanctioned axiom site is `verification/gen/` — here, one opaque
  function: SHA-256. The theorems are constructive collision extractors,
  so collision resistance is never assumed, only interpreted.
- `verification/check.sh` is THE button: compiles every file through
  `lean-guard` (memory cap, core pinning, timeout, single-flight lock)
  and axiom-audits every certificate against its documented exact cone.
- Expected boundary: `propext, Classical.choice, Quot.sound` plus
  `LTLAcc.sha256` for hash-touching certificates — documented per
  certificate in `check.sh`, audited both directions.

The finished certificates are destined for the LTL itself as attestation
leaves: the log carrying kernel-checked proofs of its own machinery.
