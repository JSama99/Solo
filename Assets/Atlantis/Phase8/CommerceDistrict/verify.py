import bpy,json,os,ast,hashlib,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));P=json.load(open(R+'/site_plan.json'));A=json.load(open(R+'/build_audit.json'));out={};checks={}
for path,names in [('Assets/Atlantis/Phase5/RivalHQs/integrate_pallas.py',['sig']),('Assets/Atlantis/Phase5/RivalHQs/verify_final.py',['prepare','sight']),('Assets/Atlantis/Phase6/StartupRow/plan.py',['inside','pointseg','orient','segdist','polyseg','polydist','corners'])]:
 t=ast.parse(open(path).read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),path,'exec'))
def metrics(s):
 obs=[o for o in s.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
 return {'meshes':len(obs),'triangles':sum(len(p.vertices)-2 for o in obs for p in o.data.polygons),'materials':len({m.name for o in obs for m in o.data.materials if m}),'public_space_meshes':sum('Commerce_PublicRealm' in [c.name for c in o.users_collection] or o.name=='Commerce_CentralPlaza' for o in obs)}
def extra(o):
 d={'hide_render':o.hide_render,'hide_viewport':o.hide_viewport,'collections':[c.name for c in o.users_collection]}
 if o.type=='CAMERA':d['camera']=[o.data.lens,o.data.type,o.data.ortho_scale,o.data.clip_start,o.data.clip_end]
 return d
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase7/FounderDistrict/Blender/Atlantis_Phase7_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();base={o.name:sig(o) for o in s.objects};extras={o.name:extra(o) for o in s.objects};out['phase7_metrics']=metrics(s)
# Preserve material node values on all original materials, including Flashpoint emissive identity.
def matsig(m):
 return str((list(m.diffuse_color),[(n.name,n.type,[(i.name,str(i.default_value)) for i in n.inputs if hasattr(i,'default_value')]) for n in m.node_tree.nodes] if m.node_tree else []))
basemats={m.name:matsig(m) for m in bpy.data.materials}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase8_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h];out['changed_original_objects']=changed;checks['original_geometry_transforms_metadata_preserved']=not changed;checks['original_materials_preserved']=all(matsig(bpy.data.materials[n])==v for n,v in basemats.items());checks['only_commerce_placeholder_visibility_changes']=all(extra(bpy.data.objects[n])==d for n,d in extras.items() if n not in A['hidden_original_objects']);checks['flashpoint_all_objects_exact']=all(sig(bpy.data.objects[n])==h and extra(bpy.data.objects[n])==extras[n] for n,h in base.items() if n.startswith(('Flashpoint','RivalHQ_Slot_05')));out['phase8_metrics']=metrics(s)
out['building_measured_heights']={a['id']:max((o.matrix_world@v.co).z for o in bpy.data.objects[a['id']].children if o.type=='MESH' for v in o.data.vertices)-a['position'][2] for a in P['sites']}
checks['ten_kit_types']=len({a['typology'] for a in P['sites']})==10;checks['three_hotels']=sum('Hotel' in a['typology'] for a in P['sites'])==3;checks['two_anchors_90_to_120m']=sum(90<=a['height']<=120 for a in P['sites'])==2;checks['all_buildings_below_pallas']=all(a['height']<160 for a in P['sites']);checks['one_conference_venue']=sum('Conference' in a['typology'] for a in P['sites'])==1
checks['buildings_inside_commerce']=all(50<x<550 and -360<y<-20 for a in P['sites'] for x,y in a['polygon']);checks['all_frontages_connected']=len(A['frontages'])==len(P['sites']) and not A['missing_frontages'];checks['walk_grades_at_most_5percent']=all(p['max_grade']<=.050001 for p in A['paths']);checks['walks_at_least_4m']=all(p['width']>=4 for p in A['paths']);checks['vehicle_crossing_ramps_at_most_5percent']=all(c['rise']/c['ramp_length']<=.05 for c in A['crossings'])
conflicts=[]
for p in A['paths']:
 for a in P['sites']:
  own=p['name']=='Commerce_Frontage_'+a['id']
  if not own and any(polyseg(a['polygon'],v,w)<p['width']/2-.01 for v,w in zip(p['points'],p['points'][1:])):conflicts.append([p['name'],a['id']])
