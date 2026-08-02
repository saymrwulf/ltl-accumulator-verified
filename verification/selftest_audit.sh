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
# The button also reads two documents from the REPOSITORY root, one level above
# verification/. Copying only verification/ left them missing, so check.sh in
# the scratch tree always died in Phase 3c with DOC DRIFT — which meant every
# `if check.sh; then <this attack was not caught>` guard below was unfirable:
# check.sh could not pass in here even with no attack at all, so those guards
# asserted nothing. Only the diagnostic greps were doing any work. Copy the
# documents so a genuinely-undetected attack would now show up as a PASS.
for d in README.md STATEMENT-MAP.md; do
  [ -f "$SRC/../$d" ] && cp "$SRC/../$d" "$WORK/$d"
done
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

# 9 — unmanifested gen/ module. TWO gates stand here now and the case
#     exercises BOTH, because asserting only the outer one would quietly
#     retire the inner one from the test suite.
#
#     9a: Phase 0c (added 2026-07-29) derives the required pin set from
#     gen/**.lean, so an unpinned model file is caught before compilation.
#     9b: with the rogue file pinned — i.e. an author who added it
#     deliberately — the dead-file gate in Phase 2 must still catch that it is
#     absent from the compile manifest.
printf '/- rogue -/\ntheorem rogue_gen : 1 = 1 := rfl\n' > "$T/gen/LTLAcc/Rogue.lean"
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check9a.out" 2>&1; then
  echo "  ✗ case 9a: check.sh PASSED with an unpinned gen/LTLAcc/Rogue.lean"; exit 1
fi
grep -q "does not match HARNESS.sha256" "$T/check9a.out" || {
  echo "  ✗ case 9a: check.sh failed without the harness-set diagnosis"; tail -5 "$T/check9a.out"; exit 1; }
echo "  ✓ case 9a unpinned gen module: Phase 0c dies with a harness-set mismatch"

( cd "$T" && sha256sum gen/LTLAcc/Rogue.lean >> HARNESS.sha256 )
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check9b.out" 2>&1; then
  echo "  ✗ case 9b: check.sh PASSED with unmanifested gen/LTLAcc/Rogue.lean"; exit 1
fi
grep -q "DEAD FILE (gen): gen/LTLAcc/Rogue.lean" "$T/check9b.out" || {
  echo "  ✗ case 9b: check.sh failed without DEAD FILE (gen) diagnosis"; tail -5 "$T/check9b.out"; exit 1; }
echo "  ✓ case 9b pinned but unmanifested: check.sh dies with DEAD FILE (gen)"

# Case 9 was the last case when it was written, so it left its rogue file and
# its pin in place — harmless then, but the cases below inherit the tree. Undo
# it here rather than in case 9, so that case keeps testing exactly what it
# tested before.
rm -f "$T/gen/LTLAcc/Rogue.lean"
( cd "$T" && grep -v ' gen/LTLAcc/Rogue.lean$' HARNESS.sha256 > .h && mv .h HARNESS.sha256 )

# ── CLASS 15: a Lean file where no phase was looking ────────────────────────
# Until 2026-07-31 the dead-file scan read Proofs/*.lean and gen/LTLAcc/*.lean
# and nothing else. A module at the verification root, or under any other gen/
# subdirectory, was neither compiled nor rejected — while being importable by
# name, since LEAN_PATH contains both roots. A source of the corpus that no
# phase reads and no pin covers is precisely what the dead-file gate exists to
# forbid; it was simply looking in two places instead of everywhere.

# 10 — a stray module at the verification root. NOTE: Phase 0c does not stand
#      in front of this one. Its required-pin set is executables plus
#      gen/**.lean, so a root .lean is invisible to it; the Phase 2 check added
#      for this class is the only gate here.
printf '/- rogue -/\ntheorem rogue_root : 1 = 1 := rfl\n' > "$T/Rogue.lean"
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check10.out" 2>&1; then
  echo "  ✗ case 10: check.sh PASSED with a stray Rogue.lean at the verification root"; exit 1
fi
grep -q "DEAD FILE (verification root): Rogue.lean" "$T/check10.out" || {
  echo "  ✗ case 10: check.sh failed without the root diagnosis"; tail -5 "$T/check10.out"; exit 1; }
