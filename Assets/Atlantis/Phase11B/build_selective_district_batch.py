"""Build audited Phase 11B selective batches for the remaining heavy districts.

The Phase 10 USDC inputs remain read-only. Landmark subtrees stay byte-for-byte
copied at the USD-spec level. Other top-level entities remain as lightweight
semantic anchors while their static render meshes are combined by material.
Commerce and Unicorn building identity/display children also stay independent.
"""
import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils


ROOT = Path(__file__).resolve().parents[3]
APP_MANIFEST = ROOT / "App/RealityKit/Atlantis/atlantis_manifest.json"
EXPORT_MANIFEST = ROOT / "Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json"

CONFIGS = {
    "commerce": {
        "district": "CommerceDistrict",
        "root": "CommerceDistrict",
        "package": "commerce_district",
        "full": {"RivalHQ_Slot_05"},
        "keep_children": ("SemanticSign", "_Label", "OccupiedSurfaces"),
        "batchable": "supporting architecture, props, and static route surfaces",
        "preserved": "Flashpoint hierarchy; every top-level semantic/navigation anchor; building signs, labels, and occupied surfaces",
    },
    "tech": {
        "district": "TechCore",
        "root": "TechCore",
        "package": "tech_core",
        "full": {"TheSpire", "RivalHQ_Slot_03", "RivalHQ_Slot_04"},
        "keep_children": (),
        "batchable": "supporting blocks, podiums, plaza, and static road geometry",
        "preserved": "The Spire, Pallas AI HQ, and Northwind Labs HQ hierarchies; every top-level semantic/navigation anchor",
    },
    "unicorn": {
        "district": "UnicornHeights",
        "root": "UnicornHeights",
        "package": "unicorn_heights",
        "full": {"PlayerUnicornHQSlot", "Bridge_TechCore_00", "Unicorn_BridgeWalk_00"},
        "keep_children": ("_Identity", "OccupiedSurfaces"),
        "batchable": "campus architecture, repeated landscape props, and static public-realm geometry",
        "preserved": "Player Unicorn HQ slot and legacy Tech Core bridge hierarchies; every top-level semantic/navigation anchor; campus identity and occupied surfaces",
    },
    "venture": {
        "district": "VentureDistrict",
        "root": "VentureDistrict",
        "package": "venture_district",
        "full": {"VentureHall"},
        "keep_children": (),
        "batchable": "supporting blocks, landscape, and static public-realm geometry",
        "preserved": "Venture Hall hierarchy and every top-level semantic/navigation anchor",
    },
    "media": {
        "district": "MediaDistrict",
        "root": "MediaDistrict",
        "package": "media_district",
        "full": {"TechComTower", "SignalTV"},
        "keep_children": (),
        "batchable": "supporting blocks, landscape, and static waterfront/route geometry",
        "preserved": "Tech.com and Signal TV hierarchies and every top-level semantic/navigation anchor",
    },
}


def descendant_meshes(prim):
    return [str(p.GetPath()) for p in Usd.PrimRange(prim) if p.IsA(UsdGeom.Mesh)]


