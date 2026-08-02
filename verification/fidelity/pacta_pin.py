#!/usr/bin/env python3
"""Pin the pacta sources the fidelity harness actually consumes.

    pacta_pin.py --write    # regenerate PACTA-PIN.sha256 (deliberate act)
    pacta_pin.py --verify   # check the subject; exit 1 on any drift

─────────────────────────────────────────────────────────────────────────────
WHY THIS EXISTS — round-8 review (GPT-5.6, register key `pacta-subject-unpinned`)

Phase 4 compares this repository's Lean definitions against the DEPLOYED
verifier. It did so by putting `$PACTA_SRC` on `sys.path` and importing
`pacta.transparency` — whatever happened to be there. No repository URL, no
commit, no clean-state check, no source hashes.

So the fidelity counts pinned OUTPUTS while the SUBJECT was unpinned. Any
implementation producing the same finite family of answers passed, and the
recorded result named no version of the thing it agreed with. The reviewer's
zero-divergence run was specifically against pacta `cd3b1bc…` — because the
reviewer selected and recorded that checkout, not because the button required
it.

A proof about a model is not evidence about an unnamed program.

WHAT IS PINNED, AND WHY IT IS NOT A GLOB. The pin covers the transitive set of
pacta modules the harness ACTUALLY LOADS, discovered by importing the harness's
entry point and reading `sys.modules` — a membership property, not a directory
listing. Globbing `pacta/*.py` would pin files the comparison never touches
(noise that breaks the pin for unrelated edits) and would miss anything loaded
from outside that directory. The estate has been bitten by name-shaped
measurement before; this is the same error class.

WHAT THIS DOES NOT ESTABLISH. Byte identity of a source tree is not proof that
the deployed service runs it, and finite-family agreement is not extensional
equality. This pin names the subject; it does not widen the claim.
─────────────────────────────────────────────────────────────────────────────
"""
import hashlib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VERIF = os.path.dirname(HERE)
PIN = os.path.join(VERIF, 'PACTA-PIN.sha256')
PACTA_SRC = os.environ.get(
    'PACTA_SRC', os.path.join(VERIF, '..', '..',
                              'proof-aware-crypto-tooling-agent', 'src'))
PACTA_SRC = os.path.abspath(PACTA_SRC)


def loaded_sources():
    """{path relative to PACTA_SRC: sha256} for every pacta module imported.

    Imports the same entry point the fidelity harness does, then keeps the
    modules whose file lives under PACTA_SRC. That is the consumed set by
    construction: if the harness stops using a module, it leaves the pin; if it
    starts using one, the pin fails until someone regenerates it deliberately.
    """
    sys.path.insert(0, PACTA_SRC)
    try:
        import pacta.transparency  # noqa: F401
    except Exception as e:                                   # pragma: no cover
        print(f'PACTA PIN: cannot import pacta.transparency from {PACTA_SRC}:'
              f' {e}', file=sys.stderr)
        raise SystemExit(1)

    out = {}
    for mod in list(sys.modules.values()):
        f = getattr(mod, '__file__', None)
        if not f:
            continue
        f = os.path.abspath(f)
        if not f.startswith(PACTA_SRC + os.sep) or not f.endswith('.py'):
            continue
        with open(f, 'rb') as fh:
            out[os.path.relpath(f, PACTA_SRC)] = hashlib.sha256(
                fh.read()).hexdigest()
    return out


def head_commit():
    """The pacta commit, for the record. NOT the enforcement — hashes are."""
    try:
        r = subprocess.run(['git', '-C', PACTA_SRC, 'rev-parse', 'HEAD'],
                           capture_output=True, text=True, timeout=10)
        c = r.stdout.strip() if r.returncode == 0 else 'unknown'
        d = subprocess.run(['git', '-C', PACTA_SRC, 'status', '--porcelain'],
                           capture_output=True, text=True, timeout=10)
        dirty = bool(d.stdout.strip()) if d.returncode == 0 else True
        return c, dirty
    except Exception:                                        # pragma: no cover
        return 'unknown', True


def write():
    got = loaded_sources()
    commit, dirty = head_commit()
    if dirty:
        print('PACTA PIN: refusing to pin a DIRTY pacta working tree.'
              ' Commit or stash first — a pin taken over uncommitted edits'
              ' names a subject nobody else can obtain.', file=sys.stderr)
        raise SystemExit(1)
    with open(PIN, 'w', encoding='utf-8') as fh:
        fh.write(f'# pacta subject pinned by fidelity/pacta_pin.py --write\n')
        fh.write(f'# commit {commit}\n')
        fh.write(f'# {len(got)} module(s), discovered by import, not by glob\n')
        for rel in sorted(got):
            fh.write(f'{got[rel]}  {rel}\n')
    print(f'PACTA PIN: wrote {len(got)} module(s) at commit {commit[:7]}')


def verify():
    if not os.path.exists(PIN):
        print('PACTA PIN: PACTA-PIN.sha256 is missing — the fidelity subject'
              ' is unpinned. Refusing to certify agreement with an unnamed'
              ' program.', file=sys.stderr)
        return 1
    want = {}
    commit = 'unknown'
    for line in open(PIN, encoding='utf-8'):
        if line.startswith('# commit '):
            commit = line.split()[2]
        if line.startswith('#') or not line.strip():
            continue
        h, rel = line.rstrip('\n').split('  ', 1)
        want[rel] = h
    got = loaded_sources()

    bad = []
    for rel in sorted(set(want) | set(got)):
        if rel not in got:
            bad.append(f'    {rel}: pinned but NOT LOADED by the harness')
        elif rel not in want:
            bad.append(f'    {rel}: loaded by the harness but NOT PINNED')
        elif want[rel] != got[rel]:
            bad.append(f'    {rel}: bytes differ from the pin')
    if bad:
        print('PACTA SUBJECT MISMATCH — the fidelity comparison would be'
              ' against a different program than the one pinned:',
              file=sys.stderr)
        print('\n'.join(bad), file=sys.stderr)
        print(f'    pinned commit: {commit}', file=sys.stderr)
        print('    Re-pin deliberately with fidelity/pacta_pin.py --write'
              ' if the new subject is the intended one.', file=sys.stderr)
        return 1
    _, dirty = head_commit()
    state = ' (WORKING TREE DIRTY)' if dirty else ''
    print(f'  pacta subject: {len(got)} module(s) match the pin,'
          f' commit {commit[:7]}{state}')
    return 1 if dirty else 0


if __name__ == '__main__':
    if '--write' in sys.argv:
        write()
    elif '--verify' in sys.argv:
        raise SystemExit(verify())
    else:
        raise SystemExit(__doc__)
