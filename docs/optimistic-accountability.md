# Optimistic by construction: what the LTL holds, and what it shares with rollups

Status: long-form source. Entry 13 (leaf index 12, hash `8cb258d6…`,
subject `ltl-accumulator-verified@172a1d0`) is live under head
`tree size 13, root 3488a2d0…`, verifiable at ltl.zkdefi.org/v1/sth.

Framing note (2026-07-19): Part II was revised to match the precise
treatment used in the paper. The rollup resemblance is a **bounded
analogy**, not a strict claim: the collision extractors are *reduction
witnesses* against SHA-256's collision resistance, not on-protocol
fraud proofs that convict the operator; a fabricated leaf is caught
only by *off-protocol* independent replay. Earlier drafts overstated
this ("fraud proof in the strict sense", "cannot fail to convict"); the
overstatement is corrected here and the paper omits the analogy from
its body entirely.

---

## Part I — What is actually inside the Merkle tree

A persistent misreading of transparency logs is that they "contain the
proofs." The LTL's tree contains none of the Lean mathematics. Each
leaf is (the 32-byte hash of) a **verification-event record**: a
signed attestation stating that the provider, at a given time, ran the
proof checks on a named subject repository at an exact commit, with an
exact toolchain, and observed a specific result — every certificate
verified, each with an exactly-listed axiom cone. The records are
published beside the tree (`entries/`); the proofs themselves live one
hop further away, in the subject git repositories the records pin.

So a leaf is a statement *about the operator's action* — "I verified
X" — and on its face that sounds like "trust me." The design's whole
point is the refinement that removes the trust: **the claim names its
own evidence.** Because the leaf pins commit hash and toolchain,
anyone can replay the verification and check the operator's statement.
The log converts

> "I guarantee I verified the proofs (which live elsewhere)"

into

> "I claim this, permanently and publicly, with enough detail that
> anyone can catch me lying — and I can never unsay it, edit it, or
> show a different history to someone else."

Three layers, three distinct guarantees, and most confusion comes from
expecting one layer to do another's job:

| layer | guarantees | does NOT guarantee |
|---|---|---|
| Lean kernel (inside the subject repos) | the mathematics of the attested proofs is true, given the declared axioms | anything about what the operator later claims |
| replay pin (leaf content) | the operator's claim is CHECKABLE — re-run the pinned commit and compare | that anyone has actually re-run it |
| Merkle accumulator + signed heads | inclusion (Thms 1–2), append-only history (Thm 3), equivocation evidence (Prop 1): claims cannot be altered, hidden, or forked without producing cryptographic evidence | that any claim is TRUE — the ledger notarizes, it does not referee |

The notary metaphor is exact: a notary does not check that your
contract is wise; the notary makes it impossible to later dispute
*what was stamped and when*, and the bound ledger makes tampering
evident. The LTL is a notary whose every stamped page happens to carry
instructions for independently re-checking the page's claim.

## Part II — The optimistic-rollup resemblance (a bounded analogy)

Optimistic rollups rest on one bet: *claims are cheap to make and
expensive to get away with*. A sequencer posts state roots without
proof; safety comes from anyone's ability to produce compact,
transferable evidence of a specific fault from public data, and from
punishment when they do. The LTL — like its direct ancestor,
Certificate Transparency (RFC 9162) — sits at the same design *point*:
record everything append-only, and make misbehavior produce publicly
verifiable evidence. The correspondence is a genuine and useful
analogy, and — this is the part worth getting right — it is an analogy
with three honest disanalogies, not an equivalence. The precise
version is what makes it interesting.

There are two very different "faults" a reader tends to conflate, and
the LTL treats them differently.

