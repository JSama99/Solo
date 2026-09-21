import bpy,bmesh,json,os,hashlib,math,struct
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=os.path.dirname(os.path.abspath(__file__));checks={}
def sig(o):
 d={'m':[list(v) for v in o.matrix_basis],'parent':o.parent.name if o.parent else None,'props':{k:str(v) for k,v in o.items()}}
 if o.type=='MESH':d.update(v=[list(v.co) for v in o.data.vertices],f=[list(p.vertices) for p in o.data.polygons],materials=[m.name for m in o.data.materials])
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase1/TheSpire/Blender/Atlantis_Phase1_Masterplan.blend');base={o.name:sig(o) for o in bpy.context.scene.objects};collections={c.name:dict(c.items()) for c in bpy.data.collections}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase2_Masterplan.blend');s=bpy.context.scene;m=json.load(open(R+'/clean_audit.json'));allowed=set(m['support_changes']);changed=[n for n,h in base.items() if sig(bpy.data.objects[n])!=h]
checks['only_four_original_masses_changed']=set(changed)==allowed
checks['district_territories_preserved']=all(dict(bpy.data.collections[n].items())==collections[n] for n in ['FounderDistrict','StartupRow','VentureDistrict','TechCore','CommerceDistrict','MediaDistrict','UnicornHeights'])
checks['spire_geometry_transform_preserved']=all(sig(bpy.data.objects[n])==h for n,h in base.items() if n.startswith('TheSpire_'))
checks['venture_anchor_and_alias_preserved']=all(sig(bpy.data.objects[n])==base[n] for n in ['Landmark_VentureHall','VentureHall_Anchor'])
checks['all_other_slots_preserved']=all(sig(bpy.data.objects[n])==h for n,h in base.items() if 'Slot' in n or n.startswith('Landmark_'))
checks['original_cameras_preserved']=all(sig(o)==base[o.name] for o in s.objects if o.type=='CAMERA' and o.name in base)
checks['source_staged']=bool(bpy.data.collections.get('VentureHall_Source'))
# Ray casts ignore all intentionally hidden source objects and retired placeholders.
for o in list(s.objects):
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  for c in list(o.users_collection):c.objects.unlink(o)
bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();vis={}
for n in ['Founder_To_City','TheSpire_StartupSightline']:
 cam=bpy.data.objects[n];p=Vector((50,420,285));d=p-cam.location;hit,loc,no,i,obj,ma=s.ray_cast(dep,cam.location,d.normalized(),distance=d.length+25);vis[n]=bool(hit and obj.name.startswith('TheSpire_'))
checks['spire_sightlines_preserved']=all(vis.values())
checks['hall_shorter_than_spire']=m['dimensions'][2]<280
# Reimport final GLB and build standalone scene.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=R+'/Export/Atlantis_VentureHall_v1.glb');s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
obs=[o for o in s.objects if o.type=='MESH'];points=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
checks['footprint_within_slot']=lo[0]>=-45.01 and hi[0]<=45.01 and lo[1]>=-37.51 and hi[1]<=37.51
checks['height_within_contract']=30<=hi[2]-lo[2]<=65
checks['origin_at_ground']=abs(lo[2])<.0001 and tuple(bpy.data.objects['VentureHall_AssetRoot'].location)==(0,0,0)
checks['unit_scale']=all(max(abs(x-1) for x in o.scale)<1e-6 for o in s.objects)
audit=[]
for o in obs:
 b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001)
 audit.append(dict(name=o.name,nonmanifold=sum(not e.is_manifold for e in b.edges),zero_area=sum(f.calc_area()<1e-8 for f in b.faces),outward_volume=b.calc_volume(signed=True)));b.free()
checks['closed_export_meshes']=all(x['nonmanifold']==0 for x in audit);checks['valid_faces_and_winding']=all(x['zero_area']==0 and x['outward_volume']>0 for x in audit)
checks['no_missing_textures']=all(im.packed_file or im.source=='GENERATED' or os.path.exists(bpy.path.abspath(im.filepath)) for im in bpy.data.images if im.type=='IMAGE')
checks['four_material_meshes']=len(obs)==4
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=130;area.spaces.active.region_3d.view_location=(0,0,20)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_VentureHall_v1.blend')
protected=json.load(open(R+'/preservation_baseline.json'));bad=[p for p,h in protected.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['phase0_phase1_app_bytes_unchanged']=not bad
checks['raw_source_retained']=os.path.getsize(R+'/Source/VentureHall_Higgsfield_Raw.glb')>0
json.dump(dict(checks=checks,geometry=audit,bounds=[lo,hi],changed_original_objects=changed,changed_protected_files=bad,sightlines=vis),open(R+'/verification.json','w'),indent=2)
print(json.dumps(checks,indent=2));assert all(checks.values()),checks
