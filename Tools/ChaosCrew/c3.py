#!/usr/bin/env python3
"""C3 public contract/audit/export. Spatial actions execute in production-backed XCTest only."""
import argparse,json,math
from pathlib import Path
from collections import Counter
import c1
GROUPS=['world-garage','world-traversal','world-camera','world-lifecycle']
LABS=[c1.LAB,'37C6DF3F-87F5-4F57-A882-B4B7D11A12F5']
COMMANDS=['computer','phone','tablet','walk','move','stop','look','camera','recenter','chair','chairExit','cancelChair','whiteboard','authoredWhiteboardProbe','door','requestTraversal','enterHandoff','returnGarage','atlantisMove','atlantisTurn','teardown','recreate','saveReload','invalidDestination']
WORLD_KEYS={'version','startingScene','startingFounderPose','cameraMode','movementInputProfile','targetInteractions','deviceProfile','reduceMotionEnabled','maximumTransitions','maximumFramesPerAction','observationScope'}
OBSERVATION_KEYS={'scene','founderPosition','cameraPosition','cameraRotation','heading','velocity','cameraMode','cameraTransition','reduceMotion','collision','motionState','navigationMode','interactionPhase','eligibility','architectureReady','founderReady','doorOpen','loadedDistricts','entityCounts','handoffs','finite'}
RESULTS={'accepted','accepted_transition','rejected_by_design','unsupported_action','observed_result','timeout','invariant_violation'}
CLASSIFICATIONS={'INVARIANT_FAILURE','VALIDLY_BLOCKED','SEARCH_EXHAUSTED','HARNESS_BLOCKED','REACHABLE'}
def manifest(root):
 m=c1.manifest(root)
 # Extend the accepted source manifest with spatial authorities/assets actually used by C3.
 for pattern in ['App/RealityKit/FounderGarage/founder_garage_v8.usdz','App/RealityKit/FounderCharacter/**/*','App/RealityKit/Atlantis/**/*']:
  for p in root.glob(pattern):
   if p.is_file():m['files'][str(p.relative_to(root))]=c1.sha(p.read_bytes())
 m['baseline']='8ccc6fbbea705ec1ce89a61ba0f2eaac8e445003';m['sourceFingerprint']=c1.sha(c1.canonical(m['files']))
 return m

