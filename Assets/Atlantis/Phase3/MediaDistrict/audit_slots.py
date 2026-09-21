import bpy,json,os,math
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase2/VentureHall/Blender/Atlantis_Phase2_Masterplan.blend')
bpy.context.view_layer.update()
def info(o):
 return dict(name=o.name,position=list(o.location),rotation=list(o.rotation_euler),dimensions=list(o.dimensions),collections=[c.name for c in o.users_collection])
report={'slots':json.load(open(R+'/slot_contracts.json')),'district_properties':dict(bpy.data.collections['MediaDistrict'].items()),'objects':[info(o) for o in bpy.data.collections['MediaDistrict'].all_objects],'nearby_infrastructure':[info(o) for o in bpy.context.scene.objects if o.type=='MESH' and any(k in o.name for k in ['Media','Bridge'])],'relationships':{}}
for n in ['Landmark_TechComTower','Landmark_SignalTV']:
 p=bpy.data.objects[n].location
 report['relationships'][n]={'actual':info(bpy.data.objects[n]),'distance_to_spire_xy':math.hypot(p.x-50,p.y-420),'distance_to_other_hero_xy':math.hypot(25,240),'east_shore_distance':1060-p.x,'public_approach':'south -Y, connected westward to existing Media Boulevard','waterfront':'east +X; existing Media_Waterfront plaza inland of unchanged east shoreline'}
json.dump(report,open(R+'/slot_audit.json','w'),indent=2);print(json.dumps(report,indent=2))
