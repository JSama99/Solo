import bpy,os
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase6_Masterplan.blend');s=bpy.context.scene;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Atlantis_Master_Aerial','Founder_To_City','TheSpire_StartupSightline','StartupRow_Aerial','Founder_To_Startup','Startup_To_TechCore','Startup_MainBoulevard','Startup_Core','Startup_ProgressionParcels','StartupRow_Flashpoint']:
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.camera=bpy.data.objects['Startup_NightPreview']
for mode,power,strength in [('Day',2,.55),('Night',.12,.08)]:
 bpy.data.objects['Review_Sun'].data.energy=power;bpy.data.objects['Review_Fill'].data.energy=.3 if mode=='Day' else .05;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=strength;s.render.filepath=R+'/Review/Startup_'+mode+'.png';bpy.ops.render.render(write_still=True)
