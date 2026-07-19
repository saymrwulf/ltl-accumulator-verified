# Statement map: paper §6 ↔ Lean corpus

**Numbering note (2026-07-19):** every paper reference in this map uses
the numbering of the archived system report — "The Lean Transparency
Log", https://ltl.zkdefi.org/paper/v0.2 — whose §6 this corpus
mechanized verbatim and whose §10 scopes the mechanization to items
i–v. The current paper ("Accountable Distribution of Machine-Checked
Correctness Evidence", https://ltl.zkdefi.org/paper) presents the same
results in its §5.1–5.2 under different theorem numbers and cites this
corpus in its §7.2 coverage table; do not match the numbers below
against it.

The kernel guarantees every proof below; what a reviewer must vet is the
**statements** — that each Lean theorem says what the paper's item says.
This map is the review surface.

| paper item | Lean name | file | cone |
|---|---|---|---|
| §5.3 split point k (RFC 9162) | `kbelow` + `kbelow_pos/lt`, `le_two_kbelow`, `kbelow_pow2` (2^j = k < n ≤ 2^{j+1} pins k uniquely) | Basic | no hash axiom |
| §5.3 MTH | `MTH` | Basic | sha256 |
| §5.3 Path | `Path` | Completeness | sha256 |
| §5.3 Root (App. B) | `Root` (Option = rejection) | Basic | sha256 |
| §5.3 inclusion accept | `acceptIncl` (= `m < n ∧ Root … = some r`); `acceptIncl_complete`, `acceptIncl_sound` route Thm 1/2 through it | Basic, Completeness, Extract | sha256 (+choice) |
| Lemma 2 (general abstract form) | **not mechanized as one theorem** — proved as specializations (see KNOWN-GAPS gap 3); the row below and the Lemma-2 rows are those instances | — | — |
| §5.3 ConsRec | `ConsRec` (+ machine-checked base-refactor equivalences `consRec_base_true_eq/false_eq`) | Basic, Refactor | sha256 |
| Lemma 1 (domain separation) | `domsep` | Basic | **axiom-free** |
| Theorem 1 (inclusion completeness) | `incl_complete` | Completeness | sha256 (+choice) |
| Lemma 2, width fact ("65-byte preimages") | `Hash` = length-32 subtype; `hnode_preimage_inj` | gen, Basic | propext |
| Lemma 2, whole-tree instance | `extractMTH` + `extractMTH_correct` | Descent | sha256 (+choice) |
| Lemma 2, ConsRec instance (Thm 3 steps 1–2) | `consRecBinding` | Binding3 | sha256 (+choice) |
| Theorem 2 (inclusion soundness, explicit 𝓔) | `extractIncl` + `extractIncl_correct` | Extract | sha256 (+choice) |
| Theorem 3 (consistency soundness, explicit 𝓔′) | `extractCons` + `extractCons_correct`; `extractCons_correct_paper` at the paper's exact quantifiers (n₀=0 discharged); `acceptCons_sound` routes it through the named `acceptCons` predicate (size bound derived from acceptance via `consRec_some_le`). Covers the MECHANIZED accept set; transfer to the deployed verifier is conditional on the pinned-pair side condition of gap 14 | Theorem3 | sha256 (+choice) |
| Prop 1(1) (pin monotonicity + prefix) | `pinAccept`, `pinAccept_monotone`, `pin_prefix_correct` | PinStore | sha256 (+choice) |
| Prop 1(2), Merkle share | `fork_distinct` (different roots ⇒ different content); transferability = signature layer, out of scope | PinStore | sha256 |
| non-vacuity guards (anti-pigeonhole) | `extractIncl_nonvacuous`, `extractMTH_nonvacuous`, `extractCons_nonvacuous`, `pin_prefix_nonvacuous` | Extract/Descent/Theorem3/PinStore | sha256 |
| definition fidelity vs deployed verifier | `fidelity/` harness: MTH==merkle_root, Path==inclusion_proof, verifier agreement 230,271 inclusion + 230,016 consistency over the pinned case families — **not extensional equality**: the lied-size family (73,573 cases) pins the known one-sided divergence of gap 14 (3,867 expected, deployed-accepts-only, direction asserted) | fidelity | (testing) |

Note on "assumption-free" (paper §10(i)): `incl_complete`'s cone lists
`LTLAcc.sha256`, but the theorem assumes **no property** of it — it
merely *mentions* the opaque constant. Constant-dependence is not
property-assumption; the soundness theorems likewise carry `sha256`
without assuming collision resistance.

Design invariant of every soundness statement: the collision is the output
of a **named extractor function** and correctness is a claim about that
output. A bare `∃ x y, x ≠ y ∧ sha256 x = sha256 y` is provable by
pigeonhole alone (sha256 maps an infinite domain into the finite 32-byte
type), so it carries no cryptographic content. What the guards certify
(precisely — round-2 M3): each named extractor does **not** return a
collision on at least one canonical honest input, which rules out the
degeneration where the conclusion is a globally inhabited bare collision
existential. They do NOT establish logical dependence on every listed
hypothesis, nor that no other classical argument could reach the
conclusion on some restricted domain.

Audit surface (enforced by `verification/check.sh`, exit 0 = green):
the FULL compiled environment of the corpus modules — 222 constants,
read from the Lean environment by `Proofs/Inventory.lean` (fully
qualified names, kinds, axiom cones) and pinned in
`verification/inventory-allowlist.txt`, diffed fail-closed both
directions on every run (round-3 replacement for the round-2 source-regex
gate, which GPT H1 showed was evadable). The 61 human-reviewed statement
cones above are additionally checked via `#print axioms` and
cross-checked against the inventory's independently computed cones.
(These two counts, and the fidelity pins in the table above, are
asserted against the allowlist/CONES/harness by check.sh Phase 3c on
every run — stale-count drift is now a red button, not an erratum:
review R4-1, after three consecutive rounds of hand-edit failures.)
`verification/selftest_audit.sh` attacks the gate with nine injection
cases (attributed/indented/private/instance declarations, a nested
namespace reusing an audited basename, a smuggled axiom, a deleted
declaration, and unmanifested Proofs/ and gen/ modules) — each must
fail the exact production gate.
