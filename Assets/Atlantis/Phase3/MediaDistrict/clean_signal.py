import bpy,bmesh,json,os,math
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));A=R+'/SignalTV'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=A+'/Source/SignalTV_Higgsfield_Raw.glb')
s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
source=[o for o in s.objects if o.type=='MESH'];o=source[0];o.name='SignalTV_GeneratedArchitecture'
b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.000001);bmesh.ops.dissolve_degenerate(b,edges=list(b.edges),dist=.000001)
# Seal boundary holes without decimation or changing the generated silhouette.
repair=[]
for attempt in range(5):
 bad=[e for e in b.edges if not e.is_manifold]
 repair.append(len(bad))
 if not bad:break
 excess=list({f for e in bad if len(e.link_faces)>2 for f in list(e.link_faces)[2:]})
 if excess:bmesh.ops.delete(b,geom=excess,context='FACES')
 boundary=[e for e in b.edges if e.is_boundary]
 if boundary:bmesh.ops.holes_fill(b,edges=boundary,sides=0)
 loose=[v for v in b.verts if not v.link_faces]
 if loose:bmesh.ops.delete(b,geom=loose,context='VERTS')
bmesh.ops.recalc_face_normals(b,faces=list(b.faces));b.to_mesh(o.data);b.free()
lo=Vector([min(v.co[i] for v in o.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in o.data.vertices) for i in range(3)]);scale=45/(hi.z-lo.z)
for v in o.data.vertices:v.co=(v.co-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*scale
root=bpy.data.objects.new('SignalTV_AssetRoot',None);s.collection.objects.link(root);o.parent=root;root['canonical_locator']='Landmark_SignalTV';root['forward']='-Y';root['source_to_metre_scale']=scale
# Remove noisy normal mapping while preserving the generated base-color and metallic textures.
for m in o.data.materials:
 m.name='SignalTV_SourceFacade'
 for node in m.node_tree.nodes:
  if node.type=='BSDF_PRINCIPLED':
   for link in list(node.inputs['Normal'].links):m.node_tree.links.remove(link)
# Save a normalized working asset for targeted surface refinement.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/SignalTV_Normalized_Working.blend')
b=bmesh.new();b.from_mesh(o.data);audit=dict(scale=scale,dimensions=[(hi[i]-lo[i])*scale for i in range(3)],triangles=sum(len(p.vertices)-2 for p in o.data.polygons),nonmanifold=sum(not e.is_manifold for e in b.edges),zero_area=sum(f.calc_area()<1e-8 for f in b.faces),volume=b.calc_volume(signed=True));b.free();json.dump(audit,open(A+'/Blender/cleanup_checkpoint.json','w'),indent=2);print(audit)
