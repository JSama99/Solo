import bpy,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase9_Masterplan.blend');bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
 if o.type!='MESH' or o.hide_render or any(c.hide_render for c in o.users_collection):continue
 pts=[o.matrix_world@Vector(c) for c in o.bound_box];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 if lo[0]>450 and lo[1]>750 and hi[0]-lo[0]>150:print(o.name,lo,hi)
