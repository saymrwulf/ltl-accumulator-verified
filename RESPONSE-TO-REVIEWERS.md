# Response to reviewers — round 5 (housekeeping)

Round-4 reviews received against `2da0a79`: the Claude reviewer
("Round 4 is the cleanest round this corpus has had… Nothing blocks the
freeze; no remaining findings on the corpus itself") and GPT-5.6
("Approve after minor documentation fixes", scoped-attestation
condition). No theorem, proof, or Lean surface changed this round —
this is the documentation-and-guardrails round both reviewers asked
for.

## Disposition

### Stale counts, third recurrence (Claude R4-1/R4-2 = GPT §6) — fixed STRUCTURALLY

All `218/59` occurrences are now `222/61` (STATEMENT-MAP footer, the
check.sh comment, README status), and — the structural part R4-1
demanded — **check.sh gained Phase 3c (doc-consistency)**: the audit
counts in STATEMENT-MAP and README are asserted against the allowlist
and the CONES table, and the four fidelity pins quoted in the
STATEMENT-MAP are asserted against the harness's own pinned constants,
on every button press. Stale-count drift is now a red button, not an
erratum. README status paragraph rewritten to round-4 reality
(lied-size family, `acceptCons_sound`, both approvals); the L6b row
names `acceptCons_sound`.

### The deployment bridge (GPT §2/§3/§4, its principal finding) — adopted in full

- **Gap 14 reworded** to GPT's evidence-vs-inference formulation: the
  exhibited divergence is outside the intended pin-store input
  invariant; applying the mechanized soundness result to the deployed
  flow additionally ASSUMES the authentic-size/root binding — "is
  assumed", not "transfers". The invariant's witnesses are now cited by
  name (paper §5.3/§5.4; pacta `src/pacta/sthstore.py`,
  `src/pacta/logclient.py` — outside the fidelity target), per Claude
  R4-3.
- **New gap 15**: "Deployment refinement invariant unmechanized" — the
  bridge gets its own named boundary, with the unproven refinement
  spelled out and the three closure paths (adopt ConsRec semantics in
  deployment / mechanize the state machine and prove refinement / keep
  the scoped claim) recorded as a post-paper-freeze operator decision.
- **Attestation language is now a runbook GATE**: the exact scoped
  wording from GPT §11 is embedded in ATTESTATION-RUNBOOK step B2 as a
  required check — entry 13 cannot be written as "the deployed verifier
  is formally verified."

### Toolchain enforcement (GPT §5) — fixed

`run_bare.sh` now fail-closes on both the Lean version (`4.30.0-rc2`)
and the exact compiler commit (`3dc1a088…`); `BARE RUN GREEN` is
reserved for the pinned toolchain, exactly as recommended.

### Banner wording (GPT §8) — adopted

The per-family line now reads `consistency baseline family: … all
agree`, so a detached quotation cannot suggest global equivalence.

### Fidelity-target provenance (GPT §7) — REFUTED, with a courtesy fix

The round-4 target tarball demonstrably contains `MANIFEST.sha256`
(six per-file SHA-256 entries) and `TARGET-PROVENANCE.md` (repo URL,
pinned commit `3d81d53`, verification instructions, extraction and run
commands) at its root — `tar tzf` lists both. The review appears to
have counted only the `.py` files. No packaging change was required;
as a courtesy, the round-5 kit ALSO ships both files unpacked beside
the tarball so they cannot be missed. (The project's discipline cuts
both ways: reviewer findings are re-verified too, and this one did not
reproduce.)

### Wording nit (Claude R4-5) — adopted

Gap 14 now says "lied new size at fixed offsets n−1/n+1/n+7" —
determinism advertised, not obscured.

### Paper queue (Claude R4-4 + GPT §11) — recorded

Added to the camera-ready queue: §10(v) "total correctness of the
pin-store state machine" must be scoped to what gaps 4/7/10 delimit;
Remark 1's "will carry" must get the gap-3 specializations rewording
when the corpus is cited as delivered; and the paper may not describe
Theorem 3 as mechanized "for the deployed verifier" without the gap-15
qualification.

## What did NOT change

Every Lean file, the allowlist, the gate, the self-test, the fidelity
pins (230,271 / 230,016 / 73,573 / 3,867), the axiom boundary, the
live log (12 leaves, `bcd15f9d…`), deployed pacta. Attestation remains
gated on the ePrint decision, the operator's read (A2), the rehearsal
(A4), and an explicit operator order — with the B2 scope wording now
part of the gate.
