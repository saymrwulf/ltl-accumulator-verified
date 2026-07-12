#!/usr/bin/env python3
"""S7 definition-fidelity harness for ltl-accumulator-verified.

Differential-tests the LEAN definitions (transliterated in lean_defs.py:
MTH / Path / Root / ConsRec, post-refactor decidable-if base) against the
DEPLOYED pacta verifiers, over the EXACT case generation of the paper's
tests/test_paper_verifiers.py — this run establishes agreement between the mechanized objects and the
deployed RFC 9162 code EXHAUSTIVELY OVER all size/index (and old/new
size) pairs through 256 FOR the two fixed generated datasets and the
listed mutation classes (honest, wrong-leaf, wrong-index, wrong-root,
truncated/padded proof, and out-of-range m≥n / n0>n1 / n0=0). It is not
a proof of extensional equality over all inputs — and extensional
equality is in fact FALSE for consistency: the lied-size family below
pins the known one-sided divergence (deployed accepts claimed sizes an
honest proof was never generated for; the mechanized ConsRec rejects —
KNOWN-GAPS gap 14). The Lean-to-Python bridge remains trusted
quoted-source inspection (see KNOWN-GAPS).

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
# lied-size family pins (gap 14; valid for the default FIDELITY_LIED_NMAX=60):
# 73,573 boundary cases, 3,867 expected one-sided divergences
# (3,405 lied-old-size + 462 lied-new-size), smallest witness (n=3, m=2 claimed 1)
LIED_PIN_TOTAL = 73_573
LIED_PIN_DIV = 3_867


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
                (data[m], n, n, P, root),        # out-of-range m = n (review F1)
                (data[m], n + 3, n, P, root),    # out-of-range m > n (review F1)
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
                (n + 1, n, r1, r0, P),           # n0 > n1 (review F1)
                (0, n, r0, r1, P),               # n0 = 0 escape (review F1)
            ]
            if P:
                cases.append((m, n, r0, r1, P[:-1]))
            for mm, nn, a, bb, pp in cases:
                total += 1
                dep = verify_consistency(mm, nn, a, bb, pp)
                lean = L.accept_cons(mm, nn, a, bb, pp)
                assert dep == lean, ("CONS VERIFIER DRIFT", n, m, dep, lean)
    return total


def lied_sizes():
    """Lied-size boundary family (round-3 review, Claude F1* / gap 14).

    The deployed RFC 9162 iterative verify_consistency accepts honest
    proofs under CLAIMED sizes the proof was never generated for (when
    the claimed old size is a power of two it seeds the walk with the
    old root and uses the sizes only as bit-navigation state); the
    mechanized ConsRec binds the split geometry to the sizes and
    rejects. Divergences in this family are therefore EXPECTED and
    documented — what this pins is:
      (a) the DIRECTION: every divergence must be deployed=True /
          lean=False (the mechanized model is the stricter one; a
          lean=True/deployed=False case would break soundness transfer
          and fails the run immediately), and
      (b) the exact divergence COUNT, so any drift in either verifier
          shows up as a pin failure.
    Inclusion showed zero divergences under identical abuse (round-3
    addendum); the inclusion side is covered by the m>=n families above.
    """
    lied_nmax = int(os.environ.get("FIDELITY_LIED_NMAX", "60"))
    total = 0
    div = 0
    for n in range(2, lied_nmax):
        data = [bytes([i % 251]) for i in range(n)]
        r1 = merkle_root(data)
        for m_true in range(1, n):
            P = consistency_proof(data, m_true)
            r0 = merkle_root(data[:m_true])
            for m_lie in range(0, n + 1):          # lied OLD size
                if m_lie == m_true:
                    continue
                total += 1
                dep = verify_consistency(m_lie, n, r0, r1, P)
                lean = L.accept_cons(m_lie, n, r0, r1, P)
                if dep != lean:
                    div += 1
                    assert dep and not lean, (
                        "ONE-SIDEDNESS BROKEN: lean accepts, deployed rejects",
                        n, m_true, m_lie)
            for n_lie in (n - 1, n + 1, n + 7):     # lied NEW size
                if n_lie < m_true or n_lie == n or n_lie < 1:
                    continue
                total += 1
                dep = verify_consistency(m_true, n_lie, r0, r1, P)
                lean = L.accept_cons(m_true, n_lie, r0, r1, P)
                if dep != lean:
                    div += 1
                    assert dep and not lean, (
                        "ONE-SIDEDNESS BROKEN: lean accepts, deployed rejects",
                        n, m_true, "n_lie", n_lie)
    return total, div


def main():
    print(f"S7 fidelity: Lean defs vs deployed pacta, NMAX={NMAX}")
    ti, rc, pc = inclusion()
    print(f"  inclusion:   {ti} verifier cases, {rc} MTH==merkle_root, {pc} Path==inclusion_proof  — all agree")
    tc = consistency()
    print(f"  consistency: {tc} verifier cases (incl. honest), MTH checks  — all agree")
    tl, dl = lied_sizes()
    print(f"  lied-sizes:  {tl} boundary cases, {dl} EXPECTED divergences, all deployed-accepts-only (gap 14)")
    # pinned counts (identical generation to the paper's harness)
    assert ti == 230_271, ti   # re-pinned after adding out-of-range families (F1)
    assert tc == 230_016, tc
    assert (tl, dl) == (LIED_PIN_TOTAL, LIED_PIN_DIV), (tl, dl)
    print(f"  PINNED: inclusion={ti} (230,271)  consistency={tc} (230,016)  lied-sizes={tl}/{dl}")
    print("=== FIDELITY GREEN: agreement over the pinned case families "
          "(not extensional equality; KNOWN-GAPS gap 14) ===")


if __name__ == "__main__":
    main()
