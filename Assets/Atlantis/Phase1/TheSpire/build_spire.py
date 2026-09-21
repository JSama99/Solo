import bpy,bmesh,json,os,math
from mathutils import Vector,Matrix
R=os.path.dirname(os.path.abspath(__file__)); BASE=os.path.abspath(R+'/../../../Phase0/Atlantis_Phase0_Masterplan.blend')
# Actual path resolved from Phase1/TheSpire.
BASE=os.path.abspath(R+'/../../Phase0/Atlantis_Phase0_Masterplan.blend')
bpy.ops.wm.open_mainfile(filepath=BASE)
scene=bpy.context.scene
baseline={o.name:dict(matrix=[list(r) for r in o.matrix_world],verts=len(o.data.vertices) if o.type=='MESH' else None) for o in scene.objects}
def col(n,p):
 c=bpy.data.collections.new(n);p.children.link(c);return c
A=bpy.data.collections['Atlantis']; stage=col('AssetStaging',A); source=col('TheSpire_Source',stage); hero=col('HeroLandmarks',bpy.data.collections['TechCore']); final=col('TheSpire',hero)
pre=set(scene.objects);bpy.ops.import_scene.gltf(filepath=R+'/Source/TheSpire_Higgsfield_Raw.glb'); imported=list(set(scene.objects)-pre)
for o in imported:
 for c in list(o.users_collection):c.objects.unlink(o)
 source.objects.link(o)
source.hide_render=True;source.hide_viewport=True
raw=next(o for o in imported if o.type=='MESH');o=raw.copy();o.data=raw.data.copy();final.objects.link(o);o.name='TheSpire_GeneratedShaft';o.parent=None;o.matrix_world=Matrix.Identity(4)
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.transform(bm,matrix=raw.matrix_world,verts=list(bm.verts));bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,-.4),plane_no=(0,0,1),clear_inner=True)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000025)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
# Retain the largest connected architectural component.
seen=set();comps=[]
for v in bm.verts:
 if v in seen:continue
 group=set([v]);seen.add(v)
 stack=[v]
 while stack:
  cur=stack.pop()
  for e in cur.link_edges:
   q=e.other_vert(cur)
   if q not in seen:seen.add(q);group.add(q);stack.append(q)
 comps.append(group)
keep=max(comps,key=len);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v not in keep],context='VERTS')
boundary=[e for e in bm.edges if e.is_boundary];bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
for v in bm.verts:v.co=(v.co-Vector((0,0,-.4)))*300+Vector((0,0,10))
bm.to_mesh(o.data);bm.free();o.data.update()
# A bounded 280 m composition: 270 m generated shaft on 10 m podium.
def material(n,color,metal=0,rough=.35,emission=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
glass=material('Spire • blue glazing',(.045,.15,.21),.65,.23);metal=material('Spire • satin titanium',(.48,.57,.63),.8,.3);stone=material('Spire • podium limestone',(.48,.46,.4),0,.65);accent=material('Spire • restrained teal',(.035,.55,.65),.4,.3,2)
o.data.materials.clear();o.data.materials.append(glass);o.data.materials.append(metal)
for p in o.data.polygons:p.material_index=1 if abs(p.normal.z)>.65 else 0;p.use_smooth=True
bpy.context.view_layer.objects.active=o;o.select_set(True)
mod=o.modifiers.new('Remove low value triangulation','DECIMATE');mod.ratio=.8;bpy.ops.object.modifier_apply(modifier=mod.name)
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.65);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001);bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
group=o.vertex_groups.new(name='FacadeSmoothing');group.add([v.index for v in o.data.vertices if 15<v.co.z<270],1,'REPLACE');sm=o.modifiers.new('Smooth generated facade noise','SMOOTH');sm.factor=.6;sm.iterations=8;sm.vertex_group=group.name;bpy.ops.object.modifier_apply(modifier=sm.name)
bm=bmesh.new();bm.from_mesh(o.data)
for attempt in range(4):
 bad=[e for e in bm.edges if not e.is_manifold]
 if not bad:break
 bmesh.ops.delete(bm,geom=list({v for e in bad for v in e.verts}),context='VERTS');bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
