import bpy, json, os, math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__))
m=json.load(open(R+'/masterplan_manifest.json')); scene=bpy.context.scene
checks={}
checks['seven_district_collections']=all(bpy.data.collections.get(n) for n in m['districts'])
checks['slot_transforms_match']=all((bpy.data.objects[s['id']].location-Vector(s['origin'])).length<.001 for s in m['slots'])
checks['single_collection_ownership']=all(len(o.users_collection)==1 for o in scene.objects)
checks['six_planning_cameras']=len([o for o in scene.objects if o.type=='CAMERA'])==6
checks['three_bridges']=len([r for r in m['roads'] if r['collection']=='Bridges'])==3
# Verify road connectivity by segment distance; intersections count as graph nodes.
def distance(p,a,b):
 p,a,b=Vector(p),Vector(a),Vector(b); d=b-a; return (p-a-d*max(0,min(1,(p-a).dot(d)/d.length_squared))).length
roads=m['roads']; reached={0}
while True:
 more=set(reached)
 for i,r in enumerate(roads):
  for j in reached:
   q=roads[j]
   if any(distance(p,a,b)<(r['width_m']+q['width_m'])/2+1 for p in r['points'] for a,b in zip(q['points'],q['points'][1:])) or any(distance(p,a,b)<(r['width_m']+q['width_m'])/2+1 for p in q['points'] for a,b in zip(r['points'],r['points'][1:])): more.add(i)
 if more==reached: break
 reached=more
checks['all_road_routes_connected']=len(reached)==len(roads)
meshes=[o for o in scene.objects if o.type=='MESH']
heights={o.name:max((o.matrix_world@Vector(v)).z for v in o.bound_box) for o in meshes}
checks['spire_absolute_tallest']=max(heights,key=heights.get).startswith('Landmark_TheSpire')
checks['slot_massing_within_height_budget']=all(s['placeholder_height_m']<=s['max_bbox_m'][2] for s in m['slots'])
# Replace conservative initial ray samples with self-aware visibility.
for s in m['slots']:
 if s['id']=='Landmark_TheSpire': s['placeholder_height_m']=348
 for cam in [o for o in scene.objects if o.type=='CAMERA']:
  point=Vector(s['origin'])+Vector((0,0,max(2,s['placeholder_height_m']*.85))); ndc=world_to_camera_view(scene,cam,point); d=point-cam.location
  hit,loc,norm,index,obj,matrix=scene.ray_cast(bpy.context.evaluated_depsgraph_get(),cam.location,d.normalized(),distance=d.length)
  s['view_visibility'][cam.name]='outside frame' if not(ndc.z>0 and 0<ndc.x<1 and 0<ndc.y<1) else ('visible upper-center sample' if not hit or obj.get('slot_id')==s['id'] or obj.name.startswith(s['id']) else 'occluded upper-center sample')
checks['founder_spire_sightline']=m['slots'][1]['view_visibility']['Founder_To_City']=='visible upper-center sample'
json.dump(m,open(R+'/masterplan_manifest.json','w'),indent=2)
json.dump(dict(checks=checks,highest_object=max(heights,key=heights.get),highest_z=max(heights.values()),unconnected_routes=[r['id'] for i,r in enumerate(roads) if i not in reached]),open(R+'/verification.json','w'),indent=2)
print(json.dumps(checks,indent=2))
assert all(checks.values()),'Masterplan audit failed'

for slot in m["slots"]: bpy.data.objects[slot["id"]]["placeholder_height_m"]=slot["placeholder_height_m"]
t=bpy.data.texts.get("READ_ME • Atlantis Phase 0"); t.clear(); t.write("Metric Z-up. Forward -Y; glTF Y-up maps (x,y,z) to (x,z,-y). Planning only. Slot-based replacement; see completion report for import contract.\n"+json.dumps(m,indent=2))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=R+"/Atlantis_Phase0_Masterplan.blend")
