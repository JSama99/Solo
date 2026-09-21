import bpy,json,os,math,ast
from mathutils import Vector,Matrix
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase3/MediaDistrict/Blender/Atlantis_Phase3_Masterplan.blend');s=bpy.context.scene
# Reuse the established closed-solid authoring helpers without executing the Media build.
tree=ast.parse(open(R+'/../../Phase3/MediaDistrict/build_media.py').read());helpers=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['col','mat','cube','prism']];exec(compile(ast.Module(body=helpers,type_ignores=[]),'authoring_helpers','exec'))
profiles=[dict(canonicalCompanyID='pallas',displayName='Pallas AI',semanticID='PallasAI',district='TechCore',slotID='RivalHQ_Slot_04',hqTier='3',targetHeightRange=[120,170],currentHeight=160,footprint=[60,42],position=[220,300,14],futureUpgradeEnvelope=[64,44,180],architecturalLanguage='Monumental composed taper, paired crown blades, formal compact podium',primaryMaterialFamily='Deep neutral glass, pale bronze metal, restrained stone',accentLanguage='Warm restrained premium edges',signageStrategy='Integrated understated podium mark',nightIdentity='Warm crown bars and lobby glow',visibilityPriority=['Venture District','Media District','Tech Core']),dict(canonicalCompanyID='northwind',displayName='Northwind Labs',semanticID='NorthwindLabs',district='TechCore',slotID='RivalHQ_Slot_03',hqTier='2/3',targetHeightRange=[100,130],preferredHeightRange=[80,130],currentHeight=115,footprint=[58,52],position=[-100,520,14],futureUpgradeEnvelope=[65,60,150],architecturalLanguage='Offset technical tower, low research wing, modular structural frame',primaryMaterialFamily='Cool blue glass and pale silver',accentLanguage='Muted cyan technical grid',signageStrategy='Small precise lobby plate',nightIdentity='Cool vertical laboratory grid',visibilityPriority=['Tech Core','Media District','Unicorn Heights']),dict(canonicalCompanyID='flashpoint',displayName='Flashpoint',semanticID='Flashpoint',district='CommerceDistrict',slotID='RivalHQ_Slot_05',hqTier='2',targetHeightRange=[55,90],preferredHeightRange=[55,95],currentHeight=75,footprint=[40,32],position=[430,-240,14],futureUpgradeEnvelope=[42,34,90],architecturalLanguage='Asymmetric stepped wedge, sharp launch-facing podium',primaryMaterialFamily='Dark glass with light structural metal',accentLanguage='Concentrated warm orange-red accent',signageStrategy='Visible south launch facade panel',nightIdentity='Energetic diagonal accent and brighter entry',visibilityPriority=['Startup Row','Commerce District','Founder skyline'])]
planning=col('Atlantis_RivalProfiles',bpy.data.collections['Atlantis']);allassets=[]
for p in profiles:
 p.update(rotationDegrees=[0,0,0],forward='-Y Blender / +Z glTF',planningOnly=True,canonicalSource='App/ContentLibrary.swift',lodReadiness=['LOD0 future hero','LOD1 future simplified HQ','LOD2 future skyline proxy'],runtimeMapping='Future visible canonical projections only; no thresholds or simulation state authored')
 group=col(p['semanticID']+'_Blockout',bpy.data.collections[p['district']]);root=bpy.data.objects.new('RivalHQ_'+p['semanticID'],None);group.objects.link(root);root.parent=bpy.data.objects[p['slotID']];root.location=(0,0,0)
 for k,val in p.items():root[k]=json.dumps(val) if isinstance(val,(list,dict)) else val
 profile=bpy.data.objects.new(p['semanticID']+'_PresentationProfile',None);planning.objects.link(profile);profile.hide_render=True;profile['profile_json']=json.dumps(p)
 n=p['semanticID'];glass=mat(n+'_Glass',(.08,.12,.16) if n=='PallasAI' else (.07,.18,.24) if n=='NorthwindLabs' else (.055,.08,.13),.5,.3);metal=mat(n+'_Metal',(.48,.39,.27) if n=='PallasAI' else (.65,.72,.76),.65,.35);stone=mat(n+'_Podium',(.55,.55,.50) if n=='PallasAI' else (.53,.62,.66),0,.6);accent=mat(n+'_Accent',(.9,.63,.29) if n=='PallasAI' else (.17,.65,.85) if n=='NorthwindLabs' else (1,.19,.035),.1,.35,1.5 if n!='Flashpoint' else 2.5)
 def box(tag,pos,size,m):return cube(n+'_'+tag,pos,size,m,group,root)
 w,d=p['footprint'];box('Foundation',(0,0,1),(w,d,2),stone)
 if n=='PallasAI':
  box('Podium',(0,0,7),(54,36,10),glass);box('PodiumRoof',(0,0,12.5),(56,38,1),metal)
  prism(n+'_ComposedTower',[(13,38,30,0,2),(137,29,25,0,2),(154,25,22,0,2)],glass,group,root)
  for x in [-15,15]:prism(n+'_CrownBlade',[(135,2,27,x,2),(160,2,20,x*.8,2)],metal,group,root)
  for x in [-12,12]:box('CrownLight',(x,-8.3,155),(.6,.3,7),accent)
  box('EntryCanopy',(0,-19,5),(20,4,1),metal);sign=(0,-18.4,8);size=(14,.3,3)
 elif n=='NorthwindLabs':
  box('ResearchPodium',(0,0,7),(54,46,10),glass);box('ResearchRoof',(0,0,12.5),(56,48,1),metal)
  box('TechnicalTower',(-9,5,60),(25,28,94),glass);box('LabWing',(17,4,23),(17,30,20),glass)
  for z in [20,40,60,80,100]:box('StructuralBand',(-9,5,z),(27,30,1),metal)
  for x in [-21,-9,3]:box('TechnicalFrame',(x,-9.4,60),(.7,.7,95),metal)
  box('Crown',(-9,5,111),(27,30,8),metal)
  for x in [-18,-9,0]:box('ReadoutLight',(x,-10,65),(.35,.3,83),accent)
  sign=(16,-23.4,7);size=(12,.3,2.5)
 else:
  box('LaunchPodium',(0,0,5),(36,28,6),glass)
  prism(n+'_VelocityWedge',[(8,27,22,-3,2),(57,27,22,-3,2),(75,17,18,1,3)],glass,group,root)
  box('LaunchWing',(12,1,22),(10,24,28),glass)
  for z in [12,27,42,57]:box('OffsetFin',(0,-9.5,z),(29,1,.8),metal)
  prism(n+'_VelocityLight',[(9,.6,.4,-15,-9.8),(57,.6,.4,-15,-9.8),(74,.6,.4,-7,-6.3)],accent,group,root)
  sign=(0,-14.4,5.3);size=(24,.3,3)
 display=box('Signage_Main',sign,size,accent);display['future_signage_target']=True;display['content']='blank'
 bpy.data.objects[p['slotID']+'_Massing'].hide_render=True;bpy.data.objects[p['slotID']+'_Massing'].hide_viewport=True
 allassets.extend(group.objects)
