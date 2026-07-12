# Response to reviewers — round 4

Corpus: `ltl-accumulator-verified`. Round-3 reviews received against the
round-3 freeze `9972ab4`: GPT-5.6 (conditional approval, one portability
finding) and the round-3 Claude reviewer's Socratic addendum (one new
confirmed finding, four reinstated ones). Every claim was independently
re-verified by the operator before any change. This round contains ONE
new theorem, one harness family, and packaging/scoping fixes. No
existing theorem statement or proof changed.

## The headline: F1* (Claude addendum) — CONFIRMED and absorbed

The addendum demonstrated that the deployed `verify_consistency` and
the mechanized `ConsRec` acceptance are **not extensionally equal**:
the deployed RFC 9162 iterative verifier accepts honest proofs under
lied size claims (witness: `verify_consistency(1, 3, R2, R3, P(2→3)) =
True`; ConsRec rejects). Reproduced exactly on the operator machine
against deployed pacta: same witness, same 3,405 divergences for
n < 60, same strictly one-sided direction (the mechanized model is the
stricter; inclusion diverges nowhere under identical abuse), same
power-of-two seeding mechanism in the deployed source.

Absorbed as follows:

- **KNOWN-GAPS gap 14**: full statement — witness, mechanism,
  one-sidedness, and the soundness-transfer side condition (the
  consumer's `(n₀, r₀)` is an authentic pinned pair and `n₁` is the
  authentic size behind `r₁`), which pacta's pin-store flow supplies by
  construction. No exploitability against that flow is claimed or ruled
  out; that assessment belongs to the signature/STH layer (gap 4).
- **Harness**: new lied-size family — 73,573 boundary cases (lied old
  size exhaustive for n < 60, lied new size sampled), 3,867 expected
  divergences PINNED, and the one-sided direction asserted on every
  case: a single `lean=True / deployed=False` instance fails the run.
  These families would have caught F1* in round 1; now they guard it
  forever.
- **Banner**: `FIDELITY GREEN` now reads "agreement over the pinned
  case families (not extensional equality; KNOWN-GAPS gap 14)". The
  STATEMENT-MAP fidelity row and Theorem-3 row carry the same scoping.
- **No pacta code change.** The deployed behavior matches upstream
  RFC 9162 implementations; the consumer flow enforces the side
  condition (`n₀` comes from the consumer's own pin, never from the
  peer; `(n₁, r₁)` arrive together in one signed head). pacta also
  remains change-frozen during paper processing.

## F2 — `acceptCons` routed through zero theorems (CONFIRMED, fixed)

New theorem `acceptCons_sound` (Theorem3.lean): soundness stated over
the named `acceptCons` predicate the harness tests — the consistency
twin of round-2's `acceptIncl_sound`. The `n₀ = 0` disjunct is
discharged from the non-prefix premise; the size bound `n₀ ≤ n₁` is
derived from ConsRec acceptance itself via the new lemma
`consRec_some_le` (the `n₀ > n` branch returns `none`), so the caller
owes nothing beyond acceptance + wrong-prefix. Cones (read from
`#print axioms`, as always): `consRec_some_le` = [propext,
LTLAcc.sha256, Quot.sound]; `acceptCons_sound` = [propext,
Classical.choice, LTLAcc.sha256, Quot.sound]. Both are in CONES,
AxiomCheck, and the inventory allowlist (218 → 222 constants; the diff
is exactly the two theorems plus their two generated auxiliaries).

## F3 — Lean-side kit reproducibility (CONFIRMED, fixed)

`verification/lean-toolchain` now pins `leanprover/lean4:v4.30.0-rc2`,
and `verification/run_bare.sh` is the reviewer's standalone runner:
plain public `lean`, no lake, no Aeneas checkout — compile all modules,
print all cones, run the inventory gate. Verified green on this machine
(under the operator's memory-cap discipline): 61 cone lines, 222
constants, gate green. check.sh remains the operator's button.

## F4 — regex metacharacters in Phase 3b (CONFIRMED, fixed)

The `PINNED BUT NOT INVENTORIED` check now uses awk field equality
instead of a regex containing the constant name; the module-manifest
greps were already `-F`. Dots no longer act as wildcards anywhere in
the gate.

## F5 — kit hygiene (CONFIRMED, fixed; one sharpening)

The stray `.pyc` was worse than reported: it was **git-tracked**, which
is why `git archive` shipped it. Untracked; `__pycache__/`/`*.pyc`
gitignored. The round-4 kit gives the corpus tarball the same treatment
as the pacta target: `MANIFEST.sha256` over every file in the archive
plus the pinned public commit and repo URL — this also implements
GPT's governance condition (publish hashes of the audit-critical
files; they are all in the archive the manifest covers).

## GPT §7 — hard-coded toolchain bootstrap (CONFIRMED, fixed)

`AENEAS_ENV` override with a clear FATAL message in both check.sh and
selftest_audit.sh, exactly as recommended; default unchanged for the
operator. Together with F3 this closes the "reviewer-friendly
push-button" gap: reviewers get `run_bare.sh`, operators keep the
guarded button.

## GPT §9 — paper-language conditions

Adopted into the paper-cycle queue verbatim (they overlap the queue
built across rounds 1–3), plus F1*'s two additions: the fidelity
sentence must say "finite differential testing over pinned families,
extensional equality is false for consistency (one-sided)", and
Theorem 3's deployment claim must carry the pinned-pair side condition.
The paper is edited in its own cycle, not in this corpus.

## Reviewer-process note (kept, per this project's candor convention)

The round-3 Claude reviewer's self-analysis (Q1–Q7) found its own
"confirmed/verified" inflations and then did what the drill demands:
applied constructive-witness standards to its own strongest doubt and
produced F1*. Its round-3.5 addendum is the strongest single review
artifact this corpus has received. The operator re-verified every claim
in it anyway — trust nothing, including good news.

## What did NOT change

All pre-existing theorem statements and proofs; the axiom boundary
(single opaque `sha256`); the 230,271/230,016 family pins; the live
transparency log (12 leaves, root `bcd15f9d…`); deployed pacta.
Attestation remains blocked pending the ePrint decision, the author's
read, and an explicit operator order.
