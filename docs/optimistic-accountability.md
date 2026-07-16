# Optimistic by construction: what the LTL holds, and what it shares with rollups

Status: published. The condensed blog version is live at
blog.zkdefi.org ("The log notarizes itself — entry 13", 2026-07-16),
and the closing claim — "the log carries kernel-checked proofs of its
own machinery" — is now literally true: entry 13 (leaf index 12, hash
`8cb258d6…`, subject `ltl-accumulator-verified@172a1d0`) is live under
head `tree size 13, root 3488a2d0…`, verifiable at
ltl.zkdefi.org/v1/sth. This essay remains the long-form source.

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

## Part II — The optimistic-rollup resemblance (it is not a metaphor)

Optimistic rollups rest on one bet: *claims are cheap to make and
expensive to get away with*. A sequencer posts state roots without
proof; safety comes from anyone's ability to produce a fraud proof
from public data, and from punishment when they do. The LTL — like its
direct ancestor, Certificate Transparency (RFC 9162) — is built on the
same bet: record everything append-only, and make misbehavior generate
publicly verifiable, transferable evidence.

The fraud-proof analogue exists in the LTL at two distinct layers:

**1. Log-layer fraud (operator rewrites or forks history).** Here the
resemblance is nearly literal, and it is exactly what this corpus
mechanized. Theorem 3 (`extractCons_correct` / `acceptCons_sound`)
states: if the verifier accepts a consistency proof between a pinned
head and a rewritten history, the named extractor **outputs a SHA-256
collision as two concrete byte strings**. That is a fraud proof in the
strict sense — and a constructive one: the adversary's own accepted
messages are compiled into the evidence against them. Equivocation has
the same shape: two conflicting signed heads ARE the fraud proof, and
the consumer's pin-store is the watchtower that collects them. Even
the rollup's liveness assumption transfers: someone must actually
watch (a pinned consumer, a mirror, a `witness-audit` run). An
unwatched log, like an unwatched rollup, is safe only on paper.

**2. Claim-layer fraud (a leaf's content is a lie).** The log does not
validate Lean proofs on append — it records the claim. That is the
optimistic part. The fraud proof here is **replay**: the leaf pins
everything needed to re-run the check, and the failed replay is the
demonstration. Two properties compare favorably with rollups: the
challenge window is *infinite* (append-only preserves the crime scene
forever — a false leaf cannot be reverted, only exposed, and its
permanence is the exposure), and no adjudicator is needed — the fraud
proof is reproducible by every reader independently.

**Where the analogy honestly stops: enforcement.** A rollup's fraud
proof triggers protocol-native consequences — state reverts, bonds are
slashed, money moves. The LTL has no bond, no slashing, no revert.
Evidence leads to out-of-band consequences (consumers stop trusting;
the evidence is publicized), exactly as in CT, where the "slash" is a
browser distrusting a CA. Same detection architecture, different
enforcement layer: cryptographic accountability with reputational
rather than economic stakes. Bolting on economic slashing would
require on-chain adjudication of "the Lean replay failed" — a
fraud-proof VM able to run a proof checker; theoretically the same
construction rollups use, practically a research program. The
pragmatic dual, implemented in this estate, is consumer-side defense:
warden's quorum of independently attested verifiers, instead of
prover-side bonding.

**The inversion worth savoring.** Rollup design treats "optimistic +
fraud proofs" and "validity proofs" as competing answers for the same
object. This stack uses both, one inside the other: each leaf's
*payload* is validity-proven in the strongest available sense (the
Lean kernel — no optimism, no challenge window), while the *envelope*
carrying it is optimistic/accountability-style. And entry 13 closes a
loop that optimistic rollups themselves aspire to and largely lack:
**formally verified fraud-proof machinery**. The mechanized theorems
say precisely "this fraud-proof system cannot fail to convict" — any
accepted rewrite yields the collision, constructively. Production
rollups would love a kernel-checked proof of their fault-proof
interpreters; this log carries one for its own — entry 13, inside the
very ledger it protects.

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
