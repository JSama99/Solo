import bpy,bmesh,json,os,hashlib
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));checks={}
def sig(o):
 d={'matrix':[list(v) for v in o.matrix_basis],'parent':o.parent.name if o.parent else None,'props':{k:str(v) for k,v in o.items()},'type':o.type}
 if o.type=='MESH':d.update(v=[list(v.co) for v in o.data.vertices],f=[list(p.vertices) for p in o.data.polygons],materials=[m.name for m in o.data.materials])
 if o.type=='CAMERA':d.update(lens=o.data.lens,ortho=o.data.ortho_scale,projection=o.data.type)
 return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase2/VentureHall/Blender/Atlantis_Phase2_Masterplan.blend');base={o.name:sig(o) for o in bpy.context.scene.objects};cols={c.name:dict(c.items()) for c in bpy.data.collections}
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase3_Masterplan.blend');s=bpy.context.scene;metrics=json.load(open(R+'/clean_audit.json'));allowed=set(metrics['support_changes']);changed=[n for n,h in base.items() if not bpy.data.objects.get(n) or sig(bpy.data.objects[n])!=h]
checks['only_six_authorized_original_blocks_changed']=set(changed)==allowed
checks['both_locators_unchanged']=all(sig(bpy.data.objects[n])==base[n] for n in ['Landmark_TechComTower','Landmark_SignalTV'])
checks['district_boundaries_preserved']=all(dict(bpy.data.collections[n].items())==cols[n] for n in ['FounderDistrict','StartupRow','VentureDistrict','TechCore','CommerceDistrict','MediaDistrict','UnicornHeights'])
for name,prefix in [('spire','TheSpire_'),('venture_hall','VentureHall_')]:checks[name+'_unchanged']=all(sig(bpy.data.objects[n])==h for n,h in base.items() if n.startswith(prefix))
checks['geography_roads_bridges_and_cameras_preserved']=all(sig(bpy.data.objects[n])==h for n,h in base.items() if n not in allowed)
checks['two_hero_placeholders_disabled']=all(bpy.data.objects[n].hide_render for n in ['Landmark_TechComTower_Massing','Landmark_SignalTV_Massing'])
checks['source_staged']=bool(bpy.data.collections.get('SignalTV_Source'))
district_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.data.collections['MediaDistrict'].all_objects if o.type=='MESH')
for o in list(s.objects):
 if o.hide_render or any(c.hide_render for c in o.users_collection):
  for c in list(o.users_collection):c.objects.unlink(o)
bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();sightlines={}
for n in ['Founder_To_City','TheSpire_StartupSightline']:
 cam=bpy.data.objects[n];p=Vector((50,420,285));d=p-cam.location;hit,loc,no,i,obj,ma=s.ray_cast(dep,cam.location,d.normalized(),distance=d.length+25);sightlines[n]=bool(hit and obj.name.startswith('TheSpire_'))
checks['founder_and_startup_spire_sightlines']=all(sightlines.values())
exports={}
for asset,fw,fd,hm,hx,targets in [('TechComTower',75,70,120,180,['TechCom_Display_Main','TechCom_Ticker']),('SignalTV',95,65,25,60,['SignalTV_Display_Main','SignalTV_Display_Secondary','SignalTV_Ticker'])]:
 path=R+'/'+asset+'/Export/Atlantis_'+asset+'_v1.glb';bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=path);s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.view_layer.update()
 obs=[o for o in s.objects if o.type=='MESH'];pts=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)];geometry=[]
 for o in obs:
  b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.00001);geometry.append({'name':o.name,'nonmanifold':sum(not e.is_manifold for e in b.edges),'zero_area':sum(f.calc_area()<1e-8 for f in b.faces),'volume':b.calc_volume(signed=True)});b.free()
 checks[asset+'_fits_slot']=lo[0]>=-fw/2-.001 and hi[0]<=fw/2+.001 and lo[1]>=-fd/2-.001 and hi[1]<=fd/2+.001 and hm<=hi[2]-lo[2]<=hx
 checks[asset+'_clean_geometry']=all(g['nonmanifold']==0 and g['zero_area']==0 and g['volume']>0 for g in geometry)
 checks[asset+'_clean_origin']=abs(lo[2])<.00001 and tuple(bpy.data.objects[asset+'_AssetRoot'].location)==(0,0,0)
 checks[asset+'_unit_scales']=all(max(abs(v-1) for v in o.scale)<.000001 for o in s.objects)
 checks[asset+'_display_targets']=all(bpy.data.objects.get(n) and bpy.data.objects[n].data.materials[0].name==n and bool(bpy.data.objects[n].data.uv_layers) for n in targets)
 checks[asset+'_no_missing_textures']=all(i.packed_file or i.source=='GENERATED' or os.path.exists(bpy.path.abspath(i.filepath)) for i in bpy.data.images if i.type=='IMAGE')
 bpy.context.preferences.filepaths.save_version=0
 for area in bpy.context.screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_distance=220 if asset=='TechComTower' else 120;area.spaces.active.region_3d.view_location=(0,0,60 if asset=='TechComTower' else 20)
 bpy.ops.wm.save_as_mainfile(filepath=R+'/'+asset+'/Blender/Atlantis_'+asset+'_v1.blend');exports[asset]={'bytes':os.path.getsize(path),'geometry':geometry,'bounds':[lo,hi]}
protected=json.load(open(R+'/preservation_baseline.json'));bad=[p for p,h in protected.items() if hashlib.sha256(open(p,'rb').read()).hexdigest()!=h];checks['protected_188_files_unchanged']=not bad;checks['techcom_below_spire']=metrics['assets']['TechComTower']['dimensions'][2]<280;checks['signal_source_preserved']=os.path.getsize(R+'/SignalTV/Source/SignalTV_Higgsfield_Raw.glb')==1602472
json.dump({'checks':checks,'exports':exports,'changed_original_objects':changed,'changed_protected_files':bad,'sightlines':sightlines,'district_triangles':district_triangles},open(R+'/verification.json','w'),indent=2);print(json.dumps(checks,indent=2));assert all(checks.values()),checks
