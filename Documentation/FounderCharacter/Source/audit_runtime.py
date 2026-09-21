"""Audit the final modular package without rebuilding or modifying the asset."""
import hashlib
import json
from pathlib import Path
from pxr import Usd, UsdGeom, UsdSkel, UsdShade

folder = Path(__file__).resolve().parents[1]
repo = folder.parents[1]
package = folder / 'Intermediate/founder_runtime_a.usdz'
bundled = repo / 'App/RealityKit/FounderCharacter/founder_candidate_a.usdz'
source = Usd.Stage.Open(str(folder / 'Intermediate/founder_candidate_a.usdc'))
stage = Usd.Stage.Open(str(package))
assert source and stage, 'Unable to open source/runtime stages'
assert package.read_bytes() == bundled.read_bytes(), 'Bundled candidate differs from audited package'
assert stage.GetDefaultPrim().GetName() == 'FounderRoot'
assert UsdGeom.GetStageUpAxis(stage) == 'Y'
assert UsdGeom.GetStageMetersPerUnit(stage) == 1
original = next(UsdSkel.Skeleton(p) for p in source.Traverse() if p.IsA(UsdSkel.Skeleton))
skeletons = [UsdSkel.Skeleton(p) for p in stage.Traverse() if p.IsA(UsdSkel.Skeleton)]
assert len(skeletons) == 10, 'Expected ten independently visible skinned modules'
for skeleton in skeletons:
    for getter in ['GetJointsAttr', 'GetBindTransformsAttr', 'GetRestTransformsAttr']:
        assert getattr(skeleton, getter)().Get() == getattr(original, getter)().Get(), (
            f'Canonical skeleton changed: {skeleton.GetPath()} {getter}')
    assert len(skeleton.GetJointsAttr().Get()) == 55

meshes = []
for prim in stage.Traverse():
    if prim.IsA(UsdGeom.Xformable):
        assert UsdGeom.Xformable(prim).ComputeLocalToWorldTransform(Usd.TimeCode.Default()).GetDeterminant() > 0
    for relationship in prim.GetRelationships():
        for target in relationship.GetTargets():
            assert stage.GetObjectAtPath(target), f'Unresolved relationship: {prim.GetPath()} -> {target}'
    if not prim.IsA(UsdGeom.Mesh):
        continue
    mesh = UsdGeom.Mesh(prim)
    module = prim.GetParent().GetParent()
    assert module.IsA(UsdSkel.Root), f'Missing module root: {prim.GetPath()}'
    binding = UsdSkel.BindingAPI(prim)
    assert binding.GetSkeletonRel().GetTargets() == [module.GetPath().AppendChild('Skeleton')]
    count = len(mesh.GetPointsAttr().Get())
    weights = binding.GetJointWeightsPrimvar()
    width = weights.GetElementSize()
    values = list(weights.ComputeFlattened())
    indices = list(binding.GetJointIndicesPrimvar().ComputeFlattened())
    assert 1 <= width <= 4 and len(values) == len(indices) == count * width
    assert all(0 <= index < 55 for index in indices)
    assert all(value >= 0 for value in values)
    assert all(abs(sum(values[i:i+width])-1) < 1e-4 for i in range(0, len(values), width))
    material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
    subsets = UsdGeom.Subset.GetAllGeomSubsets(mesh)
    assert material or (subsets and all(UsdShade.MaterialBindingAPI(s).ComputeBoundMaterial()[0] for s in subsets))
    meshes.append(str(prim.GetPath()))
assert len(meshes) == 10
shapes = [p for p in stage.Traverse() if p.IsA(UsdSkel.BlendShape)]
assert len(shapes) == 9
for name in ['HairSlot', 'TopSlot', 'BottomSlot', 'ShoeSlot', 'AccessorySlot']:
    assert stage.GetPrimAtPath('/FounderRoot/' + name), f'Missing slot: {name}'
result = {
    'status': 'TECHNICAL_RUNTIME_PACKAGE_PASS; visual and performance acceptance separate',
    'sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
    'package_bytes': package.stat().st_size,
    'bundled_package_matches': True,
    'canonical_joint_count': 55,
    'identical_skeleton_copies': len(skeletons),
    'meshes': meshes,
    'facial_targets': len(shapes),
}
(folder / 'Intermediate/runtime_audit.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
