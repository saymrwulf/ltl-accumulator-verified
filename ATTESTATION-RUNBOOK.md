# ATTESTATION RUNBOOK — entry 13 (the log attests its own machinery)

Status: **COMPLETE — entry 13 appended and live, 2026-07-16.**
Log tree 12→13; new root `3488a2d0ff9f00415bb561d61b01a420e3ca2e0f7b29351ec9ebb3f57319da0d`;
new leaf index 12, hash `8cb258d657f1fd00baaa9e0091e26c316cb69b591cb249a9543f51cade57c50a`
(subject ltl-accumulator-verified@172a1d0, 61/61, mechanized-model scope,
KNOWN-GAPS 14/15). log-clone commit `1726e8e`, pushed + deployed + live-
consumer-verified (accepted:true, ed25519:verified). Evidence on SD
outputs/entry13-append-evidence/. This runbook is retained as the record
of how it was done. The log now carries kernel-checked proofs of its own
accumulator machinery.
This file is the single authoritative ToDo for everything that happens
between now and the appending of leaf index 12 (the 13th entry, file
`entries/000012.json`, tree size 12 → 13). It is written to be executed
by a human with no AI assistance; an agent executing it must obey the
Agent Appendix at the end. Every step ends in a mechanical check.

---

## 0. Vocabulary (read once)

| term | meaning |
|---|---|
| **operator** | The human running the log service (owner of ltl.zkdefi.org and its keys). NOT warden (warden is a consumer). All Phase-B actions are operator actions. |
| **corpus** | `ltl-accumulator-verified` at freeze commit `172a1d0` (round-5 freeze — the reviewed subject; supersedes the earlier `2da0a79`) — the kernel-checked mechanization of paper §6. |
| **the button** | `verification/check.sh`. Green means: printed `=== ATTESTATION GREEN (Lean + fidelity) ===` AND `echo $?` printed `0`. BOTH. Never judge from scrolled output. |
| **the log** | Live service ltl.zkdefi.org + public mirror repo `lean-transparency-log`. At execution time: 12 leaves (indices 0–11), head root `bcd15f9d…`, frozen. NOW (post-execution): 13 leaves, head root `3488a2d0…`, entry 13 live. |
| **entry 13** | The attestation of the corpus itself. APPENDED 2026-07-16 as leaf index 12 (leaf hash `8cb258d6…`); this runbook is the record of that execution. |
| **kit round N** | The review package delivered to the external reviewers after freeze N. Round-1 kit = freeze `6e56414`; round 2 = `260ad64`; round 3 = `9972ab4`; round 4 = `2da0a79`; round 5 = `172a1d0`; round 6 = review of `172a1d0` + pacta producer (current). |

## 2a. Release tuple (the single source of immutable identifiers)

Phase B binds THESE exact identifiers. Every Phase-B command consumes
them; any mismatch aborts. Filled from the round-6 rehearsal
(2026-07-16); re-confirm each on the day (B0).

```
SUBJECT_COMMIT   = 172a1d0653f489d5b7cb73ac7942a57cbb496532   # corpus (round-5 freeze, reviewed r6)
PACTA_CODE_BASE  = 8b1a325caaef6d3993d63d4c730eab03065e936b   # round-6-hardened
                    producer: parser hardening + fail-closed classifier +
                    leaf `scope` block + examples/repos.yaml entry + dead-code
                    cleanup. The 12→13 rehearsal ran green on this producer.
PACTA_COMMIT     = <the pacta working-tree HEAD at B2 time — MUST have
                    `git diff PACTA_CODE_BASE HEAD -- src provider` EMPTY
                    (producer code identical to the reviewed base; doc-only
                    commits above it, e.g. paper/, are fine). Record the exact
                    HEAD in the B6 evidence.>
EXPECTED_OLD_SIZE= 12
EXPECTED_OLD_ROOT= bcd15f9d7ea1c9e5bd0a9e64fa8d846208b1e29ee167d4f1eac19b30e6913ee9
KEY_FINGERPRINT  = 874c8a008a607021528b2493fa1caf059f9d5c123d29193dfabc09a6d1e7a56a
CONFIG           = pacta examples/repos.yaml, entry ltl-accumulator-verified (record its sha256 in B0)
NEW_INDEX        = 12   (the 13th leaf)
NEW_SIZE         = 13
```


