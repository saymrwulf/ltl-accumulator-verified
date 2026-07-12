#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# selftest_audit.sh — adversarial self-test of the audit gate.
#
# Review round 2 (GPT H1 / Claude NEW-1) demonstrated that the old
# source-regex coverage gate was evadable. This script proves the
# replacement is not, by ATTACKING THE SHIPPING LOGIC: every case copies
# the corpus to a scratch tree, injects a declaration the old gate could
# not see, recompiles through lean-guard, and asserts that the exact
# inventory_gate.sh used by check.sh Phase 3b FAILS with the expected
# diagnosis. The two unmanifested-module cases run the full check.sh.
#
# Cases (release condition 2 of the round-2 GPT review, plus two):
#   0  positive control: pristine tree must PASS (guards against a gate
#      that fails everything — a vacuous self-test)
#   1  attributed theorem            @[simp] theorem …
#   2  indented theorem              (leading whitespace)
#   3  private theorem               private theorem …
#   4  instance declaration          instance … : Nonempty Nat
#   5  nested namespace collision    LTLAcc.Hidden.MTH vs audited LTLAcc.MTH
#   6  smuggled axiom                axiom rogue : True
#   7  deleted declaration           STALE direction of the diff
#   8  unmanifested Proofs/ module   full check.sh must die: DEAD FILE
#   9  unmanifested gen/ module      full check.sh must die: DEAD FILE (gen)
#
# Run AFTER a green check.sh (needs compiled .oleans in the tree).
# All Lean work goes through lean-guard (memory-capped, single-flight).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
AENEAS_ENV="${AENEAS_ENV:-$HOME/aeneas-toolchain/env.sh}"
[ -f "$AENEAS_ENV" ] || { echo "FATAL: Aeneas environment not found: $AENEAS_ENV"; exit 1; }
source "$AENEAS_ENV"
SRC="$(cd "$(dirname "$0")" && pwd)"
AENEAS_LEAN="$AENEAS_HOME/backends/lean"
CORES="${LEAN_MAX_CORES:-0-3}"

WORK=$(mktemp -d /tmp/acc-selftest-XXXX)
trap 'echo "(scratch tree kept for inspection: $WORK)"' ERR
echo "=== audit-gate self-test (scratch: $WORK) ==="
cp -a "$SRC" "$WORK/verification"
T="$WORK/verification"
cp "$T/Proofs/PinStore.lean" "$T/PinStore.pristine"

# Recompile the injected leaf module + the inventory, then run the gate.
# Returns the gate's exit code; gate output goes to $T/gate.out.
run_gate() {
  cd "$AENEAS_LEAN"
  lake env bash -c "
    set -euo pipefail
    cd '$T' && export LEAN_PATH=\"\$LEAN_PATH:$T/gen:$T\"
    LEAN_TIMEOUT=600 LEAN_MAX_CORES=$CORES '$T/lean-guard' Proofs/PinStore.lean >/dev/null 2>&1
    LEAN_TIMEOUT=600 LEAN_MAX_CORES=$CORES '$T/lean-guard' Proofs/Inventory.lean
  " > "$T/inv.out" 2>&1 || { echo "  (inventory compile failed — see $T/inv.out)"; return 99; }
  "$T/inventory_gate.sh" "$T/inv.out" "$T/inventory-allowlist.txt" > "$T/gate.out" 2>&1
}

expect_fail() {  # $1=case label  $2=grep pattern expected in gate output
  local rc=0; run_gate || rc=$?
  if [ "$rc" = 0 ]; then
    echo "  ✗ $1: gate PASSED but must fail"; echo "SELF-TEST FAILED"; exit 1
  elif [ "$rc" = 99 ]; then
    echo "  ✗ $1: injected code did not compile (case is vacuous)"; exit 1
  elif ! grep -q "$2" "$T/gate.out"; then
    echo "  ✗ $1: gate failed but without expected diagnosis '$2':"
    sed 's/^/      /' "$T/gate.out"; exit 1
  fi
  echo "  ✓ $1: gate fails with $(grep -c "$2" "$T/gate.out") '$2' line(s)"
}

