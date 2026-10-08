#!/usr/bin/env python3
"""Deterministic registry output; read-only unless --write is explicit."""
import argparse
import sys
sys.dont_write_bytecode=True
from pathlib import Path
from ledger import Ledger, LedgerError, ROOT, canonical_bytes

def run(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--write',action='store_true')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--task')
    args=parser.parse_args(argv)
    try:
        ledger=Ledger(args.root)
        outputs={args.root/'FailureLedger/registry/DO_NOT_DO.md':ledger.registry_bytes(),
                 args.root/'Documentation/FailureLedger/FailedFixes.md':ledger.failed_fixes_bytes()}
        if args.task: sys.stdout.buffer.write(canonical_bytes(ledger.retrieve(args.task)))
        elif args.write:
            for path,data in outputs.items(): path.write_bytes(data)
        elif args.check:
            for path,data in outputs.items():
                if path.read_bytes()!=data: raise LedgerError('stale generated registry: '+str(path))
            print('PASS: generated registries match')
        else: sys.stdout.buffer.write(ledger.registry_bytes())
        return 0
    except (LedgerError,OSError,ValueError,KeyError,TypeError) as exc:
        print('BLOCKING: '+str(exc),file=sys.stderr);return 2
if __name__=='__main__': raise SystemExit(run())