def audit(t, raw=None):
 if set(t)!=c1.REPLAY_KEYS:raise ValueError('world replay allowlist')
 m=t['mission']
 if set(m)!=c1.MISSION_KEYS|{'worldScenario'} or m['missionVersion']!='3' or m['targetSystem']!='FounderGarageRealityWorld/AtlantisRealityWorld':raise ValueError('world mission contract')
 w=m['worldScenario']
 if set(w)!=WORLD_KEYS or w['version']!='3' or w['startingScene']!='garage':raise ValueError('world scenario allowlist')
 if t['labID'] not in LABS or m['allowedActions']!=COMMANDS or t['simulatorModel']!=w['deviceProfile']:raise ValueError('production routing/lab/device')
 if w['deviceProfile'] not in ['iPhone 17 Pro Max','iPad Air 11-inch (M4)'] or type(w['reduceMotionEnabled']) is not bool:raise ValueError('device/motion profile')
 if not 0<m['actionBudget']<=24 or not 0<w['maximumTransitions']<=4 or not 0<w['maximumFramesPerAction']<=240:raise ValueError('resource budget')
 if len(t['steps'])>m['actionBudget'] or t['classification'] not in CLASSIFICATIONS:raise ValueError('actions/classification')
 if len(m['sourceFingerprint'])!=64 or any(c not in '0123456789abcdef' for c in m['sourceFingerprint']):raise ValueError('source fingerprint')
 if not isinstance(m['seed'],int) or m['seed']<0:raise ValueError('seed')
 if w['deviceProfile']!=dict(zip(LABS,['iPhone 17 Pro Max','iPad Air 11-inch (M4)']))[t['labID']]:raise ValueError('device authority')
 if len(w['startingFounderPose'])!=4 or not all(math.isfinite(x) for x in w['startingFounderPose']):raise ValueError('starting pose')
 expected=t['initialStateFingerprint'];transitions=0
 for step in t['steps']:
  if set(step)!={'input','result','beforeFingerprint','afterFingerprint','observation','violations'}:raise ValueError('world step allowlist')
  a=step['input'];o=step['observation']
  if set(a)!={'action','option','frames','lateral','forward','yaw'} or a['action'] not in COMMANDS or not 1<=a['frames']<=w['maximumFramesPerAction']:raise ValueError('world input')
  if not all(math.isfinite(a[x]) for x in ['lateral','forward','yaw']):raise ValueError('input finite')
  if (not set(o)<=OBSERVATION_KEYS or not OBSERVATION_KEYS-{'cameraTransition'}<=set(o)) or set(o['eligibility'])!={'computer','phone','tablet','chair','whiteboard','door'}:raise ValueError('private or unknown observation')
  if set(o['entityCounts'])!={'founderOccurrences','garage','atlantis'} or any(type(x) is not int or x<0 for x in o['entityCounts'].values()):raise ValueError('entity count disclosure')
  for k,n in [('founderPosition',3),('cameraPosition',3),('cameraRotation',4),('velocity',3)]:
   if len(o[k])!=n or not all(math.isfinite(x) for x in o[k]):raise ValueError('spatial vector')
  if any(type(x) is not bool for x in o['eligibility'].values()):raise ValueError('eligibility disclosure')
  allowed={'INVALID_MOVEMENT_STATE','REDUCE_MOTION_VIOLATION','DUPLICATE_SCENE_ENTITY','REJECTED_WORLD_MUTATION','SAVE_RELOAD_WORLD_STATE','INCORRECT_INTERACTION_TARGET','INVALID_WORLD_TRANSITION','COLLISION_OR_GROUNDING','synthetic_incorrect_interaction_target'}
  if not set(step['violations'])<=allowed:raise ValueError('diagnostic disclosure')
  if step['result'] not in RESULTS or step['beforeFingerprint']!=expected:raise ValueError('result/state chain')
  expected=step['afterFingerprint'];transitions+=step['result']=='accepted_transition' and a['action']!='requestTraversal'
  if step['result']=='invariant_violation' and not step['violations']:raise ValueError('missing invariant')
 if raw is not None:
  # Swift JSONSerialization emits full NSNumber decimals. Hash original bytes,
  # never Python's shorter decimal reserialization of the same numeric values.
  text=raw.decode();cursor=0;native=[];decoder=json.JSONDecoder()
  marker='"observation":'
  while True:
   start=text.find(marker,cursor)
   if start<0:break
   start+=len(marker)
   while text[start].isspace():start+=1
   observation,length=decoder.raw_decode(text[start:]);native.append((observation,c1.sha(text[start:start+length].encode())));cursor=start+length
  if len(native)!=len(t['steps']):raise ValueError('native observation count')
  if any(o!=s['observation'] or h!=s['afterFingerprint'] for (o,h),s in zip(native,t['steps'])):raise ValueError('native observation hash')
 if transitions>w['maximumTransitions'] or expected!=t['finalStateFingerprint']:raise ValueError('transition/final state budget')
 return t

