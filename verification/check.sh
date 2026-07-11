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
PROOFS=( Basic Completeness Extract Descent Consistency Binding3 Refactor )

# Certificates and their exact expected cones (observed at first green
# compile, 2026-07-10; any drift in EITHER direction is a failure).
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
  [LTLAcc.take_all]="propext, Quot.sound"
  [LTLAcc.consRecBinding]="propext, Classical.choice, LTLAcc.sha256, Quot.sound"
  [LTLAcc.consRec_base_false_eq]="propext, Quot.sound"
  [LTLAcc.consRec_base_true_eq]="propext, Quot.sound"
)

free -m | awk '/Mem:/{if($7<2048){print "FATAL: <2GB RAM available — refusing to compile"; exit 1}}'
echo "=== Phase 0: source integrity ==="
for f in "$HERE"/gen/LTLAcc/*.lean "$HERE"/Proofs/*.lean; do
  [ -f "$f" ] || continue
  if ! grep -qE '^(/-|import |namespace |theorem |def |noncomputable |open |set_option |--|abbrev )' "$f"; then
    echo "CORRUPTED: $f is not Lean source. Restore: git checkout HEAD -- $f"; exit 1
  fi
done
echo "  all sources valid"

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
[ "$FAIL" = 0 ] || exit 1
echo "=== ALL GREEN ==="