## 1. Iron rules (violating any of these is never correct)

1. **Nothing is appended, re-signed, or deployed before ALL Phase-B
   gate conditions are met.** The gate is listed verbatim at Phase B.
2. **The log's current state is always a safe state.** If any step
   fails, STOP, record the output verbatim, and leave everything as it
   is. A log stuck at 12 leaves is healthy; a log with a bad 13th leaf
   is not repairable by deletion (append-only).
3. **Never**: force-push the log repo; edit or delete anything under
   `entries/`; re-sign an already-published head; backdate anything.
4. Red output is never argued with. Fix nothing "quickly to make it
   pass." A failed check means the run is over.
5. IACR/editor correspondence never enters any git repo (SD card only).

## 2. Facts (as of 2026-07-16, post round-6)

| artifact | where | state |
|---|---|---|
| corpus | github.com/saymrwulf/ltl-accumulator-verified | **`172a1d0`** (round-5 freeze; = SUBJECT_COMMIT §2a), pushed, clean. `2da0a79` was the round-4 freeze — superseded. |
| review kits | SD `outputs/accumulator-review-kit-round{2..6}/` | round 6 (pre-attestation sign-off) delivered 2026-07-16; corpus tarball `18fbd697…` + `CORPUS-MANIFEST.sha256` |
| log mirror repo | github.com/saymrwulf/lean-transparency-log | `ec12dda` (12 leaves; unchanged since paper submission) |
| pacta (producer) | github.com/saymrwulf/proof-aware-crypto-tooling-agent | change-freeze LIFTED 2026-07-16 (IACR decided). Producer for entry 13 = `PACTA_COMMIT` (§2a): the commit carrying the round-6 parser hardening + fail-closed classifier + leaf `scope` block + `examples/repos.yaml` entry. NOT the old `3d81d53`. |
| Forgejo mirrors | `https://zkdefi.org/saymrwulf/<repo>.git` (anonymously readable) | pull-synced by server cron nightly 03:00 UTC (`/home/admin/cloud/bin/reconcile-mirrors.py`, log `.reconcile.log`); verify per step A5 |
| log public key | `lean-transparency-log/provider.ed25519.pub` (PEM) | fingerprint `874c8a00…a56a` in `log-metadata.json` |
| log PRIVATE key | **RESOLVED 2026-07-12**: laptop-side, mode 0600, inside a gitignored state dir of the pacta working tree (exact path in operator-private notes, deliberately not in this public file); public half byte-matches `provider.ed25519.pub`. NOT on the droplet. encrypted SD backup exists (A3b, operator, 2026-07-14) | A3 done; A3b done |
| producer driver | **RESOLVED 2026-07-12**: it exists and is committed — pacta's `provider/` CLI (`python3 -m pacta_provider`: `check` → signed attestation; `log-append` → leaf + signed STH + receipt; `log-publish` → public face). Heads are signed with `signing_backend: verified-dalek-serial` (the dogfooded verified signer), `self_inclusion: verified`. Only the per-run orchestration was session work | see step A4 (rehearsal, not reconstruction) |
| server deployment | the private infrastructure repo (github, `master`) — since `a186bac` includes the ltl vhost/service/reconstruct.py, md5-verified == droplet | see its `DEPLOY.md` § "The LTL service" |

---

## PHASE A — preparation (complete except A2)

### A1. Reviewer confirmations of round 4 — **DONE (2026-07-15)**
Both round-4 reviews are on the SD card. Claude reviewer: "Nothing
blocks the freeze… no remaining findings on the corpus itself"
(re-executed everything hostile, incl. deliberately breaking the
lied-size tripwires — both broke the run as designed — and the first
paper↔Lean cross-check, faithful). GPT-5.6: "Approve after minor
documentation fixes" for an attestation SCOPED TO THE MECHANIZED MODEL
(see the B2 wording requirement below); its principal finding (the
deployment refinement invariant is unmechanized) is now KNOWN-GAPS
gap 15. The round-5 housekeeping freeze addressed both reviewers'
remaining documentation items.