out['walk_building_conflicts']=conflicts;checks['walks_clear_of_buildings']=not conflicts
parcel=corners(430,-240,74.96,59.96);overlap=[]
for o in bpy.data.collections['Commerce_PublicRealm'].objects:
 if o.type!='MESH':continue
 for face in o.data.polygons:
  pts=[o.matrix_world@o.data.vertices[i].co for i in face.vertices];poly=[(v.x,v.y) for v in pts]
  area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))
  if area>.00001 and polydist(poly,parcel)<.001:overlap.append(o.name);break
out['flashpoint_parcel_overlaps']=overlap;checks['flashpoint_parcel_clear_of_new_geometry']=not overlap
prop=[]
for o in bpy.data.collections['Commerce_PublicRealm'].objects:
 if not any(t in o.name for t in ['Planter','Seat','LightPole']):continue
 pts=[o.matrix_world@Vector(c) for c in o.bound_box];poly=corners((min(v.x for v in pts)+max(v.x for v in pts))/2,(min(v.y for v in pts)+max(v.y for v in pts))/2,max(v.x for v in pts)-min(v.x for v in pts),max(v.y for v in pts)-min(v.y for v in pts))
 for p in A['paths']:
  if any(polyseg(poly,a,b)<p['width']/2 for a,b in zip(p['points'],p['points'][1:])):prop.append([o.name,p['name']])
out['walk_prop_conflicts']=prop;checks['walks_clear_of_props']=not prop
# Polygon connectivity includes the full widths of walks and public spaces.
nodes={}
for path in A['paths']:
 nodes[path['name']]=[corners((a[0]+b[0])/2,(a[1]+b[1])/2,math.dist(a[:2],b[:2]),path['width'],math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))) for a,b in zip(path['points'],path['points'][1:])]
for space in P['public_spaces']:nodes[space['name']]=[corners(*space['center'][:2],*space['size'])]
graph={n:set() for n in nodes}
for i,n in enumerate(nodes):
 for m in list(nodes)[i+1:]:
  if any(polydist(a,b)<.01 for a in nodes[n] for b in nodes[m]):graph[n].add(m);graph[m].add(n)
seen=set();components=[]
for n in graph:
 if n in seen:continue
 stack=[n];component=[]
 while stack:
  k=stack.pop()
  if k in seen:continue
  seen.add(k);component.append(k);stack+=list(graph[k]-seen)
 components.append(component)
out['pedestrian_network_components']=components;checks['single_connected_pedestrian_network']=len(components)==1
checks['all_review_cameras']=all(bpy.data.objects.get(n) and bpy.data.objects[n].type=='CAMERA' for n in A['review_cameras']);checks['separate_signage_per_building']=sum(bool(o.get('semantic_target')) for o in bpy.data.collections['Commerce_Buildings'].objects)==len(P['sites'])
views=['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View']
for phase,path in [('phase7',R+'/../../Phase7/FounderDistrict/Blender/Atlantis_Phase7_Masterplan.blend'),('phase8',R+'/Blender/Atlantis_Phase8_Masterplan.blend')]:
 s,dep=prepare(path);pts=[o.matrix_world@v.co for o in s.objects if o.type=='MESH' and o.name.startswith('TheSpire_') for v in o.data.vertices if (o.matrix_world@v.co).z>265];pts=pts[::max(1,len(pts)//40)];out[phase+'_spire_samples']={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in pts) for n in views};out[phase+'_flashpoint_samples']=sum(sight(s,dep,bpy.data.objects['StartupRow_Flashpoint'],(430+dx,-240,14+75*f),'Flashpoint_') for dx in [-4,0,4] for f in [.4,.6,.8,.95])
checks['six_spire_views_preserved']=all(out['phase8_spire_samples'][n]>=out['phase7_spire_samples'][n] for n in views);checks['startup_flashpoint_view_preserved']=out['phase8_flashpoint_samples']>=out['phase7_flashpoint_samples']
baseline=json.load(open(R+'/preservation_baseline.json'));out['protected_file_count']=len(baseline);out['changed_protected_files']=[p for p,h in baseline.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['protected_files_unchanged']=not out['changed_protected_files'];out['checks']=checks
json.dump(out,open(R+'/verification.json','w'),indent=2);print(json.dumps(out,indent=2));assert all(checks.values()),checks
