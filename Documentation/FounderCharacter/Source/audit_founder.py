"""Run with Blender --background --python-exit-code 1 --python this_file.

Reads the exported USD independently of the Blender scene. Never promotes an
appearance candidate to production; writes a technical audit and QA-only USDZ.
"""
import hashlib
import json
from pathlib import Path
from pxr import Usd, UsdGeom, UsdSkel, UsdShade, UsdUtils, Gf, Sdf

folder = Path(__file__).resolve().parents[1]
asset = folder/'Intermediate/founder_candidate_a.usdc'
contract = json.loads((folder/'Intermediate/blender_contract.json').read_text())
stage = Usd.Stage.Open(str(asset))
assert stage and stage.GetDefaultPrim().GetName() == 'FounderRoot', 'Missing root'
assert UsdGeom.GetStageUpAxis(stage) == 'Y', 'Incorrect up axis'
assert UsdGeom.GetStageMetersPerUnit(stage) == 1, 'Incorrect units'
root = stage.GetDefaultPrim()
transform = UsdGeom.Xformable(root).ComputeLocalToWorldTransform(Usd.TimeCode.Default())
assert (transform.TransformDir(Gf.Vec3d(1,0,0))-Gf.Vec3d(1,0,0)).GetLength() < 1e-5, 'Mirrored horizontal direction'
assert (transform.TransformDir(Gf.Vec3d(0,-1,0))-Gf.Vec3d(0,0,1)).GetLength() < 1e-5, 'Wrong facing direction'
skeletons = [UsdSkel.Skeleton(p) for p in stage.Traverse() if p.IsA(UsdSkel.Skeleton)]
assert len(skeletons) == 1, 'Expected exactly one skeleton'
skeleton = skeletons[0]
joints = list(skeleton.GetJointsAttr().Get())
names = [str(j).split('/')[-1] for j in joints]
assert set(names) == {b['name'] for b in contract['bones']}, 'Bone contract mismatch'
assert len(names) == len(set(names)) == 55, 'Unexpected joint count'
for b in contract['bones']:
    path = str(joints[names.index(b['name'])]).split('/')
    assert (path[-2] if len(path)>1 else None) == b['parent'], f'Wrong parent: {b}'
for matrices in [skeleton.GetBindTransformsAttr().Get(), skeleton.GetRestTransformsAttr().Get()]:
    assert len(matrices) == len(joints), 'Missing joint matrices'
    assert all(m.GetDeterminant() > 0 for m in matrices), 'Negative/singular bind transform'
meshes = {}
for prim in stage.Traverse():
    if prim.IsA(UsdGeom.Xformable):
        assert UsdGeom.Xformable(prim).ComputeLocalToWorldTransform(Usd.TimeCode.Default()).GetDeterminant() > 0, f'Negative scale: {prim.GetPath()}'
    if not prim.IsA(UsdGeom.Mesh):
        continue
    mesh = UsdGeom.Mesh(prim)
    binding = UsdSkel.BindingAPI(prim)
    assert binding.GetSkeletonRel().GetTargets() == [skeleton.GetPath()], f'Missing skin binding {prim}'
    indices = binding.GetJointIndicesPrimvar()
    weights = binding.GetJointWeightsPrimvar()
    n = weights.GetElementSize()
    values = list(weights.ComputeFlattened())
    ids = list(indices.ComputeFlattened())
    count = len(mesh.GetPointsAttr().Get())
    assert n <= 4 and len(values) == len(ids) == count*n, f'Invalid influences {prim}'
    assert all(0 <= i < len(joints) for i in ids), 'Out-of-range joint index'
    assert all(w >= 0 for w in values), 'Negative weights'
    assert all(abs(sum(values[i:i+n])-1) < 1e-4 for i in range(0,len(values),n)), 'Unnormalized weights'
    material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
    subsets = UsdGeom.Subset.GetAllGeomSubsets(mesh)
    assert material or (subsets and all(UsdShade.MaterialBindingAPI(s).ComputeBoundMaterial()[0] for s in subsets)), f'Missing materials {prim}'
    meshes[str(prim.GetPath())] = {'vertices':count, 'triangles':sum(int(v)-2 for v in mesh.GetFaceVertexCountsAttr().Get()), 'max_influences':n}
shapes = [UsdSkel.BlendShape(p) for p in stage.Traverse() if p.IsA(UsdSkel.BlendShape)]
assert {s.GetPrim().GetName() for s in shapes} == set(contract['blendshapes']), 'Missing facial shapes'
assert all(any(v.GetLength()>1e-6 for v in s.GetOffsetsAttr().Get()) for s in shapes), 'Empty facial delta'
for name in contract['slots']:
    assert stage.GetPrimAtPath('/FounderRoot/'+name), f'Missing {name}'
cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ['default', 'render'])
bounds = Gf.Range3d()
for prim in stage.Traverse():
    if prim.IsA(UsdGeom.Mesh):
        bounds.UnionWith(cache.ComputeWorldBound(prim).ComputeAlignedRange())
height = bounds.GetSize()[1]
assert 1.75 <= height <= 1.83, f'Invalid world height {height}'
textures = set()
for prim in stage.Traverse():
    for attr in prim.GetAttributes():
        value = attr.Get()
        if isinstance(value, Sdf.AssetPath) and value.resolvedPath:
            textures.add(value.resolvedPath)
result = {'status':'TECHNICAL_USD_AUDIT_PASS; appearance and RealityKit acceptance separate',
          'sha256':hashlib.sha256(asset.read_bytes()).hexdigest(), 'joints':names,
          'world_height_m':height, 'world_bounds_min':list(bounds.GetMin()), 'world_bounds_max':list(bounds.GetMax()),
          'conservative_skel_bounds_height_m':cache.ComputeWorldBound(root).ComputeAlignedRange().GetSize()[1],
          'meshes':meshes, 'total_triangles':sum(m['triangles'] for m in meshes.values()),
          'materials':len([p for p in stage.Traverse() if p.IsA(UsdShade.Material)]),
          'facial_targets':len(shapes), 'texture_files':sorted(textures),
          'texture_file_bytes':sum(Path(p).stat().st_size for p in textures),
          'texture_rgba_base_level_estimate_bytes':sum(t['width']*t['height']*4 for t in contract.get('textures', []))}
(folder/'Intermediate/usd_audit.json').write_text(json.dumps(result, indent=2))
package = folder/'Intermediate/founder_candidate_a.usdz'
assert UsdUtils.CreateNewUsdzPackage(str(asset), str(package)), 'Package failed'
print(json.dumps(result, indent=2))
