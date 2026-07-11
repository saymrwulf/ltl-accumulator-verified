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
source ~/aeneas-toolchain/env.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
AENEAS_LEAN="$AENEAS_HOME/backends/lean"
TIMEOUT="${LEAN_TIMEOUT:-600}"
export LEAN_MEM_MB="${LEAN_MEM_MB:-4096}"
CORES="${LEAN_MAX_CORES:-0-3}"

GEN_MODULES=( LTLAcc/HashExternal )
PROOFS=( Basic Completeness Extract Descent Consistency Binding3 Refactor Theorem3 PinStore )

# Certificates and their exact expected cones (observed via #print axioms,
# never guessed; any drift in EITHER direction is a failure).
# AUDIT SURFACE: every theorem/def under Proofs/ (52) + the two load-bearing
# gen/ instances (Inhabited/DecidableEq Hash). Excluded by nature: the
# sanctioned axiom itself (sha256 IS the boundary) and `abbrev Bytes`
# (a bare type alias, no cone content).
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
)

# Sanctioned exclusions from the cone audit (documented, not silent):
#   sha256 = THE boundary axiom (it IS the assumption)
#   Bytes  = bare type alias (abbrev), no cone content
declare -A EXCLUDE=( [sha256]=1 [Bytes]=1 )

free -m | awk '/Mem:/{if($7<2048){print "FATAL: <2GB RAM available — refusing to compile"; exit 1}}'
echo "=== Phase 0: source integrity ==="
for f in "$HERE"/gen/LTLAcc/*.lean "$HERE"/Proofs/*.lean; do
  [ -f "$f" ] || continue
  if ! grep -qE '^(/-|import |namespace |theorem |def |noncomputable |open |set_option |--|abbrev )' "$f"; then
    echo "CORRUPTED: $f is not Lean source. Restore: git checkout HEAD -- $f"; exit 1
  fi
done
echo "  all sources valid"
for o in "$HERE"/Proofs/*.olean; do
  [ -f "$o" ] || continue
  [ -f "${o%.olean}.lean" ] || { echo "ORPHAN OLEAN: $o has no sibling .lean (stale artifact)"; exit 1; }
done

echo "=== Phase 1: stub + axiom-smuggling audit ==="
if grep -rn 'by trivial' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "STUB DETECTED"; exit 1; fi
if grep -rn ' : True :=' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "STUB DETECTED: True-target theorem"; exit 1; fi
if grep -rnE '^(private |protected |noncomputable )*axiom ' "$HERE"/Proofs/*.lean 2>/dev/null; then
  echo "AXIOM SMUGGLING DETECTED: axiom under Proofs/ — gen/ is the only sanctioned site."; exit 1
fi
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
    [ \"\$b\" = AxiomCheck ] && continue
    case \" ${PROOFS[*]} \" in (*\" \$b \"*) ;; (*) echo \"DEAD FILE: \$f\"; exit 1;; esac
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

# -- Phase 3b: audit-surface COVERAGE (fail-closed; review H1) --------------
echo "=== Phase 3b: audit-surface coverage ==="
COVFAIL=0
DECLS=$(grep -hoE "^(theorem|noncomputable def|def|abbrev) [A-Za-z0-9_?]+" \
          "$HERE"/Proofs/*.lean "$HERE"/gen/LTLAcc/*.lean | awk '{print $NF}' | sort -u)
for d in $DECLS; do
  if [ -n "${CONES[LTLAcc.$d]+x}" ] || [ -n "${EXCLUDE[$d]+x}" ]; then :; else
    echo "  UNCLASSIFIED DECLARATION: $d (not in CONES, not a sanctioned exclusion)"; COVFAIL=1
  fi
done
# anonymous instances live only in gen/ (a controlled file); pin their count
GENINST=$(grep -cE "^instance" "$HERE"/gen/LTLAcc/*.lean)
CONEINST=$(printf '%s\n' "${!CONES[@]}" | grep -cE "LTLAcc\.inst")
if [ "$GENINST" != "$CONEINST" ]; then
  echo "  INSTANCE COUNT DRIFT: gen has $GENINST instances, CONES pins $CONEINST"; COVFAIL=1
fi
# every pinned cert must actually be queried by AxiomCheck (no pin-but-never-check)
for cert in "${!CONES[@]}"; do
  grep -qF "#print axioms $cert" "$HERE/Proofs/AxiomCheck.lean" || {
    echo "  PINNED BUT NOT QUERIED: $cert (in CONES, absent from AxiomCheck.lean)"; COVFAIL=1; }
done
[ "$COVFAIL" = 0 ] && echo "  coverage complete: every declaration classified (audited or sanctioned-excluded)"
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
