import copy
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import c1
import c2
import test_c1

class AgentContracts(unittest.TestCase):
    def fixture(self):
        v=test_c1.ContractTests().fixture();m=v['mission'];m['missionVersion']='2';m['missionId']='agent-assignment';m['seed']=19000;m['allowedActions']=c1.C2_ACTIONS
        m['agentScenario']={'version':'2','participatingAgents':['aurora','stacks','brio'],'maximumSprints':4,'workloadProfile':'production allocations and urgency','assignmentProfile':'current and stale tasks; role match and mismatch','reviewProfile':'direct/delegate/manual/delayed/duplicate','evidenceProfile':'shared production ledger; no injected quality'}
        v['steps']=[{'input':{'action':'review','option':0},'result':'invariant_violation','beforeFingerprint':'a'*64,'afterFingerprint':'b'*64,'venture':1,'sprint':1,'attentionRemaining':1,'preparationTracks':[],'launched':False,'violations':['synthetic_evidence_provenance:task:aurora:stacks'],'agentObservation':{'ownershipFingerprint':'a'*64,'evidenceProvenanceFingerprint':'b'*64,'metricsFingerprint':'c'*64,'sessionFingerprint':'d'*64,'lifecycle':['reviewed'],'workloadBands':['healthy'],'evidenceCount':1}}]
        return v
    def test_versioned_extension_and_legacy(self):
        self.assertEqual(c1.audit(self.fixture()),self.fixture())
        c1.audit(test_c1.ContractTests().fixture())
    def test_hidden_truth_at_each_boundary(self):
        for target in ['mission','profile','step','observation','input']:
            v=self.fixture();dest={'mission':v['mission'],'profile':v['mission']['agentScenario'],'step':v['steps'][0],'observation':v['steps'][0]['agentObservation'],'input':v['steps'][0]['input']}[target]
            dest['actualQuality']=99
            with self.assertRaises(ValueError):c1.audit(v)
    def test_profile_cannot_carry_private_values(self):
        v=self.fixture();v['mission']['agentScenario']['evidenceProfile']='actual quality 99'
        with self.assertRaises(ValueError):c1.audit(v)
    def test_raw_metrics_in_hash_slot_rejected(self):
        v=self.fixture();v['steps'][0]['agentObservation']['metricsFingerprint']='trust 99'
        with self.assertRaises(ValueError):c1.audit(v)
    def test_invalid_lifecycle_rejected(self):
        v=self.fixture();v['steps'][0]['agentObservation']['lifecycle']=['hidden-drift']
        with self.assertRaises(ValueError):c1.audit(v)
    def test_unknown_production_command_rejected(self):
        v=self.fixture();v['steps'][0]['input']['action']='installQuality'
        with self.assertRaises(ValueError):c1.audit(v)
    def test_missing_observation_fails_closed(self):
        v=self.fixture();v['steps'][0].pop('agentObservation')
        with self.assertRaises(ValueError):c1.audit(v)
    def test_c2_f1_candidate_is_observation_only(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);schema=root/'FailureLedger/schemas';schema.mkdir(parents=True)
            (schema/'candidate.schema.json').write_bytes((c1.ROOT/'FailureLedger/schemas/candidate.schema.json').read_bytes())
            c1.write(root/'controlled.json',self.fixture())
            candidate=c1.candidate(self.fixture(),'synthetic_evidence_provenance:task:aurora:stacks','controlled.json',root,True)
            self.assertTrue(candidate['id'].startswith('CF-c2-'));self.assertEqual(candidate['authority'],'observation_only');self.assertEqual(candidate['reviewStatus'],'CANDIDATE')
    def test_persisted_field_findings_do_not_mask_each_other(self):
        v=self.fixture();v['steps'][0]['violations']=['save_reload:evidence','save_reload:reportCache']
        self.assertEqual(c2.minimized_targets(v,'save_reload_evidence'),['save_reload:evidence'])
        self.assertEqual(c2.minimized_targets(v,'save_reload_reportCache'),['save_reload:reportCache'])
    def test_sprint_cap_and_isolation(self):
        v=self.fixture();v['mission']['agentScenario']['maximumSprints']=99
        with self.assertRaises(ValueError):c1.audit(v)
        v=self.fixture();v['labID']='owner'
        with self.assertRaises(ValueError):c1.audit(v)
if __name__=='__main__':unittest.main()