# Preserve every generic slot and unassigned placeholder; they are not new canonical rivals.
json.dump({'schema':'RivalAtlantisProfile planning v1','tiers':{'1':{'height':[15,35]},'2':{'height':[40,100]},'3':{'height':[100,180]}},'profiles':profiles,'unassignedSlots':['RivalHQ_Slot_01','RivalHQ_Slot_02'],'simulationNote':'Runtime strengths/archetypes remain untouched. Requested prestige/tier labels are visual direction only.'},open(R+'/rival_profiles.json','w'),indent=2)
ref=bpy.data.collections['Reference']
def cam(n,pos,target,scale):
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);ref.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale;d.clip_end=20000;return o
cam('Rivals_Aerial',(1000,-1200,1300),(80,240,85),1700)
cam('Pallas_HeroBlockout',(420,60,200),(220,300,90),245)
cam('Northwind_HeroBlockout',(90,270,185),(-100,520,75),210)
cam('Flashpoint_HeroBlockout',(580,-440,145),(430,-240,50),140)
cam('Founder_RivalSkyline',(-875,-950,90),(40,240,130),1900)
cam('StartupRow_Flashpoint',(-220,-500,35),(430,-240,60),330)
bpy.data.objects['StartupRow_Flashpoint'].data.type='PERSP';bpy.data.objects['StartupRow_Flashpoint'].data.lens=85
cam('Venture_Pallas',(-320,300,35),(220,300,100),420)
bpy.data.objects['Venture_Pallas'].data.type='PERSP';bpy.data.objects['Venture_Pallas'].data.lens=75
cam('Northwind_TechApproach',(-100,290,100),(-100,520,75),250)
cam('Media_RivalSkyline',(835,260,130),(80,380,120),850)
cam('TechCore_Rivals_Aerial',(600,-200,750),(70,410,70),900)
s.camera=bpy.data.objects['Rivals_Aerial'];s.render.resolution_x=1200;s.render.resolution_y=900;s.render.resolution_percentage=100
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for o in allassets:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=R+'/Export/Atlantis_Phase4_RivalBlockout.glb',use_selection=True,export_format='GLB',export_yup=True)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase4_Masterplan.blend')
print('RIVALS_BUILT')
