import bpy,json,os,bmesh,sys,hashlib
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));name=sys.argv[sys.argv.index('--')+1];A=R+'/'+name;target={'NorthwindLabs':115,'Flashpoint':75}[name];fw,fd={'NorthwindLabs':(58,52),'Flashpoint':(40,32)}[name];cam={'NorthwindLabs':'Northwind_HeroBlockout','Flashpoint':'Flashpoint_HeroBlockout'}[name]
bpy.ops.wm.open_mainfile(filepath=A+'/Blender/Integration_Candidate.blend');s=bpy.context.scene;asset=bpy.data.collections[name+'_Production']
for o in bpy.data.collections[name+'_Blockout'].objects:
 if o.type=='MESH':o.hide_render=True;o.hide_viewport=True
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
for o in s.objects:
 if o.type=='MESH':o.hide_render=o.name not in asset.objects
for mode,power,strength in [('Day',2,.6),('Night',.18,.12)]:
 bpy.data.objects['Review_Sun'].data.energy=power;bpy.data.objects['Review_Fill'].data.energy=.35 if mode=='Day' else .08;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=strength;s.camera=bpy.data.objects[cam];s.render.filepath=A+'/Review/'+name+'_'+mode+'.png';bpy.ops.render.render(write_still=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=A+'/Export/Atlantis_'+name+'_HQ_v1.glb');s=bpy.context.scene;bpy.context.view_layer.update();obs=[o for o in s.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];geo=[]
for o in obs:
 b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001);geo.append({'name':o.name,'nonmanifold':sum(not e.is_manifold for e in b.edges),'zero_area':sum(f.calc_area()<1e-8 for f in b.faces),'volume':b.calc_volume(signed=True)});b.free()
checks={'fits_initial_footprint':lo[0]>=-fw/2-.001 and hi[0]<=fw/2+.001 and lo[1]>=-fd/2-.001 and hi[1]<=fd/2+.001,'target_height':abs(hi[2]-lo[2]-target)<.01,'ground_origin':abs(lo[2])<.001,'clean_geometry':all(g['nonmanifold']==0 and g['zero_area']==0 and g['volume']>0 for g in geo),'unit_scales':all(max(abs(x-1) for x in o.scale)<.00001 for o in s.objects)}
json.dump({'checks':checks,'bounds':[lo,hi],'geometry':geo,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in obs),'meshes':len(obs)},open(A+'/export_verification.json','w'),indent=2);assert all(checks.values())
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/Atlantis_'+name+'_HQ_v1.blend');print(checks)
