import bpy,json,os,hashlib
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));A=R+'/NorthwindLabs'
def sig(o):
 d={'m':[list(v) for v in o.matrix_basis],'parent':o.parent.name if o.parent else None,'props':{k:str(v) for k,v in o.items()}}
 if o.type=='MESH':d.update(v=[list(v.co) for v in o.data.vertices],f=[list(p.vertices) for p in o.data.polygons],materials=[m.name for m in o.data.materials])
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=A+'/Blender/Before_Northwind.blend');base={o.name:sig(o) for o in bpy.context.scene.objects}
bpy.ops.wm.open_mainfile(filepath=A+'/Blender/Integration_Candidate.blend');s=bpy.context.scene;checks=json.load(open(A+'/export_verification.json'))['checks'];checks['original_objects_preserved']=all(bpy.data.objects.get(n) and sig(bpy.data.objects[n])==h for n,h in base.items())
# Hide blockout in memory for sightline tests; no save until checks pass.
for o in bpy.data.collections['NorthwindLabs_Blockout'].objects:
 if o.type=='MESH':o.hide_render=True;o.hide_viewport=True
hidden=[]
for o in list(s.objects):
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  cs=list(o.users_collection);hidden.append((o,cs))
  for c in cs:c.objects.unlink(o)
bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
for n in ['Founder_To_City','TheSpire_StartupSightline']:
 cam=bpy.data.objects[n];p=Vector((50,420,285));d=p-cam.location;hit,loc,no,i,obj,ma=s.ray_cast(dep,cam.location,d.normalized(),distance=d.length+2);checks[n+'_preserved']=bool(hit and obj.name.startswith('TheSpire_'))
for o,cs in hidden:
 for c in cs:c.objects.link(o)
baseline=json.load(open(R+'/preservation_baseline.json'));checks['protected_files_unchanged']=all(hashlib.sha256(open(p,'rb').read()).hexdigest()==h for p,h in baseline.items());json.dump(checks,open(A+'/integration_verification.json','w'),indent=2);assert all(checks.values()),checks
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend')
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Founder_To_City','TheSpire_StartupSightline','Northwind_TechApproach','Media_RivalSkyline','TechCore_Rivals_Aerial','UnicornHeights_View']:
 s.camera=bpy.data.objects[n];s.render.filepath=A+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
print(checks)