echo "  ✓ case 10 stray module at the verification root: DEAD FILE (verification root)"
rm -f "$T/Rogue.lean"

# 11 — a module in a gen/ subdirectory that is not LTLAcc/. Two gates again,
#      and both are exercised for the same reason as case 9.
mkdir -p "$T/gen/Rogue"
printf '/- rogue -/\ntheorem rogue_sub : 1 = 1 := rfl\n' > "$T/gen/Rogue/Extra.lean"
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check11a.out" 2>&1; then
  echo "  ✗ case 11a: check.sh PASSED with an unpinned gen/Rogue/Extra.lean"; exit 1
fi
grep -q "does not match HARNESS.sha256" "$T/check11a.out" || {
  echo "  ✗ case 11a: check.sh failed without the harness-set diagnosis"; tail -5 "$T/check11a.out"; exit 1; }
echo "  ✓ case 11a unpinned module in a foreign gen subdirectory: harness-set mismatch"

( cd "$T" && sha256sum gen/Rogue/Extra.lean >> HARNESS.sha256 )
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check11b.out" 2>&1; then
  echo "  ✗ case 11b: check.sh PASSED with a pinned gen/Rogue/Extra.lean"; exit 1
fi
grep -q "DEAD FILE (gen subdirectory): gen/Rogue/Extra.lean" "$T/check11b.out" || {
  echo "  ✗ case 11b: check.sh failed without the subdirectory diagnosis"; tail -5 "$T/check11b.out"; exit 1; }
echo "  ✓ case 11b pinned but in a foreign gen subdirectory: DEAD FILE (gen subdirectory)"
rm -rf "$T/gen/Rogue"
( cd "$T" && grep -v ' gen/Rogue/Extra.lean$' HARNESS.sha256 > .h && mv .h HARNESS.sha256 )

# ── CLASS 9: the instruments' own declaration surface ───────────────────────
# The audit drivers are not corpus, so nothing inventoried what THEY declare.
# Both are byte-pinned, so each attack must re-pin to reach the new gate —
# which is the point: byte-pinning stops drift, it does not stop an author.
# What follows is what byte-pinning cannot give.

# 12 — an axiom in the inventory driver itself, INDENTED. Phase 1 greps
#      Proofs/*.lean for `^axiom `, so an unindented one is caught there and
#      never reaches the new gate. Indentation is the documented evasion of
#      that regex — measured on Lean v4.30.0-rc2 — so this case is the one
#      that actually exercises the kernel-side driver walk rather than the
#      source scan standing in front of it.
sed -i 's|^#eval show MetaM Unit|  axiom driver_cheat : False\n\n#eval show MetaM Unit|' \
  "$T/Proofs/Inventory.lean"
grep -q '^  axiom driver_cheat' "$T/Proofs/Inventory.lean" || {
  echo "  ✗ case 12: could not inject the indented axiom (case would be vacuous)"; exit 1; }
( cd "$T" && grep -v ' Proofs/Inventory.lean$' HARNESS.sha256 > .h \
  && sha256sum Proofs/Inventory.lean >> .h && mv .h HARNESS.sha256 )
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check12.out" 2>&1; then
  echo "  ✗ case 12: check.sh PASSED with an axiom declared in Proofs/Inventory.lean"; exit 1
fi
grep -q "DRIVER SURFACE VIOLATION" "$T/check12.out" || {
  echo "  ✗ case 12: check.sh failed without the driver-surface diagnosis"; tail -5 "$T/check12.out"; exit 1; }
echo "  ✓ case 12 indented axiom in the inventory driver: DRIVER SURFACE VIOLATION"
cp "$SRC/Proofs/Inventory.lean" "$T/Proofs/Inventory.lean"
( cd "$T" && grep -v ' Proofs/Inventory.lean$' HARNESS.sha256 > .h \
  && sha256sum Proofs/Inventory.lean >> .h && mv .h HARNESS.sha256 )

