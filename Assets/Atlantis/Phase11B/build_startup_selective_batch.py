"""Build the Phase 11B selective Startup Row batching candidate.

The Phase 10 USDC remains read-only. Progression and bounded traversal roots stay
independent, building roots retain lightweight identity, and signage subtrees stay
separate. Only building architecture and background public-realm geometry are
batched by deterministic world-space block and material.
"""
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "App/RealityKit/Atlantis/startup_row.usdc"
OUTPUT = ROOT / "App/RealityKit/Atlantis/startup_row_batched.usdc"
PACKAGE = ROOT / "App/RealityKit/Atlantis/startup_row_batched.usdz"
APP_MANIFEST = ROOT / "App/RealityKit/Atlantis/atlantis_manifest.json"
EXPORT_MANIFEST = ROOT / "Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json"
BATCH_MANIFEST = Path(__file__).resolve().parent / "startup_batch_manifest.json"

PRESERVED_ROOT_PREFIXES = ("Progression_Startup_",)
PRESERVED_ROOTS = {"StartupRow_CrossStreet_00", "Startup_Link_00"}


def block_name(point):
    # Startup stays one district streaming unit. Material families provide useful
    # separation while avoiding a single anonymous district mega-mesh.
    return "DistrictStatic"


source = Usd.Stage.Open(str(SOURCE))
stage = Usd.Stage.CreateNew(str(OUTPUT))
root = UsdGeom.Xform.Define(stage, "/StartupRow")
stage.SetDefaultPrim(root.GetPrim())
UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
UsdGeom.SetStageMetersPerUnit(stage, 1)

source_layer = source.GetRootLayer()
destination_layer = stage.GetRootLayer()
UsdGeom.Scope.Define(stage, "/StartupRow/Materials")
for material_prim in source.GetPrimAtPath("/StartupRow/Materials").GetChildren():
    Sdf.CopySpec(source_layer, str(material_prim.GetPath()), destination_layer, str(material_prim.GetPath()))

preserved_roots = []
preserved_meshes = []
for child in source.GetDefaultPrim().GetChildren():
    name = child.GetName()
    if name == "Materials":
        continue
    if name in PRESERVED_ROOTS or name.startswith(PRESERVED_ROOT_PREFIXES):
        Sdf.CopySpec(source_layer, str(child.GetPath()), destination_layer, str(child.GetPath()))
        preserved_roots.append(str(child.GetPath()))
        preserved_meshes.extend(str(p.GetPath()) for p in Usd.PrimRange(child) if p.IsA(UsdGeom.Mesh))
        continue
    signage = next((c for c in child.GetChildren() if c.GetName().endswith("_Signage")), None)
    if signage:
        Sdf.CopySpec(source_layer, str(child.GetPath()), destination_layer, str(child.GetPath()))
        copied = stage.GetPrimAtPath(child.GetPath())
        for copied_child in list(copied.GetChildren()):
            if copied_child.GetName() != signage.GetName():
                stage.RemovePrim(copied_child.GetPath())
        preserved_roots.append(str(child.GetPath()))
        preserved_meshes.extend(str(p.GetPath()) for p in Usd.PrimRange(signage) if p.IsA(UsdGeom.Mesh))

xforms = UsdGeom.XformCache()
batches = defaultdict(lambda: {"points": [], "counts": [], "indices": [], "sources": []})
batched_sources = []

