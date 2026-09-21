"""Map the upstream sculpted mouth-open delta to the retained Pass A vertices.

Reconstructs correspondence only; never replaces candidate geometry or rig.
"""
import gzip
import json
import sys
import subprocess
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

folder=Path(__file__).resolve().parents[1]
upstream=Path('/tmp/solo-founder-mpfb')
assert subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()=='437dd513888a92399d1d3200d2e80859fae55abc'
sys.path.insert(0,str(upstream/'src'))
bpy.utils.extension_path_user=lambda *a,**k:'/tmp/solo-founder-mpfb-user'
import addon_utils
addon_utils.enable('mpfb',default_set=True)
from mpfb.services.humanservice import HumanService
from mpfb.services.targetservice import TargetService
bpy.ops.wm.open_mainfile(filepath=str(folder/'Evidence/A1/Before/founder_candidate_a.blend'))
original=[v.co.copy() for name in ['HeadMesh','BodyMesh'] for v in bpy.data.objects[name].data.vertices]
macro=TargetService.get_default_macro_info_dict()
macro.update(gender=0.8,age=0.35,muscle=0.52,weight=0.48)
human=HumanService.create_human(macro_detail_dict=macro)
bpy.context.view_layer.objects.active=human
bpy.ops.object.shape_key_remove(all=True,apply_mix=True)
points=[v.co.copy() for v in human.data.vertices[:13380]]
minimum=min(p.z for p in points)
factor=1.79/(max(p.z for p in points)-minimum)
tree=KDTree(len(points))
for index,p in enumerate(points):
    tree.insert(Vector((p.x*factor,p.y*factor,(p.z-minimum)*factor)),index)
tree.balance()
deltas={}
for ethnicity in ['african','asian','caucasian']:
    path=upstream/f'src/mpfb/data/targets/expression/units/{ethnicity}/mouth-open.target.gz'
    for line in gzip.open(path,'rt'):
        if not line.strip() or line.startswith('#'):continue
        index,x,y,z=line.split()
        # MakeHuman decimeters/Y-up -> MPFB meters/Z-up, then candidate height fit.
        delta=Vector((float(x),-float(z),float(y)))*(0.1*factor/3)
        deltas[int(index)]=deltas.get(int(index),Vector())+delta
result=[]
maximum=0
for point in original:
    co,index,distance=tree.find(point)
    maximum=max(maximum,distance)
    assert distance<1e-5,(point,co,distance)
    if index in deltas:
        result.append({'position':[round(c,6) for c in point],'delta':list(deltas[index])})
out={'source':'MPFB pinned Pass A commit; expression/units/{african,asian,caucasian}/mouth-open.target.gz, equal blend',
     'maximum_correspondence_error_m':maximum,'matched_vertices':len(original),'jaw_open':result}
(folder/'Source/facial_target_a1.json').write_text(json.dumps(out,indent=2))
print('FACIAL_CORRESPONDENCE',len(original),maximum,'delta vertices',len(result))