def export(root,evidence,output):
 root,evidence,output=root.resolve(),evidence.resolve(),output.resolve()
 source=c1.read(evidence/'source-manifest.json')
 if source!=manifest(root):raise ValueError('current world source mismatch')
 summary=c1.read(evidence/'study-summary.json');counts=Counter();groups=Counter();diagnostics=Counter();commands=Counter();classes=Counter();motion=Counter();handoffs=0;footprints=[];loads=[]
 for name,h in sorted(summary['replayFingerprints'].items()):
  p=evidence/(name+'.json');t=audit(c1.read(p),p.read_bytes());m=t['mission']
  if c1.sha(p.read_bytes())!=h or m['sourceFingerprint']!=source['sourceFingerprint']:raise ValueError('mixed or corrupted replay')
  groups[m['missionId']]+=1;classes[t['classification']]+=1;motion[str(m['worldScenario']['reduceMotionEnabled'])]+=1
  for s in t['steps']:counts[s['result']]+=1;commands[s['input']['action']]+=1;diagnostics.update(s['violations'])
  handoffs+=max((s['observation']['handoffs'] for s in t['steps']),default=0)
  perf=c1.read(evidence/(name+'-performance.json'));footprints.append(perf['processFootprintMB']);loads.append(perf['unrenderedAssetLoadSeconds'])
 if groups!=Counter({g:100 for g in GROUPS}) or sum(counts.values())!=summary['attemptedActions'] or summary['attemptedActions']!=summary['replayedActions']:raise ValueError('incomplete coverage')
 candidates=[]
 for p in sorted(evidence.glob('*-min-*.json')):
  t=audit(c1.read(p),p.read_bytes());invariant=p.stem.split('-min-',1)[1]
  if not any(invariant in s['violations'] for s in t['steps']):raise ValueError('minimized cause missing')
  candidate=c1.candidate(t,invariant,str(p.relative_to(root)),root);c1.write(root/'FailureLedger/candidates'/(candidate['id']+'.json'),candidate);candidates.append(candidate['id'])
 controlled=audit(c1.read(evidence/'controlled-minimized.json'),(evidence/'controlled-minimized.json').read_bytes());candidate=c1.candidate(controlled,'synthetic_incorrect_interaction_target',str((evidence/'controlled-minimized.json').relative_to(root)),root,True)
 candidate['expectedBehavior']='CONTROLLED TEST-ONLY OBSERVER: reported interaction target must match production resolution';c1.write(output/'controlled-candidate-example.json',candidate)
 report={'authority':'observation_only','sourceFingerprint':source['sourceFingerprint'],'baseline':source['baseline'],'scenarios':dict(groups),'attemptedActions':sum(counts.values()),'replayedActions':summary['replayedActions'],'classifications':dict(classes),'actionResults':dict(counts),'actionCoverage':dict(commands),'diagnosticOccurrences':dict(diagnostics),'reduceMotionScenarios':dict(motion),'observedHandoffs':handoffs,'candidates':candidates,'elapsedSeconds':summary['elapsedSeconds'],'performanceObservations':{'scope':'unrendered Simulator process; not physical-device or GPU metrics','assetLoadSecondsMin':min(loads),'assetLoadSecondsMax':max(loads),'processFootprintMBSampleMax':max(footprints),'performanceThreshold':None},'coverageGaps':['SwiftUI composed scene and live SceneEvents.Update camera choreography are private and not exercised.','Unrendered numeric and entity/controller observations do not establish rendered clipping, animation quality, prompt hit testing or human visual acceptance.','Garage devices tested as production eligibility/intent resolution, not actual SwiftUI screens or business effects.','Authored whiteboard endpoint is labelled a probe, not proof of physical walking reachability.','World pose persistence API and invalid destination API unavailable; reported unsupported, not passed or failed.','Atlantis exposed move/turn/grounding tested; full frame-driven contextual camera and locomotion update not exposed.','Study varies supported commands/Reduce Motion from canonical seated pose; arbitrary start pose/performance profiles unavailable.'],'promotion':False}
 c1.write(output/'coverage.json',report);return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=c1.ROOT);sub=p.add_subparsers(dest='cmd',required=True)
 a=sub.add_parser('manifest');a.add_argument('--output',type=Path,required=True)
 a=sub.add_parser('audit');a.add_argument('--evidence',type=Path,required=True);a.add_argument('--output',type=Path,required=True)
 a=p.parse_args()
 if a.cmd=='manifest':m=manifest(a.root);c1.write(a.output,m);print(m['sourceFingerprint'])
 else:print(json.dumps(export(a.root,a.evidence,a.output),indent=2))
if __name__=='__main__':main()
