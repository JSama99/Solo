import bpy,os,json
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase4_Masterplan.blend');s=bpy.context.scene
for o in list(s.objects):
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  for c in list(o.users_collection):c.objects.unlink(o)
bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get()
def score(pos,x,y,h,prefix):
 count=0
 for f in [.25,.5,.75,.95]:
  for dx in [-5,0,5]:
   p=Vector((x+dx,y,14+h*f));a=Vector(pos);d=p-a;hit,loc,no,i,o,ma=s.ray_cast(dep,a,d.normalized(),distance=d.length+2);count+=bool(hit and o.name.startswith(prefix))
 return count
for name,x,y,h,xs,ys in [('PallasAI',220,300,160,[-650,-550,-450,-320],[-40,70,180,300,400]),('Flashpoint',430,-240,75,[-680,-550,-400,-220],[-500,-400,-280,-160])]:
 results=sorted([(score((cx,cy,z),x,y,h,name+'_'),(cx,cy,z)) for z in [35,65,100,150] for cx in xs for cy in ys],key=lambda v:(-v[0],v[1][2]));print(name,results[:12])
