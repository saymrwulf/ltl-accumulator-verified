#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# selftest_statements.sh — adversarial self-test of check.sh Phase 3d.
#
# WHY A SECOND SELF-TEST. selftest_audit.sh attacks the coverage gate, which
# pins every constant's NAME, KIND and AXIOM CONE, both directions. That gate
# is strong and none of its nine attacks defeat it. It is also blind to what a
# declaration SAYS, and this script demonstrates that with a real, compiling
# edit rather than an argument:
#
#   `LTLAcc.pinAccept` is a specification definition. Wrapping one branch of
#   its body in `id (…)` is definitionally equal, so every downstream proof
#   still compiles; the name, the kind, the type and the axiom cone are all
#   unchanged. The inventory gate reports 222 constants, environment ==
#   allowlist, GREEN. Only the statement digest sees it.
#
#   That edit is deliberately harmless. The point is that the ONLY thing
#   standing between it and a genuinely vacuous redefinition is the digest.
#
# Cases:
#   0  positive control: pristine tree passes Phase 3d
#   1  defeq body edit: old gate PASSES (asserted), Phase 3d FAILS (asserted)
#   2  committed AUDIT-MANIFEST.txt hand-edited      → COMMITTED BLOCK STALE
#   3  statement block truncated                     → BLOCK TRUNCATED
#   4  a constant inventoried but carrying no statement → COVERAGE GAP
#
# Phase 3d is lifted out of check.sh at run time, so the tested logic IS the
# shipping logic. Run AFTER a green check.sh. All Lean work via lean-guard.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
AENEAS_ENV="${AENEAS_ENV:-$HOME/aeneas-toolchain/env.sh}"
[ -f "$AENEAS_ENV" ] || { echo "FATAL: Aeneas environment not found: $AENEAS_ENV"; exit 1; }
source "$AENEAS_ENV"
SRC="$(cd "$(dirname "$0")" && pwd)"
AENEAS_LEAN="$AENEAS_HOME/backends/lean"
CORES="${LEAN_MAX_CORES:-0-3}"
FAILURES=0

WORK=$(mktemp -d /tmp/acc-stmt-selftest-XXXX)
trap 'rm -rf "$WORK"' EXIT
echo "=== statement-binding self-test (scratch: $WORK) ==="
cp -a "$SRC" "$WORK/verification"
T="$WORK/verification"
cp "$T/Proofs/PinStore.lean" "$T/PinStore.pristine"
cp "$T/AUDIT-MANIFEST.txt"   "$T/MANIFEST.pristine"

# Phase 3d, lifted verbatim from the shipping button. HERE and INVLOG are the
# two variables it reads from its surroundings.
DRIVER="$T/phase3d.sh"
{
  echo 'set -euo pipefail'  # -e matches the button; see lift-drivers-drop-errexit
  echo "HERE=\"$T\""
  echo 'INVLOG="$1"'
  sed -n '/^# -- Phase 3d/,/^# -- Phase 4/p' "$SRC/check.sh" | sed '$d'
} > "$DRIVER"
if [ "$(wc -l < "$DRIVER")" -lt 40 ]; then
  echo "FATAL: could not lift Phase 3d out of check.sh — the phase markers moved."
  echo "This self-test must attack the shipping gate; refusing to run against nothing."
  exit 1
fi

# Recompile the edited leaf module + the inventory into $T/inv.out.
build_inventory() {
  cd "$AENEAS_LEAN"
  lake env bash -c "
    set -euo pipefail
    cd '$T' && export LEAN_PATH=\"\$LEAN_PATH:$T/gen:$T\"
    LEAN_TIMEOUT=600 LEAN_MAX_CORES=$CORES '$T/lean-guard' Proofs/PinStore.lean >/dev/null 2>&1
    LEAN_TIMEOUT=600 LEAN_MAX_CORES=$CORES '$T/lean-guard' Proofs/Inventory.lean
  " > "$T/inv.out" 2>&1
  local rc=$?
  cd "$T"
  return $rc
}

