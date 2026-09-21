import bpy,bmesh,json,os,math,hashlib
from mathutils import Vector,Matrix
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase1/TheSpire/Blender/Atlantis_Phase1_Masterplan.blend');s=bpy.context.scene
# Original geometry, transforms, material and anchor snapshots for regression.
def signature(o):
 d={'matrix':[list(v) for v in o.matrix_world],'type':o.type,'props':{k:str(v) for k,v in o.items()}}
 if o.type=='MESH':d.update(vertices=[list(v.co) for v in o.data.vertices],faces=[list(p.vertices) for p in o.data.polygons],materials=[m.name if m else None for m in o.data.materials])
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
baseline={o.name:signature(o) for o in s.objects}
def col(n,p):
 c=bpy.data.collections.new(n);p.children.link(c);return c
A=bpy.data.collections['Atlantis'];stage=bpy.data.collections['AssetStaging'];src=col('VentureHall_Source',stage);district=bpy.data.collections['VentureDistrict'];heroes=col('Venture_HeroLandmarks',district);asset=col('VentureHall',heroes);support=col('SupportingMassing',district);plaza=col('Venture_Plaza',district)
pre=set(s.objects);bpy.ops.import_scene.gltf(filepath=R+'/Source/VentureHall_Higgsfield_Raw.glb');imported=list(set(s.objects)-pre)
for o in imported:
 for c in list(o.users_collection):c.objects.unlink(o)
 src.objects.link(o)
src.hide_render=True;src.hide_viewport=True
# ARCHITECTURE_INSERTION
raw=next(o for o in imported if o.type=='MESH');o=raw.copy();o.data=raw.data.copy();asset.objects.link(o);o.name='VentureHall_GeneratedArchitecture';o.parent=None;o.matrix_world=Matrix.Identity(4)
b=bmesh.new();b.from_mesh(o.data);bmesh.ops.transform(b,matrix=raw.matrix_world,verts=list(b.verts))
source_dims=[max(v.co[i] for v in b.verts)-min(v.co[i] for v in b.verts) for i in range(3)];minz=min(v.co.z for v in b.verts)
bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.0002);bmesh.ops.dissolve_degenerate(b,edges=list(b.edges),dist=.00001)
# Remove tiny isolated generated debris while retaining the connected building.
seen=set();groups=[]
for v in b.verts:
 if v in seen:continue
 stack=[v];seen.add(v);group=[]
 while stack:
  q=stack.pop();group.append(q)
  for edge in q.link_edges:
   p=edge.other_vert(q)
   if p not in seen:seen.add(p);stack.append(p)
 groups.append(group)
keep=max(groups,key=len);bmesh.ops.delete(b,geom=[v for v in b.verts if v not in keep],context='VERTS')
for attempt in range(5):
 bad=[e for e in b.edges if len(e.link_faces)>2 or len(e.link_faces)==0]
 if bad:bmesh.ops.delete(b,geom=list({v for e in bad for v in e.verts}),context='VERTS')
 bmesh.ops.holes_fill(b,edges=[e for e in b.edges if e.is_boundary],sides=0)
 if all(e.is_manifold for e in b.edges):break
