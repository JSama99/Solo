"""Read-only diagnosis of Pass A before authoring repairs."""
import json
from pathlib import Path
import bpy
from mathutils import Vector
from pxr import Usd, UsdGeom

folder = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(folder/'Source/founder_candidate_a.blend'))
body, head = bpy.data.objects['BodyMesh'], bpy.data.objects['HeadMesh']
key = lambda co: tuple(round(x, 6) for x in co)
shared = {key(v.co): v for v in body.data.vertices}
pairs = [(shared[key(v.co)], v) for v in head.data.vertices if key(v.co) in shared]
angles = [a.normal.angle(b.normal) for a,b in pairs]
rig = bpy.data.objects['Armature']
data = {
 'seam_shared_positions': len(pairs),
 'seam_height_range': [min(a.co.z for a,b in pairs),max(a.co.z for a,b in pairs)],
 'seam_max_normal_angle_degrees': max(angles)*180/3.141592653589793,
 'same_skin_material': body.data.materials[0] == head.data.materials[0],
 'body_custom_normals': body.data.has_custom_normals,
 'head_custom_normals': head.data.has_custom_normals,
 'head_uv_layers': len(head.data.uv_layers),
 'bones': {b.name:{'head':list(b.head_local), 'tail':list(b.tail_local),
                      'basis': [list(v) for v in b.matrix_local.to_3x3().transposed()]}
           for b in rig.data.bones if b.name in ['Hips','Head','Neck','Thigh_L','Thigh_R','Calf_L','Calf_R','Foot_L','Foot_R','Eye_L','Eye_R','UpperArm_L','UpperArm_R','LowerArm_L','LowerArm_R','Hand_L','Hand_R']},
 'meshes': {o.name:{'vertices':len(o.data.vertices),'polygons':len(o.data.polygons),
                  'materials':[m.name for m in o.data.materials],
                  'modifiers':[m.type for m in o.modifiers],
                  'flat_faces':sum(not p.use_smooth for p in o.data.polygons)}
            for o in bpy.data.objects if o.type=='MESH'}
}
stage = Usd.Stage.Open(str(folder.parents[1]/'App/RealityKit/FounderGarage/founder_garage_v8.usdz'))
cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ['default','render'])
data['garage'] = {}
for prim in stage.Traverse():
    name = prim.GetName().lower()
    if prim.IsA(UsdGeom.Xform) and any(term in name for term in ['chair','desk','monitor']):
        bounds = cache.ComputeWorldBound(prim).ComputeAlignedRange()
        data['garage'][str(prim.GetPath())]={'min':list(bounds.GetMin()),'max':list(bounds.GetMax())}
(folder/'Evidence/A1').mkdir(exist_ok=True)
(folder/'Evidence/A1/root_cause.json').write_text(json.dumps(data,indent=2))
print(json.dumps(data,indent=2))
