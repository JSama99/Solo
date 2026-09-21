import bpy,os
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase3_Masterplan.blend');s=bpy.context.scene
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Atlantis_Master_Aerial','MediaDistrict_Aerial','TechCom_Skyline','TechCom_PublicApproach','SignalTV_Plaza','SignalTV_Waterfront','MediaDistrict_Together','MediaDistrict_ToSpire','Commerce_ToMedia']:
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
visible={o.name:not o.hide_render for o in s.objects}
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
bg=s.world.node_tree.nodes.get('Background');sun=bpy.data.objects['Review_Sun'];fill=bpy.data.objects['Review_Fill']
for asset,cam in [('TechComTower','TechCom_Hero'),('SignalTV','SignalTV_Hero')]:
 names={o.name for o in bpy.data.collections[asset].objects}
 for o in s.objects:
  if o.type=='MESH':o.hide_render=o.name not in names
 for mode,power,strength in [('Day',2,.6),('Night',.18,.12)]:
  sun.data.energy=power;fill.data.energy=.35 if mode=='Day' else .08;bg.inputs['Strength'].default_value=strength;s.camera=bpy.data.objects[cam];s.render.filepath=R+'/'+asset+'/Review/'+asset+'_'+mode+'.png';bpy.ops.render.render(write_still=True)
print('RENDERS_COMPLETE')
