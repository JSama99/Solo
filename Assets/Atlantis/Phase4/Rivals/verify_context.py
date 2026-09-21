import bpy,json,os,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));viewnames=['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View'];results={};audit=json.load(open(R+'/slot_audit.json'))
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
for phase,path in [('Phase3',R+'/../../Phase3/MediaDistrict/Blender/Atlantis_Phase3_Masterplan.blend'),('Phase4',R+'/Blender/Atlantis_Phase4_Masterplan.blend')]:
 s,dep=prepare(path);points=[]
 for o in s.objects:
  if o.type=='MESH' and o.name.startswith('TheSpire_'):
   points += [o.matrix_world@v.co for v in o.data.vertices if (o.matrix_world@v.co).z>265]
 points=points[::max(1,len(points)//40)];results[phase]={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in points) for n in viewnames}
 if phase=='Phase3':
  for slot in audit:
   q=slot['contract'];x,y,z=q['origin'];h=q['placeholder_height_m'];slot['current_phase3_visibility']={n:sum(sight(s,dep,bpy.data.objects[n],(x+dx,y,z+h*f),q['id']+'_Massing') for dx in [-4,0,4] for f in [.5,.8,.95]) for n in viewnames}
json.dump(audit,open(R+'/slot_audit.json','w'),indent=2)
v=json.load(open(R+'/verification.json'));v['spire_crown_surface_samples']=results;v['checks']['all_six_established_spire_views_not_worsened']=all(results['Phase4'][n]>=results['Phase3'][n] for n in viewnames)
# Neighbor clearances for growth envelopes against unmodified district massing.
profiles=json.load(open(R+'/rival_profiles.json'))['profiles'];clear={}
for p in profiles:
 x,y,z=p['position'];w,d,h=p['futureUpgradeEnvelope'];low=(x-w/2,y-d/2);high=(x+w/2,y+d/2);near=[]
 for o in s.objects:
  if o.type!='MESH' or not ('_Block_' in o.name or '_Podium_' in o.name):continue
  pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=[min(v[i] for v in pts) for i in range(2)];hi=[max(v[i] for v in pts) for i in range(2)];dist=math.hypot(max(lo[0]-high[0],low[0]-hi[0],0),max(lo[1]-high[1],low[1]-hi[1],0));near.append((dist,o.name))
 clear[p['semanticID']]=min(near)
v['growth_neighbor_clearance']=clear;v['checks']['all_growth_envelopes_clear_neighbor_blocks']=all(x[0]>0 for x in clear.values())
# Fresh review GLB reimport verifies retained world positions and bounds.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=R+'/Export/Atlantis_Phase4_RivalBlockout.glb');bpy.context.view_layer.update();export={}
for p in profiles:
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(p['semanticID']+'_')];pts=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box];lo=[min(q[i] for q in pts) for i in range(3)];hi=[max(q[i] for q in pts) for i in range(3)];export[p['semanticID']]=[lo,hi]
v['review_glb_bounds']=export;v['checks']['review_glb_reimport_preserves_world_positions']=all(max(abs(export[n][j][i]-v['metrics'][n]['bounds'][j][i]) for i in range(3) for j in range(2))<.01 for n in export)
json.dump(v,open(R+'/verification.json','w'),indent=2);print(json.dumps({'surface_visibility':results,'clearance':clear,'checks':v['checks']},indent=2));assert all(v['checks'].values())
