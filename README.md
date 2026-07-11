# ltl-accumulator-verified

Lean 4 mechanization of the security analysis (§6) of the paper
"The Lean Transparency Log" (https://ltl.zkdefi.org/paper): the Merkle
accumulator's own correctness and soundness theorems, kernel-checked, in
the same discipline as the four `*-ed25519-verified` subject corpora.

## Status: **FROZEN for external review** (corpus complete)

All paper-§10 mechanization targets are kernel-checked; the audit surface
is defined and green (`verification/check.sh`, exit 0). See
[STATEMENT-MAP.md](STATEMENT-MAP.md) for the paper↔Lean review surface and
[KNOWN-GAPS.md](KNOWN-GAPS.md) for the honest scope ledger.
Revised after review round 1 (GPT-5.6 + second Claude) and round 2:
the audit surface is now an environment-derived inventory
(`Proofs/Inventory.lean` + pinned allowlist, self-tested by
`selftest_audit.sh`), the review kit's fidelity target is
self-contained, `acceptIncl` routes Theorems 1–2, fidelity families
extended (230,271 / 230,016). No changes until the external review
completes. The finished certificates' attestation into the LTL is a
separate, explicitly-authorized operator decision.

| layer | content | status |
|---|---|---|
| L1 | bytes, hleaf/hnode, domain separation (Lemma 1) | **done** (domsep: axiom-free) |
| L2 | MTH, Root, ConsRec definitions + termination | **done** (cones: propext, LTLAcc.sha256, Quot.sound) |
| L3 | inclusion completeness (Theorem 1) + named acceptance `acceptIncl` | **done** (incl_complete: propext, Classical.choice, LTLAcc.sha256, Quot.sound) |
| L4 | frontier binding content (Lemma 2) | **done as specializations** — inlined in the extractor walk (`extractIncl`), whole-tree (`extractMTH`), ConsRec (`consRecBinding`); the standalone `Root` receipt-uniqueness instance was deleted with the vacuous `root_binding` in S3.5 and deliberately NOT restored (optional, unused — KNOWN-GAPS gap 3) |
| L5 | inclusion soundness = EXPLICIT extractor `extractIncl` (Theorem 2) | **done, non-vacuous** |
| L6a | descent extractor `extractMTH` (Theorem 3 step 3 = Lemma 2, whole-tree instance) | **done, non-vacuous** |
| L6b | Theorem 3 (consistency soundness): `consRecBinding` (steps 1–2) + `extractCons`/`extractCons_correct` (+ `_paper` at the paper's exact quantifiers) | **done, non-vacuous** |
| L6c | pin-store state machine safety (Proposition 1): `pinAccept_monotone`, `pin_prefix_correct`, `fork_distinct` | **done, non-vacuous** (per-step; multi-step chain = gap 7) |

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
