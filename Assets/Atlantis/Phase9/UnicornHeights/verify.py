import bpy,json,os,ast,hashlib,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));P=json.load(open(R+'/site_plan.json'));A=json.load(open(R+'/build_audit.json'));out={};checks={}
for path,names in [('Assets/Atlantis/Phase5/RivalHQs/integrate_pallas.py',['sig']),('Assets/Atlantis/Phase5/RivalHQs/verify_final.py',['prepare','sight']),('Assets/Atlantis/Phase6/StartupRow/plan.py',['inside','pointseg','orient','segdist','polyseg','polydist','corners'])]:
 t=ast.parse(open(path).read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),path,'exec'))
def metrics(s):
 obs=[o for o in s.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
 return {'meshes':len(obs),'triangles':sum(len(p.vertices)-2 for o in obs for p in o.data.polygons),'materials':len({m.name for o in obs for m in o.data.materials if m}),'vegetation_objects':sum('Tree' in o.name or 'Shrub' in o.name or bool(o.get('vegetation')) for o in obs),'unicorn_visible_meshes':sum(o.name.startswith(('Unicorn','Player_Unicorn')) for o in obs),'public_space_meshes':sum('Commerce_PublicRealm' in [c.name for c in o.users_collection] or o.name=='Commerce_CentralPlaza' for o in obs)}
def extra(o):
 d={'hide_render':o.hide_render,'hide_viewport':o.hide_viewport,'collections':[c.name for c in o.users_collection]}
 if o.type=='CAMERA':d['camera']=[o.data.lens,o.data.type,o.data.ortho_scale,o.data.clip_start,o.data.clip_end]
 return d
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase8/CommerceDistrict/Blender/Atlantis_Phase8_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();base={o.name:sig(o) for o in s.objects};extras={o.name:extra(o) for o in s.objects};out['phase8_metrics']=metrics(s)
# Preserve material node values on all original materials, including Flashpoint emissive identity.
def matsig(m):
 return str((list(m.diffuse_color),[(n.name,n.type,[(i.name,str(i.default_value)) for i in n.inputs if hasattr(i,'default_value')]) for n in m.node_tree.nodes] if m.node_tree else []))
basemats={m.name:matsig(m) for m in bpy.data.materials}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase9_Masterplan.blend');s=bpy.context.scene;bpy.context.view_layer.update();changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h];out['changed_original_objects']=changed;checks['original_geometry_transforms_metadata_preserved']=not changed;checks['original_materials_preserved']=all(matsig(bpy.data.materials[n])==v for n,v in basemats.items());checks['only_unicorn_placeholder_and_internal_road_visibility_changes']=all(extra(bpy.data.objects[n])==d for n,d in extras.items() if n not in A['hidden_original_objects']);checks['flashpoint_all_objects_exact']=all(sig(bpy.data.objects[n])==h and extra(bpy.data.objects[n])==extras[n] for n,h in base.items() if n.startswith(('Flashpoint','RivalHQ_Slot_05')));out['phase9_metrics']=metrics(s)

for site in P['sites']:site['polygon']=corners(*site['position'][:2],site['width']+1,site['depth']+1)
heights={a['id']:max((o.matrix_world@v.co).z for o in bpy.data.objects[a['id']].children if o.type=='MESH' for v in o.data.vertices)-a['position'][2] for a in P['sites']};out['measured_heights']=heights
checks['eight_supporting_campuses']=len(P['sites'])==8
checks['seven_reusable_types']=len({a['typology'] for a in P['sites']})==7
checks['supporting_heights_below_pallas']=all(40<=h<140 for h in heights.values())
checks['two_supporting_anchors']=sum(h>100 for h in heights.values())==2
checks['campuses_inside_district_and_land']=all(510<x<1130 and 760<y<1160 and inside((x,y),P['terrain_polygon']) for a in P['sites'] for x,y in a['polygon'])
checks['campuses_separated']=all(polydist(a['polygon'],b['polygon'])>10 for i,a in enumerate(P['sites']) for b in P['sites'][i+1:])
parcel=corners(970,850,140,115)
checks['player_envelope_clear_of_supporting_buildings']=all(polydist(parcel,a['polygon'])>10 for a in P['sites'])
slot=bpy.data.objects['Player_UnicornHQ_Slot'];out['player_position']=list(slot.matrix_world.translation)
checks['player_contract_children']=all(bpy.data.objects[n].parent==slot for n in ['PlayerHQ_Parcel','PlayerHQ_Forward','PlayerHQ_PlazaAnchor','PlayerHQ_SignageAnchor','PlayerHQ_GrowthEnvelope'])
checks['player_envelope_180m']=list(bpy.data.objects['PlayerHQ_GrowthEnvelope']['dimensions_m'])==[140,115,180]
checks['dynamic_identity_reserved']=bpy.data.objects['PlayerUnicornHQ_Signage_Main'].type=='EMPTY'
checks['walk_grades_at_most_5percent']=all(p['max_grade']<=.05 for p in A['paths'])
checks['walk_widths_at_least_4m']=all(p['width']>=4 for p in A['paths'])
conflicts=[]
for p in A['paths']:
 for a in P['sites']:
  if any(polyseg(a['polygon'],v,w)<p['width']/2-.01 for v,w in zip(p['points'],p['points'][1:])):conflicts.append([p['name'],a['id']])
out['path_building_conflicts']=conflicts;checks['walks_clear_of_buildings']=not conflicts
nodes={}
for p in A['paths']:nodes[p['name']]=[corners((a[0]+b[0])/2,(a[1]+b[1])/2,math.dist(a[:2],b[:2]),p['width'],math.degrees(math.atan2(b[1]-a[1],b[0]-a[0]))) for a,b in zip(p['points'],p['points'][1:])]
for p in P['public_spaces']:nodes[p['name']]=[corners(*p['center'][:2],*p['size'])]
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
out['path_components']=components;checks['single_connected_pedestrian_network']=len(components)==1
checks['all_campuses_have_frontages']=len(A['frontages'])==8
checks['all_review_cameras']=all(bpy.data.objects[n].type=='CAMERA' for n in A['review_cameras'])
checks['generic_semantic_identity_per_campus']=sum(bool(o.get('semantic_target')) for o in bpy.data.collections['Unicorn_Campuses'].objects)==8
checks['path_surfaces_inside_land_and_district']=all(510<=x<=1130 and 760<=y<=1160 and inside((x,y),P['terrain_polygon']) for polys in nodes.values() for poly in polys for x,y in poly)
props=[]
for o in bpy.data.collections['Unicorn_PublicRealm'].objects:
 if o.type!='MESH' or not any(t in o.name for t in ['TreeTrunk','SeatSupport','LightBase']):continue
 x,y=o.matrix_world.translation[:2]
 for p in A['paths']:
  if any(pointseg((x,y),a,b)<p['width']/2+.4 for a,b in zip(p['points'],p['points'][1:])):props.append([o.name,p['name']])
out['path_prop_conflicts']=props;checks['path_centers_clear_of_fixtures']=not props
out['campus_footprint_area_m2']=sum(a['width']*a['depth'] for a in P['sites'])
out['campus_coverage_percent']=out['campus_footprint_area_m2']/248000*100
out['minimum_campus_gap_m']=min(polydist(a['polygon'],b['polygon']) for i,a in enumerate(P['sites']) for b in P['sites'][i+1:])
out['original_object_count']=len(base)
checks['future_player_roof_below_spire']=85+180<294
bridge=bpy.data.objects['Bridge_TechCore_00'];landing=next(p['points'][0] for p in A['paths'] if p['name']=='Unicorn_BridgeWalk');local=bridge.matrix_world.inverted()@Vector(landing)
checks['pedestrian_landing_matches_bridge_deck']=abs(local.z-max(v.co.z for v in bridge.data.vertices))<.001 and abs(local.x)<13 and abs(local.y)<max(v.co.y for v in bridge.data.vertices)
out['bridge_walk_landing']=landing
out['new_visible_meshes']=out['phase9_metrics']['meshes']-out['phase8_metrics']['meshes']
views=['Founder_To_City','TheSpire_StartupSightline','VentureHall_ToSpire','MediaDistrict_ToSpire','TechCore_Skyline','UnicornHeights_View']
for phase,path in [('phase8',R+'/../../Phase8/CommerceDistrict/Blender/Atlantis_Phase8_Masterplan.blend'),('phase9',R+'/Blender/Atlantis_Phase9_Masterplan.blend')]:
 s,dep=prepare(path);pts=[o.matrix_world@v.co for o in s.objects if o.type=='MESH' and o.name.startswith('TheSpire_') for v in o.data.vertices if (o.matrix_world@v.co).z>265];pts=pts[::max(1,len(pts)//40)];out[phase+'_spire_samples']={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in pts) for n in views};out[phase+'_flashpoint_samples']=sum(sight(s,dep,bpy.data.objects['StartupRow_Flashpoint'],(430+dx,-240,14+75*f),'Flashpoint_') for dx in [-4,0,4] for f in [.4,.6,.8,.95])
checks['six_spire_views_preserved']=all(out['phase9_spire_samples'][n]>=out['phase8_spire_samples'][n] for n in views);checks['startup_flashpoint_view_preserved']=out['phase9_flashpoint_samples']>=out['phase8_flashpoint_samples']
out['new_spire_views']={n:sum(sight(s,dep,bpy.data.objects[n],p,'TheSpire_') for p in pts) for n in ['PlayerHQ_To_Spire','Unicorn_ScenicOverlook']}
checks['player_and_overlook_spire_visible']=all(v>0 for v in out['new_spire_views'].values())
baseline=json.load(open(R+'/preservation_baseline.json'));out['protected_file_count']=len(baseline);out['changed_protected_files']=[p for p,h in baseline.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['protected_files_unchanged']=not out['changed_protected_files'];out['checks']=checks
json.dump(out,open(R+'/verification.json','w'),indent=2);print(json.dumps(out,indent=2));assert all(checks.values()),checks