# Source-derived architectural retopology: retain measured taper and crown,
# replace noisy triangle-level facade with coherent vertical surface strips.
import statistics
sv=[v.co.copy() for v in o.data.vertices];N=32;cx=(min(v.x for v in sv)+max(v.x for v in sv))/2;cy=(min(v.y for v in sv)+max(v.y for v in sv))/2
angles=[2*math.pi*j/N for j in range(N)]
def angular(v,a):return abs((math.atan2(v.y-cy,v.x-cx)-a+math.pi)%(2*math.pi)-math.pi)
def radius(z,a):
 pool=[math.hypot(v.x-cx,v.y-cy) for v in sv if abs(v.z-z)<9 and angular(v,a)<math.pi/12]
 return statistics.median(pool) if pool else 20
levels=[10,35,70,105,140,175,210,240,258];rv=[]
for z in levels:
 radii=[radius(z,a) for a in angles]
 for j,a in enumerate(angles):
  rr=(radii[(j-1)%N]+radii[j]*2+radii[(j+1)%N])/4;rv.append((cx+rr*math.cos(a),cy+rr*math.sin(a),z))
for j,a in enumerate(angles):
 pool=[v.z for v in sv if v.z>255 and angular(v,a)<math.pi/10];z=max(pool) if pool else 270;rr=radius(min(z-3,270),a);rv.append((cx+rr*math.cos(a),cy+rr*math.sin(a),z))
rf=[tuple(range(N-1,-1,-1))]
for i in range(len(levels)):
 for j in range(N):rf.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
rf.append(tuple(range(len(rv)-N,len(rv))))
me=bpy.data.meshes.new('TheSpire_SourceDerivedEnvelope');me.from_pydata(rv,[],rf);me.update();o.data=me;me.materials.append(glass);me.materials.append(metal)
for p in me.polygons:p.material_index=1 if len(p.vertices)>4 or (p.index-1)%N in [0,8,16,24] else 0;p.use_smooth=False
bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
root=bpy.data.objects.new('TheSpire_AssetRoot',None);final.objects.link(root);root.location=(50,420,14);root['slot_id']='Landmark_TheSpire';root['forward']='-Y';root['district']='TechCore';o.parent=root
def box(n,loc,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,0));a=bpy.context.object;a.name=n
 for c in list(a.users_collection):c.objects.unlink(a)
 final.objects.link(a);a.parent=root;a.location=loc
 for v in a.data.vertices:v.co.x*=size[0];v.co.y*=size[1];v.co.z*=size[2]
 a.data.materials.append(mat);return a
box('TheSpire_PodiumLower',(0,0,2),(68,66,4),stone);box('TheSpire_PodiumUpper',(0,0,7),(62,58,6),stone)
box('TheSpire_Entrance',(0,-30,5),(18,5,6),glass);box('TheSpire_EntranceCanopy',(0,-30.5,8.5),(22,7,1),metal)
# Restrained vertical fins follow measured generated envelope at each height.
def fin(n,points,width,depth,mat):
 vs=[]
 for x,y,z in points:vs.extend([(x-width/2,y-depth/2,z),(x+width/2,y-depth/2,z),(x+width/2,y+depth/2,z),(x-width/2,y+depth/2,z)])
 fs=[(3,2,1,0)]
 for i in range(len(points)-1):
  for j in range(4):fs.append((4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j))
 fs.append(tuple(range(len(vs)-4,len(vs))));me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();a=bpy.data.objects.new(n,me);final.objects.link(a);a.parent=root;me.materials.append(mat)
verts=[v.co for v in o.data.vertices]
for i,fraction in enumerate([-.72,-.35,.35,.72]):
 points=[]
 for z in [12,60,120,180,225,255]:
  band=[v for v in verts if abs(v.z-z)<18];xmin=min(v.x for v in band);xmax=max(v.x for v in band);yy=min(v.y for v in band)-.5;points.append(((xmin+xmax)/2+(xmax-xmin)*fraction/2,yy,z))
 fin('TheSpire_VerticalFin_%d'%i,points,1.1,1.6,metal)
 if i in [1,2]:fin('TheSpire_Accent_%d'%i,[(x,y-.9,z) for x,y,z in points],.28,.2,accent)
# Crown edge traces the existing asymmetric top; no giant antenna.
for i,x in enumerate([-10,10]):
 band=[v for v in verts if abs(v.x-x)<2 and v.z>250];top=max(v.z for v in band);front=min(v.y for v in band)
 fin('TheSpire_CrownAccent_%d'%i,[(x,front-.4,250),(x,front-.4,top-1)],.5,.5,accent)
for n in ['Landmark_TheSpire_Massing','Landmark_TheSpire_Crown','Landmark_TheSpire_Needle']:
 a=bpy.data.objects[n];a.hide_render=True;a.hide_viewport=True
