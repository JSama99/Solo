import bpy,json,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase5/RivalHQs/Blender/Atlantis_Phase5_Masterplan.blend');bpy.context.view_layer.update();s=bpy.context.scene
rows=[]
for o in s.objects:
 if o.name.startswith(('Startup','RivalHQ_Slot_01','FounderGarage','Progression_Startup','Founder_Local','AtlantisBridge_Main')):
  d={'name':o.name,'type':o.type,'position':list(o.matrix_world.translation),'dimensions':list(o.dimensions),'collections':[c.name for c in o.users_collection],'hidden':o.hide_render,'props':{k:str(v) for k,v in o.items()}}
  if o.type=='MESH':
   pts=[o.matrix_world@Vector(c) for c in o.bound_box];d['bounds']=[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]
  rows.append(d)
visible=[o for o in s.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
a={'objects':rows,'visible_meshes':len(visible),'visible_triangles':sum(len(p.vertices)-2 for o in visible for p in o.data.polygons),'all_meshes':sum(o.type=='MESH' for o in s.objects),'all_triangles_including_staging':sum(len(p.vertices)-2 for o in s.objects if o.type=='MESH' for p in o.data.polygons)}
json.dump(a,open(R+'/prior_state.json','w'),indent=2);print(json.dumps(a,indent=2))
