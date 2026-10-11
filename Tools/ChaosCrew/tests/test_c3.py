import sys,unittest,copy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import c1,c3
class WorldContractTests(unittest.TestCase):
 def testSupportedCommandsKeepUnavailableAPIsExplicit(self):
  self.assertIn('saveReload',c3.COMMANDS);self.assertIn('invalidDestination',c3.COMMANDS)
  self.assertIn('unsupported_action',c3.RESULTS);self.assertIn('HARNESS_BLOCKED',c3.CLASSIFICATIONS)
 def testDedicatedLabsExcludeOwnerDevices(self):
  self.assertNotIn('1E9DD15B-55DA-42A5-92F1-45F8C8AE4414',c3.LABS)
  self.assertNotIn('A31EC05C-9FF6-4D98-BECE-BF95CC2E37AC',c3.LABS)
 def testC1C2VersionedContractsStillDistinct(self):
  self.assertNotIn('worldScenario',c1.MISSION_KEYS)
  self.assertNotIn('actualQuality',c3.OBSERVATION_KEYS)
class SerializationBoundaryTests(unittest.TestCase):
 def fixture(self):
  m={k:'fixture' for k in c1.MISSION_KEYS};m.update(schemaVersion='1',missionVersion='3',seed=20000,actionBudget=24,targetSystem='FounderGarageRealityWorld/AtlantisRealityWorld',sourceFingerprint='a'*64,allowedActions=c3.COMMANDS)
  w={k:'fixture' for k in c3.WORLD_KEYS};w.update(version='3',startingScene='garage',startingFounderPose=[0,0,0,0],deviceProfile='iPhone 17 Pro Max',reduceMotionEnabled=True,maximumTransitions=4,maximumFramesPerAction=240);m['worldScenario']=w
  return dict(schemaVersion='1',mission=m,simulatorModel='iPhone 17 Pro Max',runtime='fixture',labID=c1.LAB,initialStateFingerprint='b'*64,steps=[],finalStateFingerprint='b'*64,classification='SEARCH_EXHAUSTED')
 def testSharedC1AuditRoutesWorldVersion(self):self.assertEqual(c1.audit(self.fixture()),self.fixture())
 def testPrivateFieldsRejected(self):
  x=self.fixture();x['mission']['worldScenario']['hiddenActualQuality']=1
  with self.assertRaises(ValueError):c1.audit(x)
 def testResourceBoundsRejectOverscale(self):
  x=self.fixture();x['mission']['actionBudget']=25
  with self.assertRaises(ValueError):c3.audit(x)
 def testActualLabControlsDeviceProfile(self):
  x=self.fixture();x['labID']=c3.LABS[1]
  with self.assertRaises(ValueError):c3.audit(x)
 def testHashChainRejectsMismatchedFinal(self):
  x=self.fixture();x['finalStateFingerprint']='c'*64
  with self.assertRaises(ValueError):c3.audit(x)
 def testMissingSourceFingerprintRejects(self):
  x=self.fixture();x['mission']['sourceFingerprint']='unrecorded'
  with self.assertRaises(ValueError):c3.audit(x)
class NativeHashBoundaryTests(SerializationBoundaryTests):
 def observation(self):
  o={k:'fixture' for k in c3.OBSERVATION_KEYS};o.pop('cameraTransition');o.update(founderPosition=[0,0,0],cameraPosition=[0,1,0],cameraRotation=[0,0,0,1],velocity=[0,0,0],heading=0,eligibility={k:False for k in ['computer','phone','tablet','chair','whiteboard','door']},entityCounts={'garage':1,'atlantis':0,'founderOccurrences':1});return o
 def trace(self):
  x=self.fixture();o=self.observation();h=c1.sha(c1.canonical(o));x['steps']=[dict(input=dict(action='computer',option=0,frames=1,lateral=0,forward=0,yaw=0),result='rejected_by_design',beforeFingerprint=x['initialStateFingerprint'],afterFingerprint=h,observation=o,violations=[])];x['finalStateFingerprint']=h;return x
 def testNativeBytesHashVerified(self):
  x=self.trace();self.assertEqual(c3.audit(x,c1.canonical(x)),x)
 def testCorruptNativeObservationRejected(self):
  x=self.trace();x['steps'][0]['observation']['heading']=1
  with self.assertRaises(ValueError):c3.audit(x,c1.canonical(x))
 def testPrivateNestedEntityCountRejected(self):
  x=self.trace();x['steps'][0]['observation']['entityCounts']['hiddenTruth']=1
  with self.assertRaises(ValueError):c3.audit(x)
if __name__=='__main__':unittest.main()


