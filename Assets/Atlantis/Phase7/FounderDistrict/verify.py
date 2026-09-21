import bpy,json,os,ast,hashlib,math,re
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));A=json.load(open(R+'/build_audit.json'));out={};checks={}
for path,names in [('Assets/Atlantis/Phase5/RivalHQs/integrate_pallas.py',['sig']),('Assets/Atlantis/Phase5/RivalHQs/verify_final.py',['prepare','sight'])]:
 t=ast.parse(open(path).read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),path,'exec'))
def metrics(s):
 obs=[o for o in s.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
 return {'visible_meshes':len(obs),'visible_triangles':sum(len(p.vertices)-2 for o in obs for p in o.data.polygons),'used_materials':len({m.name for o in obs for m in o.data.materials if m}),'vegetation_objects':sum(bool(re.search(r'(^|_)(tree|shrub|hedge|plant)',o.name,re.I)) or any(m and ('Planting' in m.name or m.name=='Founder_leaf') for m in o.data.materials) for o in obs)}
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase6/StartupRow/Blender/Atlantis_Phase6_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();base={o.name:sig(o) for o in s.objects};oldhide={o.name:o.hide_render for o in s.objects};oldcam={o.name:(o.data.lens,o.data.type,o.data.ortho_scale) for o in s.objects if o.type=='CAMERA'};out['phase6_metrics']=metrics(s)
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase7_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update()
changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h];checks['original_geometry_transforms_metadata_preserved']=not changed;out['changed_original_objects']=changed
checks['old_cameras_preserved']=all((bpy.data.objects[n].data.lens,bpy.data.objects[n].data.type,bpy.data.objects[n].data.ortho_scale)==v for n,v in oldcam.items())
checks['only_authorized_visibility_changes']=all(o.hide_render==oldhide[o.name] or o.name in A['hidden_original_objects'] for o in s.objects if o.name in oldhide)
out['phase7_metrics']=metrics(s);checks['seven_building_types']=len({a['typology'] for a in A['sites']})==7
checks['buildings_within_founder_bounds']=all(-1100<a['position'][0]-a['width']/2 and a['position'][0]+a['width']/2<-600 and -1065<a['position'][1]-a['depth']/2 and a['position'][1]+a['depth']/2<-635 for a in A['sites'])
checks['heights_1_to_4_floors']=all(1<=a['floors']<=4 and a['height']<14 for a in A['sites'])
checks['all_walk_grades_below_5_percent']=all(p['max_grade']<=.05 for p in A['paths']);out['steep_paths']=[(p['name'],p['max_grade']) for p in A['paths'] if p['max_grade']>.05]
checks['walk_widths_at_least_2m']=all(p['width']>=2 for p in A['paths'])
checks['one_frontage_per_building']=sum(p['name'].startswith('Founder_Frontage') for p in A['paths'])==len(A['sites'])
# Exact axis-aligned footprint tests (buildings are rotated only 0/180 degrees).
def segrect(a,b,lo,hi):
 t0,t1=0.,1.
 for k in range(2):
  d=b[k]-a[k]
  if abs(d)<1e-9:
   if not lo[k]<=a[k]<=hi[k]:return False
  else:
   u,v=(lo[k]-a[k])/d,(hi[k]-a[k])/d
   if u>v:u,v=v,u
   t0=max(t0,u);t1=min(t1,v)
   if t0>t1:return False
 return True
collisions=[]
for p in A['paths']:
 for site in A['sites']:
  x,y,z=site['position'];pad=p['width']/2+.2;lo=(x-site['width']/2-pad,y-site['depth']/2-pad);hi=(x+site['width']/2+pad,y+site['depth']/2+pad)
  if any(segrect(a,b,lo,hi) for a,b in zip(p['points'],p['points'][1:])):collisions.append([p['name'],site['name']])
out['walk_building_conflicts']=collisions;checks['walking_lanes_clear_of_buildings']=not collisions
checks['garage_envelope_clear_of_buildings']=all(not (a['position'][0]+a['width']/2>-915 and a['position'][0]-a['width']/2<-835 and a['position'][1]+a['depth']/2>-1056 and a['position'][1]-a['depth']/2<-1000) for a in A['sites'])

oldpaths=json.load(open(R+'/../../Phase6/StartupRow/build_audit.json'))['frontage_paths']
main=next(p for p in A['paths'] if p['name']=='Founder_ToStartup_Walk')
checks['startup_endpoint_matches_existing_walk']=any(math.dist(main['points'][-1],p['points'][-1])<.001 for p in oldpaths)
prop_conflicts=[]
for o in bpy.data.collections['Founder_PublicRealm'].objects:
 if not any(t in o.name for t in ['TreeTrunk','StreetlightPole','UtilityCabinet','RecyclingEnclosure','LowFence','GreenBench']):continue
 pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=[min(v[i] for v in pts) for i in range(2)];hi=[max(v[i] for v in pts) for i in range(2)]
 for p in A['paths']:
  if any(segrect(a,b,[v-p['width']/2 for v in lo],[v+p['width']/2 for v in hi]) for a,b in zip(p['points'],p['points'][1:])):prop_conflicts.append([o.name,p['name']])
out['walk_prop_conflicts']=prop_conflicts;checks['walks_clear_of_solid_props']=not prop_conflicts

checks['slot_unchanged']=list(bpy.data.objects['FounderGarage_Slot'].location)==[-875,-1030,8]
checks['services_one_to_three']=1<=sum(a['typology'] in ['Founder_CornerStore_A','Founder_MixedUseEdge_A'] for a in A['sites'])<=3
checks['eight_review_cameras']=all(bpy.data.objects.get(n) for n in A['review_cameras'])
views=['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View']
for phase,path in [('phase6',R+'/../../Phase6/StartupRow/Blender/Atlantis_Phase6_Masterplan.blend'),('phase7',R+'/Blender/Atlantis_Phase7_Masterplan.blend')]:
 s,dep=prepare(path);pts=[o.matrix_world@v.co for o in s.objects if o.type=='MESH' and o.name.startswith('TheSpire_') for v in o.data.vertices if (o.matrix_world@v.co).z>265];pts=pts[::max(1,len(pts)//40)];out[phase+'_spire_samples']={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in pts) for n in views};out[phase+'_flashpoint_hits']=sum(sight(s,dep,bpy.data.objects['StartupRow_Flashpoint'],(430+dx,-240,14+75*f),'Flashpoint_') for dx in [-4,0,4] for f in [.4,.6,.8,.95])
checks['six_spire_views_preserved']=all(out['phase7_spire_samples'][n]>=out['phase6_spire_samples'][n] for n in views);checks['flashpoint_view_preserved']=out['phase7_flashpoint_hits']>=out['phase6_flashpoint_hits']
basefiles=json.load(open(R+'/preservation_baseline.json'));out['changed_protected_files']=[p for p,h in basefiles.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];out['protected_file_count']=len(basefiles);checks['protected_files_unchanged']=not out['changed_protected_files'];out['checks']=checks
json.dump(out,open(R+'/verification.json','w'),indent=2);print(json.dumps(out,indent=2));assert all(checks.values()),checks
