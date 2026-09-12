"""OpenUSD validation of the derived runtime packages, without scene edits."""
from pathlib import Path
import json,hashlib,zipfile
from pxr import Usd,UsdGeom,UsdShade,UsdUtils
R=Path(__file__).resolve().parent;repo=R.parents[3];out=repo/'App/RealityKit/Atlantis';manifest=json.loads((R/'export_manifest.json').read_text());results={}
for name,meta in manifest['districts'].items():
 p=out/(meta['package']+'.usdz');stage=Usd.Stage.Open(str(p));cache=UsdGeom.XformCache();root=stage.GetDefaultPrim()
 mesh=[prim for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh)];materials=[prim for prim in stage.Traverse() if prim.IsA(UsdShade.Material)]
 landmarks={k:None for k in meta['landmarks']}
 for prim in stage.Traverse():
  if prim.GetName() in landmarks:landmarks[prim.GetName()]=list(cache.GetLocalToWorldTransform(prim).ExtractTranslation())
 missing=[]
 for prim in stage.Traverse():
  for attr in prim.GetAttributes():
   if str(attr.GetTypeName())=='asset' and attr.Get() and not attr.Get().resolvedPath:missing.append(str(attr.Get()))
 check=dict(opens=bool(stage),y_up=str(UsdGeom.GetStageUpAxis(stage))=='Y',metres=UsdGeom.GetStageMetersPerUnit(stage)==1,identity_root=UsdGeom.Xformable(root).GetLocalTransformation()==cache.GetLocalToWorldTransform(root) and not UsdGeom.Xformable(root).GetOrderedXformOps(),mesh_count=len(mesh)==meta['meshes'],material_count=len(materials)==meta['materials'],landmarks=all(v and max(abs(a-b) for a,b in zip(v,meta['landmarks'][k]))<.01 for k,v in landmarks.items()),dependencies_resolved=not missing,hash_matches=hashlib.sha256(p.read_bytes()).hexdigest()==meta['sha256'])
 with zipfile.ZipFile(p) as archive:check['single_self_contained_stage']=len(archive.namelist())==1
 results[name]={'checks':check,'landmarks':landmarks,'missing':missing}
 assert all(check.values()),(name,check)
protected=json.loads((R/'preservation_baseline.json').read_text());changes=[p for p,h in protected.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
expected=['App/App.swift','SoloUnicornRun.xcodeproj/project.pbxproj'];generated=[p for p in changes if p.endswith('UserInterfaceState.xcuserstate')];assert set(changes)<=set(expected+generated),changes
result={'packages':results,'protected_file_count':len(protected),'intentional_existing_changes':[p for p in changes if p in expected],'generated_xcode_user_state':generated,'unchanged_count':len(protected)-len(changes),'checks_passed':sum(len(v['checks']) for v in results.values())};(R/'export_validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
