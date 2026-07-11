"""Line-faithful Python transliteration of the LEAN definitions in
Proofs/Basic.lean and Proofs/Completeness.lean (commit-current forms,
including the decidable-if ConsRec base and the recursive kbelow).

Each function quotes its Lean source. The fidelity harness
(run_fidelity.py) differential-tests these against the DEPLOYED pacta
verifiers; any transliteration drift is caught by the exhaustive run,
any Lean-vs-deployed drift is the finding the harness exists for.
"""
import hashlib


def sha256(b: bytes) -> bytes:
    return hashlib.sha256(b).digest()


def hleaf(d: bytes) -> bytes:
    # Lean: hleaf d = sha256 (0x00 :: d)
    return sha256(b"\x00" + d)


def hnode(x: bytes, y: bytes) -> bytes:
    # Lean: hnode x y = sha256 (0x01 :: (x.val ++ y.val))
    return sha256(b"\x01" + x + y)


def kbelow(n: int) -> int:
    # Lean: if n ≤ 2 then 1 else 2 * kbelow ((n + 1) / 2)
    if n <= 2:
        return 1
    return 2 * kbelow((n + 1) // 2)


def MTH(D: list) -> bytes:
    # Lean: if length = 0 then sha256 [] ; if length = 1 then hleaf (headD [])
    #       else hnode (MTH (take k)) (MTH (drop k)), k = kbelow length
    if len(D) == 0:
        return sha256(b"")
    if len(D) == 1:
        return hleaf(D[0])
    k = kbelow(len(D))
    return hnode(MTH(D[:k]), MTH(D[k:]))


def Path(m: int, D: list) -> list:
    # Lean: if length ≤ 1 then [] else (m<k: Path m take ++ [MTH drop]
    #       | else: Path (m-k) drop ++ [MTH take])
    if len(D) <= 1:
        return []
    k = kbelow(len(D))
    if m < k:
        return Path(m, D[:k]) + [MTH(D[k:])]
    return Path(m - k, D[k:]) + [MTH(D[:k])]


def Root(v: bytes, m: int, n: int, P: list):
    # Lean: n=1: (if P = [] then some v else none); n=0: none;
    #       P.getLast? none: none; m<k: (Root v m k P').map (hnode · s)
    #       else (Root v (m-k) (n-k) P').map (hnode s ·)
    if n == 1:
        return v if P == [] else None
    if n == 0:
        return None
    if P == []:
        return None
    s = P[-1]
    k = kbelow(n)
    if m < k:
        x = Root(v, m, k, P[:-1])
        return None if x is None else hnode(x, s)
    x = Root(v, m - k, n - k, P[:-1])
    return None if x is None else hnode(s, x)


def ConsRec(n0: int, n: int, C: list, b: bool, r: bytes):
    # Lean (post-refactor, machine-verified equivalent to the original):
    #  n0=n: b: (if C = [] then some (r,r) else none)
    #        ¬b: (if C.length = 1 then some (getLastD, getLastD) else none)
    #  n0>n ∨ n0=0 ∨ n≤1: none ; getLast? none: none
    #  n0≤k: sub.map (fun (x,y) => (x, hnode y s))
    #  else: sub(false).map (fun (x,y) => (hnode s x, hnode s y))
    if n0 == n:
        if b:
            return (r, r) if C == [] else None
        return (C[-1], C[-1]) if len(C) == 1 else None
    if n0 > n or n0 == 0 or n <= 1:
        return None
    if C == []:
        return None
    s = C[-1]
    k = kbelow(n)
    if n0 <= k:
        sub = ConsRec(n0, k, C[:-1], b, r)
        return None if sub is None else (sub[0], hnode(sub[1], s))
    sub = ConsRec(n0 - k, n - k, C[:-1], False, r)
    return None if sub is None else (hnode(s, sub[0]), hnode(s, sub[1]))


def accept_incl(d: bytes, m: int, n: int, P: list, root: bytes) -> bool:
    # Lean acceptance: m < n ∧ Root (hleaf d) m n P = some root
    return m < n and Root(hleaf(d), m, n, P) == root


def accept_cons(n0: int, n1: int, r0: bytes, r1: bytes, C: list) -> bool:
    # Lean acceptCons: n0 = 0 ∨ ConsRec n0 n1 C true r0 = some (r0, r1)
    return n0 == 0 or ConsRec(n0, n1, C, True, r0) == (r0, r1)
