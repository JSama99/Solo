import bpy,json,os,hashlib,bmesh,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));m=json.load(open(R+'/../../Phase0/masterplan_manifest.json'));profiles=json.load(open(R+'/rival_profiles.json'))['profiles'];checks={}
def sig(o):
 d={'transform':[list(v) for v in o.matrix_basis],'parent':o.parent.name if o.parent else None,'props':{k:str(v) for k,v in o.items()}}
 if o.type=='MESH':d.update(v=[list(v.co) for v in o.data.vertices],f=[list(p.vertices) for p in o.data.polygons],materials=[x.name for x in o.data.materials])
 if o.type=='CAMERA':d.update(lens=o.data.lens,scale=o.data.ortho_scale,kind=o.data.type)
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase3/MediaDistrict/Blender/Atlantis_Phase3_Masterplan.blend');base={o.name:sig(o) for o in bpy.context.scene.objects}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase4_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h];checks['all_original_geometry_transforms_properties_preserved']=not changed
checks['three_canonical_ids']=set(p['canonicalCompanyID'] for p in profiles)=={'northwind','pallas','flashpoint'};checks['one_distinct_slot_each']=len(set(p['slotID'] for p in profiles))==3
metrics={}
def seg(p,a,b):
 p=Vector(p[:2]);a=Vector(a[:2]);b=Vector(b[:2]);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-a-t*d).length
for p in profiles:
 n=p['semanticID'];c=bpy.data.collections[n+'_Blockout'];pts=[o.matrix_world@Vector(v) for o in c.objects if o.type=='MESH' for v in o.bound_box];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)];dims=[hi[i]-lo[i] for i in range(3)];slot=next(x for x in m['slots'] if x['id']==p['slotID']);geo=[]
 for o in c.objects:
  if o.type!='MESH':continue
  b=bmesh.new();b.from_mesh(o.data);geo.append({'name':o.name,'nonmanifold':sum(not e.is_manifold for e in b.edges),'zero_area':sum(f.calc_area()<1e-8 for f in b.faces),'volume':b.calc_volume(signed=True)});b.free()
 checks[n+'_geometry_valid']=all(x['nonmanifold']==0 and x['zero_area']==0 and x['volume']>0 for x in geo)
 checks[n+'_fits_parcel']=all(dims[i]<=slot['footprint_m'][i]+.001 for i in range(2)) and abs(lo[2]-14)<.001
 checks[n+'_height']=p['targetHeightRange'][0]<=dims[2]<=p['targetHeightRange'][1] and dims[2]<280
 checks[n+'_locator_traceable']=bpy.data.objects['RivalHQ_'+n].parent.name==p['slotID']
 checks[n+'_signage']=bool(bpy.data.objects.get(n+'_Signage_Main'))
 w,d,h=p['futureUpgradeEnvelope'];x,y,z=p['position'];corners=[(x+i*w/2,y+j*d/2) for i in [-1,1] for j in [-1,1]]
 roadclear=min(min(seg(v,a,b) for v in corners for a,b in zip(road['points'],road['points'][1:]))-road['width_m']/2 for road in m['roads']);checks[n+'_growth_road_clearance']=roadclear>0
 near=min((math.dist(p['position'][:2],q['position'][:2]),q['displayName']) for q in profiles if q!=p)
 metrics[n]={'dimensions':dims,'bounds':[lo,hi],'triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in c.objects if o.type=='MESH'),'meshes':len(geo),'materials':len({mat.name for o in c.objects if o.type=='MESH' for mat in o.data.materials}),'growth_road_edge_clearance':roadclear,'nearest_rival':{'name':near[1],'distance':near[0]},'spire_distance':math.dist(p['position'][:2],[50,420])}
protected=json.load(open(R+'/preservation_baseline.json'));bad=[p for p,h in protected.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['all_protected_files_unchanged']=not bad
# Ray visibility excludes deliberately hidden source studies and retired placeholders.
for o in list(s.objects):
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  for c in list(o.users_collection):c.objects.unlink(o)
bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
def visible(cam,p,prefix):
 p=Vector(p);ndc=world_to_camera_view(s,cam,p)
 if not (0<=ndc.x<=1 and 0<=ndc.y<=1 and ndc.z>0):return False
 if cam.data.type=='ORTHO':direction=-(cam.matrix_world.to_quaternion()@Vector((0,0,1)));origin=p-direction*5000
 else:origin=cam.location;direction=(p-origin).normalized()
 hit,loc,no,i,obj,ma=s.ray_cast(dep,origin,direction,distance=(p-origin).length+2);return bool(hit and obj.name.startswith(prefix))
spire={}
for n in ['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View']:
 spire[n]=visible(bpy.data.objects[n],(50,420,285),'TheSpire_')
checks['founder_spire_crown_preserved']=spire['Founder_To_City'];checks['startup_spire_crown_preserved']=spire['TheSpire_StartupSightline']
views={'Founder District':'Founder_RivalSkyline','Startup Row':'StartupRow_Flashpoint','Venture District':'Venture_Pallas','Tech Core':'TechCore_Rivals_Aerial','Media District':'Media_RivalSkyline','Unicorn Heights':'UnicornHeights_View'}
vis={}
for label,cn in views.items():
 vis[label]={}
 for p in profiles:
  x,y,z=p['position'];h=p['currentHeight'];scores=[visible(bpy.data.objects[cn],(x+dx,y,z+h*f),p['semanticID']+'_') for f in [.35,.6,.82,.95] for dx in [-5,0,5]];num=sum(scores);vis[label][p['displayName']]={'rating':'Strong' if num>=6 else 'Partial' if num else 'Hidden','visible_samples':num,'total_samples':12,'camera':cn}
json.dump({'checks':checks,'metrics':metrics,'visibility':vis,'spire_crown_visibility':spire,'changed_original_objects':changed,'changed_protected_files':bad,'protected_file_count':len(protected)},open(R+'/verification.json','w'),indent=2);print(json.dumps(checks));assert all(checks.values()),checks
# Review renders: reload master because ray filtering above was in-memory only.
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase4_Masterplan.blend');s=bpy.context.scene;s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Atlantis_Master_Aerial','Founder_To_City','Founder_RivalSkyline','StartupRow_Flashpoint','TheSpire_StartupSightline','Venture_Pallas','Northwind_TechApproach','Media_RivalSkyline','TechCore_Rivals_Aerial','UnicornHeights_View','Rivals_Aerial']:
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True
bg=s.world.node_tree.nodes.get('Background');sun=bpy.data.objects['Review_Sun'];fill=bpy.data.objects['Review_Fill']
for n,cam in [('PallasAI','Pallas_HeroBlockout'),('NorthwindLabs','Northwind_HeroBlockout'),('Flashpoint','Flashpoint_HeroBlockout')]:
 names={o.name for o in bpy.data.collections[n+'_Blockout'].objects}
 for o in s.objects:
  if o.type=='MESH':o.hide_render=o.name not in names
 for mode,power,light in [('Day',2,.6),('Night',.18,.12)]:
  sun.data.energy=power;fill.data.energy=.35 if mode=='Day' else .08;bg.inputs['Strength'].default_value=light;s.camera=bpy.data.objects[cam];s.render.filepath=R+'/Review/'+n+'_'+mode+'.png';bpy.ops.render.render(write_still=True)
print('RIVAL_REVIEW_COMPLETE')
