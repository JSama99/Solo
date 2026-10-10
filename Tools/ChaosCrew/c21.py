#!/usr/bin/env python3
"""C2.1 read-only study comparison. Original C2 candidates and traces are never overwritten."""
import argparse,json
from collections import Counter
from pathlib import Path
import c1,c2

def audit(root,evidence,output):
 root,evidence,output=root.resolve(),evidence.resolve(),output.resolve()
 source=c1.read(evidence/'source-manifest.json')
 if source!=c2.manifest(root):raise ValueError('final study source mismatch')
 summary=c1.read(evidence/'c2-study-summary.json');count=Counter();actions=Counter();classes=Counter();diag=Counter();rows=[];scenarios=Counter();fingerprints={}
 for name,digest in sorted(summary['replayFingerprints'].items()):
  p=evidence/(name+'.json');t=c1.audit(c1.read(p));m=t['mission']
  if c1.sha(p.read_bytes())!=digest or m['sourceFingerprint']!=source['sourceFingerprint']:raise ValueError('trace integrity/source mismatch')
  scenarios[m['missionId']]+=1;classes[t['classification']]+=1;fingerprints[name]=digest
  expected=t['initialStateFingerprint']
  for s in t['steps']:
   if s['beforeFingerprint']!=expected:raise ValueError('broken state chain')
   expected=s['afterFingerprint'];count[s['result']]+=1;actions[s['input']['action']]+=1
   for v in s['violations']:diag[v if v.startswith('save_reload:') else v.split(':')[0]]+=1
  if expected!=t['finalStateFingerprint']:raise ValueError('broken final fingerprint')
  rows.append(t)
 if scenarios!=Counter({m:100 for m in c2.MISSIONS}) or summary['scenarios']!=400:raise ValueError('incomplete C2 rerun')
 if sum(count.values())!=summary['attemptedActions'] or summary['attemptedActions']!=summary['replayedActions']:raise ValueError('action count mismatch')
 original=root/'Documentation/ChaosCrew/C2/FinalEvidence';before_diag=Counter();before_class=Counter()
 for name in summary['replayFingerprints']:
  t=c1.audit(c1.read(original/(name+'.json')));before_class[t['classification']]+=1
  for s in t['steps']:
   for v in s['violations']:before_diag[v if v.startswith('save_reload:') else v.split(':')[0]]+=1
 report={'authority':'engineering_review_pending_owner_acceptance','sourceFingerprint':source['sourceFingerprint'],'originalC2SourceFingerprint':'2794faf488926ac52af08a87b31a949e09d60cdbd7f2ba6d79246d02f660bc04','scenarios':dict(scenarios),'attemptedActions':sum(count.values()),'replayedActions':summary['replayedActions'],'actionResults':dict(count),'actionCoverage':dict(actions),'beforeClassifications':dict(before_class),'afterClassifications':dict(classes),'beforeDiagnosticOccurrences':dict(before_diag),'afterDiagnosticOccurrences':dict(diag),'residualViolations':sum(diag.values()),'elapsedSeconds':summary['elapsedSeconds'],'replayMismatches':0,'promotion':False,'memoryMeasurement':None}
 c1.write(output/'Comparison.json',report)
 return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=c1.ROOT);p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=audit(a.root,a.evidence,a.output);print({k:r[k] for k in ['sourceFingerprint','scenarios','beforeDiagnosticOccurrences','afterDiagnosticOccurrences','beforeClassifications','afterClassifications']})
if __name__=='__main__':main()
