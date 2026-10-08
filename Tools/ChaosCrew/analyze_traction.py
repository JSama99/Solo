#!/usr/bin/env python3
"""Analyze production XCTest CSV evidence; never implements traction formulas."""
import argparse, collections, csv, hashlib, json, statistics
from pathlib import Path

def quantiles(values):
    values = sorted(values)
    def percentile(p):
        index = (len(values) - 1) * p
        lower = int(index)
        return values[lower] + (values[min(lower + 1, len(values) - 1)] - values[lower]) * (index - lower)
    return {f'p{int(p*100)}': percentile(p) for p in [.1, .25, .5, .75, .9, .99]}

def summarize(trajectories):
    finals = [rows[-1] for rows in trajectories]
    periods = [row for rows in trajectories for row in rows]
    at_risk = sum(r['before'] for r in periods)
    def first(rows, fit):
        return next((r['cycle'] for r in rows if r['fit'] in fit), None)
    strong = [first(r, {'Strong', 'Breakout'}) for r in trajectories]
    breakout = [first(r, {'Breakout'}) for r in trajectories]
    return dict(n=len(finals), customers=quantiles([r['customers'] for r in finals]),
        median_paying=statistics.median(r['paying'] for r in finals),
        median_final_revenue=statistics.median(r['revenue'] for r in finals),
        cumulative_revenue=quantiles([sum(r['revenue'] for r in rows) for rows in trajectories]),
        cumulative_focus_cost=quantiles([sum(r['cost'] for r in rows) for rows in trajectories]),
        cash=quantiles([r['cash'] for r in finals]),
        weighted_churn_rate=sum(r['churned'] for r in periods)/at_risk if at_risk else None,
        median_growth_from_first_cycle=statistics.median((rows[-1]['customers']-rows[0]['customers'])/max(1, rows[0]['customers']) for rows in trajectories),
        survival_rate=None, catastrophic_company_failure_rate=None,
        company_lifecycle='not simulated; cash exhaustion is not bankruptcy',
        cash_exhaustion_frequency=sum(any(r['cash']==0 for r in rows) for rows in trajectories)/len(finals),
        final_fit=dict(collections.Counter(r['fit'] for r in finals)),
        ever_declining=sum(any(r['fit']=='Declining' for r in rows) for rows in trajectories)/len(finals),
        strong_reach_rate=sum(x is not None for x in strong)/len(finals),
        median_cycles_to_strong=statistics.median(x for x in strong if x is not None) if any(x is not None for x in strong) else None,
        breakout_reach_rate=sum(x is not None for x in breakout)/len(finals),
        median_cycles_to_breakout=statistics.median(x for x in breakout if x is not None) if any(x is not None for x in breakout) else None,
        fit_ABA_count=sum(sum(rows[i]['fit']==rows[i-2]['fit'] and rows[i]['fit']!=rows[i-1]['fit'] for i in range(2,len(rows))) for rows in trajectories),
        focus_selection=dict(collections.Counter(r['focus'] for r in periods)),
        acquisition_to_churn=sum(r['activated'] for r in periods)/max(1,sum(r['churned'] for r in periods)),
        revenue_per_customer=sum(r['revenue'] for r in periods)/max(1,sum(r['customers'] for r in periods)))

