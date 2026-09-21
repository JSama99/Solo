import bpy,json,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=R+'/Source/TheSpire_Higgsfield_Raw.glb')
obs=[o for o in bpy.context.scene.objects if o.type=='MESH']; bpy.context.view_layer.update()
v=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]; low=Vector([min(p[i] for p in v) for i in range(3)]); high=Vector([max(p[i] for p in v) for i in range(3)]); dims=high-low
m=dict(dimensions=list(dims),bounds=[list(low),list(high)],meshes=len(obs),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),materials=len(bpy.data.materials),textures=[dict(name=i.name,size=list(i.size),colorspace=i.colorspace_settings.name,alpha=i.alpha_mode,packed=bool(i.packed_file)) for i in bpy.data.images],objects=[dict(name=o.name,scale=list(o.scale),rotation=list(o.rotation_euler)) for o in obs])
json.dump(m,open(R+'/Source/source_audit.json','w'),indent=2)
for o in obs:
 mat=o.matrix_world.copy()
 for p in o.data.vertices: p.co=(mat@p.co-Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z)))*100/dims.z
 o.parent=None; o.matrix_world.identity()
scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [] else 'CYCLES'; scene.cycles.samples=16
scene.world.color=(.3,.3,.3)
def aim(o,t): o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler()
for loc,power,size in [((100,-100,150),2000000,100),((-100,-50,80),1000000,90)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new('Softbox',d);scene.collection.objects.link(o);o.location=loc;aim(o,(0,0,50))
d=bpy.data.cameras.new('Source_Review');o=bpy.data.objects.new('Source_Review',d);scene.collection.objects.link(o);o.location=(150,-210,110);aim(o,(0,0,50));d.type='ORTHO';d.ortho_scale=130;scene.camera=o
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.filepath=R+'/Review/Source_Candidate.png';bpy.ops.render.render(write_still=True)
print('SOURCE_AUDIT',json.dumps(m))