### A2. The author's read (the one step only the operator can do)
Read, in this order, against the paper's §6 and §10:
1. `STATEMENT-MAP.md` — every row: does the Lean statement say what
   the paper's item says?
2. `KNOWN-GAPS.md` — all **15** entries (confirm the count on the day:
   `grep -cE '^[0-9]+\.' KNOWN-GAPS.md` → 15): is each acceptable to
   publish? Gap 15 (deployment refinement invariant unmechanized) is
   the one that most constrains the leaf's claim — read it last and
   deliberately.
No proofs need reading; the kernel checked those. Budget one evening.
**Check:** operator writes one line — "statement map and gaps read and
accepted, <date>" — into the SD card notes (NOT into a repo, to keep
the repo freeze clean until Phase B).

### A3. Locate and verify the signing key (operator-only; no agent)
The private key's location was deliberately NOT hunted down by the
agent (credential searches are operator work). Candidate locations, in
likely order: the server (`ssh admin@zkdefi.org`, under
`/home/admin/cloud/ltl/` or a docker volume of the `ltl` compose
service); a local directory outside the git repos; removable media.
Find the file, then verify it is THE key by deriving its public half
and comparing byte-for-byte with the published one:

```
openssl pkey -in <CANDIDATE_PRIVATE_KEY> -pubout \
  | diff - lean-transparency-log/provider.ed25519.pub \
  && echo "KEY CONFIRMED" || echo "WRONG KEY - keep looking"
```

**Check:** prints `KEY CONFIRMED`. Then record the path in the
operator's private notes (never in git). Do not copy the key anywhere,
do not print it, do not change its permissions.

### A4. Structural 12→13 rehearsal — **DONE (round 6, 2026-07-16)**
The first A4 rehearsal (a one-leaf log from scratch) was rejected by
round-6 review: it exercised the invocation but NOT the 12→13
transition. Redone as a structural 12→13 rehearsal (GPT Method B:
throwaway key on a disposable COPY of the real operational state).
Transcript on SD (`entry13-rehearsal-12to13_20260716-…_e1a15aab.txt`),
throwaway state destroyed. Verified end to end:
- disposable copy of `provider/state/transparency-log-main` roots to
  `bcd15f9d…` == live (the real append base);
- candidate from the clean-room subject `172a1d0` + pinned producer:
  61/61 proven+clean, and the **scoped wording is IN THE LEAF's `scope`
  block** (subject/certs/scope all inspected — this is the B2b gate,
  rehearsed);
- append 12→13 → tree_size 13, leaf index 12;
- prefix immutability: entries 0..11 byte-identical to the predecessor;
- consistency 12→13 accepted by BOTH the deployed verifier AND the
  mechanized model.

Three real defects were found and fixed by this rehearsal before it
went green:
1. re-APPENDING published entries double-wraps them (`log-append`
   wraps its input; published `leaf` fields are already wrapped) —
   wrong root. The published face itself rebuilds the tree fine; the
   append base must nonetheless be the operational state
   (`provider/state/transparency-log-main`), which stores unwrapped
   attestations. Now B0 checks exactly this.
2. pacta axiom parser mis-attributed cones to axiom-free certificates
   and matched names by substring (the accumulator is the first subject
   with axiom-free certs) — fixed + record-scoped + fail-closed
   classification (pacta round-6 hardening; 6 regression tests).
3. the attestation LEAF did not carry its scope block at all — the
   scoped wording reached only the claim card. Fixed: `build_attestation`
   now emits `scope` (guarantees/exclusions/deployment_constraints).