bmesh.ops.recalc_face_normals(b,faces=list(b.faces))
rot=Matrix.Rotation(math.radians(-45),4,'Z');factor=50
for v in b.verts:v.co=(rot@(v.co-Vector((0,0,minz))))*factor+Vector((0,0,2))
b.to_mesh(o.data);b.free();o.data.update()
# Patch remaining local boundary defects without resampling the source facade.
b=bmesh.new();b.from_mesh(o.data)
for attempt in range(8):
 bad=[e for e in b.edges if not e.is_manifold]
 if not bad:break
 bmesh.ops.delete(b,geom=list({v for e in bad for v in e.verts}),context='VERTS')
 bmesh.ops.holes_fill(b,edges=[e for e in b.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(b,faces=list(b.faces));b.to_mesh(o.data);b.free()
# Keep one original atlas material. Normal map noise is removed; base/ORM retained.
for m in o.data.materials:
 if m and m.use_nodes:
  p=m.node_tree.nodes.get('Principled BSDF')
  if p:
   for link in list(p.inputs['Normal'].links):m.node_tree.links.remove(link)
   p.inputs['Roughness'].default_value=.45
for p in o.data.polygons:p.use_smooth=True
root=bpy.data.objects.new('VentureHall_AssetRoot',None);asset.objects.link(root);root.location=(-520,110,14);root['slot_id']='Landmark_VentureHall';root['forward']='-Y';o.parent=root
normalization=dict(source_dimensions=source_dims,uniform_scale=factor,source_rotation_degrees=-45,final_root_rotation_degrees=0,base_offset=2,removed_components=len(groups)-1)
def mat(n,color,metal=0,rough=.4,emission=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
stone=mat('Venture • pale limestone',(.65,.59,.48),0,.65);bronze=mat('Venture • brushed bronze',(.34,.22,.1),.7,.35);glass=mat('Venture • atrium glazing',(.12,.27,.32),.5,.22);warm=mat('Venture • warm entry',(.85,.49,.19),.1,.4,1.3);poolmat=mat('Venture • reflecting water',(.08,.23,.25),.5,.17);green=mat('Venture • landscape blockout',(.15,.27,.13),0,.8)
def cube(n,loc,size,material,collection=asset,parent=root):
 bpy.ops.mesh.primitive_cube_add(size=1);q=bpy.context.object;q.name=n
 for c in list(q.users_collection):c.objects.unlink(q)
 collection.objects.link(q);q.parent=parent;q.location=loc
 for v in q.data.vertices:v.co.x*=size[0];v.co.y*=size[1];v.co.z*=size[2]
 q.data.materials.append(material);return q
# Retain the repaired generated study in staging; reconstruct clean architectural
# surfaces from its stepped terrace / glazed atrium / roof concept.
asset.objects.unlink(o);src.objects.link(o);o.parent=None;o.name='VentureHall_CleanedSourceStudy'
normalization['final_method']='Source-informed architectural reconstruction; source 50x normalized study retained in staging'
# Broad stepped wings and continuous shallow atrium; no modeled interiors.
for level in range(8):
 z=2+level*4.7;outer=37-level*1.8;front=-25+level*1.5;back=24-level*.5
 for side in [-1,1]:
  width=outer-11;cx=side*(11+width/2);depth=back-front;cy=(back+front)/2
  cube('VentureHall_WingGlass_%d_%d'%(side,level),(cx,cy,z+2.1),(width,depth,4.2),glass)
  cube('VentureHall_StoneBand_%d_%d'%(side,level),(cx,cy,z+.25),(width+1.5,depth+1.5,.5),stone)
  for fraction in [.15,.5,.85]:
   x=cx+(fraction-.5)*width
   cube('VentureHall_FacadePier_%d_%d_%s'%(side,level,fraction),(x,front-.3,z+2.25),(.65,.7,4.5),bronze)
# The atrium facade is a shallow glass envelope, with an opaque rear boundary.
cube('VentureHall_CentralAtrium',(0,-2,20.5),(21,44,37),glass)
for x in [-10,-5,0,5,10]:cube('VentureHall_AtriumMullion_'+str(x),(x,-24.25,20.5),(.35,.4,37),bronze)
for z in [7,16.5,26,35.5]:cube('VentureHall_AtriumTransom_'+str(z),(0,-24.4,z),(21,.35,.25),bronze)
for x in [-9.4,9.4]:cube('VentureHall_AtriumWarmEdge_'+str(x),(x,-24.6,20.5),(.35,.15,35),warm)
for x in [-12,12]:
 cap=cube('VentureHall_RoofWing_'+str(x),(x,4,40),(25,37,1.1),bronze);cap.rotation_euler.y=math.radians(-4 if x<0 else 4)
cube('VentureHall_CivicPodium',(0,0,1),(88,73,2),stone)
# Forecourt canopy, shallow lobby glazing, and a ceremonial colonnade; exterior only.
cube('VentureHall_EntryGlazing',(0,-28,6),(16,1,8),glass)
cube('VentureHall_EntryCanopy',(0,-31,10.5),(24,9,1),bronze)
for x in [-10,-5,5,10]:cube('VentureHall_EntryColumn_'+str(x),(x,-34,6),(1,1,8),bronze)
for x in [-7,7]:cube('VentureHall_EntryLight_'+str(x),(x,-28.6,6),(1,.15,6),warm)
# Horizontal side terraces extend the base and emphasize civic breadth.
for x in [-35,35]:
 cube('VentureHall_TerraceBase_'+str(x),(x,4,4),(14,45,4),stone)
 cube('VentureHall_TerraceCap_'+str(x),(x,5,6.3),(15,46,.6),bronze)
# Consolidate by material; bake each mesh into foundation-local coordinates.
for material in [stone,bronze,glass,warm]:
 group=[q for q in asset.objects if q.type=='MESH' and q.data.materials[0]==material]
 if not group:continue
 bpy.ops.object.select_all(action='DESELECT')
 for q in group:q.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();q=group[0];q.name='VentureHall_'+material.name.split(' • ')[-1].replace(' ','_')
 transform=q.matrix_basis.copy()
 for v in q.data.vertices:v.co=transform@v.co
 q.matrix_basis=Matrix.Identity(4)
for q in asset.objects:q['district']='VentureDistrict';q['slot_id']='Landmark_VentureHall'
exec(compile(open(R+'/integration_tail.py').read(),R+'/integration_tail.py','exec'))
