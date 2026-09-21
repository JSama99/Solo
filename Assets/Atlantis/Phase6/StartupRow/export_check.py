import bpy,bmesh,json,os,struct
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));p=R+'/Export/Atlantis_Phase6_StartupRow_Review.glb';bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=p);bpy.context.view_layer.update();obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];issues=[];tri=0
for me in {o.data for o in obs}:
 b=bmesh.new();b.from_mesh(me);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001)
 # Architectural joints intentionally overlap. Inspect each face and scale without falsely treating touching components as a union.
 bad=sum(f.calc_area()<1e-9 for f in b.faces)
 if bad:issues.append({'mesh':me.name,'zero_area_faces':bad})
 b.free()
raw=open(p,'rb').read();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);targets=[o for o in obs if o.get('semantic_target')];checks={'no_zero_area_faces':not issues,'no_negative_scales':all(min(o.scale)>0 for o in obs),'38_signage_targets':len(targets)==38,'signage_uvs':all(len(o.data.uv_layers)>0 for o in targets),'five_planning_slots':all(bpy.data.objects.get('Progression_'+n) is not None for n in ['Loft','SmallOffice','Office','SmallBuilding','BigBuilding']),'no_textures':len(g.get('images',[]))==0}
a={'checks':checks,'issues':issues,'triangles':sum(len(p.vertices)-2 for o in obs for p in o.data.polygons),'meshes':len(obs),'materials':len(g.get('materials',[])),'textures':len(g.get('images',[])),'bytes':len(raw)};json.dump(a,open(R+'/export_verification.json','w'),indent=2);print(a);assert all(checks.values())
