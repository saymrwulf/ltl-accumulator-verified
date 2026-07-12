#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check.sh — THE button (accumulator corpus). Same discipline as the
# *-ed25519-verified repos: compiles every shipped .lean through lean-guard
# and axiom-audits every certificate against its DOCUMENTED exact cone,
# both directions.
#
# Phases: 0 resource/integrity · 1 stub+axiom-smuggling audit ·
#         2 compile manifest · 3 boundary-exact axiom audit
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

# Certificates and their exact expected cones (observed via #print axioms,
# never guessed; any drift in EITHER direction is a failure).
# AUDIT SURFACE: Phase 3b pins the FULL environment of the corpus modules
# (inventory-allowlist.txt, 218 constants incl. compiler-generated
# auxiliaries); the 59 entries below are the human-reviewed statement
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
# Recursive: no compiled artifact anywhere in the tree may lack its source
# (review round 2, GPT M1 — previously scanned Proofs/*.olean only).
while IFS= read -r -d '' o; do
  [ -f "${o%.olean}.lean" ] || { echo "ORPHAN OLEAN: $o has no sibling .lean (stale artifact)"; exit 1; }
done < <(find "$HERE" -name '*.olean' -print0)

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
    [ \"\$b\" = AxiomCheck ] && continue   # audit infrastructure, compiled in Phase 3
    [ \"\$b\" = Inventory ]  && continue   # audit infrastructure, compiled in Phase 3b
    case \" ${PROOFS[*]} \" in (*\" \$b \"*) ;; (*) echo \"DEAD FILE: \$f\"; exit 1;; esac
  done
  # gen/ gets the same unmanifested-source check (review round 2, GPT M1)
  for f in gen/LTLAcc/*.lean; do
    b=\"LTLAcc/\$(basename \"\$f\" .lean)\"
    case \" ${GEN_MODULES[*]} \" in (*\" \$b \"*) ;; (*) echo \"DEAD FILE (gen): \$f\"; exit 1;; esac
  done
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

# The inventory's corpus-module list must BE the compile manifest — both
# directions, so neither can drift from the other silently.
for m in "${GEN_MODULES[@]}" "${PROOFS[@]}"; do
  mod=$(echo "$m" | sed 's|^LTLAcc/|LTLAcc.|; s|^\([A-Z]\)|Proofs.\1|; s|^Proofs\.LTLAcc\.|LTLAcc.|')
  grep -qF "\`$mod" "$HERE/Proofs/Inventory.lean" || {
    echo "  MANIFEST DRIFT: $mod compiled by check.sh but not inventoried"; COVFAIL=1; }
done
NMANIFEST=$(( ${#GEN_MODULES[@]} + ${#PROOFS[@]} ))
NINV=$(grep -oE '`(LTLAcc|Proofs)\.[A-Za-z0-9_.]+' "$HERE/Proofs/Inventory.lean" | wc -l)
[ "$NMANIFEST" = "$NINV" ] || {
  echo "  MANIFEST DRIFT: check.sh compiles $NMANIFEST modules, Inventory lists $NINV"; COVFAIL=1; }

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
rm -f "$INVLOG"

# every pinned cert must actually be queried by AxiomCheck (no pin-but-never-check)
for cert in "${!CONES[@]}"; do
  grep -qF "#print axioms $cert" "$HERE/Proofs/AxiomCheck.lean" || {
    echo "  PINNED BUT NOT QUERIED: $cert (in CONES, absent from AxiomCheck.lean)"; COVFAIL=1; }
done
[ "$COVFAIL" = 0 ] && echo "  coverage complete: environment == allowlist, CONES cross-checked"
[ "$COVFAIL" = 0 ] || { echo "COVERAGE FAILED"; FAIL=1; }
[ "$FAIL" = 0 ] || exit 1
# -- Phase 4: definition fidelity (Lean defs vs deployed pacta verifiers) --
echo "=== Phase 4: definition fidelity ==="
PACTA_SRC="${PACTA_SRC:-$HERE/../../proof-aware-crypto-tooling-agent/src}"
FIDELITY_RAN=0
if [ "${SKIP_FIDELITY:-0}" = "1" ]; then
  echo "  skipped (SKIP_FIDELITY=1)"
elif [ -d "$PACTA_SRC/pacta" ]; then
  PACTA_SRC="$PACTA_SRC" python3 "$HERE/fidelity/run_fidelity.py" || { echo "FIDELITY FAILED"; exit 1; }
  FIDELITY_RAN=1
else
  echo "  SKIPPED: pacta repo not found at $PACTA_SRC (set PACTA_SRC to run)"
fi

# Fail-closed markers (review H2): the Lean corpus is green either way, but
# only the strong marker — required by the attestation gate — is emitted
# when fidelity actually ran. Never conflate the two.
echo "=== LEAN GREEN ==="
if [ "$FIDELITY_RAN" = 1 ]; then
  echo "=== ATTESTATION GREEN (Lean + fidelity) ==="
else
  echo "=== FIDELITY NOT RUN — NOT attestation-ready (run with pacta present) ==="
fi
