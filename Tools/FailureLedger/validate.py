#!/usr/bin/env python3
"""Validate offline Failure Ledger evidence, schemas and cross references."""
import argparse
import sys
sys.dont_write_bytecode=True
from ledger import Ledger, LedgerError, ROOT
from pathlib import Path

def run(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    args=parser.parse_args(argv)
    try:
        ledger=Ledger(args.root)
        print(f'PASS: {len(ledger.records)} incidents, {len(ledger.rules)} rules; SHA256 {ledger.fingerprint}')
        return 0
    except (LedgerError,OSError,ValueError,KeyError,TypeError) as exc:
        print('BLOCKING: '+str(exc),file=sys.stderr);return 2
if __name__=='__main__': raise SystemExit(run())
