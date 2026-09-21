"""Collect identified QA runs; fails rather than accepting stale device metrics."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--device',required=True)
parser.add_argument('--name',required=True)
parser.add_argument('--physical',action='store_true')
parser.add_argument('--cases',default='Seated,Standing,Face,POV,HeadHidden,HeadLeft,HeadRight,HeadDown,HeadUp')
parser.add_argument('--output',default='Evidence/A1')
args=parser.parse_args()
folder=Path(__file__).resolve().parents[1]/args.output
folder.mkdir(parents=True,exist_ok=True)
bundle='com.talonsight.solounicornrun'
options={'Seated':['--founder-character-seated'],'Standing':[],
         'Face':['--founder-character-close-up'],'POV':['--founder-character-pov'],
         'HeadHidden':['--founder-character-head-hidden'],
         'Blink':['--founder-character-blink'],
         'JawOpen':['--founder-character-jaw-open'],
         'Profile':['--founder-character-close-up','--founder-character-head-profile'],
         **{name:['--founder-character-close-up','--founder-character-head-'+name[4:].lower()] for name in ['HeadLeft','HeadRight','HeadDown','HeadUp']}}
def run(command):
    return subprocess.run(command,check=True,capture_output=True,text=True).stdout.strip()

for case in args.cases.split(','):
    token='--founder-character-run='+str(uuid.uuid4())
    launch=['--founder-character-qa',token]+options[case]
    if args.physical:
        run(['xcrun','devicectl','device','process','launch','--terminate-existing','--device',args.device,bundle]+launch)
    else:
        run(['xcrun','simctl','launch','--terminate-running-process',args.device,bundle]+launch)
        container=Path(run(['xcrun','simctl','get_app_container',args.device,bundle,'data']))/'Documents'
    def fetch(name,destination):
        if args.physical:
            run(['xcrun','devicectl','device','copy','from','--device',args.device,'--domain-type','appDataContainer',
                 '--domain-identifier',bundle,'--source','Documents/'+name,'--destination',str(destination)])
        else:
            shutil.copy2(container/name,destination)
    metrics=folder/f'{args.name}_{case}_metrics.json'
    deadline=time.monotonic()+90
    while time.monotonic()<deadline:
        try:
            fetch('founder-character-qa.json',metrics)
            if json.loads(metrics.read_text()).get('run_id')==token:
                break
        except (OSError,subprocess.CalledProcessError,json.JSONDecodeError):
            pass
        time.sleep(2)
    else:
        raise RuntimeError(f'{args.name} {case}: no matching completed capture after 90s')
    fetch('founder-character-first-capture.png',folder/f'{args.name}_{case}.png')
    if case=='Seated':
        fetch('founder-character-baseline.png',folder/f'{args.name}_GarageBaseline.png')
    print(args.name,case,'captured',flush=True)