restore() { cp "$T/PinStore.pristine" "$T/Proofs/PinStore.lean"; }

# 0 — positive control
if run_gate; then echo "  ✓ case 0 control: pristine tree passes the gate"; else
  echo "  ✗ case 0 control: pristine tree FAILED the gate:"; sed 's/^/      /' "$T/gate.out"; exit 1; fi

# 1 — attributed
restore; printf '\n@[simp] theorem smuggled_attr : 1 = 1 := rfl\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 1 attributed theorem" "UNCLASSIFIED.*smuggled_attr"

# 2 — indented
restore; printf '\n  theorem smuggled_indent : 3 = 3 := rfl\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 2 indented theorem" "UNCLASSIFIED.*smuggled_indent"

# 3 — private
restore; printf '\nprivate theorem smuggled_private : 2 = 2 := rfl\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 3 private theorem" "UNCLASSIFIED.*_private.*smuggled_private"

# 4 — instance
restore; printf '\ninstance smuggledInst : Nonempty Nat := ⟨0⟩\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 4 instance" "UNCLASSIFIED.*smuggledInst"

# 5 — nested namespace reusing an audited basename
restore; printf '\nnamespace LTLAcc.Hidden\ntheorem MTH : 1 = 1 := rfl\nend LTLAcc.Hidden\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 5 namespace collision (LTLAcc.Hidden.MTH)" "UNCLASSIFIED.*LTLAcc\.Hidden\.MTH"

# 6 — smuggled axiom
restore; printf '\naxiom rogue : True\n' >> "$T/Proofs/PinStore.lean"
expect_fail "case 6 smuggled axiom" "AXIOM SURFACE DRIFT"

# 7 — deleted declaration (STALE direction)
restore
python3 - "$T/Proofs/PinStore.lean" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
# drop the trailing nonvacuity guard (a leaf theorem nothing imports),
# including its doc comment — an orphaned /-- ... -/ would not compile
i = s.rindex("/-- Permanent non-vacuity witness for pin_prefix_correct")
j = s.index("end LTLAcc", i)
open(p, "w").write(s[:i] + s[j:])
EOF
expect_fail "case 7 deleted declaration" "STALE.*pin_prefix_nonvacuous"

restore
rm -f "$T/PinStore.pristine"

# 8 — unmanifested Proofs/ module (full check.sh; dies in Phase 2)
printf '/- rogue -/\ntheorem rogue_thm : 1 = 1 := rfl\n' > "$T/Proofs/Rogue.lean"
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check8.out" 2>&1; then
  echo "  ✗ case 8: check.sh PASSED with unmanifested Proofs/Rogue.lean"; exit 1
fi
grep -q "DEAD FILE: Proofs/Rogue.lean" "$T/check8.out" || {
  echo "  ✗ case 8: check.sh failed without DEAD FILE diagnosis"; tail -5 "$T/check8.out"; exit 1; }
echo "  ✓ case 8 unmanifested Proofs module: check.sh dies with DEAD FILE"
rm -f "$T/Proofs/Rogue.lean"

# 9 — unmanifested gen/ module (full check.sh; dies in Phase 2)
printf '/- rogue -/\ntheorem rogue_gen : 1 = 1 := rfl\n' > "$T/gen/LTLAcc/Rogue.lean"
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check9.out" 2>&1; then
  echo "  ✗ case 9: check.sh PASSED with unmanifested gen/LTLAcc/Rogue.lean"; exit 1
fi
grep -q "DEAD FILE (gen): gen/LTLAcc/Rogue.lean" "$T/check9.out" || {
  echo "  ✗ case 9: check.sh failed without DEAD FILE (gen) diagnosis"; tail -5 "$T/check9.out"; exit 1; }
echo "  ✓ case 9 unmanifested gen module: check.sh dies with DEAD FILE (gen)"

rm -rf "$WORK"
trap - ERR
echo "=== SELF-TEST GREEN: 9 attack cases defeated + positive control ==="
