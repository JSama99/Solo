"""Contract tests for the offline adapter; no simulator or save access."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import c1

class ContractTests(unittest.TestCase):
    def fixture(self):
        return {'schemaVersion':'1','mission':{'schemaVersion':'1','missionVersion':'1','missionId':'fixture','seed':1,'actionBudget':2,'initialStateContract':'test only','targetSystem':'GameStore','objective':'controlled test','sourceFingerprint':'a'*64,'relevantCanonRecords':[],'relevantFailurePrecedents':['FL-001'],'invariants':[],'allowedActions':c1.ACTIONS,'successCondition':'bounded','failureCondition':'controlled'},'simulatorModel':'iPhone 17 Pro Max','runtime':'fixture','labID':c1.LAB,'initialStateFingerprint':'a'*64,'steps':[],'finalStateFingerprint':'b'*64,'classification':'INVARIANT_FAILURE'}
    def test_canonical_order(self):
        self.assertEqual(c1.canonical({'b':2,'a':1}),c1.canonical({'a':1,'b':2}))
    def test_hidden_truth_filtered(self):
        value=self.fixture();value['actualQuality']=90
        with self.assertRaises(ValueError):c1.audit(value)
        value=self.fixture();value['mission']['hiddenTruth']=True
        with self.assertRaises(ValueError):c1.audit(value)
    def test_owner_device_rejected(self):
        value=self.fixture();value['labID']='1E9DD15B-55DA-42A5-92F1-45F8C8AE4414'
        with self.assertRaises(ValueError):c1.audit(value)
    def test_budget_and_versions(self):
        value=self.fixture();value['mission']['actionBudget']=201
        with self.assertRaises(ValueError):c1.audit(value)
        value=self.fixture();value['schemaVersion']='2'
        with self.assertRaises(ValueError):c1.audit(value)
    def test_f1_schema_and_promotion_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);schema=root/'FailureLedger/schemas';schema.mkdir(parents=True)
            (schema/'candidate.schema.json').write_bytes((c1.ROOT/'FailureLedger/schemas/candidate.schema.json').read_bytes())
            evidence=root/'controlled.json';evidence.write_bytes(c1.canonical(self.fixture()))
            result=c1.candidate(self.fixture(),'synthetic_duplicate_review','controlled.json',root,True)
            self.assertEqual(result['authority'],'observation_only');self.assertEqual(result['reviewStatus'],'CANDIDATE')
            result['reviewStatus']='CONFIRMED'
            with self.assertRaises(ValueError):c1.validate_candidate(result,root)
    def test_evidence_tampering_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);schema=root/'FailureLedger/schemas';schema.mkdir(parents=True)
            (schema/'candidate.schema.json').write_bytes((c1.ROOT/'FailureLedger/schemas/candidate.schema.json').read_bytes())
            evidence=root/'controlled.json';evidence.write_text('{}')
            result=c1.candidate(self.fixture(),'synthetic_duplicate_review','controlled.json',root,True)
            evidence.write_text('{"changed":true}')
            with self.assertRaises(ValueError):c1.validate_candidate(result,root)
    def test_manifest_stable_and_source_sensitive(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'App').mkdir();source=root/'App/One.swift';source.write_text('// one')
            first=c1.manifest(root);self.assertEqual(first,c1.manifest(root))
            source.write_text('// two');self.assertNotEqual(first['sourceFingerprint'],c1.manifest(root)['sourceFingerprint'])
if __name__=='__main__':unittest.main()
