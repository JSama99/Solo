import bpy,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));os.makedirs(R+'/Review',exist_ok=True);bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend');s=bpy.context.scene
s.render.engine='BLENDER_WORKBENCH';s.display.shading.color_type='MATERIAL';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
for n in ['Founder_To_City','TheSpire_StartupSightline','Venture_Pallas','Northwind_TechApproach','StartupRow_Flashpoint','TechCore_Rivals_Aerial','Media_RivalSkyline','UnicornHeights_View','Atlantis_Master_Aerial']:
 s.camera=bpy.data.objects[n];s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
# Additional bounded Flashpoint context views; cameras exist only for review.
for n,pos,target,width in [('Flashpoint_CommerceApproach',(580,-440,65),(430,-240,50),200),('Flashpoint_TechApproach',(430,50,80),(430,-240,50),300)]:
 d=bpy.data.cameras.new(n);c=bpy.data.objects.new(n,d);s.collection.objects.link(c);c.location=pos;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=width;d.clip_end=20000;s.camera=c;s.render.filepath=R+'/Review/'+n+'.png';bpy.ops.render.render(write_still=True)
# A separate unsaved comparison places the three independent assets on one metre scale.
visible=set()
for n,x in [('PallasAI',-80),('NorthwindLabs',0),('Flashpoint',75)]:
 root=bpy.data.objects[n+'_HQ_AssetRoot'];root.parent=None;root.location=(x,0,0)
 visible.update(o.name for o in bpy.data.collections[n+'_Production'].objects if o.type=='MESH')
for o in s.objects:
 if o.type=='MESH':o.hide_render=o.name not in visible
camdata=bpy.data.cameras.new('Phase5_ArchitectureComparison');cam=bpy.data.objects.new('Phase5_ArchitectureComparison',camdata);s.collection.objects.link(cam);cam.location=(65,-450,205);cam.rotation_euler=(Vector((0,0,80))-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=300;s.camera=cam
s.render.resolution_x=1600;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
for mode,power,strength in [('Day',2,.6),('Night',.18,.12)]:
 bpy.data.objects['Review_Sun'].data.energy=power;bpy.data.objects['Review_Fill'].data.energy=.35 if mode=='Day' else .08;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=strength;s.render.filepath=R+'/Review/Rivals_Architecture_'+mode+'.png';bpy.ops.render.render(write_still=True)
