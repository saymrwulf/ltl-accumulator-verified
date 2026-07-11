# Known gaps and scope boundaries (honest ledger)

Deliberate, documented, and none silent. Reviewers should verify this
list is COMPLETE, not merely that the items are acceptable.

1. **SHA-256 is opaque** — the single boundary axiom (`LTLAcc.sha256`),
   by design identical to the paper's posture: soundness theorems
   construct collisions, never assume collision resistance.
2. **No consistency-completeness theorem** (honest ConsRec acceptance).
   Matches the paper (its Theorem 1 is inclusion-only); honest
   consistency behavior is covered by the fidelity harness's honest
   cases (164,224-case agreement with the deployed verifier).
3. **Lemma 2, path instance not restored** — receipt-uniqueness for
   `Root` (an accepting `(v,P)` is the honest receipt) was removed with
   the vacuous `root_binding` and not re-proven in extractor form.
   Optional: unused by Theorems 2–3 as assembled.
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
