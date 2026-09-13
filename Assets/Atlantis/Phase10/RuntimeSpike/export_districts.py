"""Phase 9 -> metre/Y-up USDZ. Read-only Blender source; explicit ownership manifest."""
import bpy,os,json,math,hashlib,collections
from pathlib import Path
from mathutils import Matrix,Vector
from pxr import Usd,UsdGeom,UsdShade,UsdUtils,Sdf,Gf,Tf
R=Path(__file__).resolve().parent;REPO=R.parents[3];OUT=REPO/'App/RealityKit/Atlantis';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'../../Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend'));bpy.context.view_layer.update()
DIST=['FounderDistrict','StartupRow','CommerceDistrict','VentureDistrict','MediaDistrict','TechCore','UnicornHeights'];FILES=['founder_district','startup_row','commerce_district','venture_district','media_district','tech_core','unicorn_heights']
RENAMES={'TheSpire_AssetRoot':'TheSpire','VentureHall_AssetRoot':'VentureHall','TechComTower_AssetRoot':'TechComTower','SignalTV_AssetRoot':'SignalTV','PallasAI_HQ_AssetRoot':'PallasAIHQ','NorthwindLabs_HQ_AssetRoot':'NorthwindLabsHQ','Flashpoint_HQ_AssetRoot':'FlashpointHQ','Player_UnicornHQ_Slot':'PlayerUnicornHQSlot','FounderGarage_Slot':'FounderGarageSlot'}
B=Matrix.Rotation(-math.pi/2,4,'X');BI=B.inverted()
def cv(p):return [float(p[0]),float(p[2]),-float(p[1])]
def visible(o):return not o.hide_render and not any(c.hide_render for c in o.users_collection)
def ancestry(c):
 return {c.name}|{n for p in bpy.data.collections if c.name in p.children for n in ancestry(p)}
COL={c.name:ancestry(c) for c in bpy.data.collections}
def owner(o):
 names=set().union(*(COL[c.name] for c in o.users_collection))
 for d in DIST:
  if d in names:return d
 if o.get('district') in DIST:return o['district']
 if o.parent:return owner(o.parent)
 n=o.name
 for tokens,d in [(('Founder','AtlantisBridge_Main'),'FounderDistrict'),(('Startup','Progression_Startup'),'StartupRow'),(('Commerce','Flashpoint','RivalHQ_Slot_05'),'CommerceDistrict'),(('Venture','Landmark_Venture'),'VentureDistrict'),(('Media','Bridge_Media','TechCom','Signal','Landmark_TechCom','Landmark_Signal'),'MediaDistrict'),(('Tech','Spire','Landmark_TheSpire','RivalHQ_Slot_02','RivalHQ_Slot_03','RivalHQ_Slot_04'),'TechCore'),(('Unicorn','Player_Unicorn','Bridge_TechCore','Heights_'),'UnicornHeights')]:
  if n.startswith(tokens):return d
 return 'WorldContext'
objects=[o for o in bpy.context.scene.objects if visible(o) and o.type in ['MESH','FONT','EMPTY'] and not any(k in o.name for k in ['_Boundary_'])]
# Skip authoring reference empties with no renderable or semantic descendants.
objects=[o for o in objects if o.type!='EMPTY' or o.name in RENAMES or o.children or o.name.startswith(('PlayerHQ_','PlayerUnicorn','Startup_','Founder_'))]
MESH={}
for o in objects:
 if o.type=='FONT':
  dep=bpy.context.evaluated_depsgraph_get();MESH[o.name]=bpy.data.meshes.new_from_object(o.evaluated_get(dep))
 elif o.type=='MESH':MESH[o.name]=o.data
