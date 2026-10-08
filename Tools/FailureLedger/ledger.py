"""Offline developer precedents. Never simulation state or Canon authority."""
import datetime
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class LedgerError(ValueError):
    pass

def canonical_bytes(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + '\n').encode()

def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError, UnicodeError) as exc:
        raise LedgerError(f'{path}: unavailable or corrupt JSON: {exc}') from exc

def check_schema(value, schema, where='$'):
    """Small stdlib validator for the explicit subset used by the checked-in schemas."""
    if not isinstance(schema,dict): raise LedgerError(f'{where}: schema must be an object')
    allowed={'type','required','properties','additionalProperties','items','enum','pattern',
             'minItems','minLength','format','minimum','$schema','title','description'}
    if set(schema)-allowed:
        raise LedgerError(f'{where}: unsupported schema keywords {sorted(set(schema)-allowed)}')
    types={'object':lambda x:isinstance(x,dict),'array':lambda x:isinstance(x,list),
           'string':lambda x:isinstance(x,str),'integer':lambda x:isinstance(x,int) and not isinstance(x,bool),
           'null':lambda x:x is None,'boolean':lambda x:isinstance(x,bool)}
    wanted=schema.get('type',[]); wanted=[wanted] if isinstance(wanted,str) else wanted
    if wanted and not any(types.get(t,lambda _:False)(value) for t in wanted):
        raise LedgerError(f'{where}: expected {wanted}')
    if 'enum' in schema and value not in schema['enum']:
        raise LedgerError(f'{where}: invalid value {value!r}')
    if isinstance(value,dict):
        missing=set(schema.get('required',[]))-value.keys()
        if missing: raise LedgerError(f'{where}: missing {sorted(missing)}')
        props=schema.get('properties',{})
        if schema.get('additionalProperties') is False and set(value)-props.keys():
            raise LedgerError(f'{where}: unknown fields {sorted(set(value)-props.keys())}')
        for key in sorted(value):
            if key in props: check_schema(value[key],props[key],where+'.'+key)
    if isinstance(value,list):
        if len(value)<schema.get('minItems',0): raise LedgerError(f'{where}: insufficient entries')
        for i,item in enumerate(value): check_schema(item,schema.get('items',{}),f'{where}[{i}]')
    if isinstance(value,str):
        if len(value.strip())<schema.get('minLength',0): raise LedgerError(f'{where}: empty text')
        if 'pattern' in schema and not re.fullmatch(schema['pattern'],value):
            raise LedgerError(f'{where}: invalid pattern')
        if schema.get('format')=='date':
            try: datetime.date.fromisoformat(value)
            except ValueError as exc: raise LedgerError(f'{where}: invalid date') from exc
    if isinstance(value,int) and not isinstance(value,bool) and value<schema.get('minimum',value):
        raise LedgerError(f'{where}: below minimum')

def safe_path(root, name):
    if not isinstance(name,str) or not name or '\\' in name:
        raise LedgerError('invalid evidence path')
    path=Path(name)
    if path.is_absolute() or '..' in path.parts or not (root/path).resolve().is_relative_to(root.resolve()):
        raise LedgerError(f'unsafe evidence path: {name}')
    return root/path

def unique(values, label):
    found={}
    for item in values:
        if item['id'] in found: raise LedgerError(f'duplicate {label} ID: {item["id"]}')
        found[item['id']]=item
    return found

def validate_candidate(candidate, root=ROOT):
    check_schema(candidate,read_json(root/'FailureLedger/schemas/candidate.schema.json'))
    for ref in candidate['evidenceReferences']:
        p=safe_path(Path(root),ref['path'])
        try: data=p.read_bytes()
        except OSError as exc: raise LedgerError('candidate evidence unavailable: '+ref['path']) from exc
        if hashlib.sha256(data).hexdigest()!=ref['sha256']:
            raise LedgerError('candidate evidence fingerprint mismatch: '+ref['path'])
    return candidate

