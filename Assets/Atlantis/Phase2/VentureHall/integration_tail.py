# Executed by build_venture.py after asset cleanup.
# Supporting placeholders retain centers and make a four-building ceremonial cluster.
changes={}
for n,h in [('VentureDistrict_Block_001',38),('VentureDistrict_Block_004',30),('VentureDistrict_Block_009',32),('VentureDistrict_Block_007',45)]:
 o=bpy.data.objects[n];old=list(o.dimensions);p=o.location.copy()
 for c in list(o.users_collection):c.objects.unlink(o)
 support.objects.link(o)
 for v in o.data.vertices:v.co.z*=h/old[2]
 o.location.z=14+h/2;o.data.materials.clear();o.data.materials.append(stone);changes[n]={'old_height':old[2],'new_height':h}
 cube(n+'_Terrace',(p.x,p.y,17),(40,34,6),stone,support,None)
 cube(n+'_GlazedCap',(p.x,p.y,14+h+2),(24,21,4),glass,support,None)
# Forum geometry retained, overlay and immediate approach are bounded additions.
cube('Venture_ForumPaving',(-520,30,14.5),(108,58,.3),stone,plaza,None)
cube('Venture_EntryWalk',(-520,66,14.55),(24,14,.3),stone,plaza,None)
for x in [-557,-483]:
 cube('Venture_ReflectingBasin_'+str(x),(x,33,14.9),(10,28,.5),bronze,plaza,None)
 cube('Venture_ReflectingWater_'+str(x),(x,33,15.2),(8.5,26,.12),poolmat,plaza,None)
for x in [-565,-475]:
 for y in [9,55]:
  cube('Venture_LandscapeBed_'+str((x,y)),(x,y,15),(7,7,1),stone,plaza,None)
  cube('Venture_LandscapeMass_'+str((x,y)),(x,y,17),(5.5,5.5,3),green,plaza,None)
bpy.data.objects['Landmark_VentureHall_Massing'].hide_render=True;bpy.data.objects['Landmark_VentureHall_Massing'].hide_viewport=True
# Metrics and regression permit only the four declared original mass changes.
bpy.context.view_layer.update();reg=[n for n,h in baseline.items() if signature(bpy.data.objects[n])!=h and n not in changes]
assert not reg,reg
metrics=[]
for o in asset.objects:
 if o.type!='MESH':continue
 b=bmesh.new();b.from_mesh(o.data);metrics.append(dict(name=o.name,triangles=sum(len(p.vertices)-2 for p in o.data.polygons),nonmanifold=sum(not e.is_manifold for e in b.edges),zero_area=sum(f.calc_area()<1e-8 for f in b.faces),signed_volume=b.calc_volume(signed=True)));b.free()
vs=[o.matrix_world@Vector(c) for o in asset.objects if o.type=='MESH' for c in o.bound_box];lo=[min(p[i] for p in vs) for i in range(3)];hi=[max(p[i] for p in vs) for i in range(3)]
json.dump(metrics,open(R+'/geometry_audit.json','w'),indent=2)
assert all(m['nonmanifold']==0 and m['zero_area']==0 and m['signed_volume']>0 for m in metrics),metrics
assert lo[0]>=-565.01 and hi[0]<=-474.99 and lo[1]>=72.49 and hi[1]<=147.51 and 30<=hi[2]-lo[2]<=65
root.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=R+'/Export/Atlantis_VentureHall_v1.glb',use_selection=True,export_format='GLB',export_yup=True)
root.location=(-520,110,14);bpy.context.view_layer.update()
json.dump(dict(meshes=metrics,triangles=sum(m['triangles'] for m in metrics),bounds=[lo,hi],dimensions=[hi[i]-lo[i] for i in range(3)],source_normalization=normalization,support_changes=changes,unexpected_original_changes=reg,district_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in district.all_objects if o.type=='MESH'),materials=sorted({m.name for o in asset.objects if o.type=='MESH' for m in o.data.materials})),open(R+'/clean_audit.json','w'),indent=2)
# Cameras specific to this pass; existing cameras retained.
ref=bpy.data.collections['Reference']
def camera(n,pos,target,ortho=None,lens=45):
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);ref.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=20000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return o
camera('VentureHall_Hero',(-365,-90,140),(-520,110,35),ortho=180)
camera('VentureHall_Side',(-300,110,80),(-520,110,35),ortho=170)
camera('VentureHall_Plaza',(-520,-20,17),(-520,110,35),lens=32)
camera('VentureDistrict_Aerial',(-850,-400,530),(-490,180,20),ortho=740)
camera('VentureDistrict_Arrival',(-455,-85,25),(-520,110,38),lens=42)
camera('VentureHall_ToSpire',(-850,-400,470),(-230,260,100),ortho=950)
camera('Startup_ToVenture',(-535,-265,30),(-520,110,45),lens=45)
s.camera=bpy.data.objects['VentureDistrict_Aerial'];s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase2_Masterplan.blend')
# City-context studies use the original Phase0 viewport colors.
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Atlantis_Master_Aerial','VentureDistrict_Aerial','VentureHall_Plaza','VentureDistrict_Arrival','VentureHall_ToSpire','Startup_ToVenture','UnicornHeights_View','Founder_To_City']:
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
# Isolated material previews hide context only in memory after saving.
for o in s.objects:
 if o.type=='MESH' and o.name not in asset.objects:o.hide_render=True
s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
bg=s.world.node_tree.nodes.get('Background');sun=bpy.data.objects['Review_Sun'];fill=bpy.data.objects['Review_Fill']
for n,cam,power,strength in [('VentureHall_Hero','VentureHall_Hero',2,.6),('VentureHall_Side','VentureHall_Side',2,.6),('VentureHall_Morning','VentureHall_Hero',1,.4),('VentureHall_Evening','VentureHall_Hero',.35,.16),('VentureHall_NightPreview','VentureHall_Hero',.18,.12)]:
 s.camera=bpy.data.objects[cam];sun.data.energy=power;fill.data.energy=.35 if power>1 else .08;bg.inputs['Strength'].default_value=strength;s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
print('VENTURE_BUILD_COMPLETE')