active_materials={m for me in MESH.values() for m in me.materials if m}
used_images={n.image.name for m in active_materials if m.node_tree for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image}
assert not used_images,('Active textures require explicit export support',used_images)
manifest={'axis':'Y','metersPerUnit':1,'conversion':'Blender (x,y,z) -> RealityKit (x,z,-y)','sourceSHA256':hashlib.sha256((R/'../../Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend').read_bytes()).hexdigest(),'districts':{},'ownership':{},'landmarks':{},'excluded_authoring_images':len(bpy.data.images),'active_texture_count':len(used_images)}
walktri=[];barriers=[]
def material(stage,root,m,cache):
 if m.name in cache:return cache[m.name]
 path=root+'/Materials/'+Tf.MakeValidIdentifier(m.name);ma=UsdShade.Material.Define(stage,path);sh=UsdShade.Shader.Define(stage,path+'/Surface');sh.CreateIdAttr('UsdPreviewSurface')
 p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) if m.node_tree else None
 def val(n,default):return p.inputs[n].default_value if p and n in p.inputs else default
 for n,t,v in [('diffuseColor',Sdf.ValueTypeNames.Color3f,tuple(val('Base Color',m.diffuse_color)[:3])),('roughness',Sdf.ValueTypeNames.Float,float(val('Roughness',.7))),('metallic',Sdf.ValueTypeNames.Float,float(val('Metallic',0))),('emissiveColor',Sdf.ValueTypeNames.Color3f,tuple(float(x)*float(val('Emission Strength',0)) for x in val('Emission Color',[0,0,0])[:3]))]:sh.CreateInput(n,t).Set(v)
 ma.CreateSurfaceOutput().ConnectToSource(sh.ConnectableAPI(),'surface');cache[m.name]=ma;return ma
for district,filename in list(zip(DIST,FILES))+[('WorldContext','world_context')]:
 obs=[o for o in objects if owner(o)==district];selected={o.name for o in obs};stage=Usd.Stage.CreateNew(str(OUT/(filename+'.usdc')));root='/'+district;rp=UsdGeom.Xform.Define(stage,root);stage.SetDefaultPrim(rp.GetPrim());UsdGeom.SetStageUpAxis(stage,UsdGeom.Tokens.y);UsdGeom.SetStageMetersPerUnit(stage,1)
 paths={};materials={};allpts=[];tri=0;meshcount=0;landmarks={};mesh_uses=collections.Counter()
 def objpath(o):
  if o.name in paths:return paths[o.name]
  parent=objpath(o.parent) if o.parent and o.parent.name in selected else root
  path=parent+'/'+Tf.MakeValidIdentifier(RENAMES.get(o.name,o.name));paths[o.name]=path;return path
 for o in obs:
  path=objpath(o);xf=UsdGeom.Xform.Define(stage,path);local=o.matrix_local if o.parent and o.parent.name in selected else o.matrix_world;mat=B@local@BI
  xf.AddTransformOp().Set(Gf.Matrix4d(tuple(tuple(float(mat[j][i]) for j in range(4)) for i in range(4))))
  xf.GetPrim().CreateAttribute('atlantis:sourceName',Sdf.ValueTypeNames.String).Set(o.name)
  manifest['ownership'][o.name]=district
  if o.name in RENAMES:
   landmarks[RENAMES[o.name]]=cv(o.matrix_world.translation);manifest['landmarks'][RENAMES[o.name]]={'district':district,'position':cv(o.matrix_world.translation)}
  if o.name not in MESH:continue
  me=MESH[o.name];meshcount+=1;mesh_uses[me.name]+=1;mesh=UsdGeom.Mesh.Define(stage,path+'/Geometry');mesh.CreateSubdivisionSchemeAttr('none');mesh.CreatePointsAttr([Gf.Vec3f(*cv(v.co)) for v in me.vertices]);mesh.CreateFaceVertexCountsAttr([len(p.vertices) for p in me.polygons]);mesh.CreateFaceVertexIndicesAttr([i for p in me.polygons for i in p.vertices]);mesh.CreateDoubleSidedAttr(False)
  tri+=sum(len(p.vertices)-2 for p in me.polygons)
  for mi,m in enumerate(me.materials):
   if not m:continue
   ma=material(stage,root,m,materials);subset=UsdGeom.Subset.Define(stage,path+'/Geometry/Material_'+str(mi));subset.CreateElementTypeAttr('face');subset.CreateFamilyNameAttr('materialBind');subset.CreateIndicesAttr([p.index for p in me.polygons if p.material_index==mi]);UsdShade.MaterialBindingAPI.Apply(subset.GetPrim()).Bind(ma)
  pts=[o.matrix_world@v.co for v in me.vertices];allpts.extend(cv(p) for p in pts)
  # Grounding uses exact source triangle surfaces, never inferred district elevation.
  terrain='Terrain' in [c.name for c in o.users_collection]
  surface=terrain or any(k in o.name for k in ['Walk','Sidewalk','Driveway','Apron','Seam','Crossing','ContinuousPaving','Road','Boulevard','Bridge_','CrossStreet','_Spine','_Link','Progression_','Plaza_Surface','Street'])
  if surface and not any(k in o.name for k in ['Pole','Light','Guard','Rail','Pier','Paint','Seat','Tree','Window']):
   me.calc_loop_triangles()
   for t in me.loop_triangles:
    a,b,c=[pts[i] for i in t.vertices];norm=(b-a).cross(c-a)
    if norm.length>0 and norm.normalized().z>.7:walktri.append({'district':district,'source':o.name,'points':[cv(a),cv(b),cv(c)]})
 bounds=[[min(p[i] for p in allpts) for i in range(3)],[max(p[i] for p in allpts) for i in range(3)]] if allpts else [[0]*3]*2
 stage.GetRootLayer().Save();package=OUT/(filename+'.usdz');UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(str(OUT/(filename+'.usdc'))),str(package));check=Usd.Stage.Open(str(package));assert check and str(UsdGeom.GetStageUpAxis(check))=='Y' and UsdGeom.GetStageMetersPerUnit(check)==1
 cache=UsdGeom.BBoxCache(Usd.TimeCode.Default(),['default','render']);box=cache.ComputeWorldBound(check.GetDefaultPrim()).ComputeAlignedRange();actual=[list(box.GetMin()),list(box.GetMax())];assert max(abs(actual[j][i]-bounds[j][i]) for j in range(2) for i in range(3))<.01,(district,actual,bounds)
 manifest['districts'][district]={'package':filename,'bytes':package.stat().st_size,'meshes':meshcount,'triangles':tri,'materials':len(materials),'textures':0,'bounds':bounds,'landmarks':landmarks,'sha256':hashlib.sha256(package.read_bytes()).hexdigest(),'source_shared_mesh_variants':sum(v>1 for v in mesh_uses.values()),'mesh_payloads_exported':meshcount,'instancing':'expanded per object in baseline; runtime sharing not assumed'}
 print('EXPORTED',district,manifest['districts'][district])
