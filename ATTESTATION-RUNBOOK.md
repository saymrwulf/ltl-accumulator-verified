# ATTESTATION RUNBOOK — entry 13 (the log attests its own machinery)

Status: **Phase A open, Phase B BLOCKED** (see gate at Phase B).
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
| **corpus** | `ltl-accumulator-verified` at freeze commit `2da0a79` — the kernel-checked mechanization of paper §6. |
| **the button** | `verification/check.sh`. Green means: printed `=== ATTESTATION GREEN (Lean + fidelity) ===` AND `echo $?` printed `0`. BOTH. Never judge from scrolled output. |
| **the log** | Live service ltl.zkdefi.org + public mirror repo `lean-transparency-log`. Currently 12 leaves (indices 0–11), head root `bcd15f9d…`, FROZEN. |
| **entry 13** | The next leaf: the attestation of the corpus itself. Does not exist yet. |
| **kit round N** | The review package delivered to the external reviewers after freeze N. Round-1 kit = freeze `6e56414`; round 2 = `260ad64`; round 3 = `9972ab4`; round 4 = `2da0a79` (current). |

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

## 2. Facts (as of 2026-07-12, round-4 freeze)

| artifact | where | state |
|---|---|---|
| corpus | github.com/saymrwulf/ltl-accumulator-verified | `2da0a79`, pushed, working tree clean |
| review kit round 4 | SD `outputs/accumulator-review-kit-round4/` | delivered (corpus tarball sha `2963acbb…`, per-file `CORPUS-MANIFEST.sha256`) |
| log mirror repo | github.com/saymrwulf/lean-transparency-log | `ec12dda` (12 leaves; unchanged since paper submission) |
| pacta | github.com/saymrwulf/proof-aware-crypto-tooling-agent | `3d81d53` (change-frozen during paper processing) |
| Forgejo mirrors | `https://zkdefi.org/saymrwulf/<repo>.git` (anonymously readable) | pull-synced by server cron nightly 03:00 UTC (`/home/admin/cloud/bin/reconcile-mirrors.py`, log `.reconcile.log`); verify per step A5 |
| log public key | `lean-transparency-log/provider.ed25519.pub` (PEM) | fingerprint `874c8a00…a56a` in `log-metadata.json` |
| log PRIVATE key | **location not yet confirmed**, but verified NOT on the droplet (the server only serves; no key material under `~/cloud/ltl/`) — so it is laptop-side or on removable media | see step A3 — Phase B is blocked until confirmed |
| producer driver | **does not exist in version control** | see step A4 — Phase B is blocked until persisted |
| server deployment | private repo `PersonalCloudServer` (github, `master`) — since `a186bac` includes the ltl vhost/service/reconstruct.py, md5-verified == droplet | see its `DEPLOY.md` § "The LTL service" |

---

## PHASE A — do now / while waiting for the IACR decision

### A1. Reviewer confirmations of round 4
Deliver the round-4 kit (already on SD) to both reviewers. Required
outcome, in their words: GPT-5.6's conditional approval stands with the
round-4 evidence (its conditions 2 and 3 — recorded hashes, fresh
button run by exit code — are satisfied by `CORPUS-MANIFEST.sha256` and
`check-transcript.txt` in the kit); the Claude reviewer confirms F1*
was absorbed faithfully (gap 14 + lied-size family + banner scoping).
**Check:** two written reviews on the SD card saying so. If either
finds anything new: run another revision round first; do not proceed.

### A2. The author's read (the one step only the operator can do)
Read, in this order, against the paper's §6 and §10:
1. `STATEMENT-MAP.md` — every row: does the Lean statement say what
   the paper's item says?
2. `KNOWN-GAPS.md` — all 14 entries: is each acceptable to publish?
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

### A4. Reconstruct and persist the append driver (blocker, found 2026-07-12)
Finding: the script that appended leaves 8–11 was session work and was
never committed anywhere. Phase B must not be improvised. Before the
IACR decision arrives, a driver script must be written, committed (to
pacta `tools/`, in a commit that touches nothing else — this does not
alter deployed behavior or any paper claim), and rehearsed. It must do
exactly, in order, against a THROWAWAY copy of the log repo:
1. build the attestation JSON for subject `ltl-accumulator-verified @
   2da0a79` with the same schema as `entries/000008.json`
   (`pacta.attestation` builders + certificate list from the button's
   Phase-3 cone output);
2. compute the leaf bytes (`pacta.transparency.leaf_bytes_for_attestation`),
   append as `entries/000012.json`;
