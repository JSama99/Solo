import bpy,json,os,math
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));m=json.load(open(R+'/../../Phase0/masterplan_manifest.json'))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase3/MediaDistrict/Blender/Atlantis_Phase3_Masterplan.blend');bpy.context.view_layer.update()
def seg(p,a,b):
 p=Vector(p[:2]);a=Vector(a[:2]);b=Vector(b[:2]);d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-a-t*d).length
out=[]
for slot in m['slots']:
 if not slot['id'].startswith('RivalHQ_Slot_'):continue
 p=slot['origin'];o=bpy.data.objects[slot['id']];roads=[]
 for road in m['roads']:
  d=min(seg(p,a,b) for a,b in zip(road['points'],road['points'][1:]));roads.append({'name':road['id'],'center_distance':d,'edge_distance':d-road['width_m']/2,'class':road['collection']})
 near=[]
 for q in bpy.context.scene.objects:
  if q.type!='MESH' or q.hide_render or any(c.hide_render for c in q.users_collection) or not any('District' in c.name or c.name=='TechCore' for c in q.users_collection):continue
  if 'Boundary' in q.name:continue
  pts=[q.matrix_world@Vector(v) for v in q.bound_box];lo=[min(v[i] for v in pts) for i in range(3)];hi=[max(v[i] for v in pts) for i in range(3)];d=math.hypot(max(lo[0]-p[0],0,p[0]-hi[0]),max(lo[1]-p[1],0,p[1]-hi[1]))
  if d<130:near.append({'name':q.name,'bounds':[lo,hi],'distance':d})
 out.append({'contract':slot,'actual_position':list(o.location),'actual_rotation':list(o.rotation_euler),'associated_objects':[q.name for q in bpy.context.scene.objects if slot['id'] in q.name],'roads':sorted(roads,key=lambda x:x['edge_distance'])[:4],'nearby_buildings':sorted(near,key=lambda x:x['distance']),'landmark_distances':{n:math.dist(p[:2],pos) for n,pos in [('Spire',(50,420)),('VentureHall',(-520,110)),('TechCom',(835,220)),('SignalTV',(860,460))]}})
json.dump(out,open(R+'/slot_audit.json','w'),indent=2);print(json.dumps(out,indent=2))
