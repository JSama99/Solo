"""Verify packaged USD contracts with OpenUSD (pxr), without changing assets.

Run with Blender's bundled Python, or another Python with OpenUSD installed:
  python verify_package.py [--source /path/to/original.usdc]
"""
import argparse
import hashlib
import json
from pathlib import Path
from pxr import Usd, UsdGeom, UsdShade

REPO = Path(__file__).resolve().parents[3]
ASSETS = REPO / 'App/RealityKit/FounderGarage'
EXPECTED_HASH = '1d1a831f75212a5d378cfa73c5cd32c0d2d94d82db45854f7f7a3fcb75fcf25e'
SOURCE_HASH = '7b22868b58886a9f62738ec7fe2e73355d09ad65c245a523e4619e2bf3f868ed'


def metrics(stage, path):
    meshes = [p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
    textures = {str(a.Get()) for p in stage.Traverse() for a in p.GetAttributes()
                if str(a.GetTypeName()) == 'asset' and a.Get()}
    return dict(meshes=len(meshes), triangles=sum(sum(max(0, c - 2) for c in
                UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()) for p in meshes),
                materials=sum(p.IsA(UsdShade.Material) for p in stage.Traverse()),
                textures=len(textures), bytes=path.stat().st_size)


def anchors(stage):
    cache = UsdGeom.XformCache()
    return {p.GetName(): cache.GetLocalToWorldTransform(p) for p in stage.Traverse()
            if p.GetName().startswith('Anchor_')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    args = parser.parse_args()
    old_path = ASSETS / 'founder_garage_v4.usdz'
    new_path = ASSETS / 'founder_garage_v7.usdz'
    old, new = Usd.Stage.Open(str(old_path)), Usd.Stage.Open(str(new_path))
    assert hashlib.sha256(new_path.read_bytes()).hexdigest() == EXPECTED_HASH
    assert UsdGeom.GetStageUpAxis(new) == 'Y'
    assert UsdGeom.GetStageMetersPerUnit(new) == 1
    assert str(new.GetDefaultPrim().GetPath()) == '/root'
    assert not UsdGeom.Xformable(new.GetDefaultPrim()).GetOrderedXformOps()
    before, after = anchors(old), anchors(new)
    assert len(before) == len(after) == 20 and before.keys() == after.keys()
    assert before == after, 'Full anchor transform drift'
    max_drift = max((before[k].ExtractTranslation() - after[k].ExtractTranslation()).GetLength()
                    for k in before)
    assert max_drift <= 0.001
    names = {p.GetName() for p in new.Traverse()}
    assert {'Driveway', 'Threshold_Apron', 'LotGround', 'FrontLawn_L', 'FrontLawn_R',
            'Curb_L', 'Curb_R', 'Street', 'ExteriorFacade', 'ExteriorLight_01',
            'ExteriorLight_01_Lens', 'Mailbox', 'Tree_L', 'Tree_R'} <= names
    for p in new.Traverse():
        for attr in p.GetAttributes():
            if str(attr.GetTypeName()) == 'asset' and attr.Get():
                assert attr.Get().resolvedPath, f'Unresolved texture: {attr.Get()}'
    for name in [f'GarageDoor_Section_{n:02}' for n in range(1, 6)] + ['GarageDoor_Handle']:
        a = next(p for p in old.Traverse() if p.GetName() == name)
        b = next(p for p in new.Traverse() if p.GetName() == name)
        assert UsdGeom.Xformable(a).GetLocalTransformation() == UsdGeom.Xformable(b).GetLocalTransformation()
    if args.source:
        assert hashlib.sha256(args.source.read_bytes()).hexdigest() == SOURCE_HASH
        source = Usd.Stage.Open(str(args.source))
        assert source.GetRootLayer().ExportToString().replace('upAxis = "Z"', 'upAxis = "Y"') == new.GetRootLayer().ExportToString()
    print(json.dumps(dict(v4=metrics(old, old_path), v7=metrics(new, new_path),
                          anchor_count=len(after), max_anchor_drift_metres=max_drift,
                          metadata_only_source_comparison=bool(args.source)), indent=2))


if __name__ == '__main__':
    main()
