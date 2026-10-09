#!/usr/bin/env python3
"""C1 developer-only manifest, replay audit and exact F1 candidate adapter.

Does not launch simulators, modify saves, promote findings or implement gameplay.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools'))
from FailureLedger.ledger import Ledger, validate_candidate

LAB = '40D4F1B3-092A-4E6F-9251-7A686A734B55'
ACTIONS = ['assign','delegate','review','approve','commit','route','reload','beginLaunch','decisions','release','publicity','execute','resolve','finishLaunch','focus','advance']
REPLAY_KEYS = {'schemaVersion','mission','simulatorModel','runtime','labID','initialStateFingerprint','steps','finalStateFingerprint','classification'}
STEP_KEYS = {'input','result','beforeFingerprint','afterFingerprint','venture','sprint','attentionRemaining','preparationTracks','launched','operationState','violations'}
MISSION_KEYS = {'schemaVersion','missionVersion','missionId','seed','actionBudget','initialStateContract','targetSystem','objective','sourceFingerprint','relevantCanonRecords','relevantFailurePrecedents','invariants','allowedActions','successCondition','failureCondition'}

def canonical(value):
    return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()

def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(Path(path).read_text())
def write(path, value):
    Path(path).parent.mkdir(parents=True,exist_ok=True)
    Path(path).write_bytes(canonical(value)+b'\n')

def manifest(root):
    paths = set()
    for pattern in ['App/**/*.swift','Tools/**/*.py','Canon/**/*.json','FailureLedger/**/*.json','Tests/ChaosCrewMissionTests.swift','SoloUnicornRun.xcodeproj/project.pbxproj','SoloUnicornRun.xcodeproj/xcshareddata/xcschemes/*.xcscheme','AGENTS.md','Documentation/ChaosCrew/C1-Architecture.md']:
        paths.update(root.glob(pattern))
    # Generated candidate findings are outputs, not inputs. Prevent fingerprint recursion.
    files = {str(p.relative_to(root)):sha(p.read_bytes()) for p in sorted(paths) if p.is_file() and 'candidates' not in p.parts}
    return {'schemaVersion':'1','baseline':'817b67cb7ee439711af200ddaef541e6c8bf0364','sourceFingerprint':sha(canonical(files)),'files':files}

def audit(replay):
    if set(replay) != REPLAY_KEYS or set(replay['mission']) != MISSION_KEYS: raise ValueError('replay public allowlist mismatch')
    m = replay['mission']
    if replay['schemaVersion']!='1' or m['schemaVersion']!='1' or m['missionVersion']!='1': raise ValueError('unsupported contract version')
    if replay['labID'] != LAB: raise ValueError('unverified lab')
    if m['targetSystem'] != 'GameStore' or m['allowedActions'] != ACTIONS: raise ValueError('unsupported production adapter')
    if not isinstance(m['seed'],int) or m['seed']<0 or not 0 < m['actionBudget']<=200: raise ValueError('invalid seed or budget')
    if len(replay['steps'])>m['actionBudget']: raise ValueError('action budget exceeded')
    for step in replay['steps']:
        if not set(step)<=STEP_KEYS or not {'input','result','beforeFingerprint','afterFingerprint','venture','sprint','attentionRemaining','preparationTracks','launched','violations'}<=set(step): raise ValueError('step public allowlist mismatch')
        if not set(step['input']) <= {'action','taskID','agentID','option'}: raise ValueError('private/unknown action parameter')
        if step['input']['action'] not in ACTIONS: raise ValueError('unsupported action')
        if step['result'] not in {'accepted','rejected_by_design','unavailable','invariant_violation'}: raise ValueError('unknown action result')
        if any(x not in {'aurora','stacks','brio'} for x in step['preparationTracks']): raise ValueError('noncanonical preparation owner')
    # Human-readable output is structurally allowlisted, not a hidden-value denylist.
    return replay

def candidate(replay, invariant, evidence_path, root, synthetic=False):
    audit(replay)
    m = replay['mission']; scenario = f"{m['missionId']}-v{m['missionVersion']}-s{m['seed']}"
    evidence = root/evidence_path
    suffix = sha(canonical([scenario,invariant]))[:12]
    result = {'schemaVersion':'1','id':f'CF-c1-{suffix}', 'missionId':m['missionId'], 'scenarioId':scenario,'seed':m['seed'],'sourceFingerprint':m['sourceFingerprint'],
        'actionTrace':[{'action':s['input']['action'],'parameters':{k:v for k,v in s['input'].items() if k!='action'},'observedResult':s['result']} for s in replay['steps']],
        'expectedBehavior': ('CONTROLLED TEST-ONLY OBSERVER: duplicate review must not be reported as accepted' if synthetic else 'Production contract must preserve '+invariant),
        'observedBehavior': ('CONTROLLED TEST-ONLY OBSERVER DEFECT; not a production incident' if synthetic else 'Source-backed observer flagged '+invariant+'; candidate requires review'),
        'invariantViolation':invariant,'evidenceReferences':[{'path':evidence_path,'sha256':sha(evidence.read_bytes())}],
        'reproductionStatus':'REPRODUCED','reviewStatus':'CANDIDATE','authority':'observation_only'}
    return validate_candidate(result,root)

def summarize(root, evidence, output):
    source = read(evidence/'source-manifest.json')
    if manifest(root) != source: raise ValueError('source diverged from study manifest')
    summary = read(evidence/'study-summary.json')
    counts = Counter(); actions=Counter(); outcomes=Counter(); transitions=Counter(); failures=Counter()
    traces=[]
    for scenario,digest in sorted(summary['replayFingerprints'].items()):
        path=evidence/(scenario+'.json'); raw=path.read_bytes(); trace=audit(json.loads(raw))
        if sha(raw)!=digest: raise ValueError('replay fingerprint mismatch: '+scenario)
        if trace['mission']['sourceFingerprint']!=source['sourceFingerprint']: raise ValueError('mixed source state')
        traces.append(trace); outcomes[trace['classification']]+=1
        previous=None
        for s in trace['steps']:
            counts[s['result']]+=1; actions[s['input']['action']]+=1; failures.update(s['violations'])
            state=(s['venture'],s['sprint'],s['attentionRemaining'],tuple(s['preparationTracks']),s['launched'],s.get('operationState'))
            if previous is not None: transitions[str((previous,state))]+=1
            previous=state
    if len(traces)!=200 or summary['launchScenarios']!=100 or summary['fuzzScenarios']!=100: raise ValueError('study scenario counts incorrect')
    if sum(counts.values()) != summary['attemptedActions']: raise ValueError('action count mismatch')
    ledger=Ledger(root)
    precedents=ledger.retrieve('product launch save persistence chaos grow research source recovery isolation')
    write(output/'precedents.json',precedents)
    findings=[]
    for path in sorted(evidence.glob('*-min-*.json')):
        trace=audit(read(path)); invariants=sorted(set(v for s in trace['steps'] for v in s['violations']))
        for invariant in invariants:
            if invariant.startswith('synthetic'): continue
            rel=str(path.relative_to(root))
            finding=candidate(trace,invariant,rel,root)
            write(root/'FailureLedger/candidates'/ (finding['id']+'.json'),finding)
            findings.append({'id':finding['id'],'invariant':invariant,'minimalReplay':rel,'relatedPrecedents':trace['mission']['relevantFailurePrecedents']})
    controlled=evidence/'controlled-defect-minimized.json'
    fixture=candidate(read(controlled),'synthetic_duplicate_review',str(controlled.relative_to(root)),root,True)
    # Contract proof only, segregated from genuine production candidates.
    write(output/'controlled-candidate-example.json',fixture)
    report={'schemaVersion':'1','sourceFingerprint':source['sourceFingerprint'],'scenarios':200,'launchScenarios':100,'fuzzScenarios':100,
        'attemptedActions':sum(counts.values()),'replayedActions':summary['replayedActions'],'actionResults':dict(sorted(counts.items())),
        'actionCoverage':dict(sorted(actions.items())),'classifications':dict(sorted(outcomes.items())), 'uniqueObservedTransitions':len(transitions),
        'saveReloadOperations':actions['reload'],'violationOccurrences':dict(sorted(failures.items())), 'candidateFindings':findings,
        'elapsedSeconds':summary['elapsedSeconds'],'authority':'observation_only',
        'limitations':['Only bounded initial careers, authored agent capabilities and 16 action commands explored; no fixtures installed.',
        'Deletion minimization bounded to 256 trials; one representative per invariant, complete original traces preserved.',
        'Venture transition oracle is conditional; no claim of transition coverage without observed transitions.',
        'Existing Loop runner is not present in the reconstruction; Canon chaos_preflight reused, no replacement gameplay or Loop engine.',
        'Peak memory not instrumented; elapsed time excludes Xcode compilation and tests other than study.']}
    write(output/'coverage.json',report)
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--root',type=Path,default=ROOT)
    sub=p.add_subparsers(dest='command',required=True)
    m=sub.add_parser('manifest');m.add_argument('--output',type=Path,required=True)
    s=sub.add_parser('summarize');s.add_argument('--evidence',type=Path,required=True);s.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    if a.command=='manifest':
        value=manifest(a.root);write(a.output,value);print(value['sourceFingerprint'])
    else:
        value=summarize(a.root,a.evidence,a.output);print(json.dumps({k:value[k] for k in ['scenarios','attemptedActions','classifications','candidateFindings']}))
if __name__=='__main__': main()
