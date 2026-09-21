import bpy,bmesh,json,os,sys,struct
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
name=sys.argv[sys.argv.index('--')+1]
path=R+'/'+name+'/Source/'+name+'_Higgsfield_Raw.glb'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=path)
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.context.view_layer.update()
pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)]);dims=hi-lo
raw=open(path,'rb').read();length=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+length])
audit=[]
for o in obs:
 b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.000001)
 pending=set(b.verts);groups=[]
 while pending:
  todo=[pending.pop()];size=0
  while todo:
   v=todo.pop();size+=1
   for e in v.link_edges:
    other=e.other_vert(v)
    if other in pending:pending.remove(other);todo.append(other)
  groups.append(size)
 audit.append(dict(name=o.name,position=list(o.location),rotation=list(o.rotation_euler),scale=list(o.scale),parent=o.parent.name if o.parent else None,nonmanifold=sum(not e.is_manifold for e in b.edges),zero_area=sum(f.calc_area()<1e-12 for f in b.faces),components=sorted(groups,reverse=True)));b.free()
m=dict(filename=os.path.basename(path),bytes=len(raw),dimensions=list(dims),bounds=[list(lo),list(hi)],meshes=len(obs),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),materials=len(gltf.get('materials',[])),textures=len(gltf.get('images',[])),objects=audit)
json.dump(m,open(R+'/'+name+'/Source/source_audit.json','w'),indent=2)
scale=140/dims.z if name=='TechComTower' else min(90/dims.x,60/dims.y,45/dims.z)
for o in obs:
 mat=o.matrix_world.copy()
 for v in o.data.vertices:v.co=(mat@v.co-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*scale
 o.parent=None;o.matrix_world.identity()
s=bpy.context.scene;s.world=bpy.data.worlds.new('ReviewWorld');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.8,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.6
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True
for loc,power in [((100,-150,200),3),((-100,80,150),1)]:
 d=bpy.data.lights.new('ReviewSun','SUN');d.energy=power;o=bpy.data.objects.new('ReviewSun',d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,40))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('SourceReview');o=bpy.data.objects.new('SourceReview',d);s.collection.objects.link(o);o.location=(200,-300,180);o.rotation_euler=(Vector((0,0,dims.z*scale/2))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=240 if name=='TechComTower' else 145;s.camera=o
s.render.resolution_x=1100;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.filepath=R+'/'+name+'/Review/Source_Candidate.png';bpy.ops.render.render(write_still=True)
print(json.dumps(m))
