import bpy,os,bmesh,json
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=R+'/PallasAI/Source/PallasAI_Higgsfield_Raw_candidate2.glb');o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for z in [-.2,-.15,-.1,0]:
 vs=[v.co for v in o.data.vertices if v.co.z>z];print(z,[(min(v[i] for v in vs),max(v[i] for v in vs)) for i in range(3)])
