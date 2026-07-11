#!/usr/bin/env python3
"""S7 definition-fidelity harness for ltl-accumulator-verified.

Differential-tests the LEAN definitions (transliterated in lean_defs.py:
MTH / Path / Root / ConsRec, post-refactor decidable-if base) against the
DEPLOYED pacta verifiers, over the EXACT case generation of the paper's
tests/test_paper_verifiers.py — so the pinned counts (164,479 / 164,224)
carry over and this run establishes, by exhaustive testing, that the
mechanized objects agree with the deployed RFC 9162 code.

Requires the pacta repo on PYTHONPATH (its src/). Bound NMAX matches the
paper.
"""
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PACTA_SRC = os.environ.get("PACTA_SRC",
    os.path.join(HERE, "..", "..", "..", "proof-aware-crypto-tooling-agent", "src"))
sys.path.insert(0, PACTA_SRC)
sys.path.insert(0, HERE)

# deployed (pacta) side
from pacta.transparency import (            # noqa: E402
    consistency_proof, inclusion_proof, merkle_root,
    verify_consistency, verify_inclusion,
)
# lean (mechanized) side
import lean_defs as L                       # noqa: E402

NMAX = int(os.environ.get("FIDELITY_NMAX", "256"))


def _h(b):
    return hashlib.sha256(b).digest()


def inclusion():
    total = 0
    root_checks = 0
    path_checks = 0
    for n in range(1, NMAX + 1):
        data = [bytes([i % 251]) + bytes([(i * 5) % 256]) * (i % 3) for i in range(n)]
        root = merkle_root(data)
        # root fidelity: Lean MTH == deployed merkle_root
        assert L.MTH(data) == root, ("MTH drift", n)
        root_checks += 1
        for m in range(n):
            P = inclusion_proof(data, m)
            # path fidelity: Lean Path == deployed inclusion_proof
            assert L.Path(m, data) == P, ("Path drift", n, m)
            path_checks += 1
            cases = [
                (data[m], m, n, P, root),
                (data[m] + b"!", m, n, P, root),
                (data[m], (m + 1) % n, n, P, root),
                (data[m], m, n, P, _h(b"q")),
            ]
            if P:
                cases.append((data[m], m, n, P[:-1], root))
            for d2, m2, n2, P2, r2 in cases:
                total += 1
                dep = verify_inclusion(d2, m2, n2, P2, r2)
                lean = L.accept_incl(d2, m2, n2, P2, r2)
                assert dep == lean, ("INCL VERIFIER DRIFT", n, m, dep, lean)
    return total, root_checks, path_checks


def consistency():
    total = 0
    for n in range(1, NMAX + 1):
        data = [bytes([i % 251]) + bytes([(i * 7) % 256]) * (i % 4) for i in range(n)]
        r1 = merkle_root(data)
        assert L.MTH(data) == r1, ("MTH drift (cons)", n)
        for m in range(1, n + 1):
            P = consistency_proof(data, m)
            r0 = merkle_root(data[:m])
            cases = [
                (m, n, r0, r1, P),               # honest consistency
                (m, n, _h(b"x"), r1, P),
                (m, n, r0, _h(b"y"), P),
                (m, n, r0, r1, P + [_h(b"z")]),
            ]
            if P:
                cases.append((m, n, r0, r1, P[:-1]))
            for mm, nn, a, bb, pp in cases:
                total += 1
                dep = verify_consistency(mm, nn, a, bb, pp)
                lean = L.accept_cons(mm, nn, a, bb, pp)
                assert dep == lean, ("CONS VERIFIER DRIFT", n, m, dep, lean)
    return total


def main():
    print(f"S7 fidelity: Lean defs vs deployed pacta, NMAX={NMAX}")
    ti, rc, pc = inclusion()
    print(f"  inclusion:   {ti} verifier cases, {rc} MTH==merkle_root, {pc} Path==inclusion_proof  — all agree")
    tc = consistency()
    print(f"  consistency: {tc} verifier cases (incl. honest), MTH checks  — all agree")
    # pinned counts (identical generation to the paper's harness)
    assert ti == 164_479, ti
    assert tc == 164_224, tc
    print(f"  PINNED: inclusion={ti} (164,479)  consistency={tc} (164,224)")
    print("=== FIDELITY GREEN: mechanized defs agree with deployed verifier ===")


if __name__ == "__main__":
    main()