3. recompute the root over all 13 leaves (`merkle_root`), build the new
   head via `pacta.transparency.make_signed_tree_head(log_id,
   tree_size=13, root_hash, timestamp, private_key_path,
   public_key_path)`;
4. update `latest-sth.json`, append to `sth-history.jsonl`, write the
   inclusion receipt under `receipts/`;
5. NEVER touch existing files under `entries/`.
**Check (rehearsal, throwaway copy only):** `pacta witness-audit` on
the throwaway copy exits 0 — every prefix root recomputed, every
historical STH + signature verified, including the new one. The
throwaway copy is then DELETED (its head was signed with the real key
over a rehearsal tree — it must never be published or retained; if
retention is wanted for study, rehearse with a throwaway KEY instead).

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

**GATE — all five, no exceptions, no substitutions:**
- [ ] A1 done (both reviewers confirmed, in writing, on SD)
- [ ] A2 done (author read, dated note)
- [ ] A3 done (KEY CONFIRMED)
- [ ] A4 done (driver committed + rehearsal witness-audit exit 0)
- [ ] The IACR decision has arrived AND the operator has given an
      explicit, fresh order to append — in words, on that day.
      A past "we'll do it after acceptance" does NOT count.

### B1. Clean-room re-verification of the subject
```
git clone https://github.com/saymrwulf/ltl-accumulator-verified /tmp/attest-13
cd /tmp/attest-13 && git checkout 2da0a79
cd verification && ./check.sh ; echo "exit=$?"
```
**Check:** prints `=== ATTESTATION GREEN (Lean + fidelity) ===` and
`exit=0`. Then `./selftest_audit.sh ; echo "exit=$?"` → `SELF-TEST
GREEN`, `exit=0`. Any other outcome: STOP (iron rule 4).

### B2. Run the driver (from A4) against the REAL log repo clone
Fresh clone of `lean-transparency-log`, driver runs once, produces:
`entries/000012.json`, updated `latest-sth.json` (tree_size 13),
one new line in `sth-history.jsonl`, one new receipt.
**Check:** `git status` shows exactly those four paths changed/added,
nothing else. `pacta witness-audit` on the clone exits 0.

### B3. Consumer's-eye check before publishing
From a DIFFERENT directory with the old pin (size 12):
`pacta sth-refresh` against the local clone (or after B4, the live
URL) must verify the signature, verify consistency 12 → 13, and
advance the pin. **Check:** exit 0, pin now 13. This exercises the
exact theorems of the corpus one last time, on the real data.

### B4. Publish
The droplet serves the log from a DERIVED dir (`~/cloud/ltl/log`),
rebuilt from a content mirror (`~/cloud/ltl/published`) — a bare
`git pull` in `app/` is NOT enough (see PersonalCloudServer DEPLOY.md
§ "The LTL service" for the layout).
```
cd <log clone> && git add -A && git commit -m "log update: leaf 12 - attestation of ltl-accumulator-verified@2da0a79 (paper §6 mechanization)" && git push origin main
ssh admin@zkdefi.org
  cd ~/cloud/ltl/app && git pull                          # code/paper (usually no-op here)
  # refresh published/ with the new log content, e.g.:
  git clone --depth 1 https://github.com/saymrwulf/lean-transparency-log /tmp/ltl-pub \
    && rsync -a --exclude .git /tmp/ltl-pub/ ~/cloud/ltl/published/ && rm -rf /tmp/ltl-pub
  cd ~/cloud/ltl && python3 reconstruct.py                # re-derive log/
  cd ~/cloud && docker compose restart ltl
```
**Check:** `curl -s https://ltl.zkdefi.org/v1/sth` returns
`"tree_size": 13` and the same root the driver computed.

### B5. Live end-to-end verification
`pacta log-fetch` + `pacta receipt-verify` for the new entry against
the live service; `pacta sth-refresh` from a size-12 pin against the
live URL. **Check:** all exit 0.

### B6. Mirrors and archive
Forgejo picks the push up on the nightly cron (or trigger manually per
A5); verify head equality. Copy the new leaf, STH, and receipt to the
SD card under `outputs/` with the standing `_<timestamp>_<hash8>`
naming. **Check:** SD hashes match the repo files.

### B7. Aftermath (same day)
- Update the paper's camera-ready wording per the queued list (Lemma-2
  specializations; fidelity = pinned-family testing, extensional
  equality false one-sided; Theorem-3 pinned-pair side condition;
  §10(i)/(v) phrasings) — paper repo, its own commit.
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
