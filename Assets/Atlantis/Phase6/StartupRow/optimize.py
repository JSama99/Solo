import bpy,json,os,hashlib
from mathutils import Matrix
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase6_Masterplan.blend');s=bpy.context.scene;B=bpy.data.collections['Startup_Buildings'];U=bpy.data.collections['Startup_PublicRealm'];K=bpy.data.collections['Startup_KitLibrary'];counts={}
def merge(group,name):
 if not group:return
 group[0].data=group[0].data.copy()
 bpy.ops.object.select_all(action='DESELECT')
 for o in group:o.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();o=group[0];m=o.matrix_basis.copy();o.data.transform(m);o.matrix_basis=Matrix.Identity(4);o.name=name
 return o
counts['building_meshes_before']=sum(o.type=='MESH' for o in B.objects)
# Separate architecture and dynamic targets, sharing identical consolidated mesh data across repeats.
shared={}
for root in [o for o in B.objects if o.type=='EMPTY']:
 meshes=[o for o in root.children if o.type=='MESH' and not o.get('semantic_target')]
 o=merge(meshes,root.name+'_Architecture')
 if o:
  signature=hashlib.sha256(str(([(tuple(v.co)) for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],[m.name for m in o.data.materials],[p.material_index for p in o.data.polygons])).encode()).hexdigest()
  if signature in shared:o.data=shared[signature]
  else:shared[signature]=o.data
# Spatial cells keep public realm separable for future district streaming.
groups={}
for o in list(U.objects):
 if o.type!='MESH':continue
 key=(int(o.location.x//100),int(o.location.y//100),o.data.materials[0].name);groups.setdefault(key,[]).append(o)
for key,group in groups.items():merge(group,'Startup_PublicCell_%s_%s_%s'%key)
counts['building_meshes_after']=sum(o.type=='MESH' for o in B.objects);counts['shared_building_architecture_meshes']=len(shared);counts['public_realm_cells']=len(groups);json.dump(counts,open(R+'/optimization.json','w'),indent=2)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase6_Masterplan.blend')
bpy.ops.object.select_all(action='DESELECT')
for c in [B,U,bpy.data.collections['Startup_ProgressionPlanning']]:
 for o in c.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=R+'/Export/Atlantis_Phase6_StartupRow_Review.glb',export_format='GLB',use_selection=True,export_extras=True,export_yup=True);print(counts)