def build(key):
    config = CONFIGS[key]
    package_name = config["package"] + "_batched"
    source_path = ROOT / f"App/RealityKit/Atlantis/{config['package']}.usdc"
    output_path = ROOT / f"App/RealityKit/Atlantis/{package_name}.usdc"
    package_path = ROOT / f"App/RealityKit/Atlantis/{package_name}.usdz"
    batch_manifest_path = Path(__file__).resolve().parent / f"{key}_batch_manifest.json"

    source = Usd.Stage.Open(str(source_path))
    stage = Usd.Stage.CreateNew(str(output_path))
    root = UsdGeom.Xform.Define(stage, f"/{config['root']}")
    stage.SetDefaultPrim(root.GetPrim())
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1)
    source_layer = source.GetRootLayer()
    destination_layer = stage.GetRootLayer()

    materials_path = f"/{config['root']}/Materials"
    UsdGeom.Scope.Define(stage, materials_path)
    for material_prim in source.GetPrimAtPath(materials_path).GetChildren():
        Sdf.CopySpec(source_layer, str(material_prim.GetPath()), destination_layer, str(material_prim.GetPath()))

    preserved_roots = []
    preserved_meshes = []
    semantic_anchors = []
    for child in source.GetDefaultPrim().GetChildren():
        if child.GetName() == "Materials":
            continue
        child_path = str(child.GetPath())
        Sdf.CopySpec(source_layer, child_path, destination_layer, child_path)
        copied = stage.GetPrimAtPath(child.GetPath())
        if child.GetName() in config["full"]:
            preserved_roots.append(child_path)
            preserved_meshes.extend(descendant_meshes(child))
            continue

        kept = []
        for copied_child in list(copied.GetChildren()):
            if any(token in copied_child.GetName() for token in config["keep_children"]):
                kept.append(copied_child.GetName())
                preserved_meshes.extend(descendant_meshes(source.GetPrimAtPath(copied_child.GetPath())))
            else:
                stage.RemovePrim(copied_child.GetPath())
        semantic_anchors.append({"path": child_path, "preservedChildren": sorted(kept)})

    xforms = UsdGeom.XformCache()
    batches = defaultdict(lambda: {"points": [], "counts": [], "indices": [], "sources": []})
    batched_sources = []
    for prim in source.Traverse():
        prim_path = str(prim.GetPath())
        if not prim.IsA(UsdGeom.Mesh) or prim_path in preserved_meshes:
            continue
        mesh = UsdGeom.Mesh(prim)
        points = mesh.GetPointsAttr().Get()
        counts = [int(value) for value in mesh.GetFaceVertexCountsAttr().Get()]
        indices = [int(value) for value in mesh.GetFaceVertexIndicesAttr().Get()]
        transform = xforms.GetLocalToWorldTransform(prim)
        world_points = [transform.Transform(Gf.Vec3d(point)) for point in points]
        direct_material, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
        direct_path = str(direct_material.GetPath()) if direct_material else f"{materials_path}/Unbound"
        face_materials = {}
        for subset_prim in prim.GetChildren():
            if not subset_prim.IsA(UsdGeom.Subset):
                continue
            subset_material, _ = UsdShade.MaterialBindingAPI(subset_prim).ComputeBoundMaterial()
            if subset_material:
                for face_index in UsdGeom.Subset(subset_prim).GetIndicesAttr().Get():
                    face_materials[int(face_index)] = str(subset_material.GetPath())

        remaps = defaultdict(dict)
        used_materials = set()
        cursor = 0
        for face_index, count in enumerate(counts):
            material = face_materials.get(face_index, direct_path)
            batch = batches[material]
            remap = remaps[material]
            for source_index in indices[cursor:cursor + count]:
                if source_index not in remap:
                    remap[source_index] = len(batch["points"])
                    batch["points"].append(world_points[source_index])
                batch["indices"].append(remap[source_index])
            batch["counts"].append(count)
            used_materials.add(material)
            cursor += count
        for material in used_materials:
            batches[material]["sources"].append(prim_path)
        batched_sources.append(prim_path)

    for index, (material, batch) in enumerate(sorted(batches.items())):
        material_name = material.rsplit("/", 1)[-1]
        mesh = UsdGeom.Mesh.Define(stage, f"/{config['root']}/StaticBatches/Batch_{index:03d}_{material_name}")
        mesh.CreateSubdivisionSchemeAttr("none")
        mesh.CreateDoubleSidedAttr(False)
        mesh.CreatePointsAttr([Gf.Vec3f(point) for point in batch["points"]])
        mesh.CreateFaceVertexCountsAttr(batch["counts"])
        mesh.CreateFaceVertexIndicesAttr(batch["indices"])
        bound = UsdShade.Material(stage.GetPrimAtPath(material))
        if bound and bound.GetPrim().IsValid():
            UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(bound)

    stage.GetRootLayer().Save()
    UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(output_path)), str(package_path))

    check = Usd.Stage.Open(str(package_path))
    bounds_cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), ["default", "render"])
    bounds = bounds_cache.ComputeWorldBound(check.GetDefaultPrim()).ComputeAlignedRange()
    mesh_count = sum(1 for prim in check.Traverse() if prim.IsA(UsdGeom.Mesh))
    triangles = sum(
        sum(int(count) - 2 for count in UsdGeom.Mesh(prim).GetFaceVertexCountsAttr().Get())
        for prim in check.Traverse() if prim.IsA(UsdGeom.Mesh)
    )
    material_count = sum(1 for prim in check.Traverse() if prim.IsA(UsdShade.Material))
    manifest = json.loads(APP_MANIFEST.read_text())
    baseline = manifest["districts"][config["district"]]
    entry = {
        "package": package_name,
        "bytes": package_path.stat().st_size,
        "meshes": mesh_count,
        "triangles": triangles,
        "materials": material_count,
        "textures": baseline["textures"],
        "bounds": [list(bounds.GetMin()), list(bounds.GetMax())],
        "landmarks": baseline["landmarks"],
        "sha256": hashlib.sha256(package_path.read_bytes()).hexdigest(),
        "experiment": "Selective material batching with landmark subtrees and semantic anchors preserved",
    }
    for path in (APP_MANIFEST, EXPORT_MANIFEST):
        data = json.loads(path.read_text())
        data.setdefault("experiments", {})[config["district"] + "Batched"] = entry
        path.write_text(json.dumps(data, separators=(",", ":")) if path == APP_MANIFEST else json.dumps(data, indent=2))

    audit = {
        "source": str(source_path.relative_to(ROOT)),
        "sourceSHA256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "output": str(package_path.relative_to(ROOT)),
        "outputSHA256": entry["sha256"],
        "classification": {"batchable": config["batchable"], "preserveSeparate": config["preserved"]},
        "preservedRoots": sorted(preserved_roots),
        "semanticAnchors": semantic_anchors,
        "preservedMeshPaths": sorted(preserved_meshes),
        "batchedSourceMeshPaths": sorted(batched_sources),
        "batches": [
            {"material": material, "sourceMeshes": sorted(batch["sources"])}
            for material, batch in sorted(batches.items())
        ],
        "baseline": baseline,
        "optimized": entry,
    }
    batch_manifest_path.write_text(json.dumps(audit, indent=2) + "\n")
    print(json.dumps(entry, indent=2))


parser = argparse.ArgumentParser()
parser.add_argument("district", choices=CONFIGS)
build(parser.parse_args().district)
