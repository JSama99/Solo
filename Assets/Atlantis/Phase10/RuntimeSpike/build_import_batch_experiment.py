"""Build a Founder-only static batching experiment from the validated Phase 10 USDC.

The authoritative Phase 9 Blender file and Phase 10 district package are read-only.
Geometry is baked to world space and grouped by bound material so RealityKit imports
far fewer Mesh entities. This is diagnostic output, not a production asset decision.
"""
import hashlib
import json
from pathlib import Path

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "App/RealityKit/Atlantis/founder_district.usdc"
OUTPUT = ROOT / "App/RealityKit/Atlantis/founder_district_batched.usdc"
PACKAGE = ROOT / "App/RealityKit/Atlantis/founder_district_batched.usdz"
MANIFEST = ROOT / "App/RealityKit/Atlantis/atlantis_manifest.json"
EXPORT_MANIFEST = Path(__file__).resolve().parent / "export_manifest.json"

source = Usd.Stage.Open(str(SOURCE))
stage = Usd.Stage.CreateNew(str(OUTPUT))
root = UsdGeom.Xform.Define(stage, "/FounderDistrict")
stage.SetDefaultPrim(root.GetPrim())
UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
UsdGeom.SetStageMetersPerUnit(stage, 1)

xforms = UsdGeom.XformCache()
batches = {}

for prim in source.Traverse():
    if not prim.IsA(UsdGeom.Mesh):
        continue
    mesh = UsdGeom.Mesh(prim)
    points = mesh.GetPointsAttr().Get()
    counts = mesh.GetFaceVertexCountsAttr().Get()
    indices = mesh.GetFaceVertexIndicesAttr().Get()
    transform = xforms.GetLocalToWorldTransform(prim)
    world_points = [transform.Transform(Gf.Vec3d(point)) for point in points]

    face_material = {}
    for child in prim.GetChildren():
        if not child.IsA(UsdGeom.Subset):
            continue
        material, _ = UsdShade.MaterialBindingAPI(child).ComputeBoundMaterial()
        if not material:
            continue
        for face in UsdGeom.Subset(child).GetIndicesAttr().Get():
            face_material[int(face)] = str(material.GetPath())

    cursor = 0
    material_offsets = {}
    for face_index, count in enumerate(counts):
        material_path = face_material.get(face_index, "/FounderDistrict/Materials/Unbound")
        batch = batches.setdefault(material_path, {"points": [], "counts": [], "indices": []})
        if material_path not in material_offsets:
            material_offsets[material_path] = len(batch["points"])
            batch["points"].extend(world_points)
        offset = material_offsets[material_path]
        batch["counts"].append(int(count))
        batch["indices"].extend(offset + int(index) for index in indices[cursor:cursor + count])
        cursor += count

materials = {}
for source_path in sorted(batches):
    name = source_path.rsplit("/", 1)[-1]
    destination_path = f"/FounderDistrict/Materials/{name}"
    material = UsdShade.Material.Define(stage, destination_path)
    shader = UsdShade.Shader.Define(stage, destination_path + "/Surface")
    shader.CreateIdAttr("UsdPreviewSurface")
    source_shader = UsdShade.Shader(source.GetPrimAtPath(source_path + "/Surface"))
    for input_name, value_type, fallback in [
        ("diffuseColor", Sdf.ValueTypeNames.Color3f, Gf.Vec3f(.8)),
        ("roughness", Sdf.ValueTypeNames.Float, .7),
        ("metallic", Sdf.ValueTypeNames.Float, 0.0),
        ("emissiveColor", Sdf.ValueTypeNames.Color3f, Gf.Vec3f(0)),
    ]:
        source_input = source_shader.GetInput(input_name) if source_shader else None
        source_value = source_input.Get() if source_input else None
        shader.CreateInput(input_name, value_type).Set(source_value if source_value is not None else fallback)
    material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
    materials[source_path] = material

for index, (material_path, batch) in enumerate(sorted(batches.items())):
    mesh = UsdGeom.Mesh.Define(stage, f"/FounderDistrict/Batched/Material_{index:02d}")
    mesh.CreateSubdivisionSchemeAttr("none")
    mesh.CreateDoubleSidedAttr(False)
    mesh.CreatePointsAttr([Gf.Vec3f(point) for point in batch["points"]])
    mesh.CreateFaceVertexCountsAttr(batch["counts"])
    mesh.CreateFaceVertexIndicesAttr(batch["indices"])
    UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(materials[material_path])

slot = UsdGeom.Xform.Define(stage, "/FounderDistrict/FounderGarageSlot")
slot.AddTranslateOp().Set(Gf.Vec3d(-875, 8, 1030))
slot.GetPrim().CreateAttribute("atlantis:sourceName", Sdf.ValueTypeNames.String).Set("FounderGarage_Slot")

stage.GetRootLayer().Save()
UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(OUTPUT)), str(PACKAGE))

check = Usd.Stage.Open(str(PACKAGE))
bounds_cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ["default", "render"])
bounds = bounds_cache.ComputeWorldBound(check.GetDefaultPrim()).ComputeAlignedRange()
mesh_count = sum(1 for prim in check.Traverse() if prim.IsA(UsdGeom.Mesh))
triangles = sum(
    sum(int(count) - 2 for count in UsdGeom.Mesh(prim).GetFaceVertexCountsAttr().Get())
    for prim in check.Traverse() if prim.IsA(UsdGeom.Mesh)
)
entry = {
    "package": "founder_district_batched",
    "bytes": PACKAGE.stat().st_size,
    "meshes": mesh_count,
    "triangles": triangles,
    "materials": len(materials),
    "textures": 0,
    "bounds": [list(bounds.GetMin()), list(bounds.GetMax())],
    "landmarks": {"FounderGarageSlot": [-875, 8, 1030]},
    "sha256": hashlib.sha256(PACKAGE.read_bytes()).hexdigest(),
    "experiment": "Static geometry grouped by material; source transforms baked; diagnostic only",
}

for path in [MANIFEST, EXPORT_MANIFEST]:
    data = json.loads(path.read_text())
    data["experiments"] = {"FounderDistrictBatched": entry}
    path.write_text(json.dumps(data, separators=(",", ":")) if path == MANIFEST else json.dumps(data, indent=2))

print(json.dumps(entry, indent=2))