expect() {  # expect <label> <invlog> <want-rc> <want-substring>
  local label="$1" invlog="$2" want_rc="$3" want_txt="$4" out rc
  # Phase 3d removes its INVLOG on the way out — that is correct behaviour for
  # the button and fatal for a fixture, so it always gets a disposable copy.
  cp "$invlog" "$T/inv.feed"
  out=$(bash "$DRIVER" "$T/inv.feed" 2>&1); rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    echo "  ✗ $label: exit $rc, expected $want_rc"; echo "$out" | sed 's/^/      /'
    FAILURES=$((FAILURES+1)); return
  fi
  if ! grep -qF "$want_txt" <<<"$out"; then
    echo "  ✗ $label: exit code right, diagnostic wrong (rejected for the wrong reason)"
    echo "      wanted: $want_txt"; echo "$out" | sed 's/^/      /'
    FAILURES=$((FAILURES+1)); return
  fi
  echo "  ✓ $label"
}

# ── 0. positive control ────────────────────────────────────────────────────
build_inventory || { echo "  ✗ case 0: pristine tree did not compile"; exit 1; }
cp "$T/inv.out" "$T/inv.pristine"
expect "case 0 control: pristine tree passes Phase 3d" "$T/inv.pristine" 0 "statements bound"

# ── 1. THE ONE THAT MATTERS: a compiling, definitionally-equal body edit ───
python3 - "$T/Proofs/PinStore.lean" <<'PY'
import sys
f = sys.argv[1]; s = open(f).read()
old = "  else ConsRec n n' C true r = some (r, r')"
assert s.count(old) == 1, "pinAccept body not found — this case is vacuous"
open(f, "w").write(s.replace(old, "  else id (ConsRec n n' C true r = some (r, r'))", 1))
PY
if build_inventory; then
  # The premise: the coverage gate must NOT see this. If it ever does, this
  # case stops testing what it claims and must be re-examined, not re-labelled.
  if "$T/inventory_gate.sh" "$T/inv.out" "$T/inventory-allowlist.txt" >/dev/null 2>&1; then
    echo "  ✓ case 1 premise: the coverage gate passes the edit (kind and cone unmoved)"
  else
    echo "  ✗ case 1 premise: the coverage gate caught it — this case no longer isolates Phase 3d"
    FAILURES=$((FAILURES+1))
  fi
  expect "case 1: defeq body edit caught by the statement digest" "$T/inv.out" 1 "STATEMENT DIGEST MISMATCH"
else
  echo "  ✗ case 1: the edited corpus did not compile (case is vacuous)"
  FAILURES=$((FAILURES+1))
fi
cp "$T/PinStore.pristine" "$T/Proofs/PinStore.lean"

# ── 2. committed block hand-edited ─────────────────────────────────────────
sed -i '1s/$/ TAMPERED/' "$T/AUDIT-MANIFEST.txt"
expect "case 2: hand-edited committed block" "$T/inv.pristine" 1 "COMMITTED BLOCK STALE"
cp "$T/MANIFEST.pristine" "$T/AUDIT-MANIFEST.txt"

# ── 3. truncated block: "nothing found" must not pass for "nothing wrong" ──
grep -v '^STMT|LTLAcc.pinAccept|def|value=' "$T/inv.pristine" > "$T/inv.truncated"
expect "case 3: truncated statement block" "$T/inv.truncated" 1 "BLOCK TRUNCATED"

# ── 4. a constant inventoried but carrying no statement ────────────────────
#     Drop one type line AND fix the trailer, so only the coverage comparison
#     against the INV count can still object.
grep -v '^STMT|LTLAcc.pinAccept|def|type=' "$T/inv.pristine" > "$T/inv.gap"
NEW_N=$(awk '/^STMT-BEGIN/{f=1;next}/^STMT-END/{f=0}f' "$T/inv.gap" | grep -c '^STMT|')
sed -i "s/^STMT-COUNT|.*/STMT-COUNT|$NEW_N/" "$T/inv.gap"
expect "case 4: inventoried constant with no statement" "$T/inv.gap" 1 "STATEMENT COVERAGE GAP"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "=== SELF-TEST GREEN: 4 attack cases defeated + positive control ==="
  echo "    Phase 3d catches what the coverage gate provably cannot see."
  exit 0
fi
echo "=== SELF-TEST FAILED: $FAILURES case(s) did not behave as claimed ==="
exit 1
