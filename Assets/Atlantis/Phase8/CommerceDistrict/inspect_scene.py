import bpy,json,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase7/FounderDistrict/Blender/Atlantis_Phase7_Masterplan.blend');bpy.context.view_layer.update()
rows=[]
for o in bpy.context.scene.objects:
 if o.name.startswith(('Commerce','Flashpoint','RivalHQ_Slot_05')) or o.type=='CAMERA' or ('Terrain' in [c.name for c in o.users_collection]):
  d={'name':o.name,'type':o.type,'position':list(o.matrix_world.translation),'dimensions':list(o.dimensions),'hidden':o.hide_render or any(c.hide_render for c in o.users_collection),'props':{k:str(v) for k,v in o.items()}}
  if o.type=='MESH':
   pts=[o.matrix_world@Vector(c) for c in o.bound_box];d['bounds']=[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]
  rows.append(d)
json.dump(rows,open(R+'/prior_state.json','w'),indent=2)
print('PLACEHOLDERS',sum(o['name'].startswith('CommerceDistrict_Block_') for o in rows))
for o in rows:
 if not o['name'].startswith('CommerceDistrict_Block_') and o['type']!='CAMERA':print(o)
