#!/usr/bin/env python3
"""Agent Laboratory audit and F1 export; production executes only via C1 GameStore XCTest adapter."""
import argparse
from collections import Counter
from pathlib import Path
import c1
MISSIONS = ['agent-assignment','agent-trust','agent-evidence','agent-lifecycle']
BASELINE = '27b8f8de0dcfc230755acaaa1958c9c7853e9eee'

def manifest(root):
    value=c1.manifest(root)
    value['baseline']=BASELINE
    return value

def minimized_targets(trace, category):
    # Persisted fields are distinct contracts; cache failure must not mask Evidence.
    target = category.replace('save_reload_', 'save_reload:', 1) if category.startswith('save_reload_') else category
    return sorted({v for s in trace['steps'] for v in s['violations'] if (v == target if target.startswith('save_reload:') else v.split(':')[0] == target)})

def summarize(root, evidence, output):
    root, evidence, output = root.resolve(), evidence.resolve(), output.resolve()
    source=c1.read(evidence/'source-manifest.json')
    if source != manifest(root): raise ValueError('source diverged from C2 manifest')
    summary=c1.read(evidence/'c2-study-summary.json')
    counts=Counter();actions=Counter();missions=Counter();violations=Counter();classifications=Counter();lifecycle=Counter();bands=Counter()
    accepted_by_agent=Counter();transitions=Counter();replayed=0
    for scenario,digest in sorted(summary['replayFingerprints'].items()):
        path=evidence/(scenario+'.json'); trace=c1.audit(c1.read(path));m=trace['mission']
        if c1.sha(path.read_bytes())!=digest: raise ValueError('replay fingerprint mismatch: '+scenario)
        if m['sourceFingerprint']!=source['sourceFingerprint'] or m['missionVersion']!='2': raise ValueError('mixed source or mission version')
        if m['missionId'] not in MISSIONS or not 19000<=m['seed']<19100: raise ValueError('unexpected scenario')
        if scenario!=f"{m['missionId']}-v2-s{m['seed']}": raise ValueError('scenario identity mismatch')
        missions[m['missionId']]+=1;classifications[trace['classification']]+=1
        expected=trace['initialStateFingerprint']
        for step in trace['steps']:
            if step['beforeFingerprint']!=expected: raise ValueError('broken action fingerprint chain')
            expected=step['afterFingerprint']
            counts[step['result']]+=1;actions[step['input']['action']]+=1;violations.update(step['violations'])
            lifecycle.update(step['agentObservation']['lifecycle']);bands.update(step['agentObservation']['workloadBands'])
            transitions[(step['input']['action'],step['result'])]+=1
            if step['result']=='accepted':accepted_by_agent[step['input'].get('agentID','implicit')]+=1
        if expected!=trace['finalStateFingerprint']:raise ValueError('broken final state fingerprint')
        replayed+=len(trace['steps'])
    if missions!=Counter({k:100 for k in MISSIONS}) or summary['scenarios']!=400: raise ValueError('incomplete mission coverage')
    if summary['attemptedActions']!=sum(counts.values()) or summary['replayedActions']!=replayed: raise ValueError('action counts mismatch')
    precedents=c1.Ledger(root).retrieve('agent assignment evidence persistence simulator isolation source preservation')
    c1.write(output/'precedents.json',precedents)
    findings=[]
    for path in sorted(evidence.glob('agent-*-min-*.json')):
        trace=c1.audit(c1.read(path))
        if trace['mission']['sourceFingerprint']!=source['sourceFingerprint']: raise ValueError('minimized trace source mismatch')
        invariant=path.stem.split('-min-',1)[1]
        matched=minimized_targets(trace,invariant)
        if not matched:raise ValueError('minimized target absent')
        for target in matched:
            finding=c1.candidate(trace,target,str(path.relative_to(root)),root)
            c1.write(root/'FailureLedger/candidates'/(finding['id']+'.json'),finding)
            findings.append({'id':finding['id'],'invariant':target,'actions':len(trace['steps']),'reproduction':str(path.relative_to(root)),'precedents':['FL-015']})
    controlled=evidence/'c2-controlled-minimized.json';trace=c1.audit(c1.read(controlled))
    if trace['mission']['sourceFingerprint']!=source['sourceFingerprint']: raise ValueError('controlled trace source mismatch')
    invariant=next(v for s in trace['steps'] for v in s['violations'] if v.startswith('synthetic_'))
    example=c1.candidate(trace,invariant,str(controlled.relative_to(root)),root,True)
    c1.write(output/'controlled-candidate-example.json',example)
    report={'authority':'observation_only','sourceFingerprint':source['sourceFingerprint'],'baseline':BASELINE,'scenarios':dict(missions),'attemptedActions':sum(counts.values()),'replayedActions':replayed,'actionResults':dict(counts),'actionCoverage':dict(actions),'classifications':dict(classifications),'violationOccurrences':dict(violations),'candidateFindings':findings,'lifecycleObservations':dict(lifecycle),'workloadBandObservations':dict(bands),'acceptedAgentParameters':dict(accepted_by_agent),'elapsedSeconds':summary['elapsedSeconds'],'replayMismatches':0,'memoryMeasurement':None,'limitations':['Authored starting roster only; no forced private quality/capability fixtures. Poor outcomes are observed, not assigned balance expectations.','Coordination uses existing task/launch prerequisites and Evidence; direct agent messaging is unimplemented.','Gameplay task state is observed; animation state is outside scope.','Career reset isolation exercised; natural venture completion coverage is conditional.','Four sprint commitment attempts and 80 actions per scenario; 2400 second study ceiling.','Public allowlist and gameplay reveal flags checked; no rendered UI disclosure audit.','Minimization at most 256 trials per representative category, exact task/agent diagnostic identity preserved.','Metrics and persistence are hashed; reports contain no raw hidden values.']}
    c1.write(output/'coverage.json',report)
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=c1.ROOT)
    sub=p.add_subparsers(dest='command',required=True)
    m=sub.add_parser('manifest');m.add_argument('--output',type=Path,required=True)
    s=sub.add_parser('summarize');s.add_argument('--evidence',type=Path,required=True);s.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    if a.command=='manifest':v=manifest(a.root);c1.write(a.output,v);print(v['sourceFingerprint'])
    else:v=summarize(a.root,a.evidence,a.output);print({k:v[k] for k in ['scenarios','attemptedActions','actionResults','candidateFindings']})
if __name__=='__main__':main()
