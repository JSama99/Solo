import bpy,json,os,hashlib,ast
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));out={};checks={}
tr=ast.parse(open(R+'/integrate_pallas.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name=='sig'],type_ignores=[]),'sig','exec'))
views=['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View']
def prepare(path):
 bpy.ops.wm.open_mainfile(filepath=path);s=bpy.context.scene
 for o in list(s.objects):
  if o.hide_render or any(c.hide_render for c in o.users_collection):
   for c in list(o.users_collection):c.objects.unlink(o)
 bpy.context.view_layer.update();return s,bpy.context.evaluated_depsgraph_get()
def sight(s,dep,cam,p,prefix):
 p=Vector(p);ndc=world_to_camera_view(s,cam,p)
 if not (0<=ndc.x<=1 and 0<=ndc.y<=1 and ndc.z>0):return False
 if cam.data.type=='ORTHO':d=-(cam.matrix_world.to_quaternion()@Vector((0,0,1)));a=p-d*5000
 else:a=cam.location;d=(p-a).normalized()
 hit,loc,no,i,o,ma=s.ray_cast(dep,a,d,distance=(p-a).length+1);return bool(hit and o.name.startswith(prefix))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase4/Rivals/Blender/Atlantis_Phase4_Masterplan.blend');base={o.name:sig(o) for o in bpy.context.scene.objects}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend');changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h];checks['all_phase4_object_geometry_transforms_metadata_preserved']=not changed;out['changed_original_objects']=changed
contracts=json.load(open(R+'/../../Phase4/Rivals/future_higgsfield_contracts.json'));names=['PallasAI','NorthwindLabs','Flashpoint'];metrics=json.load(open(R+'/final_metrics.json'));bpy.context.view_layer.update()
for n,c in zip(names,contracts):
 root=bpy.data.objects[n+'_HQ_AssetRoot'];locator=bpy.data.objects[c['semanticLocator']]
 checks[n+'_slot_preserved']=root.parent==locator and locator.parent.name==c['slotID'] and max(abs(root.matrix_world.translation[i]-c['worldPosition'][i]) for i in range(3))<.001
 checks[n+'_blockout_disabled']=all(o.hide_render and o.hide_viewport for o in bpy.data.collections[n+'_Blockout'].objects if o.type=='MESH')
 checks[n+'_independent_export_pass']=all(metrics[n]['checks'].values());checks[n+'_below_spire']=metrics[n]['dimensions'][2]<280
 checks[n+'_within_height_limit']=metrics[n]['dimensions'][2]<{'PallasAI':180,'NorthwindLabs':180,'Flashpoint':100}[n]
 checks[n+'_growth_capacity']=all(v>0 for v in metrics[n]['remaining_growth_dimensions'])
for phase,path in [('Phase4',R+'/../../Phase4/Rivals/Blender/Atlantis_Phase4_Masterplan.blend'),('Phase5',R+'/Blender/Atlantis_Phase5_Masterplan.blend')]:
 s,dep=prepare(path);points=[]
 for o in s.objects:
  if o.type=='MESH' and o.name.startswith('TheSpire_'):points += [o.matrix_world@v.co for v in o.data.vertices if (o.matrix_world@v.co).z>265]
 points=points[::max(1,len(points)//40)];out[phase+'_spire_crown_samples']={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in points) for n in views}
checks['all_six_spire_views_preserved']=all(out['Phase5_spire_crown_samples'][n]>=out['Phase4_spire_crown_samples'][n] for n in views)
context=views+['Venture_Pallas','Northwind_TechApproach','StartupRow_Flashpoint','Media_RivalSkyline','TechCore_Rivals_Aerial'];visibility={}
for name,c in zip(names,contracts):
 x,y,z=c['worldPosition'];h=c['targetHeight'];visibility[name]={}
 for n in context:
  hits=sum(sight(s,dep,bpy.data.objects[n],(x+dx,y,z+h*f),name+'_') for dx in [-4,0,4] for f in [.4,.6,.8,.95]);visibility[name][n]={'hits_of_12':hits,'rating':'Strong' if hits>=6 else 'Partial' if hits else 'Hidden'}
out['sampled_visibility']=visibility
baseline=json.load(open(R+'/preservation_baseline.json'));changedfiles=[p for p,h in baseline.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['protected_files_unchanged']=not changedfiles;out['protected_file_count']=len(baseline);out['changed_protected_files']=changedfiles;source_base=json.load(open(R+'/source_preservation.json'));checks['raw_sources_preserved']=all(hashlib.sha256(open(p,'rb').read()).hexdigest()==h for p,h in source_base.items());out['source_file_count']=len(source_base);out['checks']=checks
json.dump(out,open(R+'/verification.json','w'),indent=2);print(json.dumps(out,indent=2));assert all(checks.values()),checks
