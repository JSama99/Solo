"""Build the single permitted Pass A.2 reduced-duplication experiment.

The source USD already owns one canonical skeleton. This packages that hierarchy
without the ten-module compatibility rewrite so RealityKit can determine whether
shared skeleton ownership preserves independent renderable modules.
"""
import hashlib
import json
from pathlib import Path

from pxr import Usd, UsdGeom, UsdSkel, UsdUtils


folder = Path(__file__).resolve().parents[1]
source = folder / "Intermediate/founder_candidate_a.usdc"
destination = folder / "Intermediate/founder_runtime_shared_skeleton_experiment.usdz"
stage = Usd.Stage.Open(str(source))
assert stage
skeletons = [prim for prim in stage.Traverse() if prim.IsA(UsdSkel.Skeleton)]
meshes = [prim for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh)]
assert len(skeletons) == 1
assert len(meshes) == 10
assert UsdUtils.CreateNewUsdzPackage(str(source), str(destination))
result = {
    "status": "STRUCTURAL_EXPERIMENT_READY; RealityKit behavior unverified",
    "candidate": destination.name,
    "package_bytes": destination.stat().st_size,
    "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
    "skeleton_instances": len(skeletons),
    "mesh_count": len(meshes),
    "facial_targets": sum(1 for prim in stage.Traverse() if prim.IsA(UsdSkel.BlendShape)),
    "required_test": "FounderCharacterContractTests before any retention decision",
}
(folder / "Evidence/A2/packaging_shared_skeleton_experiment.json").write_text(
    json.dumps(result, indent=2) + "\n"
)
print("FOUNDER_PACKAGING_EXPERIMENT " + json.dumps(result, sort_keys=True))