# Keep anchor, all roads and original plaza intact.
for a in final.objects:a['district']='TechCore';a['slot_id']='Landmark_TheSpire'
# Standalone asset library and GLB export use local foundation origin.
root.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for a in final.objects:a.select_set(True)
bpy.ops.export_scene.gltf(filepath=R+'/Export/Atlantis_TheSpire_v1.glb',use_selection=True,export_format='GLB',export_yup=True)
root.location=(50,420,14);bpy.context.view_layer.update()
# Geometry checks for the exported asset.
metrics=[]
for a in final.objects:
 if a.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(a.data)
 metrics.append(dict(name=a.name,triangles=sum(len(p.vertices)-2 for p in a.data.polygons),nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),zero_area_faces=sum(f.calc_area()<1e-8 for f in bm.faces),scale=list(a.scale),materials=len(a.data.materials)))
 bm.free()
v=[a.matrix_world@Vector(c) for a in final.objects if a.type=='MESH' for c in a.bound_box];lo=[min(p[i] for p in v) for i in range(3)];hi=[max(p[i] for p in v) for i in range(3)]
regression=[]
for n,data in baseline.items():
 a=bpy.data.objects[n]
 if data['matrix']!=[list(r) for r in a.matrix_world] or (data['verts'] is not None and data['verts']!=len(a.data.vertices)):regression.append(n)
json.dump(dict(objects=metrics,triangles=sum(x['triangles'] for x in metrics),bounds=[lo,hi],dimensions=[hi[i]-lo[i] for i in range(3)],source_uniform_scale=300,removed_source_below_z=-.4,world_rotation=[0,0,0],baseline_transform_or_geometry_changes=regression,material_count=4,texture_count=0),open(R+'/clean_audit.json','w'),indent=2)
assert not regression
assert hi[2]-lo[2]<=350 and hi[0]-lo[0]<=70 and hi[1]-lo[1]<=70
assert all(x['zero_area_faces']==0 and x['nonmanifold_edges']==0 for x in metrics),metrics
# Review cameras retain all original camera transforms.
ref=bpy.data.collections['Reference']
def cam(n,pos,target,ortho=None,lens=45):
 d=bpy.data.cameras.new(n);a=bpy.data.objects.new(n,d);ref.objects.link(a);a.location=pos;a.rotation_euler=(Vector(target)-a.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=20000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return a
cam('TheSpire_Hero',(410,-120,260),(50,420,150),510);cam('TheSpire_Side',(550,420,175),(50,420,150),470)
cam('TheSpire_StartupSightline',(-460,-400,25),(50,420,145),lens=45);cam('TheSpire_TechCoreApproach',(50,105,20),(50,420,145),lens=23)
cam('TheSpire_VentureSightline',(-490,70,35),(50,420,160),lens=38);cam('TheSpire_MediaSightline',(780,300,35),(50,420,150),lens=40)
# Material renders: simple daylight and night, not runtime lighting.
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.world.use_nodes=True;worldbg=scene.world.node_tree.nodes.get('Background');worldbg.inputs['Color'].default_value=(.55,.68,.8,1);worldbg.inputs['Strength'].default_value=.6
lights=col('Spire_ReviewLighting',ref)
def sun(n,energy,rot):
 d=bpy.data.lights.new(n,'SUN');d.energy=energy;d.angle=.15;a=bpy.data.objects.new(n,d);lights.objects.link(a);a.rotation_euler=rot;return a
key=sun('Review_Sun',2,(.45,-.4,-.6));fill=sun('Review_Fill',.45,(.5,.4,2.5))
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.camera=bpy.data.objects['Atlantis_Master_Aerial'];bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase1_Masterplan.blend')
for n in ['Atlantis_Master_Aerial','Founder_To_City','TheSpire_StartupSightline','TechCore_Skyline','TheSpire_TechCoreApproach','TheSpire_Hero','TheSpire_Side','UnicornHeights_View','TheSpire_VentureSightline','TheSpire_MediaSightline']:
 scene.camera=bpy.data.objects[n];scene.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['TheSpire_Hero']
for name,strength,energy in [('Evening',.16,.35),('Night',.12,.18)]:
 worldbg.inputs['Strength'].default_value=strength;key.data.energy=energy;fill.data.energy=.06;scene.render.filepath=R+'/Review/TheSpire_'+name+'Preview.png';bpy.ops.render.render(write_still=True)
print('SPIRE_BUILD_COMPLETE')
