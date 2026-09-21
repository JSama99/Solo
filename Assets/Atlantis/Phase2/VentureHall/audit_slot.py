import bpy,json,os,math
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase1/TheSpire/Blender/Atlantis_Phase1_Masterplan.blend')
p=bpy.data.objects['Landmark_VentureHall'].location
blocks=[dict(name=o.name,position=list(o.location),dimensions=list(o.dimensions),distance_xy=math.hypot(o.location.x-p.x,o.location.y-p.y)) for o in bpy.data.collections['VentureDistrict'].objects if '_Block_' in o.name]
report=dict(anchor=list(p),rotation=list(bpy.data.objects['Landmark_VentureHall'].rotation_euler),blocks=sorted(blocks,key=lambda v:v['distance_xy']),plaza=dict(name='Venture_Forum',position=list(bpy.data.objects['Venture_Forum'].location),dimensions=list(bpy.data.objects['Venture_Forum'].dimensions)),spire_distance=math.hypot(50-p.x,420-p.y),founder_distance=math.hypot(-875-p.x,-1030-p.y))
json.dump(report,open(R+'/slot_audit.json','w'),indent=2);print(json.dumps(report))