class Ledger:
    def __init__(self, root=ROOT):
        self.root=Path(root)
        base=self.root/'FailureLedger'
        self.evidence=read_json(base/'evidence.json')
        evidence_schema=read_json(base/'schemas/evidence.schema.json')
        check_schema(self.evidence,evidence_schema)
        refs=unique(self.evidence,'Evidence')
        for e in self.evidence:
            p=safe_path(self.root,e['path'])
            try: data=p.read_bytes()
            except OSError as exc: raise LedgerError(f'missing evidence: {e["path"]}') from exc
            if hashlib.sha256(data).hexdigest()!=e['sha256']:
                raise LedgerError(f'evidence fingerprint mismatch: {e["id"]} ({e["path"]})')
        schema=read_json(base/'schemas/failure.schema.json')
        paths=sorted((base/'records').glob('*.json'))
        if not paths: raise LedgerError('missing Failure Ledger records')
        self.records=[read_json(p) for p in paths]
        for record in self.records: check_schema(record,schema)
        records=unique(self.records,'Failure')
        self.rules=read_json(base/'registry/rules.json')
        rules_schema=read_json(base/'schemas/rule.schema.json')
        check_schema(self.rules,{'type':'array','items':rules_schema})
        rules=unique(self.rules,'Rule')
        canon={read_json(p)['id'] for p in (self.root/'Canon/records').rglob('*.json')}
        def evidence(ids, where):
            if not ids or set(ids)-refs.keys(): raise LedgerError(f'{where}: missing mandatory evidence reference')
        for r in self.records:
            evidence(r['evidenceReferences'],r['id'])
            if set(r['relatedFailureIds'])-records.keys(): raise LedgerError(r['id']+': unknown related failure')
            if set(r['relatedCanonRecords'])-canon: raise LedgerError(r['id']+': unknown Canon record')
            if set(r['preventionRules'])-rules.keys(): raise LedgerError(r['id']+': unknown prevention rule')
            if r['rootCause'] is None and r['rootCauseConfidence']!='UNKNOWN':
                raise LedgerError(r['id']+': unknown cause must have UNKNOWN confidence')
            if r['status']=='RESOLVED' and r['successfulCorrection'] is None:
                raise LedgerError(r['id']+': resolved failure needs a correction')
            if r['status']=='CANDIDATE' and r['rootCauseConfidence']=='ESTABLISHED':
                raise LedgerError(r['id']+': candidate cannot establish a cause')
            for fix in r['failedApproaches']: evidence(fix['evidenceReferences'],r['id']+' failed fix')
            for lesson in r['lessons']: evidence(lesson['evidenceReferences'],r['id']+' lesson')
            for test in r['relatedTests']:
                safe_path(self.root,test.split('::')[0])
                if not (self.root/test.split('::')[0]).is_file(): raise LedgerError(r['id']+': missing related test')
        for rule in self.rules:
            evidence(rule['evidenceReferences'],rule['id'])
            if not rule['supportingFailureIds'] or set(rule['supportingFailureIds'])-records.keys():
                raise LedgerError(rule['id']+': unknown supporting failure')
            for fid in rule['supportingFailureIds']:
                if rule['id'] not in records[fid]['preventionRules']: raise LedgerError(rule['id']+': missing reciprocal incident link')
                if rule['acceptance']=='ACCEPTED' and records[fid]['status'] in {'CANDIDATE','REPRODUCED'}:
                    raise LedgerError(rule['id']+': candidate or unconfirmed finding cannot support accepted rules')
            if rule['acceptance']=='ACCEPTED' and not rule['review']:
                raise LedgerError(rule['id']+': acceptance requires explicit review')
        candidate_schema=read_json(base/'schemas/candidate.schema.json')
        if not isinstance(candidate_schema,dict) or candidate_schema.get('type')!='object':
            raise LedgerError('invalid candidate schema')
        candidates=base/'candidates'
        if not candidates.is_dir(): raise LedgerError('missing candidate directory')
        findings=[validate_candidate(read_json(p),self.root) for p in sorted(candidates.glob('*.json'))]
        unique(findings,'Candidate')
        self.records.sort(key=lambda r:r['id']); self.rules.sort(key=lambda r:r['id'])
        source_paths=[*paths,base/'evidence.json',base/'registry/rules.json',*sorted((base/'schemas').glob('*.json'))]
        self.fingerprint=hashlib.sha256(canonical_bytes({str(p.relative_to(self.root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_paths})).hexdigest()

    def retrieve(self, task):
        terms=set(re.findall(r'[a-z0-9]+',task.lower()))
        if not terms: raise LedgerError('task needs searchable terms')
        scored=[]
        for r in self.records:
            tag_terms=set(re.findall(r'[a-z0-9]+',' '.join(r['system']).lower()))
            title_terms=set(re.findall(r'[a-z0-9]+',r['title'].lower()))
            overlap=terms & (tag_terms|title_terms)
            if overlap: scored.append((len(terms&tag_terms)*3+len(terms&title_terms),r))
        records=[r for _,r in sorted(scored,key=lambda x:(-x[0],x[1]['id']))]
        ids={r['id'] for r in records}
        rules=[r for r in self.rules if r['acceptance']=='ACCEPTED' and ids.intersection(r['supportingFailureIds'])]
        return {'visibility':'developer_only','authority':'historical_precedents_not_canon',
                'ledger_sha256':self.fingerprint,'incidents':[r for r in records if r['status'] not in {'CANDIDATE','REPRODUCED'}],
                'candidate_lessons':[r for r in records if r['status'] in {'CANDIDATE','REPRODUCED'}],
                'accepted_rules':rules,'pending_rules':[r for r in self.rules if r['acceptance']!='ACCEPTED' and ids.intersection(r['supportingFailureIds'])],
                'required_gates':sorted({r['futureVerificationGate'] for r in rules}),
                'failed_fixes':[dict(failureId=r['id'],**fix) for r in records for fix in r['failedApproaches']],
                'unresolved_warnings':[r for r in records if r['status'] in {'DESIGN_DECISION_REQUIRED','CONFIRMED'}]}

    def registry_bytes(self):
        lines=['# SOLO DO NOT DO Registry','', 'Developer prevention rules. Canon and production remain authoritative. Exceptions require evidence and review; these rules cannot override Canon.','']
        for r in self.rules:
            if r['acceptance']!='ACCEPTED': continue
            lines += [f'## {r["id"]} — {r["shortProhibition"]}','', 'Applies to: '+', '.join(r['applicability']),
                      'Supporting failures: '+', '.join(r['supportingFailureIds']),
                      'Exception evidence: '+r['requiredExceptionEvidence'],'Future gate: '+r['futureVerificationGate'],
                      'Evidence: '+', '.join(r['evidenceReferences']),'Review: '+r['review'],'']
        return ('\n'.join(lines).rstrip()+'\n').encode()

    def failed_fixes_bytes(self):
        lines=['# Failed Fixes Registry','', 'Historical outcomes; reconsider only under the listed conditions. Missing experiments are not invented.','']
        for r in self.records:
            for fix in r['failedApproaches']:
                lines += [f'## {r["id"]} — {fix["approach"]}','', 'Reason attempted: '+fix['reasonAttempted'],
                          'Observed outcome: '+fix['observedOutcome'],'Why rejected: '+fix['whyRejected'],
                          'Reconsideration: '+fix['conditionsPermittingReconsideration'],
                          'Evidence: '+', '.join(fix['evidenceReferences']),'']
        return ('\n'.join(lines).rstrip()+'\n').encode()
