#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check.sh — THE button (accumulator corpus). Same discipline as the
# *-ed25519-verified repos: compiles every shipped .lean through lean-guard
# and axiom-audits every certificate against its DOCUMENTED exact cone,
# both directions.
#
# Phases: 0 resource/integrity · 1 stub+axiom-smuggling audit ·
#         2 compile manifest · 3 boundary-exact axiom audit ·
#         3b environment-derived coverage · 3c doc-consistency ·
#         3d statement + specification binding · 4 definition fidelity
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
# Toolchain bootstrap is overridable for reviewers with their own install
# (review round 3, GPT §7); the operator default stays pinned.
AENEAS_ENV="${AENEAS_ENV:-$HOME/aeneas-toolchain/env.sh}"
[ -f "$AENEAS_ENV" ] || { echo "FATAL: Aeneas environment not found: $AENEAS_ENV (set AENEAS_ENV; or use run_bare.sh with a plain lean per lean-toolchain)"; exit 1; }
source "$AENEAS_ENV"
HERE="$(cd "$(dirname "$0")" && pwd)"
AENEAS_LEAN="$AENEAS_HOME/backends/lean"
TIMEOUT="${LEAN_TIMEOUT:-600}"
export LEAN_MEM_MB="${LEAN_MEM_MB:-4096}"
CORES="${LEAN_MAX_CORES:-0-3}"

GEN_MODULES=( LTLAcc/HashExternal )
PROOFS=( Basic Completeness Extract Descent Consistency Binding3 Refactor Theorem3 PinStore )
# The audit infrastructure, named ONCE. These are not corpus — they are the
# instruments — but they are Lean modules in the audited tree, so the dead-file
# scan must know them by membership rather than by two hard-coded basename
# comparisons, and Phase 3b must inventory what they declare. CLASS 9: until
# 2026-07-31 nothing looked at the drivers' own declaration surface, so an
# `axiom` or a `theorem` added to either was invisible to every phase.
DRIVERS=( AxiomCheck Inventory )

# Certificates and their exact expected cones (observed via #print axioms,
# never guessed; any drift in EITHER direction is a failure).
# AUDIT SURFACE: Phase 3b pins the FULL environment of the corpus modules
# (inventory-allowlist.txt, every compiler-generated auxiliary included —
# the count is pinned by the allowlist itself and asserted against the
# docs in Phase 3c); the entries below are the human-reviewed statement
# surface, additionally queried through #print axioms in Phase 3 and
# cross-checked against the inventory's independently computed cones.
declare -A CONES=(
  [LTLAcc.domsep]=""
  [LTLAcc.kbelow_pos]="propext, Quot.sound"
  [LTLAcc.kbelow_lt]="propext, Quot.sound"
  [LTLAcc.le_two_kbelow]="propext, Quot.sound"
  [LTLAcc.kbelow_pow2]="propext, Quot.sound"
  [LTLAcc.MTH]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Root]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.ConsRec]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Path]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.incl_complete]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.hnode_preimage_inj]="propext"
  [LTLAcc.IsCollision]="LTLAcc.sha256"
  [LTLAcc.extractIncl]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractIncl_correct]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractIncl_nonvacuous]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractMTH]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractMTH_correct]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractMTH_nonvacuous]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.kbelow_prefix_eq]="propext, Quot.sound"
  [LTLAcc.take_take_le]="propext, Quot.sound"
  [LTLAcc.take_drop_prefix]="propext, Classical.choice, Quot.sound"
  [LTLAcc.extractConsNode]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.take_all]="propext"
  [LTLAcc.consRecBinding]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.consRec_base_false_eq]="propext, Classical.choice, Quot.sound"
  [LTLAcc.consRec_base_true_eq]="propext"
  [LTLAcc.extractCons]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractCons_correct]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractCons_nonvacuous]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.pinAccept_monotone]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.pin_prefix_correct]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.fork_distinct]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.pin_prefix_nonvacuous]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.MTH_single]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.MTH_split]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Root_left]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Root_one]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Root_one_cons]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.Root_right]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.acceptCons]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.exists_singleton_of_length_one]="propext, Classical.choice, Quot.sound"
  [LTLAcc.getD_drop]="propext, Quot.sound"
  [LTLAcc.getD_take]="propext, Quot.sound"
  [LTLAcc.hleaf]="LTLAcc.sha256"
  [LTLAcc.hnode]="LTLAcc.sha256"
  [LTLAcc.kbelow]="propext, Quot.sound"
  [LTLAcc.kbelow_eq_of_pow2_between]="propext, Quot.sound"
  [LTLAcc.pinAccept]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.pinExtract]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.pow2_exp_unique]="propext, Quot.sound"
  [LTLAcc.take_append_drop]=""
  [LTLAcc.eq_dropLast_append_of_getLast?]="propext"
  [LTLAcc.instInhabitedHash]="propext"
  [LTLAcc.instDecidableEqHash]=""
  [LTLAcc.Hash]=""
  [LTLAcc.acceptIncl]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.acceptIncl_complete]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.acceptIncl_sound]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.extractCons_correct_paper]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.consRec_some_le]="propext, LTLAcc.sha256, Quot.sound"
  [LTLAcc.acceptCons_sound]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
)

