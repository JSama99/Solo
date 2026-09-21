import bpy,os
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase1_Masterplan.blend');s=bpy.context.scene
for o in s.objects:
 if o.type=='MESH' and not o.name.startswith('TheSpire_'):o.hide_render=True
bg=s.world.node_tree.nodes.get('Background');sun=bpy.data.objects['Review_Sun'];fill=bpy.data.objects['Review_Fill']
for name,cam,strength,energy in [('TheSpire_Hero','TheSpire_Hero',.6,2),('TheSpire_Side','TheSpire_Side',.6,2),('TheSpire_EveningPreview','TheSpire_Hero',.16,.35),('TheSpire_NightPreview','TheSpire_Hero',.12,.18)]:
 s.camera=bpy.data.objects[cam];bg.inputs['Strength'].default_value=strength;sun.data.energy=energy;fill.data.energy=.45 if energy==2 else .06;s.render.filepath=R+'/Review/'+name+'.png';bpy.ops.render.render(write_still=True)
