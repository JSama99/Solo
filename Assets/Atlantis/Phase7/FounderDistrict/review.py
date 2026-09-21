import bpy,json,os
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase7_Masterplan.blend');s=bpy.context.scene;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in json.load(open(R+'/build_audit.json'))['review_cameras']:
 if n=='Founder_NightPreview':continue
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True;s.camera=bpy.data.objects['Founder_NightPreview']
for mode,power,strength in [('Day',2,.55),('Night',.08,.035)]:
 bpy.data.objects['Review_Sun'].data.energy=power;bpy.data.objects['Review_Fill'].data.energy=.3 if mode=='Day' else .02;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=strength;s.render.filepath=R+'/Review/Founder_'+mode+'.png';bpy.ops.render.render(write_still=True)