# Representative envelope collisions from existing campus/building roots; no detailed mesh colliders.
for district,folder,phase in [('FounderDistrict','FounderDistrict',7),('StartupRow','StartupRow',6)]:
 plan=json.load(open(REPO/f'Assets/Atlantis/Phase{phase}/{folder}'/('build_audit.json' if phase==7 else 'site_plan.json')))
 for a in plan.get('sites',[]):
  p=a.get('position');w=a.get('width');d=a.get('depth')
  if w and d:
   angle=math.radians(a.get('rotation_degrees',0));w,d=abs(w*math.cos(angle))+abs(d*math.sin(angle)),abs(w*math.sin(angle))+abs(d*math.cos(angle))
  if p is not None and w and d:barriers.append({'district':district,'name':a.get('id',a.get('name')),'min':[p[0]-w/2,p[2],-p[1]-d/2],'max':[p[0]+w/2,p[2]+a.get('height',20),-p[1]+d/2]})
route=json.load(open(REPO/'Assets/Atlantis/Phase7/FounderDistrict/build_audit.json'));routes=[{'name':p['name'],'points':[cv(v) for v in p['points']]} for p in route['paths'] if p['name'] in ['Founder_GarageDriveway','Founder_GarageApron','Founder_ToStartup_Walk']]
startup=json.load(open(REPO/'Assets/Atlantis/Phase6/StartupRow/site_plan.json'))
routes.append({'name':'Startup_Row_Core_SourceRoute','points':[cv(v) for v in startup['route'][4:8]]})
manifest['traversal']={'triangles':walktri,'barriers':barriers,'routes':routes}
(R/'export_manifest.json').write_text(json.dumps(manifest,indent=2));(OUT/'atlantis_manifest.json').write_text(json.dumps(manifest,separators=(',',':')))
print('EXPORT_COMPLETE',len(walktri),'ground triangles',len(barriers),'barriers')