**Fault 1 — the operator rewrites or forks the log's own history.**
This is the layer this corpus mechanized, and it is where the
resemblance is strongest — but the mechanized result is a *reduction*,
not a courtroom verdict. Theorem 3 (`extractCons_correct` /
`acceptCons_sound`) states: if the verifier accepts a consistency proof
between a pinned head and a rewritten history, the named extractor
**outputs a SHA-256 collision as two concrete byte strings**. Read that
statement exactly. It does not say "the operator is guilty"; it says
"accepting this would break SHA-256." The extractor is a reduction
witness: it converts a successful attack on the log's structure into a
concrete refutation of the hash function's collision resistance. Under
the standing assumption that no such collision is feasible, the attack
therefore cannot succeed in the first place — which is a *stronger and
cleaner* guarantee than a fraud proof that convicts after the fact.
Equivocation is the one place the operator is directly on the hook:
two conflicting signed heads at the same size, in one log context, are
transferable evidence attributable to the key holder (this reduces to signature
unforgeability, not to collision resistance) — the closest analogue to
a rollup fraud proof against the sequencer, and the consumer's
pin-store is the watchtower that collects it. The liveness assumption
transfers cleanly: someone must actually watch (a pinned consumer, a
mirror, a `witness-audit` run). An unwatched log, like an unwatched
rollup, is safe only on paper.

**Fault 2 — a leaf's content is simply false** (the operator lies about
a Lean result it never actually observed). This is the optimistic part,
and it is the honest limit of the whole design: the cryptography does
**not** catch it. The Merkle machinery faithfully commits and orders a
false statement exactly as it would a true one — it notarizes, it does
not referee. What catches a false leaf is **independent replay**: the
leaf pins the commit and toolchain, so anyone can re-run the check, and
a failed replay is the demonstration. But replay is *off-protocol* —
it is not a challenge transaction the log adjudicates; it is work a
third party does with a theorem prover, and the log's only contribution
is to make the claim precise enough to be replayable and impossible to
later unsay. Two properties do compare favorably: the challenge window
is effectively infinite (append-only preserves the record forever — a
false leaf cannot be reverted, only exposed), and no privileged
adjudicator exists — every reader replays independently.

**The three disanalogies, stated plainly.** (1) The consistency and
inclusion extractors are reduction witnesses against a cryptographic
assumption, not on-protocol fraud proofs against the operator — a false
opening refutes SHA-256, it does not by itself prove misconduct. (2)
Detecting a fabricated *leaf* requires off-protocol independent replay;
the log defines no challenge transaction, adjudicator, or compact proof
that a replay observation was fabricated. (3) There is no bond, no
slashing, no revert: consequences are reputational and out-of-band —
consumers stop trusting and the evidence is publicized — exactly as in
CT, where the "slash" is a browser distrusting a CA. Bolting on
economic slashing would require an on-chain adjudicator able to run a
proof checker inside a fault-proof VM; theoretically the same
construction rollups use, practically a research program. The dual this
estate actually implements is consumer-side defense: warden's quorum of
independently attested verifiers, instead of prover-side bonding.

**What entry 13 does close.** Set the analogy aside and state the plain
fact: the log now carries, as one of its own leaves, a kernel-checked
mechanization of the very soundness arguments its accumulator relies
on — the extractors, the consistency binding, the per-step pin safety
— scoped honestly to the recursive model (not the deployed verifier;
see `KNOWN-GAPS.md`). Whatever one calls that machinery, its proofs are
now inside the ledger it protects, verifiable end to end by anyone with
a stock toolchain. That is the loop worth savoring, and it needs no
rollup metaphor to be remarkable.

## Pointers (for the eventual blog rendering)

- Mechanized statements: `STATEMENT-MAP.md` (this repo); the fraud-
  proof-generator reading of Theorem 3 is `extractCons_correct` +
  `acceptCons_sound`; scope boundaries in `KNOWN-GAPS.md` (esp. gap 14:
  the deployed-verifier side condition; gap 4: the signature layer,
  where equivocation-evidence transferability lives).
- Deployed anatomy: leaf → `entries/NNNNNN.json`; head →
  `latest-sth.json` (+ `sth-history.jsonl`); the head is signed by the
  dogfooded verified-dalek backend (`self_inclusion: verified`).
- Lineage: RFC 9162 / Certificate Transparency — the original
  accountability-over-validity system; the LTL is CT's discipline
  applied to formal-verification claims.
