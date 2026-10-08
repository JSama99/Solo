import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

TOOLS=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(TOOLS))
sys.path.insert(0,str(TOOLS/'SoloCanon'))
from FailureLedger.ledger import Ledger, LedgerError, ROOT, canonical_bytes, read_json, validate_candidate
from canon_store import CanonStore, CanonError
from canon_pack import build_pack
from codex_preflight import build_preflight, render_text

class FailureLedgerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        shutil.copytree(ROOT/'FailureLedger',self.root/'FailureLedger')
        shutil.copytree(ROOT/'Canon/records',self.root/'Canon/records')
        for e in read_json(ROOT/'FailureLedger/evidence.json'):
            dest=self.root/e['path'];dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/e['path'],dest)
        for r in Ledger(ROOT).records:
            for t in r['relatedTests']:
                dest=self.root/t.split('::')[0];dest.parent.mkdir(parents=True,exist_ok=True)
                if not dest.exists():shutil.copyfile(ROOT/t.split('::')[0],dest)
        dest=self.root/'Tools/FailureLedger/ledger.py';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(TOOLS/'FailureLedger/ledger.py',dest)
    def edit(self, name, change):
        path=self.root/name;value=read_json(path);change(value);path.write_bytes(canonical_bytes(value))
    def test_valid_records(self):
        self.assertEqual(len(Ledger(self.root).records),14)
    def test_invalid_classification(self):
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(classification='UNSUPPORTED'))
        with self.assertRaisesRegex(LedgerError,'classification'):Ledger(self.root)
    def test_invalid_status(self):
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(status='ACCEPTED'))
        with self.assertRaisesRegex(LedgerError,'status'):Ledger(self.root)
    def test_duplicate_failure_ids(self):
        shutil.copyfile(self.root/'FailureLedger/records/FL-001.json',self.root/'FailureLedger/records/duplicate.json')
        with self.assertRaisesRegex(LedgerError,'duplicate Failure'):Ledger(self.root)
    def test_mandatory_evidence(self):
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(evidenceReferences=[]))
        with self.assertRaisesRegex(LedgerError,'insufficient'):Ledger(self.root)
    def test_unknown_evidence_id(self):
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(evidenceReferences=['EV-999']))
        with self.assertRaisesRegex(LedgerError,'mandatory evidence'):Ledger(self.root)
    def test_explicit_unknown_information(self):
        candidate=next(r for r in Ledger(self.root).records if r['id']=='FL-012')
        self.assertIsNone(candidate['observedBehavior']);self.assertIsNone(candidate['rootCause'])
        self.assertIsNone(candidate['firstObservedDate']);self.assertTrue(candidate['unknownInformation'])
    def test_unknown_fields_and_guessed_causes_rejected(self):
        self.edit('FailureLedger/records/FL-012.json',lambda r:r.update(rootCauseConfidence='ESTABLISHED'))
        with self.assertRaisesRegex(LedgerError,'unknown cause'):Ledger(self.root)
        self.edit('FailureLedger/records/FL-012.json',lambda r:r.update(rootCauseConfidence='UNKNOWN',bindingCanon=True))
        with self.assertRaisesRegex(LedgerError,'unknown fields'):Ledger(self.root)
    def test_deterministic_ordering(self):
        a=Ledger(self.root);self.assertEqual([r['id'] for r in a.records],sorted(r['id'] for r in a.records))
        self.assertEqual(canonical_bytes(a.retrieve('Grow customer traction')),canonical_bytes(Ledger(self.root).retrieve('Grow customer traction')))
    def test_registry_missing_failure(self):
        self.edit('FailureLedger/registry/rules.json',lambda rs:rs[0].update(supportingFailureIds=['FL-999']))
        with self.assertRaisesRegex(LedgerError,'unknown supporting'):Ledger(self.root)
    def test_candidates_excluded_from_accepted_rules(self):
        results=Ledger(self.root).retrieve('Founder shoulder topology App Store purchase')
        candidates={r['id'] for r in results['candidate_lessons']}
        self.assertEqual(candidates,{'FL-008','FL-012'})
        for rule in results['accepted_rules']:self.assertFalse(candidates & set(rule['supportingFailureIds']))
    def test_candidates_cannot_support_accepted_rules(self):
        self.edit('FailureLedger/registry/rules.json',lambda rs:rs[0].update(supportingFailureIds=['FL-008']))
        self.edit('FailureLedger/records/FL-008.json',lambda r:r.update(preventionRules=['DND-001']))
        with self.assertRaisesRegex(LedgerError,'cannot support accepted'):Ledger(self.root)
    def test_launch_retrieval(self):
        result=Ledger(self.root).retrieve('Modify Product Launch readiness')
        self.assertIn('FL-001',[r['id'] for r in result['incidents']])
        self.assertIn('DND-001',[r['id'] for r in result['accepted_rules']])
        self.assertTrue(any('two-Attention' in gate for gate in result['required_gates']))
    def test_failed_fixes_are_evidence_linked(self):
        ledger=Ledger(self.root);result=ledger.retrieve('Grow balance')
        fix=next(f for f in result['failed_fixes'] if f['failureId']=='FL-004')
        self.assertIn('89.4%',fix['observedOutcome']);self.assertTrue(fix['evidenceReferences'])
        self.edit('FailureLedger/records/FL-004.json',lambda r:r['failedApproaches'][0].update(evidenceReferences=['EV-999']))
        with self.assertRaisesRegex(LedgerError,'failed fix'):Ledger(self.root)
    def test_candidate_contract_cannot_promote(self):
        candidate=read_json(self.root/'FailureLedger/candidates/example.json')
        for field,value in [('reviewStatus','ACCEPTED'),('authority','production_canon')]:
            bad=copy.deepcopy(candidate);bad[field]=value
            with self.assertRaises(LedgerError):validate_candidate(bad,self.root)
        bad=copy.deepcopy(candidate);bad['acceptedRule']='DND-999'
        with self.assertRaises(LedgerError):validate_candidate(bad,self.root)
        self.assertEqual(validate_candidate(candidate,self.root)['reviewStatus'],'CANDIDATE')
    def test_corrupt_or_missing_files(self):
        path=self.root/'FailureLedger/records/FL-001.json';path.write_text('{corrupt')
        with self.assertRaisesRegex(LedgerError,'corrupt JSON'):Ledger(self.root)
        path.unlink();(self.root/'FailureLedger/registry/rules.json').unlink()
        with self.assertRaisesRegex(LedgerError,'unavailable'):Ledger(self.root)
    def test_missing_evidence_or_stale_fingerprint(self):
        path=self.root/'Documentation/FailureLedger/Evidence/OwnerStatements.md';path.write_text('altered')
        with self.assertRaisesRegex(LedgerError,'fingerprint mismatch'):Ledger(self.root)
        path.unlink()
        with self.assertRaisesRegex(LedgerError,'missing evidence'):Ledger(self.root)
    def test_unsafe_evidence_path(self):
        self.edit('FailureLedger/evidence.json',lambda es:es[0].update(path='../private.txt'))
        with self.assertRaisesRegex(LedgerError,'unsafe'):Ledger(self.root)
    def test_byte_identical_registry_generation(self):
        a=Ledger(self.root);b=Ledger(self.root)
        self.assertEqual(a.registry_bytes(),b.registry_bytes())
        self.assertEqual(a.failed_fixes_bytes(),b.failed_fixes_bytes())
        self.assertEqual(a.registry_bytes(),(ROOT/'FailureLedger/registry/DO_NOT_DO.md').read_bytes())
        self.assertEqual(a.failed_fixes_bytes(),(ROOT/'Documentation/FailureLedger/FailedFixes.md').read_bytes())
    def test_generated_candidate_findings_do_not_enter_rules(self):
        before=Ledger(self.root).registry_bytes()
        original=read_json(self.root/'FailureLedger/candidates/example.json')
        original['id']='CF-new.synthetic';original['reproductionStatus']='REPRODUCED'
        (self.root/'FailureLedger/candidates/new.json').write_bytes(canonical_bytes(original))
        after=Ledger(self.root)
        self.assertEqual(before,after.registry_bytes())
        self.assertFalse(any('CF-new' in str(r) for r in after.retrieve('synthetic')['accepted_rules']))
    def test_unreviewed_rule_acceptance_rejected(self):
        self.edit('FailureLedger/registry/rules.json',lambda rs:rs[0].update(review=None))
        with self.assertRaisesRegex(LedgerError,'explicit review'):Ledger(self.root)
    def test_canon_pack_backward_compatibility_and_authority(self):
        store=CanonStore(ROOT);task='Modify Product Launch readiness'
        before=canonical_bytes(build_pack(store,consumer='codex',task=task))
        repo={'worktree':str(ROOT),'branch':'test','head':'a'*40,'dirty':False,'status_short':[]}
        artifact,pack=build_preflight(store,task,repo,timestamp='fixed')
        self.assertEqual(before,canonical_bytes(pack))
        self.assertEqual(artifact['failure_precedents']['authority'],'historical_precedents_not_canon')
        self.assertFalse(any(r['id'].startswith('FL-') for r in pack['records']))
        self.assertIn('FL-001',render_text(artifact))
        runtime=build_pack(store,consumer='runtime',task='Product launch')
        self.assertNotIn('failure_precedents',runtime)
    def test_installed_missing_ledger_blocks_preflight(self):
        store=CanonStore(ROOT)
        shutil.rmtree(self.root/'FailureLedger')
        with patch.object(store,'root',self.root):
            with self.assertRaisesRegex(CanonError,'Failure Ledger unavailable'):
                build_preflight(store,'product launch',{'dirty':False})
    def test_preintegration_canon_roots_remain_compatible(self):
        store=CanonStore(ROOT)
        shutil.rmtree(self.root/'FailureLedger');(self.root/'Tools/FailureLedger/ledger.py').unlink()
        with patch.object(store,'root',self.root):
            artifact,_=build_preflight(store,'product launch',{'dirty':False})
        self.assertNotIn('failure_precedents',artifact)
    def test_cli_corrupt_record_fails_clearly(self):
        (self.root/'FailureLedger/records/FL-001.json').write_text('broken')
        result=subprocess.run([sys.executable,'-B',str(TOOLS/'FailureLedger/validate.py'),'--root',str(self.root)],capture_output=True,text=True)
        self.assertEqual(result.returncode,2);self.assertIn('BLOCKING:',result.stderr)
    def test_tuning_excerpt_is_exact_logged_payload(self):
        ops=read_json(ROOT/'Documentation/Reconstruction/HistoricalSourceOperations.json')
        expected=ops[92]['item']['changes']['/private/tmp/solo-loop-v3-integration/Documentation/CustomerTraction/Slice1/Tuning/Report.md']['content']
        self.assertEqual(expected,(ROOT/'Documentation/FailureLedger/Evidence/TuningHistorical.md').read_text())
    def test_source_fingerprint_tracks_ledger_changes(self):
        before=Ledger(self.root).fingerprint
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(title=r['title']+' clarified'))
        self.assertNotEqual(before,Ledger(self.root).fingerprint)
    def test_invalid_dates_and_missing_required_fields(self):
        self.edit('FailureLedger/records/FL-001.json',lambda r:r.update(firstObservedDate='2026-02-30'))
        with self.assertRaisesRegex(LedgerError,'date'):Ledger(self.root)
        self.edit('FailureLedger/records/FL-001.json',lambda r:(r.update(firstObservedDate=None),r.pop('rootCause')))
        with self.assertRaisesRegex(LedgerError,'missing'):Ledger(self.root)
    def test_duplicate_candidate_ids_fail(self):
        shutil.copyfile(self.root/'FailureLedger/candidates/example.json',self.root/'FailureLedger/candidates/duplicate.json')
        with self.assertRaisesRegex(LedgerError,'duplicate Candidate'):Ledger(self.root)
    def test_missing_candidate_schema_fails_even_without_findings(self):
        (self.root/'FailureLedger/candidates/example.json').unlink()
        (self.root/'FailureLedger/schemas/candidate.schema.json').unlink()
        with self.assertRaisesRegex(LedgerError,'unavailable'):Ledger(self.root)
    def test_unsupported_schema_keyword_fails_clearly(self):
        self.edit('FailureLedger/schemas/failure.schema.json',lambda r:r.update(unimplementedKeyword=True))
        with self.assertRaisesRegex(LedgerError,'unsupported schema'):Ledger(self.root)
    def test_pending_rules_are_separate(self):
        proposed=copy.deepcopy(Ledger(self.root).rules[0])
        proposed.update(id='DND-013',supportingFailureIds=['FL-008'],acceptance='PROPOSED',review=None)
        self.edit('FailureLedger/registry/rules.json',lambda rs:rs.append(proposed))
        self.edit('FailureLedger/records/FL-008.json',lambda r:r.update(preventionRules=['DND-013']))
        result=Ledger(self.root).retrieve('Founder shoulder')
        self.assertEqual([r['id'] for r in result['pending_rules']],['DND-013'])
        self.assertNotIn('DND-013',[r['id'] for r in result['accepted_rules']])
    def test_unresolved_design_warnings_retrieve(self):
        result=Ledger(self.root).retrieve('Cash Runway Coverage')
        self.assertEqual({r['id'] for r in result['unresolved_warnings']},{'FL-007','FL-013'})
    def test_candidate_evidence_is_verified(self):
        candidate=read_json(self.root/'FailureLedger/candidates/example.json')
        candidate['evidenceReferences'][0]['sha256']='f'*64
        with self.assertRaisesRegex(LedgerError,'candidate evidence fingerprint'):validate_candidate(candidate,self.root)

if __name__=='__main__':unittest.main()