Version-controlled artifacts for the real run: pacta
`examples/repos.yaml` entry `ltl-accumulator-verified` (61 certs w/
per-cert cones, nine `axiom_imports`, `known_status` = the scoped
wording), plus the round-6 pacta commit (`PACTA_COMMIT`, §2a). The real
B-phase run differs only in: real key/pub paths (A3 notes),
`--log-dir provider/state/transparency-log-main`, `log-publish
--git-dir <lean-transparency-log clone>`, and — the one thing the
rehearsal could NOT do under a throwaway key — full-history
witness-audit under the PRODUCTION key (that is B0 + B3's job).

Background (retained): the producer driver was never lost session work
— it is the committed `pacta_provider` CLI (`check` → signed
attestation; `log-append` → leaf + head via `make_signed_tree_head`,
verified-dalek-serial signer; `log-publish` → public face; `serve`
keyless). Leaves 8–11 were produced this way; only the per-run
orchestration was ephemeral, and it is now the version-controlled
`examples/repos.yaml` entry + this runbook's B-steps.

### A3b. Back up the signing key — **DONE (operator, confirmed 2026-07-14)**
Completed by the operator; the procedure below is retained as the
reference for future key-backup refreshes.
The laptop file is the only copy in existence; a disk failure would
freeze the log at its current size forever (still verifiable, never
extendable). Operator-only: create an ENCRYPTED backup (e.g.
`openssl enc -aes-256-cbc -pbkdf2` or `age`) of the key file onto the
SD card under the standing naming convention, passphrase memorized or
stored separately — never plaintext, never in any git repo, never on
the droplet. **Check:** decrypt the backup to a temp file, run A3's
openssl pubkey diff against it (prints KEY CONFIRMED), shred the temp
file.

### A5. Confirm the Forgejo mirrors (no SSH needed)
The mirrors are anonymously readable. For each repo, both commands must
print the same hash:

```
for r in ltl-accumulator-verified lean-transparency-log \
         proof-aware-crypto-tooling-agent dalek-ed25519-verified \
         anza-ed25519-verified risc0-ed25519-verified betrusted-ed25519-verified; do
  a=$(git ls-remote "https://github.com/saymrwulf/$r.git" main | cut -f1)
  b=$(git ls-remote "https://zkdefi.org/saymrwulf/$r.git" main | cut -f1)
  [ "$a" = "$b" ] && echo "OK   $r $a" || echo "LAG  $r github=$a forgejo=$b"
done
```

**Check:** seven `OK` lines. A `LAG` line within 24h of a push is
normal (nightly 03:00 UTC sync); a LAG older than that means the
server cron needs attention (`/home/admin/cloud/.reconcile.log`).

---

## PHASE B — the append (BLOCKED until the gate below is fully open)

**GATE — all six, no exceptions, no substitutions:**
- [ ] A1 done (both reviewers confirmed, in writing, on SD)
- [ ] A2 done (author read of all **15** KNOWN-GAPS entries, dated note)
- [ ] A3 done (KEY CONFIRMED) + A3b (encrypted backup)
- [ ] A4 done (structural **12→13** rehearsal green — round 6)
- [ ] B0 passed on the day (live predecessor state re-verified)
- [ ] The operator has given an explicit, fresh order to append — in
      words, on that day. A past intention does NOT count. (The IACR
      decision arrived 2026-07-16, rejected; per operator it no longer
      gates — so this reduces to the fresh order.)

Set the release tuple (§2a) into the shell first; every step reads it:
```
SUBJECT_COMMIT=172a1d0653f489d5b7cb73ac7942a57cbb496532
PACTA_COMMIT=<pacta commit with the round-6 hardening + repos.yaml entry>
EXPECTED_OLD_SIZE=12
EXPECTED_OLD_ROOT=bcd15f9d7ea1c9e5bd0a9e64fa8d846208b1e29ee167d4f1eac19b30e6913ee9
```

### B0. Preflight the live predecessor state (NEW — round-6 GPT §10)
An append-only system must re-read its actual predecessor, not trust a
Facts table. Fresh clone of `lean-transparency-log`; verify ALL of:
- exactly `$EXPECTED_OLD_SIZE` NUMBERED leaves `entries/[0-9]*.json`
  (NOT `ls entries/ | wc -l` — `entries/` also holds per-component
  `<component>.attestation.json` convenience pointers; the live log has
  12 numbered leaves + 4 named pointers = 16 files. The tree size is the
  numbered count and the STH's `tree_size`, never the file count);
- `latest-sth.json` tree_size == `$EXPECTED_OLD_SIZE`;
- its full `root_hash` == `$EXPECTED_OLD_ROOT`;
- the STH signature verifies under `provider.ed25519.pub`
  (fingerprint == `KEY_FINGERPRINT`);
- `pacta witness-audit --published-dir <clone>` exits 0 (every prefix
  root + every historical STH signature — real key, so this passes here
  where the rehearsal could not);
- live service agrees: `curl -s https://ltl.zkdefi.org/v1/sth` returns
  the same size and root;
- GitHub mirror head == local clone head;
- the operator's operational state
  (`provider/state/transparency-log-main`) has `$EXPECTED_OLD_SIZE`
  entries and roots to `$EXPECTED_OLD_ROOT` (this IS the append base.
  The published face DOES rebuild the tree — hash each stored `leaf`
  as-is; witness-audit does exactly that. The trap the round-6
  rehearsal hit is different: published entries store the WRAPPED leaf,
  and feeding them back through `log-append` wraps them AGAIN —
  double-wrapped leaves, wrong root. Appends therefore run ONLY against
  the operational state, which stores unwrapped attestations);
- no partial entry 13 exists anywhere (no `entries/000012.json`, no
  size-13 head).
**Check:** every bullet true. Any mismatch: STOP.

### B1. Clean-room re-verification of the subject
```
git clone https://github.com/saymrwulf/ltl-accumulator-verified /tmp/attest-13
cd /tmp/attest-13 && git checkout $SUBJECT_COMMIT
test -z "$(git status --porcelain)"        # clean tree
cd verification && ./check.sh ; echo "exit=$?"
```
**Check:** clean tree; prints `=== ATTESTATION GREEN (Lean + fidelity)
===` and `exit=0`. Then `./selftest_audit.sh ; echo "exit=$?"` →
`SELF-TEST GREEN`, `exit=0`. Archive the check transcript; record its
sha256 (bound into evidence per B6). Any other outcome: STOP.

### B1b. Pin the producer (NEW — round-6 GPT §4; corrected during execution)
The leaf is generated by pacta AND signed by the verified-dalek-serial
dogfood binary using the private key — BOTH the built binary
(`dogfood/state/`) and the key (`provider/state/local-provider/`) live
only in the operator's working tree, NOT in a bare clone. So the
producer for B2/B3 is the operator's pacta WORKING TREE, verified to be:
```
git -C <pacta working tree> rev-parse HEAD          # == $PACTA_COMMIT
git -C <pacta working tree> status --porcelain   | grep -v '^??' | wc -l                           # == 0 (tracked clean)
ls dogfood/state/*.provenance.json                  # dogfood binary present
python3 scripts/mini_pytest.py                      # full green (needs the binary)
```
**Check:** HEAD == `$PACTA_COMMIT`; no tracked modifications; dogfood
binary present; suite green. (A fresh clone will FAIL the wallet
dogfood-signer test — that test needs the built binary; it is
orthogonal to the log path. Verify the log-relevant modules explicitly
if in doubt: `test_lean.py`, `test_provider.py`, `test_web_and_witness.py`.)

### B2. Generate the candidate attestation (do NOT append yet)
Using the pinned producer (the operator's pacta working tree at
`$PACTA_COMMIT`, verified in B1b) and its
`examples/repos.yaml` entry `ltl-accumulator-verified`, run
`pacta_provider check` against the clean-room subject `/tmp/entry13/attest-13`
(A4's rehearsed invocation, real key/pub from A3's notes). NOTE: the
candidate emerges PROVIDER-SIGNED (check signs at generation — that is
fine and reversible); what must not happen before inspection is the
APPEND. Nothing enters the log in this step.

### B2b. Candidate-leaf inspection gate (NEW — round-6 GPT §5, both reviewers)
Before any append, mechanically require of the generated attestation:
- `subject.component == ltl-accumulator-verified`
- `subject.repo_url ==` the expected URL
- `subject.repo_commit == $SUBJECT_COMMIT` (FULL sha)
- 61 certificates; all `status == proven`; all `axiom_status == clean`
- `scope.deployment_constraints` contains the REQUIRED scoped wording
  (below) and does NOT contain "deployed verifier is formally verified"
- `scope.exclusions` contains the boundary exclusions (SHA-256 CR,
  gaps 14/15, gap 4)

REQUIRED ATTESTATION SCOPE (round-4 GPT §11; now carried by the LEAF's
`scope` block — round-6 fix — not merely the claim card):

> This corpus kernel-checks the listed theorems about the mechanized
> recursive accumulator model. Correspondence with the deployed
> inclusion verifier is supported by finite differential testing over
> the pinned families. The deployed consistency verifier is not
> extensionally equal to the model; applying the mechanized soundness
> result to the deployed consumer flow additionally relies on an
> unmechanized authentic-size/root invariant (KNOWN-GAPS 14/15).

**Check:** all assertions pass; record the candidate's pre-append sha256.
Any failure: STOP (do not append a leaf you could not inspect).

### B3. Append 12→13 against the operational state
`pacta_provider log-append --log-dir provider/state/transparency-log-main`
with the inspected candidate; then `log-publish --git-dir <B0's log
clone>`. Produces `entries/000012.json`, updated `latest-sth.json`
(tree_size 13), one new `sth-history.jsonl` line, one new receipt.
**Check (exact-path + prefix immutability — corrected empirically on
the live-state clone 2026-07-16; the round-6 "exactly 4 paths" was
WRONG — `publish` regenerates every component's inclusion-proof receipt
against the NEW head, which is correct CT behavior, not tampering):**
the publish clone's `git status --porcelain` shows EXACTLY these, and
nothing else:
```
?? entries/000012.json                              # the new leaf
?? entries/ltl-accumulator-verified.attestation.json # new component pointer
?? receipts/ltl-accumulator-verified.receipt.json    # new component receipt
 M latest-sth.json                                   # tree_size 12→13
 M sth-history.jsonl                                 # one line appended
 M receipts/anza-ed25519-verified.receipt.json       # ) inclusion proofs
 M receipts/betrusted-ed25519-verified.receipt.json  # ) recomputed vs the
 M receipts/dalek-ed25519-verified.receipt.json      # ) size-13 head —
 M receipts/risc0-ed25519-verified.receipt.json      # ) EXPECTED, correct
```
INVARIANTS (any violation = STOP):
- `entries/000000.json`..`000011.json` byte-identical to the pre-run clone;
- the 4 existing `entries/<component>.attestation.json` byte-identical
  (their attestation content is stable; only receipts move with the head);
- `provider.ed25519.pub` UNCHANGED (the real key is the same key — if this
  shows M, the WRONG key signed: STOP);
- `sth-history.jsonl`: all prior lines unchanged, exactly one appended;
- the new head's root == the root the append computed;
- `pacta witness-audit` on the clone exits 0 (real key — full history,
  incl. every historical STH signature, verifies).

### B3b. Consumer's-eye 12→13 (round-6: independent pin advance)
From a DIFFERENT directory holding the OLD pin (size 12, root
`$EXPECTED_OLD_ROOT`): `pacta sth-refresh` against the clone must
verify the new head signature, verify consistency 12→13, and advance
the pin to 13. **Check:** exit 0, pin now 13.

### B4. Publish (the single irreversible step)
The droplet serves the log from a DERIVED dir (`~/cloud/ltl/log`),
rebuilt from a content mirror (`~/cloud/ltl/published`) — a bare
`git pull` in `app/` is NOT enough (the private infra repo's DEPLOY.md
§ "The LTL service").
```
cd <log clone> && git add -A && git commit -m "log update: leaf 12 - attestation of ltl-accumulator-verified@$SUBJECT_COMMIT (mechanized-model scope; KNOWN-GAPS 14/15)" && git push origin main
ssh admin@zkdefi.org
  cd ~/cloud/ltl/app && git pull                          # code/paper (usually no-op)
  git clone --depth 1 https://github.com/saymrwulf/lean-transparency-log /tmp/ltl-pub \
    && rsync -a --exclude .git /tmp/ltl-pub/ ~/cloud/ltl/published/ && rm -rf /tmp/ltl-pub
  cd ~/cloud/ltl && python3 reconstruct.py                # re-derive log/
  cd ~/cloud && docker compose restart ltl
```
**Check:** `curl -s https://ltl.zkdefi.org/v1/sth` returns
`"tree_size": 13` and the same root the append computed. This is the
first and only irreversible action; everything before it was on
disposable clones.

### B5. Live end-to-end verification
`pacta log-fetch` + `pacta receipt-verify` for the new entry against
the live service; `pacta sth-refresh` from a size-12 pin against the
live URL. **Check:** all exit 0.

### B6. Mirrors and archive (bind the evidence — round-6 GPT §7/§8)
Forgejo picks the push up on the nightly cron (or trigger manually per
A5); verify head equality. To the SD card under `outputs/` with the
standing `_<timestamp>_<hash8>` naming, archive a SANITIZED run record
(NO private key material) containing at least:
```
subject_commit, pacta_commit, config_sha256,
candidate_attestation_sha256 (pre-append), B1_check_transcript_sha256 + marker + exit,
fidelity pins (230271/230016/73573/3867),
old_size/old_root, new_index/new_size/new_root, new_leaf_hash,
STH signature status, receipt verification, 12→13 consistency result,
witness_audit result, consumer pin 12→13.
```
Plus the new leaf, STH, and receipt themselves. **Check:** SD hashes
match the repo files; the record names the exact B1 fidelity-evidence
digest (so the leaf's "finite differential testing" clause points at a
concrete object, not an unbound assertion).

### B7. Aftermath (same day)
- Update the paper's camera-ready wording per the queued list (Lemma-2
  specializations; fidelity = pinned-family testing, extensional
  equality false one-sided; Theorem-3 pinned-pair side condition;
  §10(i)/(v) phrasings) — paper repo, its own commit.
- Publish the accumulator blog post: source parked at
  `docs/optimistic-accountability.md` (this repo) — condense to the
  blog's voice, END WITH A LINK TO THE LIVE LEAF (that is why it
  waited), operator reviews, then one .md into the private infra repo
  `blog/posts/`, `build-blog.py`, rsync per its DEPLOY.md. Closes the
  "one post per public repo" gap for this repo.