def analyze(path, destination):
    numeric = 'seed cycle day before acquired activated churned retained customers paying revenue cost cash retention researchSupport productSupport acquisitionSupport retentionSupport qualityDiagnostic alignmentDiagnostic valueDiagnostic unitRevenueDiagnostic'.split()
    trajectories = collections.defaultdict(list)
    with path.open() as source:
        for row in csv.DictReader(source):
            for key in numeric: row[key] = int(row[key])
            key = tuple(row[k] for k in ['strategy','seed','product','scenario','capability','operations'])
            trajectories[key].append(row)
    assert trajectories
    assert all([r['cycle'] for r in rows]==list(range(1,13)) for rows in trajectories.values())
    groups = collections.defaultdict(list)
    strata = collections.defaultdict(list)
    for key, rows in trajectories.items():
        strategy, seed, product, scenario, capability, operations = key
        groups[strategy].append(rows)
        for dimension, value in [('product',product),('scenario',scenario),('capability',capability),('operations',operations)]:
            strata[f'{strategy}|{dimension}|{value}'].append(rows)
    paired = {}
    for a in groups:
        for b in groups:
            if a==b: continue
            wins = collections.Counter()
            for key, rows in trajectories.items():
                if key[0]!=a: continue
                other = trajectories[(b,)+key[1:]]
                wins['customers'] += rows[-1]['customers'] > other[-1]['customers']
                wins['revenue'] += sum(r['revenue'] for r in rows)>sum(r['revenue'] for r in other)
                wins['cash'] += rows[-1]['cash']>other[-1]['cash']
                wins['strongFit'] += (any(r['fit'] in ['Strong','Breakout'] for r in rows) and not any(r['fit'] in ['Strong','Breakout'] for r in other))
                wins['customer_revenue_cash_pareto'] += (rows[-1]['customers']>=other[-1]['customers'] and sum(r['revenue'] for r in rows)>=sum(r['revenue'] for r in other) and rows[-1]['cash']>=other[-1]['cash'] and (rows[-1]['customers']>other[-1]['customers'] or sum(r['revenue'] for r in rows)>sum(r['revenue'] for r in other) or rows[-1]['cash']>other[-1]['cash']))
            paired[f'{a}>{b}'] = {k: v/len(groups[a]) for k,v in wins.items()}
    repeat = {}
    for strategy, rows_list in groups.items():
        repeat[strategy] = {str(cycle): {'median_customers': statistics.median(rows[cycle-1]['customers'] for rows in rows_list), 'median_revenue': statistics.median(rows[cycle-1]['revenue'] for rows in rows_list), 'median_retention': statistics.median(rows[cycle-1]['retention'] for rows in rows_list)} for cycle in range(1,13)}
    variance = {}
    for key, rows in trajectories.items():
        bucket = '|'.join(str(x) for x in (key[0],)+key[2:])
        variance.setdefault(bucket, []).append(rows[-1]['customers'])
    outliers = sorted([dict(strategy=k[0], seed=k[1], product=k[2], scenario=k[3], capability=k[4], operations=k[5], customers=v[-1]['customers']) for k,v in trajectories.items()], key=lambda r:r['customers'], reverse=True)[:20]
    report = dict(schema_version=1, raw_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), trajectories=len(trajectories), periods=sum(map(len,trajectories.values())), strategies={k:summarize(v) for k,v in groups.items()}, strata={k:summarize(v) for k,v in strata.items()}, paired_comparisons=paired, repeated_focus_progression=repeat, seed_variation={k:quantiles(v) for k,v in variance.items()}, extreme_growth_outliers=outliers)
    destination.write_text(json.dumps(report, indent=2, sort_keys=True)+'\n')
    return report

def analyze_career(path, destination):
    trajectories = collections.defaultdict(list)
    with path.open() as source:
        for row in csv.DictReader(source):
            for key in ['seed','cycle','customers','paying','revenue','cost','cash','runway']: row[key]=int(row[key])
            trajectories[tuple(row[k] for k in ['strategy','seed','product','scenario','doctrine'])].append(row)
    assert len(trajectories)==288
    groups = collections.defaultdict(list)
    for key, rows in trajectories.items():
        groups[key[0]].append(rows)
        groups[key[0]+'|doctrine|'+key[-1]].append(rows)
    stats = {}
    for group, rows in groups.items():
        finals = [r[-1] for r in rows]
        stats[group] = dict(n=len(rows),
            active_rate=sum(r['alive']=='true' for r in finals)/len(finals),
            survival_rate=sum(r['outcome'] not in ['bankruptcy','burnout'] for r in finals)/len(finals),
            catastrophic_failure_rate=sum(r['outcome'] in ['bankruptcy','burnout'] for r in finals)/len(finals),
            outcomes=dict(collections.Counter(r['outcome'] for r in finals)),
            customers=quantiles([r['customers'] for r in finals]),
            cash=quantiles([r['cash'] for r in finals]), runway=quantiles([r['runway'] for r in finals]),
            median_cycles_observed=statistics.median(r['cycle'] for r in finals),
            median_paying=statistics.median(r['paying'] for r in finals),
            median_last_cycle_revenue=statistics.median(r['revenue'] for r in finals),
            cumulative_customer_revenue=quantiles([sum(r['revenue'] for r in trajectory) for trajectory in rows]),
            cumulative_focus_cost=quantiles([sum(r['cost'] for r in trajectory) for trajectory in rows]),
            final_fit=dict(collections.Counter(r['fit'] for r in finals)))
    report = dict(n=len(trajectories), periods=sum(map(len,trajectories.values())), raw_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), survival_definition='active or completed without bankruptcy/burnout; victory is successful completion', groups=stats)
    destination.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    return report

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('csv',type=Path); parser.add_argument('output',type=Path); parser.add_argument('--career',action='store_true')
    args=parser.parse_args()
    if args.career:
        result=analyze_career(args.csv,args.output); print(json.dumps(result['groups'],indent=2)); raise SystemExit(0)
    result=analyze(args.csv,args.output)
    print(json.dumps({k:{m:v[m] for m in ['n','customers','median_paying','median_final_revenue','weighted_churn_rate','strong_reach_rate','ever_declining','cash_exhaustion_frequency']} for k,v in result['strategies'].items()}, indent=2))
