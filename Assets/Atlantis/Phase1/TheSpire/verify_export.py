import bpy,bmesh,json,os,math,hashlib
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=R+'/Export/Atlantis_TheSpire_v1.glb');scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
meshes=[o for o in scene.objects if o.type=='MESH'];v=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box];lo=[min(p[i] for p in v) for i in range(3)];hi=[max(p[i] for p in v) for i in range(3)]
checks={};checks['export_height_280m']=abs(hi[2]-lo[2]-280)<.01;checks['export_base_at_zero']=abs(lo[2])<.01;checks['within_centered_70m_parcel']=all(lo[i]>=-35.01 and hi[i]<=35.01 for i in [0,1]);checks['unit_scale']=all(all(abs(x-1)<1e-6 for x in o.scale) for o in scene.objects)
geo=[]
for o in meshes:
 b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.0001)
 geo.append(dict(name=o.name,nonmanifold_edges=sum(not e.is_manifold for e in b.edges),zero_area_faces=sum(f.calc_area()<1e-8 for f in b.faces),signed_volume=b.calc_volume(signed=True)));b.free()
checks['closed_meshes_after_export_seam_weld']=all(x['nonmanifold_edges']==0 for x in geo);checks['nonzero_faces']=all(x['zero_area_faces']==0 for x in geo);checks['outward_winding']=all(x['signed_volume']>0 for x in geo)
# Save a complete standalone scene, not a datablock-only library.
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=400;area.spaces.active.region_3d.view_location=(0,0,140);area.spaces.active.clip_end=10000
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_TheSpire_v1.blend')
# Masterplan inspection excludes deliberately hidden source and retired placeholder.
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase1_Masterplan.blend');scene=bpy.context.scene
hidden=[o for o in scene.objects if o.hide_render or any(c.hide_render for c in o.users_collection)]
for o in hidden:
 for c in list(o.users_collection):c.objects.unlink(o)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
vis={}
for n in ['Founder_To_City','TheSpire_StartupSightline','TheSpire_TechCoreApproach','TheSpire_VentureSightline','TheSpire_MediaSightline','UnicornHeights_View']:
 cam=bpy.data.objects[n];samples=[]
 for z in [270,280,290]:
  p=Vector((50,420,z));ndc=world_to_camera_view(scene,cam,p);d=p-cam.location;hit,loc,norm,idx,obj,mat=scene.ray_cast(deps,cam.location,d.normalized(),distance=d.length+40)
  samples.append(bool(0<ndc.x<1 and 0<ndc.y<1 and hit and obj.name.startswith('TheSpire_')))
 vis[n]=samples
checks['founder_sightline']=any(vis['Founder_To_City']);checks['startup_sightline']=any(vis['TheSpire_StartupSightline'])
others=[o for o in scene.objects if o.type=='MESH' and not o.name.startswith('TheSpire_')]
checks['spire_tallest_visible_mass']=max(max((o.matrix_world@Vector(c)).z for c in o.bound_box) for o in others)<294
# Planar nearest center and silhouette angular height.
p=Vector((50,420,14));neighbors=sorted([(math.hypot(o.location.x-50,o.location.y-420),o.name) for o in others if 'Block_' in o.name or 'Massing' in o.name]);cam=bpy.data.objects['Founder_To_City'];d=math.hypot(cam.location.x-50,cam.location.y-420)
angle=math.degrees(math.atan2(294-cam.location.z,d)-math.atan2(14-cam.location.z,d))
base=json.load(open(R+'/preservation_baseline.json'));changed=[p for p,h in base.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['app_and_phase0_bytes_unchanged']=not changed
json.dump(dict(checks=checks,export_geometry=geo,export_bounds=[lo,hi],sightline_samples=vis,founder_angular_height_degrees=angle,nearest_neighbor_planar_center_m=neighbors[0],changed_protected_files=changed),open(R+'/verification.json','w'),indent=2)
print(json.dumps(checks,indent=2));assert all(checks.values()),checks
