#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_bare.sh — REVIEWER's standalone runner (review round 3, Claude F3).
#
# Compiles, axiom-audits, and inventory-gates the corpus with a plain
# public `lean` binary — no lake, no Aeneas checkout, no operator
# environment. The corpus is Mathlib-free and needs only the toolchain
# pinned in ./lean-toolchain (elan users: `elan default $(cat lean-toolchain)`
# or run inside this directory and let elan pick it up).
#
# This runner exists so a reviewer can go from "trust the transcripts"
# to "run the button" on any machine. It is NOT the operator's button:
# check.sh remains the release gate (memory-guarded lean-guard, cone
# table, fidelity phase, ATTESTATION marker). This script covers the
# kernel-facing phases only: compile, #print-axioms audit, inventory
# gate.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
command -v lean >/dev/null || { echo "FATAL: no 'lean' on PATH (want $(cat "$HERE/lean-toolchain"))"; exit 1; }
echo "toolchain: $(lean --version)"
echo "pinned:    $(cat "$HERE/lean-toolchain")"

export LEAN_PATH="${LEAN_PATH:+$LEAN_PATH:}$HERE/gen:$HERE"

echo "=== compile (gen + 9 proof modules) ==="
( cd "$HERE/gen" && lean -o LTLAcc/HashExternal.olean LTLAcc/HashExternal.lean )
cd "$HERE"
for m in Basic Completeness Extract Descent Consistency Binding3 Refactor Theorem3 PinStore; do
  echo "  · Proofs/$m"
  lean -o "Proofs/$m.olean" "Proofs/$m.lean"
done

echo "=== axiom audit (#print axioms, compare against check.sh CONES yourself) ==="
lean Proofs/AxiomCheck.lean | tee bare-axcheck.out | grep -c "depends on axioms\|does not depend" \
  | xargs -I{} echo "  {} cone lines printed (full output: bare-axcheck.out)"

echo "=== inventory gate (environment == allowlist) ==="
lean Proofs/Inventory.lean > bare-inventory.out
"$HERE/inventory_gate.sh" bare-inventory.out "$HERE/inventory-allowlist.txt"

echo "=== BARE RUN GREEN (compile + axiom print + inventory gate) ==="
