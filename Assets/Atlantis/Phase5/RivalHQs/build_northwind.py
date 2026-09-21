import bpy,json,os,ast
from mathutils import Matrix
R=os.path.dirname(os.path.abspath(__file__));name='NorthwindLabs';A=R+'/'+name;bpy.ops.wm.open_mainfile(filepath=R+'/Blender/Atlantis_Phase5_Masterplan.blend');s=bpy.context.scene
tr=ast.parse(open(R+'/../../Phase3/MediaDistrict/build_media.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name in ['col','mat','cube','prism']],type_ignores=[]),'helpers','exec'))
# Store the incoming accepted state separately for sequential preservation testing.
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/Before_Northwind.blend')
pre=set(s.objects);bpy.ops.import_scene.gltf(filepath=A+'/Source/NorthwindLabs_Higgsfield_Raw.glb');stage=col(name+'_Source',bpy.data.collections['AssetStaging'])
for o in set(s.objects)-pre:
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
stage.hide_render=True;stage.hide_viewport=True
asset=col(name+'_Production',bpy.data.collections['TechCore']);root=bpy.data.objects.new(name+'_HQ_AssetRoot',None);asset.objects.link(root);root.parent=bpy.data.objects['RivalHQ_'+name];root['canonicalCompanyID']='northwind';root['method']='Source-informed architectural reconstruction, no source mesh deformation';root['forward']='-Y'
stone=mat(name+'_PaleStructure',(.66,.74,.77),.15,.55);glass=mat(name+'_ResearchGlazing',(.07,.21,.29),.5,.3);metal=mat(name+'_Silver',(.43,.56,.62),.65,.35);dark=mat(name+'_RoofLouvers',(.06,.10,.13),.3,.5);glow=mat(name+'_LabGlow',(.22,.58,.7),.1,.4,.55)
def box(n,p,d,m):return cube(name+'_'+n,p,d,m,asset,root)
box('Foundation',(0,0,1),(56,50,2),stone)
# Source-like tower to rear and connected front research wing.
box('ResearchWing',(0,-9,12),(52,28,20),glass);box('WingRoof',(0,-9,22.5),(54,30,1),stone)
box('Tower',(4,7,57),(29,29,110),glass)
for x in [-10.5,18.5]:
 for y in [-7.5,21.5]:box('StructuralCorner',(x,y,57),(1.2,1.2,110),stone)
for z in range(8,109,6):
 box('TowerFloor',(4,7,z),(30,30,.55),stone)
for x in [-6,-1,4,9,14]:box('VerticalMullion',(x,-7.8,66),(.4,.5,87),metal)
for y in [-3,3,9,15]:box('SideMullion',(18.8,y,57),(.4,.45,108),metal)
for z in [7,14,21]:box('WingFloor',(0,-9,z),(53,29,.6),stone)
for x in range(-24,25,6):box('WingFrame',(x,-23.4,12),(.65,.65,19),stone)
box('TechnicalRoof',(4,7,113.5),(32,32,3),stone)
# Recessed roof vents, not exposed science-fiction machinery.
for x in [-7,-3,1,5,9,13]:box('RoofVent',(x,-8.2,110.5),(1.5,.4,2),dark)
box('EntryCanopy',(12,-23.4,5),(16,3,1),metal)
for x in [-21,-9,3]:box('LabLight',(x,-23.8,12),(.2,.2,10),glow)
for n,p,d in [('Signage_Main',(12,-23.8,8),(10,.25,2)),('LabDisplay',(-13,-23.8,5),(8,.25,3))]:
 ma=mat(name+'_'+n,(.2,.48,.56),.1,.4,.4);q=box(n,p,d,ma);q['dynamic_material_target']=True;q['content']='blank'
for ma in [stone,glass,metal,dark,glow]:
 group=[q for q in asset.objects if q.type=='MESH' and q.data.materials[0]==ma];bpy.ops.object.select_all(action='DESELECT')
 for q in group:q.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();q=group[0];trans=q.matrix_basis.copy()
 for v in q.data.vertices:v.co=trans@v.co
 q.matrix_basis=Matrix.Identity(4);q.name=ma.name
parent=root.parent;root.parent=None;root.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for q in asset.objects:q.select_set(True)
bpy.ops.export_scene.gltf(filepath=A+'/Export/Atlantis_'+name+'_HQ_v1.glb',use_selection=True,export_format='GLB',export_yup=True);root.parent=parent;root.location=(0,0,0)
bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/Integration_Candidate.blend');print('NORTHWIND_BUILT')
