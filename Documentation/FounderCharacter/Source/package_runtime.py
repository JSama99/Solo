"""Preserve independently visible skinned modules in RealityKit's importer."""
from pathlib import Path
from pxr import Usd, UsdGeom, UsdSkel, Sdf, UsdUtils

folder = Path(__file__).resolve().parents[1]
source = folder / 'Intermediate/founder_candidate_a.usdc'
destination = folder / 'Intermediate/founder_runtime_a.usdc'
stage = Usd.Stage.Open(str(source))
layer = stage.GetRootLayer()
armature = stage.GetPrimAtPath('/FounderRoot/Armature')
skeleton_path = Sdf.Path('/FounderRoot/Armature/Armature')
modules = [child for child in armature.GetChildren() if child.IsA(UsdGeom.Xform)]
for module in modules:
    old_path = module.GetPath()
    new_root = Sdf.Path('/FounderRoot/' + module.GetName() + 'Module')
    UsdSkel.Root.Define(stage, new_root)
    new_skeleton = new_root.AppendChild('Skeleton')
    Sdf.CopySpec(layer, skeleton_path, layer, new_skeleton)
    new_path = new_root.AppendChild(module.GetName())
    Sdf.CopySpec(layer, old_path, layer, new_path)
    for prim in Usd.PrimRange(stage.GetPrimAtPath(new_root)):
        for relationship in prim.GetRelationships():
            targets = relationship.GetTargets()
            mapped = [target.ReplacePrefix(old_path, new_path).ReplacePrefix(skeleton_path, new_skeleton) for target in targets]
            if mapped != targets:
                relationship.SetTargets(mapped)
    stage.RemovePrim(old_path)
stage.RemovePrim('/FounderRoot/Armature')
stage.GetRootLayer().Export(str(destination))
assert UsdUtils.CreateNewUsdzPackage(str(destination), str(folder / 'Intermediate/founder_runtime_a.usdz'))
print('Packaged', len(modules), 'independent skinned modules sharing the canonical 55-joint contract')
