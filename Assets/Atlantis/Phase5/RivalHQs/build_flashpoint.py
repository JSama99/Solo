import bpy,json,os,ast
from mathutils import Matrix
R=os.path.dirname(os.path.abspath(__file__));name='Flashpoint';A=R+'/'+name;bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend');s=bpy.context.scene
tr=ast.parse(open(R+'/../../Phase3/MediaDistrict/build_media.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name in ['col','mat','cube','prism']],type_ignores=[]),'helpers','exec'))
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/Before_Flashpoint.blend')
pre=set(s.objects);bpy.ops.import_scene.gltf(filepath=A+'/Source/Flashpoint_Higgsfield_Raw_candidate2.glb');stage=col(name+'_Source',bpy.data.collections['AssetStaging'])
for o in set(s.objects)-pre:
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
stage.hide_render=True;stage.hide_viewport=True
asset=col(name+'_Production',bpy.data.collections['CommerceDistrict']);root=bpy.data.objects.new(name+'_HQ_AssetRoot',None);asset.objects.link(root);root.parent=bpy.data.objects['RivalHQ_'+name];root['canonicalCompanyID']='flashpoint';root['method']='Source-informed architectural reconstruction';root['forward']='-Y'
stone=mat(name+'_PodiumConcrete',(.38,.43,.46),.1,.6);glass=mat(name+'_DarkGlazing',(.035,.10,.15),.55,.3);silver=mat(name+'_StructuralSilver',(.5,.59,.63),.65,.35);glow=mat(name+'_MomentumAccent',(.95,.21,.045),.1,.4,1.1)
def box(n,p,d,m):return cube(name+'_'+n,p,d,m,asset,root)
def wedge(n,verts,m):
 me=bpy.data.meshes.new(name+'_'+n);me.from_pydata(verts,[],[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]);me.update();o=bpy.data.objects.new(name+'_'+n,me);asset.objects.link(o);o.parent=root;me.materials.append(m);return o
box('Foundation',(0,0,1),(38,30,2),stone);box('LaunchPodium',(0,-.5,7),(36,27,10),glass);box('PodiumRoof',(0,-.5,12),(37,28,1),silver)
box('SideWing',(-11,1,13),(12,23,6),glass);box('WingCap',(-11,1,16.2),(13,24,.4),silver)
# Rebuild the selected source silhouette with planar walls and a sloped asymmetric roof.
bottom=[(-6,-9,12),(16,-9,12),(16,13,12),(-6,13,12)];top=[(-6,-7.5,69),(14,-7.5,75),(14,11.5,75),(-6,11.5,69)]
wedge('Tower',bottom+[(x,y,z-1.1) for x,y,z in top],glass);wedge('SlopedRoof',[(x,y,z-1.1) for x,y,z in top]+top,silver)
for z in range(16,68,4):
 t=(z-12)/57;box('HorizontalFin',(5-t,2,z),(22-2*t+.6,22-3*t+.6,.35),silver)
# Single narrow warm edge, attached to the front face; no all-over neon treatment.
prism('Flashpoint_VelocityEdge',[(12,.45,.4,-5.6,-9.1),(67,.45,.4,-5.6,-7.65)],glow,asset,root)
for x in [-16,-8,0,8,16]:box('PodiumMullion',(x,-14,7),(.35,.35,9.5),silver)
for z in [2.5,7,11.5]:box('PodiumFloor',(0,-.5,z),(36.4,27.4,.3),silver)
box('EntranceCanopy',(-9,-13.7,4),(12,2.5,.65),silver)
for x in [-13,-5]:box('EntryGlow',(x,-14.1,3.5),(.3,.3,3),glow)
for n,p,d,c,e in [('Signage_Main',(-9,-14.25,7),(7,.25,1.5),(.75,.39,.16),.5),('LaunchDisplay',(8,-14.25,7),(9,.25,4),(.22,.35,.42),.55),('Ticker',(4,-14.3,11),(20,.25,.6),(.8,.25,.07),.8)]:
 ma=mat(name+'_'+n,c,.1,.4,e);q=box(n,p,d,ma);q['semantic_target']=name+'_'+n;q['dynamic_material_target']=True;q['content']='blank'
for ma in [stone,glass,silver,glow]:
 group=[q for q in asset.objects if q.type=='MESH' and q.data.materials[0]==ma];bpy.ops.object.select_all(action='DESELECT')
 for q in group:q.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();q=group[0];trans=q.matrix_basis.copy()
 for v in q.data.vertices:v.co=trans@v.co
 q.matrix_basis=Matrix.Identity(4);q.name=ma.name
parent=root.parent;root.parent=None;root.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for q in asset.objects:q.select_set(True)
bpy.ops.export_scene.gltf(filepath=A+'/Export/Atlantis_'+name+'_HQ_v1.glb',use_selection=True,export_format='GLB',export_yup=True,export_extras=True);root.parent=parent;root.location=(0,0,0)
bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/Integration_Candidate.blend');print('FLASHPOINT_BUILT')