# 13 — a standalone claim in the OTHER driver. A theorem there is not a
#      compiler artefact of any definition, which is exactly the distinction
#      the gate draws: it must admit `axiomCone._proof_1` and reject this.
printf '\ntheorem driver_claim : 1 = 1 := rfl\n' >> "$T/Proofs/AxiomCheck.lean"
( cd "$T" && grep -v ' Proofs/AxiomCheck.lean$' HARNESS.sha256 > .h   && sha256sum Proofs/AxiomCheck.lean >> .h && mv .h HARNESS.sha256 )
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check13.out" 2>&1; then
  echo "  ✗ case 13: check.sh PASSED with a standalone theorem in Proofs/AxiomCheck.lean"; exit 1
fi
grep -q "DRIVER SURFACE VIOLATION" "$T/check13.out" || {
  echo "  ✗ case 13: check.sh failed without the driver-surface diagnosis"; tail -5 "$T/check13.out"; exit 1; }
echo "  ✓ case 13 standalone claim in the axiom-check driver: DRIVER SURFACE VIOLATION"
cp "$SRC/Proofs/AxiomCheck.lean" "$T/Proofs/AxiomCheck.lean"

# Case 13 restores Proofs/AxiomCheck.lean but not its PIN, which it rewrote to
# match the tampered file. Harmless while 13 was last; case 14 runs check.sh and
# would die in Phase 0c on that stale pin. Re-pin here rather than in case 13,
# so that case keeps testing exactly what it tested before. (Second instance of
# this residue pattern in this file — see the note above case 10.)
( cd "$T" && grep -v ' Proofs/AxiomCheck.lean$' HARNESS.sha256 > .h \
  && sha256sum Proofs/AxiomCheck.lean >> .h && sort -k2 -o .h .h && mv .h HARNESS.sha256 )

# 14 — A DECLARATION THAT POST-DATES THE WALK THAT REPORTS IT.
#      Round-7 review (Claude, finding F2), reproduced verbatim. The driver
#      surface is reported by an `#eval` inside Proofs/Inventory.lean.
#      Anything declared AFTER that command exists in the compiled object file
#      but not in the environment while the command runs, so the walk cannot
#      see it. Before Phase 3b-kernel existed this went GREEN: the button
#      printed "no axiom, no claim", the statement digest was byte-identical
#      to the clean tree, and a theorem with a real axiom cone sat in the
#      environment — in neither walk, in no allowlist, pinned by nothing.
#
#      The kernel reads OBJECT FILES, so it sees what an environment walk
#      placed mid-file cannot. That is the whole point of the containment
#      check, and this case is the reason it exists.
#      NOTE ON THE PAYLOAD. `theorem bait.smuggled : True := trivial` does NOT
#      work here, and the reason is worth keeping: Phase 1's stub audit greps
#      for `: True :=` and catches it first. That is real defence in depth, but
#      it means the naive payload never reaches the gate under test. The one
#      below is the reviewer's original — a genuine claim with a real cone,
#      invisible to every source-text check — so this case exercises the
#      accounting identity and nothing else.
cat >> "$T/Proofs/Inventory.lean" <<'BAIT'

def bait : Nat := 0
theorem bait.smuggled : ∀ n : Nat, n + 0 = n := by
  have _h := Classical.em True
  intro n; simp
BAIT
( cd "$T" && grep -v ' Proofs/Inventory.lean$' HARNESS.sha256 > .h \
  && sha256sum Proofs/Inventory.lean >> .h && sort -k2 -o .h .h && mv .h HARNESS.sha256 )
if SKIP_FIDELITY=1 "$T/check.sh" > "$T/check14.out" 2>&1; then
  echo "  ✗ case 14: check.sh PASSED with a declaration appended after the driver walk"; exit 1
fi
grep -q "ACCOUNTING FAILED" "$T/check14.out" \
  && grep -q "bait" "$T/check14.out" || {
  echo "  ✗ case 14: failed, but not with the accounting diagnosis naming the declaration"
  tail -8 "$T/check14.out"; exit 1; }
echo "  ✓ case 14 declaration after the driver walk: ACCOUNTING FAILED names it"
cp "$SRC/Proofs/Inventory.lean" "$T/Proofs/Inventory.lean"
( cd "$T" && grep -v ' Proofs/Inventory.lean$' HARNESS.sha256 > .h \
  && sha256sum Proofs/Inventory.lean >> .h && sort -k2 -o .h .h && mv .h HARNESS.sha256 )

rm -rf "$WORK"
trap - ERR
echo "=== SELF-TEST GREEN: 15 attack cases defeated + positive control ==="