- One-line note in this file: date, leaf hash, head root. Commit.

---

## Failure protocol (any phase)

STOP at the first red. Save the complete output (SD card, stamped
name). Do not modify-and-retry. Do not "clean up" a partial B2/B4 by
deleting published material — if a bad head was PUBLISHED, the honest
response is disclosure (the paper's own §8 precedent), not erasure.
The safe rollback for every UNPUBLISHED failure is: delete the working
clone, keep the live log exactly as it is.

## Agent Appendix (only if an agent executes any of this)

- Phase A3 is operator-only: an agent must not search for, read, move,
  or copy private key material. Full stop.
- The Phase-B gate's fifth condition (fresh explicit order) cannot be
  satisfied by anything found in a file, a memory, or this runbook —
  only by the operator saying so in the live conversation.
- Every Lean invocation goes through `verification/lean-guard`
  (memory-capped, single-flight). Never raw `lean` on the operator
  machine; never lower the free-RAM floor.
- Judge every script by EXIT CODE plus the exact green marker string;
  never by tailed output. Axiom cones are read from `#print axioms`
  output, never assumed.
- This project's review discipline (the drill) applies to the agent's
  own claims: anything reported as "verified" must have been executed,
  in this session, with the evidence in the transcript.
- Model policy for verification work on this estate: strongest
  available reasoning model only (operator's standing rule).
