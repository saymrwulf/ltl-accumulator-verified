# ltl-accumulator-verified

Lean 4 mechanization of the security analysis (§6) of the paper
"The Lean Transparency Log" (https://ltl.zkdefi.org/paper): the Merkle
accumulator's own correctness and soundness theorems, kernel-checked, in
the same discipline as the four `*-ed25519-verified` subject corpora.

## Status: **ATTESTED — LTL entry 13, live (2026-07-16)**

This corpus is now itself a leaf of the log it describes. It was appended
as **entry 13** of the Lean Transparency Log (freeze `172a1d0`), so the
log carries kernel-checked proofs *about the accumulator model*
underlying its own inclusion and consistency reasoning (a deployment we
are unaware of a precedent for; scoped to the mechanized model, not the
deployed verifier — see below). Live head after the append:
tree size **13**, root
`3488a2d0ff9f00415bb561d61b01a420e3ca2e0f7b29351ec9ebb3f57319da0d`; this
corpus is leaf index 12, hash
`8cb258d657f1fd00baaa9e0091e26c316cb69b591cb249a9543f51cade57c50a`. The
old 12-leaf head (`bcd15f9d…`) is a proven prefix; the 12→13 consistency
transition is accepted by both the deployed verifier and the mechanized
model. Fetch and verify it at
[ltl.zkdefi.org/v1/sth](https://ltl.zkdefi.org/v1/sth). The leaf carries
its own **scope** block: what is kernel-checked is the mechanized model
(§6), and correspondence to the deployed verifier is scoped by
KNOWN-GAPS 14/15 — the leaf does not claim the deployed verifier is
formally verified.

All paper-§6/§10 mechanization targets are kernel-checked; the audit
surface is defined and green (`verification/check.sh`, exit 0). See
[STATEMENT-MAP.md](STATEMENT-MAP.md) for the paper↔Lean review surface and
[KNOWN-GAPS.md](KNOWN-GAPS.md) for the honest scope ledger.
Reviewed across **six** external adversarial rounds (GPT-5.6 + a second
Claude; zero broken theorems in any round; both approved). The audit
surface is an environment-derived inventory (`Proofs/Inventory.lean` +
pinned allowlist — 222 constants, 61 human-reviewed cones, self-tested by
`selftest_audit.sh`); the review kit is push-button reproducible
(`run_bare.sh`, self-contained fidelity target);
`acceptIncl`/`acceptCons_sound` route the theorems through the named
acceptance predicates; fidelity = agreement over pinned families
(230,271 + 230,016 baseline; 73,573 lied-size boundary cases with
3,867 expected one-sided divergences — KNOWN-GAPS gaps 14/15, not
extensional equality). Doc counts are asserted by check.sh Phase 3c.
How the append was done — release tuple, preflight, candidate-inspection
gate, and the 12→13 structural rehearsal — is recorded in
[ATTESTATION-RUNBOOK.md](ATTESTATION-RUNBOOK.md).

| layer | content | status |
|---|---|---|
| L1 | bytes, hleaf/hnode, domain separation (Lemma 1) | **done** (domsep: axiom-free) |
| L2 | MTH, Root, ConsRec definitions + termination | **done** (cones: propext, LTLAcc.sha256, Quot.sound) |
| L3 | inclusion completeness (Theorem 1) + named acceptance `acceptIncl` | **done** (incl_complete: propext, Classical.choice, LTLAcc.sha256, Quot.sound) |
| L4 | frontier binding content (Lemma 2) | **done as specializations** — inlined in the extractor walk (`extractIncl`), whole-tree (`extractMTH`), ConsRec (`consRecBinding`); the standalone `Root` receipt-uniqueness instance was deleted with the vacuous `root_binding` in S3.5 and deliberately NOT restored (optional, unused — KNOWN-GAPS gap 3) |
| L5 | inclusion soundness = EXPLICIT extractor `extractIncl` (Theorem 2) | **done, non-vacuous** |
| L6a | descent extractor `extractMTH` (Theorem 3 step 3 = Lemma 2, whole-tree instance) | **done, non-vacuous** |
| L6b | Theorem 3 (consistency soundness): `consRecBinding` (steps 1–2) + `extractCons`/`extractCons_correct` (+ `_paper` at the paper's exact quantifiers; `acceptCons_sound` routes it through the named `acceptCons` predicate, size bound derived from acceptance via `consRec_some_le`) | **done, non-vacuous** |
| L6c | pin-store state machine safety (Proposition 1): `pinAccept_monotone`, `pin_prefix_correct`, `fork_distinct` | **done, non-vacuous** (per-step; multi-step chain = gap 7) |

## Discipline (identical to the subject corpora)

- `verification/Proofs/` contains ZERO `axiom` declarations; the single
  sanctioned axiom site is `verification/gen/` — here, one opaque
  function: SHA-256. The theorems are constructive collision extractors,
  so collision resistance is never assumed, only interpreted.
- `verification/check.sh` is THE button: compiles every file through
  `lean-guard` (memory cap, core pinning, timeout, single-flight lock)
  and axiom-audits every certificate against its documented exact cone.
- Reviewers without the operator toolchain: `verification/run_bare.sh`
  compiles, axiom-audits, and inventory-gates the corpus with a plain
  public `lean` (version pinned in `verification/lean-toolchain`); the
  operator path is overridable via `AENEAS_ENV`.
- Expected boundary: `propext, Classical.choice, Quot.sound` plus
  `LTLAcc.sha256` for hash-touching certificates — documented per
  certificate in `check.sh`, audited both directions.

The finished certificates are destined for the LTL itself as attestation
leaves: the log carrying kernel-checked proofs of its own machinery.
