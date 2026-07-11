# Statement map: paper §6 ↔ Lean corpus

The kernel guarantees every proof below; what a reviewer must vet is the
**statements** — that each Lean theorem says what the paper's item says.
This map is the review surface. Paper = "The Lean Transparency Log"
(https://ltl.zkdefi.org/paper), §6 and §10 (which scopes the
mechanization to items i–v).

| paper item | Lean name | file | cone |
|---|---|---|---|
| §5.3 split point k (RFC 9162) | `kbelow` + `kbelow_pos/lt`, `le_two_kbelow`, `kbelow_pow2` (2^j = k < n ≤ 2^{j+1} pins k uniquely) | Basic | no hash axiom |
| §5.3 MTH | `MTH` | Basic | sha256 |
| §5.3 Path | `Path` | Completeness | sha256 |
| §5.3 Root (App. B) | `Root` (Option = rejection) | Basic | sha256 |
| §5.3 ConsRec | `ConsRec` (+ machine-checked base-refactor equivalences `consRec_base_true_eq/false_eq`) | Basic, Refactor | sha256 |
| Lemma 1 (domain separation) | `domsep` | Basic | **axiom-free** |
| Theorem 1 (inclusion completeness) | `incl_complete` | Completeness | sha256 (+choice) |
| Lemma 2, width fact ("65-byte preimages") | `Hash` = length-32 subtype; `hnode_preimage_inj` | gen, Basic | propext |
| Lemma 2, whole-tree instance | `extractMTH` + `extractMTH_correct` | Descent | sha256 (+choice) |
| Lemma 2, ConsRec instance (Thm 3 steps 1–2) | `consRecBinding` | Binding3 | sha256 (+choice) |
| Theorem 2 (inclusion soundness, explicit 𝓔) | `extractIncl` + `extractIncl_correct` | Extract | sha256 (+choice) |
| Theorem 3 (consistency soundness, explicit 𝓔′) | `extractCons` + `extractCons_correct` | Theorem3 | sha256 (+choice) |
| Prop 1(1) (pin monotonicity + prefix) | `pinAccept`, `pinAccept_monotone`, `pin_prefix_correct` | PinStore | sha256 (+choice) |
| Prop 1(2), Merkle share | `fork_distinct` (different roots ⇒ different content); transferability = signature layer, out of scope | PinStore | sha256 |
| non-vacuity guards (anti-pigeonhole) | `extractIncl_nonvacuous`, `extractMTH_nonvacuous`, `extractCons_nonvacuous`, `pin_prefix_nonvacuous` | Extract/Descent/Theorem3/PinStore | sha256 |
| definition fidelity vs deployed verifier | `fidelity/` harness: MTH==merkle_root, Path==inclusion_proof, verifier agreement 164,479 + 164,224 (paper's exact case set) | fidelity | (testing) |

Design invariant of every soundness statement: the collision is the output
of a **named extractor function** and correctness is a claim about that
output. A bare `∃ x y, x ≠ y ∧ sha256 x = sha256 y` is provable by
pigeonhole alone (sha256 maps an infinite domain into the finite 32-byte
type), so it carries no cryptographic content; the guards above prove each
extractor's conclusion is *false* on honest inputs, hence not
choice-dischargeable.

Audit surface (enforced by `verification/check.sh`, exit 0 = green):
every theorem/def under `Proofs/` (52) plus the two load-bearing `gen/`
instances; excluded by nature: the sanctioned axiom `sha256` (it *is* the
boundary) and `abbrev Bytes` (alias, no cone content).
