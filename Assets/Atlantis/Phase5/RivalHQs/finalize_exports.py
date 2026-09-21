"""Normalize production semantic names, preserve legacy blockouts, reimport each export."""
import bpy,json,os,struct,bmesh
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
contracts=json.load(open(R+'/../../Phase4/Rivals/future_higgsfield_contracts.json'))
names=['PallasAI','NorthwindLabs','Flashpoint'];all_metrics={}
for name,c in zip(names,contracts):
 path=R+'/'+name+'/Export/Atlantis_'+name+'_HQ_v1.glb'
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=path)
 for o in bpy.context.scene.objects:
  if o.name.endswith('.001'):o.name=o.name[:-4]
  if any(t in o.name for t in ['Signage_Main','LobbyDisplay','CrownMark','LabDisplay','LaunchDisplay','Ticker']):
   o['semantic_target']=o.name;o['dynamic_material_target']=True;o['content']='blank';o['forward']='-Y Blender / +Z glTF'
 root=bpy.data.objects[name+'_HQ_AssetRoot'];root['canonicalCompanyID']=c['canonicalCompanyID'];root['units']='metres';root['origin']='footprint center at ground';root['forward']=c['forward']
 bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',export_yup=True,export_extras=True)
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=path);bpy.context.view_layer.update();s=bpy.context.scene
 obs=[o for o in s.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(p) for o in obs for p in o.bound_box];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 geo=[]
 for o in obs:
  b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001)
  geo.append({'name':o.name,'nonmanifold':sum(not e.is_manifold for e in b.edges),'zero_area':sum(f.calc_area()<1e-8 for f in b.faces),'signed_volume':b.calc_volume(signed=True)});b.free()
 raw=open(path,'rb').read();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);targets=[o for o in obs if o.get('semantic_target')]
 fw,fd=c['initialMaximumFootprint'];ew,ed,eh=c['absoluteUpgradeEnvelope'];dims=[hi[i]-lo[i] for i in range(3)]
 checks={'fits_initial_footprint':lo[0]>=-fw/2-.001 and hi[0]<=fw/2+.001 and lo[1]>=-fd/2-.001 and hi[1]<=fd/2+.001,'target_height':abs(dims[2]-c['targetHeight'])<.01,'ground_origin':abs(lo[2])<.001,'clean_geometry':all(v['nonmanifold']==0 and v['zero_area']==0 and v['signed_volume']>0 for v in geo),'clean_transforms':all(max(abs(v-1) for v in o.scale)<1e-5 and max(abs(v) for v in o.rotation_euler)<1e-5 for o in s.objects),'semantic_main_exact':c['signageObject'] in [o.name for o in targets],'semantic_uvs':all(len(o.data.uv_layers)>0 for o in targets),'metres':True}
 assert all(checks.values()),(name,checks)
 m={'checks':checks,'bounds':[lo,hi],'dimensions':dims,'triangles':sum(len(p.vertices)-2 for o in obs for p in o.data.polygons),'meshes':len(obs),'materials':len(g.get('materials',[])),'textures':len(g.get('images',[])),'bytes':len(raw),'semantic_targets':[o.name for o in targets],'geometry':geo,'remaining_growth_dimensions':[ew-dims[0],ed-dims[1],eh-dims[2]],'remaining_growth_plan_area_m2':ew*ed-dims[0]*dims[1]}
 all_metrics[name]=m;json.dump(m,open(R+'/'+name+'/final_metrics.json','w'),indent=2)
 s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/'+name+'/Blender/Atlantis_'+name+'_HQ_v1.blend')
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend')
for name in names:
 for o in bpy.data.collections[name+'_Production'].objects:
  if o.type=='MESH' and any(t in o.name for t in ['Signage_Main','LobbyDisplay','CrownMark','LabDisplay','LaunchDisplay','Ticker']):
   o['semantic_target']=o.name.removesuffix('.001');o['dynamic_material_target']=True;o['content']='blank'
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend');json.dump(all_metrics,open(R+'/final_metrics.json','w'),indent=2)
print('FINAL_EXPORTS_PASS')