# (The former EXCLUDE table is gone: since Phase 3b reads the environment,
# sha256 and Bytes are ordinary allowlist entries — the axiom is pinned as
# the SINGLE axiom-kind constant, the abbrev carries its empty cone.)

free -m | awk '/Mem:/{if($7<2048){print "FATAL: <2GB RAM available — refusing to compile"; exit 1}}'
echo "=== Phase 0: source integrity ==="
for f in "$HERE"/gen/LTLAcc/*.lean "$HERE"/Proofs/*.lean; do
  [ -f "$f" ] || continue
  if ! grep -qE '^(/-|import |namespace |theorem |def |noncomputable |open |set_option |--|abbrev )' "$f"; then
    echo "CORRUPTED: $f is not Lean source. Restore: git checkout HEAD -- $f"; exit 1
  fi
done
echo "  all sources valid"

# ── Phase 0a: build hygiene ─────────────────────────────────────────────────
# P0-a was applied to the four ed25519 repositories on 2026-07-30 and never
# here — found on 2026-07-31 by the control repo's capability matrix, which
# asks the property rather than looking for a phase by name.
#
# The finding that made it matter there applies verbatim: a verification that
# never cleans up cannot distinguish "these proofs check" from "these proofs
# check GIVEN WHATEVER IS LYING AROUND". Compiled artifacts are gitignored, so
# no `git status` can show a reader that a verdict rested on an object from an
# earlier run of a different script. Purge, and compile from source.
#
# This repository has no --audit-only mode, so there is no case in which the
# artifacts must be kept: the purge is unconditional.
echo "=== Phase 0a: build hygiene ==="
find "$HERE" -name '*.olean' -delete 2>/dev/null || true
find "$HERE" -name '*.ilean' -delete 2>/dev/null || true
echo "  purged every compiled artifact — this run compiles from source"
# Recursive: no compiled artifact anywhere in the tree may lack its source
# (review round 2, GPT M1 — previously scanned Proofs/*.olean only).
while IFS= read -r -d '' o; do
  [ -f "${o%.olean}.lean" ] || { echo "ORPHAN OLEAN: $o has no sibling .lean (stale artifact)"; exit 1; }
done < <(find "$HERE" -name '*.olean' -print0)

# ── Phase 0c: harness integrity ─────────────────────────────────────────────
# WHY. Every gate below is executed by a script that, until now, nothing
# pinned. Round-5 review of the companion SLH-DSA repository stubbed the
# compiler wrapper alone and its button printed ALL GREEN in 3.6 seconds over
# deliberately destroyed proofs. Depth of checking is worth nothing if the
# thing doing the checking is unbound — and this repo's gates are the estate's
# strongest, which makes them the most valuable to switch off.
#
# WHICH files must be pinned is POLICY, and policy lives here — in the root of
# trust — never inside the map being consulted. If the required set were read
# from HARNESS.sha256, deleting an entry would silently un-pin that file
# instead of failing the build.
#
# Membership is SELF-DERIVING from two sources the filesystem can answer: the
# executable bit (anything this script can shell out to) and gen/**.lean (the
# extracted model, which nothing else byte-pins in this repo). Load-bearing
# files that are neither — the audit drivers, the policy tables, the toolchain
# pin, the fidelity harness — cannot be discovered and are listed explicitly.
HARNESS_EXTRA=(
  AUDIT-MANIFEST.txt        # the statement block Phase 3d's digest is taken over
  inventory-allowlist.txt   # the pinned audit surface Phase 3b diffs against
  lean-toolchain            # which Lean the corpus claims to have been checked by
  fidelity/lean_defs.py     # the Python transcription the differential compares
  fidelity/run_fidelity.py  # the differential itself
  PACTA-PIN.sha256          # WHICH pacta the differential is entitled to compare
                            # against. Pinned here because it is not executable
                            # and would otherwise sit outside the harness set —
                            # a subject pin an attacker may rewrite pins nothing,
                            # the same shape as a forgeable .audit-basis.
  Proofs/Inventory.lean     # audit driver: emits the inventory AND the statements
  Proofs/AxiomCheck.lean    # audit driver: the #print axioms queries of Phase 3
)
echo "=== Phase 0c: harness integrity ==="
if [ ! -s "$HERE/HARNESS.sha256" ]; then
  echo "FATAL: HARNESS.sha256 is missing or empty — the harness is unpinned."
  exit 1
fi
# check.sh is pinned like everything else: that catches drift and accident. It
# does NOT stop an author who edits this script and refreshes its pin in one
# commit — nothing executed by the harness can. The defence there is that both
# changes appear in the diff at the pinned commit.
HARNESS_REQUIRED=$( { find "$HERE" -type f -executable -not -path '*/.git/*' -printf '%P\n'
                      find "$HERE/gen" -type f -name '*.lean' -printf 'gen/%P\n'
                      printf '%s\n' "${HARNESS_EXTRA[@]}"; } | sort -u )
HARNESS_PINNED=$(awk '{print $2}' "$HERE/HARNESS.sha256" | sort -u)
if [ "$HARNESS_REQUIRED" != "$HARNESS_PINNED" ]; then
  echo "FATAL: the set of harness files does not match HARNESS.sha256."
  echo "  (< pinned, > present and requiring a pin)"
  diff <(echo "$HARNESS_PINNED") <(echo "$HARNESS_REQUIRED") | sed 's/^/    /'
  exit 1
fi
if ! ( cd "$HERE" && sha256sum -c --quiet HARNESS.sha256 ) ; then
  echo "FATAL: a harness file does not match its pin. The button you are"
  echo "running is not the button that was reviewed."
  exit 1
fi
echo "  $(wc -l < "$HERE/HARNESS.sha256") harness files match their pins"

echo "=== Phase 1: stub + axiom-smuggling audit ==="
if grep -rn 'by trivial' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "STUB DETECTED"; exit 1; fi
if grep -rn ' : True :=' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "STUB DETECTED: True-target theorem"; exit 1; fi
if grep -rnE '^(private |protected |noncomputable )*axiom ' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "AXIOM SMUGGLING DETECTED: axiom under Proofs/ — gen/ is the only sanctioned site."; exit 1
fi
# gen/ is the sanctioned site for exactly ONE axiom (review round 2, GPT M1).
# This textual pin is the fast belt; the semantic guarantee is Phase 3b's
# environment inventory (exactly one axiom-kind constant, LTLAcc.sha256).
AXCOUNT=$(grep -hcE '^(private |protected |noncomputable )*axiom ' "$HERE"/gen/LTLAcc/*.lean | paste -sd+ - | bc)
[ "$AXCOUNT" = 1 ] || { echo "AXIOM COUNT DRIFT: gen/ declares $AXCOUNT axioms, sanctioned: 1 (sha256)"; exit 1; }
echo "  clean"

echo "=== Phase 2: compile ==="
LOG=$(mktemp /tmp/acc-check-XXXX.log)
cd "$AENEAS_LEAN"
lake env bash -c "
  set -euo pipefail
  cd '$HERE/gen' && export LEAN_PATH=\"\$LEAN_PATH:\$PWD:$HERE\"
  compile() {
    echo \"  · \$1\"
    LEAN_TIMEOUT=$TIMEOUT LEAN_MAX_CORES=$CORES '$HERE/lean-guard' \"\${1}.lean\" 2>&1 | tee -a '$LOG' || { echo \"FAIL: \$1\"; exit 1; }
  }
  for m in ${GEN_MODULES[*]}; do compile \"\$m\"; done
  cd '$HERE'
  for m in ${PROOFS[*]}; do
    [ -f \"Proofs/\$m.lean\" ] || { echo \"MISSING: Proofs/\$m.lean\"; exit 1; }
    compile \"Proofs/\$m\"
  done
  for f in Proofs/*.lean; do
    b=\$(basename \"\$f\" .lean)
    case \" ${DRIVERS[*]} \" in (*\" \$b \"*) continue;; esac  # audit infrastructure, compiled in Phase 3/3b
    case \" ${PROOFS[*]} \" in (*\" \$b \"*) ;; (*) echo \"DEAD FILE: \$f\"; exit 1;; esac
  done
  # gen/ gets the same unmanifested-source check (review round 2, GPT M1)
  for f in gen/LTLAcc/*.lean; do
    b=\"LTLAcc/\$(basename \"\$f\" .lean)\"
    case \" ${GEN_MODULES[*]} \" in (*\" \$b \"*) ;; (*) echo \"DEAD FILE (gen): \$f\"; exit 1;; esac
  done
  # CLASS 15. The two loops above look only INSIDE Proofs/ and gen/LTLAcc/, so
  # until 2026-07-31 a Lean file anywhere else was invisible: one at the
  # verification root, or under gen/AnythingElse/, was neither compiled nor
  # rejected. It could be imported by name from a manifested module — the
  # manifest names modules, and LEAN_PATH includes both roots — which is a
  # source of the corpus that no phase reads and no pin covers. Nothing may
  # live in either root but the two enumerated sets.
  shopt -s nullglob
  for f in *.lean; do echo \"DEAD FILE (verification root): \$f\"; exit 1; done
  for d in gen/*/; do
    [ \"\$d\" = 'gen/LTLAcc/' ] && continue
    for f in \"\$d\"*.lean; do echo \"DEAD FILE (gen subdirectory): \$f\"; exit 1; done
  done
  for f in gen/*.lean; do echo \"DEAD FILE (gen root): \$f\"; exit 1; done
  shopt -u nullglob
"
if grep -q "uses 'sorry'" "$LOG"; then echo "STUB: sorry detected"; exit 1; fi
rm -f "$LOG"

echo "=== Phase 3: boundary-exact axiom audit ==="
AUD=$(mktemp /tmp/acc-audit-XXXX.log)
cd "$AENEAS_LEAN"
lake env bash -c "
  cd '$HERE' && export LEAN_PATH=\"\$LEAN_PATH:$HERE/gen:$HERE\"
  LEAN_TIMEOUT=300 LEAN_MAX_CORES=$CORES '$HERE/lean-guard' Proofs/AxiomCheck.lean
" > "$AUD" 2>&1 || { cat "$AUD"; exit 1; }
FAIL=0
for cert in "${!CONES[@]}"; do
  want="${CONES[$cert]}"
  if [ -z "$want" ]; then
    exp="'$cert' does not depend on any axioms"
  else
    exp="'$cert' depends on axioms: [$want]"
  fi
  if ! grep -qF "$exp" "$AUD"; then
    echo "  CONE DRIFT: $cert"
    echo "    expected: $exp"
    echo "    observed: $(grep -F "'$cert'" "$AUD" || echo '(missing)')"
    FAIL=1
  else
    echo "  ✓ $cert  [$want]"
  fi
done
rm -f "$AUD"

# -- Phase 3b: ENVIRONMENT-derived audit-surface coverage (fail-closed) ------
# Review round 2 (GPT H1 / Claude NEW-1): the previous source-regex
# enumerator was evadable (attributes, indentation, private/protected,
# instance, and namespace-nested basename collisions). Replaced entirely:
# Proofs/Inventory.lean reads the compiled Lean ENVIRONMENT and emits every
# constant of every corpus module — fully qualified, unfiltered, each with
# kind and axiom cone (its own walker, cross-checked in-process against
# core collectAxioms). inventory_gate.sh diffs that against the pinned
# allowlist, fail-closed BOTH directions. No name shape can hide: what the
# kernel saw is what gets audited.
echo "=== Phase 3b: environment-derived audit-surface coverage ==="
COVFAIL=0
INVLOG=$(mktemp /tmp/acc-inv-XXXX.log)
cd "$AENEAS_LEAN"
lake env bash -c "
  cd '$HERE' && export LEAN_PATH=\"\$LEAN_PATH:$HERE/gen:$HERE\"
  LEAN_TIMEOUT=600 LEAN_MAX_CORES=$CORES '$HERE/lean-guard' Proofs/Inventory.lean
" > "$INVLOG" 2>&1 || { cat "$INVLOG"; echo "INVENTORY COMPILE FAILED"; exit 1; }
"$HERE/inventory_gate.sh" "$INVLOG" "$HERE/inventory-allowlist.txt" || COVFAIL=1

# ── Phase 3b-kernel: kernel-side axiom-declaration gate ─────────────────────
# PORTED FROM THE ed25519 FORKS after round-7 review (Claude, finding F2).
#
# What this repository had: a SOURCE-TEXT axiom grep in Phase 1, and an
# environment walk in Phase 3b that runs inside Inventory.lean. Both have the
# same blind spot from opposite directions. The grep misses ` axiom c : ...`
# with a leading space — this repo's own selftest_audit.sh case 12 exploits
# exactly that. And the environment walk is an `#eval`: a declaration placed
# AFTER it in the same file exists in the compiled object file but not in the
# environment when the walk runs, so the button reported "no axiom, no claim"
# over a claim that was sitting in the environment, with the statement digest
# byte-identical. A reviewer demonstrated it.
#
# The fix is the one the forks already carry: ask the KERNEL, by reading every
# compiled object file directly. readModuleData sees what was actually stored,
# regardless of indentation, attributes, privacy, or where in the file a
# declaration sits relative to any #eval. Membership self-derives from the
# manifest, so a new module cannot escape by being unlisted, and the module
# count must match so a deleted .olean cannot make the scan vacuous.
# PLACEMENT. This deliberately runs INSIDE Phase 3b rather than beside the
# compile phase, unlike the ed25519 forks. There the audit drivers are members
# of the compile manifest, so they exist by the time the kernel gate runs. Here
# they are not: AxiomCheck is compiled by Phase 3 and Inventory by Phase 3b, so
# an earlier gate would fail on a missing artifact — which it did, correctly,
# when this was first ported. It must run after both drivers exist, because the
# instruments are exactly what it has to see.
echo "=== Phase 3b-kernel: kernel-side axiom-declaration gate ==="
KERNLOG=$(mktemp /tmp/acc-kernel-XXXX.log)
AXGATE=$(mktemp "$HERE/.axgate-XXXX.lean")
ALL_MODULES=$(printf '"%s.olean", ' "${PROOFS[@]}" "${DRIVERS[@]}" | sed 's/, $//')
cat > "$AXGATE" <<LEANGATE
import Lean
open Lean System
#eval show CoreM Unit from do
  let dir : FilePath := "$HERE/Proofs"
  let expected : List String := [$ALL_MODULES]
  let mut errs : Array String := #[]
  let mut nConst := 0
  let mut nMod := 0
  let mut seen : Std.HashSet Name := {}
  for name in expected do
    let p := dir / name
    -- FAIL CLOSED ON ABSENCE: a missing artifact would make this scan vacuous
    -- for that module, so it is an error and never a skip.
    unless (← p.pathExists) do
      throwError "MISSING ARTIFACT: {p} — the kernel gate would be vacuous for it"
    let (mod, _) ← readModuleData p
    nMod := nMod + 1
    for ci in mod.constants do
      nConst := nConst + 1
      seen := seen.insert ci.name
      if ci matches .axiomInfo _ then
        errs := errs.push s!"  {name}: {ci.name}"
  unless errs.isEmpty do
    throwError "AXIOM DECLARED under Proofs/ (kernel-side gate):\n{String.intercalate "\n" errs.toList}"
  logInfo s!"  kernel confirms: {nConst} declarations across {nMod} compiled modules, none is an axiom"
  for n in seen do IO.println s!"KERNEL-NAME|{n}"
LEANGATE
cd "$AENEAS_LEAN"
AXGATE_RC=0
lake env bash -c "
  set -euo pipefail
  cd '$HERE/gen' && export LEAN_PATH=\"\$LEAN_PATH:\$PWD:$HERE\"
  cd '$HERE'
  LEAN_TIMEOUT=$TIMEOUT LEAN_MAX_CORES=$CORES '$HERE/lean-guard' '$AXGATE'
" 2>&1 | tee "$KERNLOG" || AXGATE_RC=${PIPESTATUS[0]}
cd "$HERE"
rm -f "$AXGATE" "${AXGATE%.lean}.olean"
if [ "$AXGATE_RC" -ne 0 ]; then
  echo "AXIOM SMUGGLING GATE FAILED (kernel-side) — see the error above."
  rm -f "$KERNLOG" "$INVLOG"; exit 1
fi
echo ""

# ── THE ACCOUNTING IDENTITY ─────────────────────────────────────────────────
# Ported from the ed25519 forks, and the reason it is here is a demonstrated
# attack, not symmetry. A reviewer appended to Proofs/Inventory.lean, AFTER the
# `#eval` that performs the driver walk:
#
#     def bait : Nat := 0
#     theorem bait.smuggled : ... := ...
#
# re-pinned, and ran the button. It printed "no axiom, no claim", the statement
# digest was byte-identical to the clean tree, and the run went green — while a
# theorem with a real axiom cone sat in the compiled environment. It was in
# neither walk: not corpus, because an instrument is not corpus; not driver
# surface, because it post-dates the emitter that reports the driver surface.
#
# The two walks read ENVIRONMENTS. Phase 2b reads OBJECT FILES. What a walk
# cannot see because of where it sits in a file, the object file still holds.
# So the property enforced here is containment, and it is what closes the hole:
#
#     every constant the kernel sees  ⊆  corpus inventory ∪ instrument surface
#
# Compared as SETS, deliberately. Counts cannot express this relation: an
# object file may hold two physical copies of one lazily-materialised equation
# lemma, while an environment holds one constant per name — arithmetic between
# those views misled the ed25519 version of this check twice before it was
# stated as containment.
KERN_NAMES=$(mktemp /tmp/acc-kernnames-XXXX.txt)
ACCT_NAMES=$(mktemp /tmp/acc-acctnames-XXXX.txt)
LC_ALL=C grep '^KERNEL-NAME|' "$KERNLOG" | cut -d'|' -f2 | LC_ALL=C sort -u > "$KERN_NAMES"
{ LC_ALL=C awk -F'|' '/^INV\|/{print $2}' "$INVLOG"
  LC_ALL=C grep '^DRV|' "$INVLOG" | cut -d'|' -f2
} | LC_ALL=C sort -u > "$ACCT_NAMES"
UNACCOUNTED=$(LC_ALL=C comm -23 "$KERN_NAMES" "$ACCT_NAMES")
if [ ! -s "$KERN_NAMES" ]; then
  echo "  ACCOUNTING FAILED: Phase 2b reported no constant names — the scan was vacuous"
  COVFAIL=1
elif [ -n "$UNACCOUNTED" ]; then
  echo "  ACCOUNTING FAILED: the kernel holds constants that neither walk accounts for:"
  printf '%s\n' "$UNACCOUNTED" | head -20 | sed 's/^/    /'
  COVFAIL=1
else
  echo "  accounting: every one of $(wc -l < "$KERN_NAMES") kernel constants is covered by the corpus inventory or the instrument surface"
fi
rm -f "$KERN_NAMES" "$ACCT_NAMES" "$KERNLOG"

# The inventory's corpus-module list must BE the compile manifest — both
# directions, so neither can drift from the other silently.
# Read the module LISTS, not the file. This comparison used to grep the whole
# of Inventory.lean for a backticked name, which meant any PROSE mention of a
# module counted: a doc comment naming `Proofs.AxiomCheck` broke the count, and
# — worse in the other direction — a doc mention of a module missing from the
# array would have satisfied the presence check and hidden the omission. The
# manifest is the arrays; read the arrays.
MODLISTS=$(sed -n '/^def corpusModules/,/\]/p;/^def driverModules/,/\]/p' "$HERE/Proofs/Inventory.lean")
for m in "${GEN_MODULES[@]}" "${PROOFS[@]}"; do
  mod=$(echo "$m" | sed 's|^LTLAcc/|LTLAcc.|; s|^\([A-Z]\)|Proofs.\1|; s|^Proofs\.LTLAcc\.|LTLAcc.|')
  grep -qF "\`$mod" <<<"$MODLISTS" || {
    echo "  MANIFEST DRIFT: $mod compiled by check.sh but not inventoried"; COVFAIL=1; }
done
# The drivers are named in Inventory.lean too, now that it walks their
# declaration surface — so they count on both sides of this equality.
for d in "${DRIVERS[@]}"; do
  [ "$d" = Inventory ] && continue   # covered as the current module, which has
                                     # no module index while it elaborates and
                                     # so is not named in its own module list
  grep -qF "\`Proofs.$d" <<<"$MODLISTS" || {
    echo "  MANIFEST DRIFT: driver Proofs.$d is not inventoried"; COVFAIL=1; }
done
NMANIFEST=$(( ${#GEN_MODULES[@]} + ${#PROOFS[@]} + ${#DRIVERS[@]} - 1 ))
NINV=$(grep -oE '`(LTLAcc|Proofs)\.[A-Za-z0-9_.]+' <<<"$MODLISTS" | wc -l)
[ "$NMANIFEST" = "$NINV" ] || {
  echo "  MANIFEST DRIFT: check.sh compiles $NMANIFEST modules, Inventory lists $NINV"; COVFAIL=1; }

# CLASS 9. The driver-surface block must actually have RUN. Its violations are
# raised inside Lean, so a walk that silently did not execute would look exactly
# like a clean one — the same vacuous-pass shape the INV-COUNT trailer exists to
# close. Require the trailer, and require it to agree with the lines.
NDRV=$(grep -c '^DRV|' "$INVLOG" || true)
DRVTRAILER=$(grep '^DRV-COUNT|' "$INVLOG" | tail -1 | cut -d'|' -f2)
if [ -z "$DRVTRAILER" ] || [ "$DRVTRAILER" != "$NDRV" ]; then
  echo "  DRIVER SURFACE NOT OBSERVED: trailer=${DRVTRAILER:-absent}, observed $NDRV lines"
  COVFAIL=1
elif [ "$NDRV" -eq 0 ]; then
  echo "  DRIVER SURFACE NOT OBSERVED: the instruments declare nothing at all,"
  echo "  which cannot be true — Inventory.lean declares its own machinery."
  COVFAIL=1
else
  echo "  driver surface: $NDRV declarations across the audit instruments, no axiom, no claim"
fi
# NOTE ON WHAT THIS DOES NOT DO. It does not pin WHICH definitions the
# instruments declare — a new inert `def` in a driver is allowed. That is
# deliberate: both drivers are byte-pinned in HARNESS.sha256 (Phase 0c), so
# their contents cannot drift unnoticed, and a second policy file listing their
# internals would add a thing to maintain without adding a thing to catch. What
# the check above adds is the property byte-pinning cannot give: that no
# instrument declares an AXIOM or a CLAIM, whatever its bytes are.

# CONES ⊆ allowlist with IDENTICAL cones: the #print-axioms-pinned table
# and the environment inventory are two independent computations of the
# same facts — any disagreement is a failure of one of them.
# (cones are compared as SETS: CONES keeps #print-axioms order, the
#  inventory emits byte-sorted order — canonicalize both before comparing)
canon() { tr -d ' ' <<<"$1" | tr ',' '\n' | LC_ALL=C sort | paste -sd, -; }
while IFS='|' read -r _ name _ cone; do
  if [ -n "${CONES[$name]+x}" ]; then
    want=$(canon "${CONES[$name]}")
    got=$(canon "$cone")
    [ "$want" = "$got" ] || {
      echo "  CONE CROSS-CHECK FAILED: $name CONES=[$want] inventory=[$got]"; COVFAIL=1; }
  fi
done < <(grep '^INV|' "$HERE/inventory-allowlist.txt")
# (field-equality, not regex — dots in names must not act as wildcards;
#  review round 3, F4)
for cert in "${!CONES[@]}"; do
  awk -F'|' -v n="$cert" '$1=="INV" && $2==n {found=1} END {exit !found}' \
      "$HERE/inventory-allowlist.txt" || {
    echo "  PINNED BUT NOT INVENTORIED: $cert (in CONES, not in allowlist)"; COVFAIL=1; }
done
# (INVLOG is NOT removed here: Phase 3d binds the statement block emitted by
#  this same run. Removed at the end of 3d.)

# every pinned cert must actually be queried by AxiomCheck (no pin-but-never-check)
for cert in "${!CONES[@]}"; do
  grep -qF "#print axioms $cert" "$HERE/Proofs/AxiomCheck.lean" || {
    echo "  PINNED BUT NOT QUERIED: $cert (in CONES, absent from AxiomCheck.lean)"; COVFAIL=1; }
done
[ "$COVFAIL" = 0 ] && echo "  coverage complete: environment == allowlist, CONES cross-checked"
[ "$COVFAIL" = 0 ] || { echo "COVERAGE FAILED"; FAIL=1; }
[ "$FAIL" = 0 ] || exit 1

# -- Phase 3c: documentation consistency (review R4-1: hand-maintained ------
# counts went stale three rounds running — so the docs' numbers are now
# ASSERTED against their sources: allowlist, CONES, and the fidelity pins.
echo "=== Phase 3c: doc-consistency ==="
DOCFAIL=0
NALLOW=$(grep -c '^INV|' "$HERE/inventory-allowlist.txt")
NCONES=${#CONES[@]}
SMAP="$HERE/../STATEMENT-MAP.md"
RDME="$HERE/../README.md"
grep -qF "$NALLOW constants" "$SMAP" || { echo "  DOC DRIFT: STATEMENT-MAP lacks '$NALLOW constants'"; DOCFAIL=1; }
grep -qF "$NCONES human-reviewed" "$SMAP" || { echo "  DOC DRIFT: STATEMENT-MAP lacks '$NCONES human-reviewed'"; DOCFAIL=1; }
grep -qF "$NALLOW constants" "$RDME" || { echo "  DOC DRIFT: README lacks '$NALLOW constants'"; DOCFAIL=1; }
grep -qF "$NCONES human-reviewed" "$RDME" || { echo "  DOC DRIFT: README lacks '$NCONES human-reviewed'"; DOCFAIL=1; }
# fidelity pins quoted in the docs must equal the harness's pinned constants
for n in $(python3 -c "
import re
src = open('$HERE/fidelity/run_fidelity.py').read()
vals = [re.search(r'assert ti == ([0-9_]+)', src).group(1),
        re.search(r'assert tc == ([0-9_]+)', src).group(1),
        re.search(r'LIED_PIN_TOTAL = ([0-9_]+)', src).group(1),
        re.search(r'LIED_PIN_DIV = ([0-9_]+)', src).group(1)]
print(' '.join(f'{int(v.replace(chr(95),\"\")):,}' for v in vals))"); do
  grep -qF "$n" "$SMAP" || { echo "  DOC DRIFT: STATEMENT-MAP lacks fidelity pin '$n'"; DOCFAIL=1; }
done
[ "$DOCFAIL" = 0 ] && echo "  docs agree with allowlist ($NALLOW), CONES ($NCONES), fidelity pins"
[ "$DOCFAIL" = 0 ] || { echo "DOC-CONSISTENCY FAILED"; exit 1; }
# -- Phase 3d: statement + specification binding (P1-a) ---------------------
# WHAT PHASES 3/3b DO NOT ESTABLISH. Phase 3 pins each certificate's exact
# axiom cone; Phase 3b pins the full environment surface, kind and cone, both
# directions. Neither records what a declaration SAYS. A theorem gutted to a
# tautology keeps its name, its kind and its cone. A `def` redefined to BE the
# thing it was meant to specify keeps all three, and every certificate stated
# against it silently becomes vacuous — with the allowlist unmoved.
#
# Proofs/Inventory.lean therefore also emits, for every inventoried constant,
# its fully-elaborated TYPE, and for every definition its fully-elaborated
# BODY. Proof terms are deliberately absent: by proof irrelevance a theorem's
# content is its statement. This phase binds the SHA-256 of that block, and
# the block itself is committed as AUDIT-MANIFEST.txt so a mismatch is DIFFED
# rather than merely reported.
#
# To rotate deliberately: run check.sh, take the printed OBSERVED digest, and
# update the constant below AND AUDIT-MANIFEST.txt in the same reviewable
# commit. Visibility in review is the defence; no harness audits its author.
EXPECTED_STMT_SHA256="e7d422f0be9a9e6f5465058292e30c711d52856428da2b01c470a57ec181540c"
echo "=== Phase 3d: statement + specification binding ==="
STMTFAIL=0
STMT_BLOCK=$(awk '/^STMT-BEGIN/{f=1;next} /^STMT-END/{f=0} f' "$INVLOG")
# FAIL CLOSED ON ABSENCE: no block and a matching block must not share a path.
if [ -z "$STMT_BLOCK" ]; then
  echo "  NO STATEMENT BLOCK emitted by Proofs/Inventory.lean (fail-closed)"; STMTFAIL=1
else
  # Output integrity, same discipline as the INV-COUNT trailer: a truncated or
  # crashed run must not pass as a short-but-matching block.
  N_STMT=$(printf '%s\n' "$STMT_BLOCK" | grep -c '^STMT|')
  STMT_TRAILER=$(grep '^STMT-COUNT|' "$INVLOG" | tail -1 | cut -d'|' -f2)
  if [ -z "$STMT_TRAILER" ] || [ "$STMT_TRAILER" != "$N_STMT" ]; then
    echo "  STATEMENT BLOCK TRUNCATED: trailer=${STMT_TRAILER:-absent}, observed $N_STMT"; STMTFAIL=1
  fi
  # Every inventoried constant must carry a statement line. Inventory.lean
  # asserts this internally too; asserting it here as well means a tampered
  # Inventory.lean cannot simply drop its own check.
  N_INV=$(grep -c '^INV|' "$INVLOG")
  N_TYPES=$(printf '%s\n' "$STMT_BLOCK" | grep -c '|type=')
  if [ "$N_TYPES" != "$N_INV" ]; then
    echo "  STATEMENT COVERAGE GAP: $N_INV constants inventoried, $N_TYPES carry a statement"; STMTFAIL=1
  fi
  GOT_STMT_SHA=$(printf '%s\n' "$STMT_BLOCK" | sha256sum | cut -d' ' -f1)
  if [ "$GOT_STMT_SHA" != "$EXPECTED_STMT_SHA256" ]; then
    printf '%s\n' "$STMT_BLOCK" > "$HERE/.stmt-manifest.observed"
    echo "  STATEMENT DIGEST MISMATCH."
    echo "    expected: $EXPECTED_STMT_SHA256"
    echo "    observed: $GOT_STMT_SHA"
    echo "    A statement or a definition body changed. First differences:"
    diff -u "$HERE/AUDIT-MANIFEST.txt" "$HERE/.stmt-manifest.observed" 2>/dev/null \
      | head -30 | sed 's/^/      /' || echo "      (AUDIT-MANIFEST.txt absent — cannot diff)"
    rm -f "$HERE/.stmt-manifest.observed"
    STMTFAIL=1
  elif ! printf '%s\n' "$STMT_BLOCK" | cmp -s - "$HERE/AUDIT-MANIFEST.txt"; then
    # The digest's INPUT must be committed and current, or the diff above would
    # compare against a stale reference and quietly mislead the next reader.
    echo "  COMMITTED BLOCK STALE: AUDIT-MANIFEST.txt does not match the emitted block"
    echo "  (the digest matched, so the committed copy needs refreshing)"; STMTFAIL=1
  fi
fi
[ "$STMTFAIL" = 0 ] && echo "  statements bound: $N_STMT lines over $N_INV constants, sha256 = $GOT_STMT_SHA"
[ "$STMTFAIL" = 0 ] || { echo "STATEMENT BINDING FAILED"; rm -f "$INVLOG"; exit 1; }
rm -f "$INVLOG"

# -- Phase 4: definition fidelity (Lean defs vs deployed pacta verifiers) --
echo "=== Phase 4: definition fidelity ==="
PACTA_SRC="${PACTA_SRC:-$HERE/../../proof-aware-crypto-tooling-agent/src}"
FIDELITY_RAN=0
if [ "${SKIP_FIDELITY:-0}" = "1" ]; then
  echo "  skipped (SKIP_FIDELITY=1)"
elif [ -d "$PACTA_SRC/pacta" ]; then
  # PIN THE SUBJECT BEFORE COMPARING AGAINST IT (round-8 review, GPT-5.6,
  # register key `pacta-subject-unpinned`). This phase used to import whatever
  # sat at $PACTA_SRC: no repository, no commit, no clean state, no hashes. It
  # pinned the fidelity OUTPUTS while leaving the SUBJECT anonymous, so any
  # program producing the same finite family of answers passed and the recorded
  # result named no version of the thing it agreed with. Agreement with an
  # unnamed program is not evidence about a deployed one.
  PACTA_SRC="$PACTA_SRC" python3 "$HERE/fidelity/pacta_pin.py" --verify \
    || { echo "FIDELITY FAILED — the pacta subject is not the pinned one."; exit 1; }
  PACTA_SRC="$PACTA_SRC" python3 "$HERE/fidelity/run_fidelity.py" || { echo "FIDELITY FAILED"; exit 1; }
  FIDELITY_RAN=1
else
  echo "  SKIPPED: pacta repo not found at $PACTA_SRC (set PACTA_SRC to run)"
fi

# Fail-closed markers AND A FAIL-CLOSED EXIT CODE (round-7 review: raised
# independently by both reviewers — Claude F1, GPT-5.6 F10; register key
# `acc-exit0-fidelity`).
#
# Until now this emitted the weak marker and RETURNED 0. The marker discipline
# was right and the exit code contradicted it: a caller doing the obvious thing
#
#     ./check.sh && append
#
# read success from a run whose own last line says NOT attestation-ready. And
# because pacta is not part of this estate, the skip branch is the ONLY branch
# any third party ever takes — so for everyone but the author, the button
# always returned 0 without ever checking definition fidelity. A procedure of
# the form "run the button, then append" was unsound for this component.
#
# An exit code is what programs read. If the button cannot establish
# attestation-readiness it must not return success, whatever it prints.
#
#   fidelity ran          -> ATTESTATION GREEN, exit 0
#   SKIP_FIDELITY=1       -> exit 3: the caller opted out EXPLICITLY, so the
#                            code is distinguishable, but it is not 0
#   pacta absent          -> exit 1: nobody opted out; this is a real failure
#                            to establish the property the button exists for
#
# The self-tests are unaffected: every SKIP_FIDELITY=1 case already expects a
# non-zero exit and asserts on a diagnostic from an earlier phase, and the
# control case compiles modules directly rather than invoking this script.
echo "=== LEAN GREEN ==="
if [ "$FIDELITY_RAN" = 1 ]; then
  echo "=== ATTESTATION GREEN (Lean + fidelity) ==="
elif [ "${SKIP_FIDELITY:-0}" = "1" ]; then
  echo "=== FIDELITY SKIPPED ON REQUEST — NOT attestation-ready (exit 3) ==="
  echo "    The Lean corpus is green. Definition fidelity against the deployed"
  echo "    verifier was not checked, so this run does NOT certify that this"
  echo "    repository may be attested."
  exit 3
else
  echo "=== FIDELITY NOT RUN — NOT attestation-ready (exit 1) ==="
  echo "    pacta was not found at: $PACTA_SRC"
  echo "    Set PACTA_SRC to a pacta checkout and re-run, or pass"
  echo "    SKIP_FIDELITY=1 to acknowledge deliberately skipping it (exit 3)."
  exit 1
fi