for prim in source.Traverse():
    if not prim.IsA(UsdGeom.Mesh) or str(prim.GetPath()) in preserved_meshes:
        continue
    top_name = prim.GetPath().pathString.split("/")[2]
    if top_name in PRESERVED_ROOTS or top_name.startswith(PRESERVED_ROOT_PREFIXES):
        continue
    mesh = UsdGeom.Mesh(prim)
    points = mesh.GetPointsAttr().Get()
    counts = [int(value) for value in mesh.GetFaceVertexCountsAttr().Get()]
    indices = [int(value) for value in mesh.GetFaceVertexIndicesAttr().Get()]
    transform = xforms.GetLocalToWorldTransform(prim)
    world_points = [transform.Transform(Gf.Vec3d(point)) for point in points]
    center = sum(world_points, Gf.Vec3d(0)) / max(1, len(world_points))
    block = block_name(center)
    direct_material, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
    direct_path = str(direct_material.GetPath()) if direct_material else "/StartupRow/Materials/Unbound"
    face_materials = {}
    for subset_prim in prim.GetChildren():
        if not subset_prim.IsA(UsdGeom.Subset):
            continue
        subset_material, _ = UsdShade.MaterialBindingAPI(subset_prim).ComputeBoundMaterial()
        if not subset_material:
            continue
        for face_index in UsdGeom.Subset(subset_prim).GetIndicesAttr().Get():
            face_materials[int(face_index)] = str(subset_material.GetPath())
    remaps = defaultdict(dict)
    used_keys = set()
    cursor = 0
    for face_index, count in enumerate(counts):
        key = (block, face_materials.get(face_index, direct_path))
        batch = batches[key]
        remap = remaps[key]
        for source_index in indices[cursor:cursor + count]:
            if source_index not in remap:
                remap[source_index] = len(batch["points"])
                batch["points"].append(world_points[source_index])
            batch["indices"].append(remap[source_index])
        batch["counts"].append(count)
        used_keys.add(key)
        cursor += count
    for key in used_keys:
        batches[key]["sources"].append(str(prim.GetPath()))
    batched_sources.append(str(prim.GetPath()))

for index, ((block, material), batch) in enumerate(sorted(batches.items())):
    name = material.rsplit("/", 1)[-1]
    mesh = UsdGeom.Mesh.Define(stage, f"/StartupRow/StaticBatches/{block}/Batch_{index:03d}_{name}")
    mesh.CreateSubdivisionSchemeAttr("none")
    mesh.CreateDoubleSidedAttr(False)
    mesh.CreatePointsAttr([Gf.Vec3f(point) for point in batch["points"]])
    mesh.CreateFaceVertexCountsAttr(batch["counts"])
    mesh.CreateFaceVertexIndicesAttr(batch["indices"])
    bound = UsdShade.Material(stage.GetPrimAtPath(material))
    if bound and bound.GetPrim().IsValid():
        UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(bound)

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
    "package": "startup_row_batched",
    "bytes": PACKAGE.stat().st_size,
    "meshes": mesh_count,
    "triangles": triangles,
    "materials": 14,
    "textures": 0,
    "bounds": [list(bounds.GetMin()), list(bounds.GetMax())],
    "landmarks": {},
    "sha256": hashlib.sha256(PACKAGE.read_bytes()).hexdigest(),
    "experiment": "Selective block/material batching; progression, traversal, building roots, and signage preserved",
}

for path in (APP_MANIFEST, EXPORT_MANIFEST):
    data = json.loads(path.read_text())
    data.setdefault("experiments", {})["StartupRowBatched"] = entry
    path.write_text(json.dumps(data, separators=(",", ":")) if path == APP_MANIFEST else json.dumps(data, indent=2))

audit = {
    "source": str(SOURCE.relative_to(ROOT)),
    "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "output": str(PACKAGE.relative_to(ROOT)),
    "outputSHA256": entry["sha256"],
    "classification": {
        "batchable": "building architecture and static public-realm background geometry",
        "preserveSeparate": "progression corridor meshes, route/cross-street meshes, building identity roots, and signage subtrees",
    },
    "preservedRoots": sorted(preserved_roots),
    "preservedMeshPaths": sorted(preserved_meshes),
    "batchedSourceMeshPaths": sorted(batched_sources),
    "batches": [
        {"block": block, "material": material, "sourceMeshes": sorted(batch["sources"])}
        for (block, material), batch in sorted(batches.items())
    ],
    "baseline": json.loads(APP_MANIFEST.read_text())["districts"]["StartupRow"],
    "optimized": entry,
}
BATCH_MANIFEST.write_text(json.dumps(audit, indent=2) + "\n")
print(json.dumps(entry, indent=2))
