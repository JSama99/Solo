import bpy,bmesh,json,os,math
from mathutils import Vector,Matrix
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase2/VentureHall/Blender/Atlantis_Phase2_Masterplan.blend');s=bpy.context.scene
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1

def col(n,p):
 c=bpy.data.collections.new(n);p.children.link(c);return c
D=bpy.data.collections['MediaDistrict'];H=col('Media_HeroLandmarks',D);support=col('Media_SupportingMassing',D);plaza=col('BroadcastPlaza',D);fore=col('TechComForecourt',D);water=col('Media_Promenade',D)
# Preserve unmodified generated source separately; never use failed repair study.
stage=col('SignalTV_Source',bpy.data.collections['AssetStaging']);before=set(s.objects);bpy.ops.import_scene.gltf(filepath=R+'/SignalTV/Source/SignalTV_Higgsfield_Raw.glb')
for o in set(s.objects)-before:
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
stage.hide_render=True;stage.hide_viewport=True

def mat(n,c,metal=0,rough=.4,emit=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emit:p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=emit
 return m
stone=mat('Media_PearlConcrete',(.63,.68,.7),0,.65);glass=mat('Media_BlueGlazing',(.055,.18,.27),.6,.24);silver=mat('Media_BrushedSilver',(.45,.55,.61),.75,.3);dark=mat('Media_Graphite',(.065,.08,.10),.5,.4);warm=mat('Media_LobbyLight',(.9,.56,.22),.1,.4,1.2);green=mat('Media_Planting',(.15,.29,.20),0,.8)
def cube(n,loc,size,m,c,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.name=n
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o);o.parent=parent;o.location=loc
 for v in o.data.vertices:
  for i in range(3):v.co[i]*=size[i]
 o.data.materials.append(m);return o

def prism(n,rings,m,c,parent):
 # Counterclockwise rectangular rings, closed with outward faces.
 vs=[]
 for z,x,y,cx,cy in rings:vs += [(cx-x/2,cy-y/2,z),(cx+x/2,cy-y/2,z),(cx+x/2,cy+y/2,z),(cx-x/2,cy+y/2,z)]
 fs=[(3,2,1,0)]
 for j in range(len(rings)-1):
  for i in range(4):fs.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
 k=(len(rings)-1)*4;fs.append(tuple(k+i for i in range(4)));me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);c.objects.link(o);o.parent=parent;me.materials.append(m);return o

def root(n,pos):
 c=col(n,H);o=bpy.data.objects.new(n+'_AssetRoot',None);c.objects.link(o);o.location=pos;o['slot_id']='Landmark_'+n;o['forward']='-Y';return c,o
T,tr=root('TechComTower',(835,220,14));S,sr=root('SignalTV',(860,460,14))
def tc(n,p,d,m):return cube('TechCom_'+n,p,d,m,T,tr)
def sg(n,p,d,m):return cube('SignalTV_'+n,p,d,m,S,sr)
# Direct Blender authoring authorized after external generation rejection.
tc('Foundation',(0,0,1),(73,68,2),stone);tc('NewsroomPodium',(0,0,8),(65,56,12),glass)
for z in [2.5,14.5]:tc('PodiumBand'+str(z),(0,0,z),(68,60,1),stone)
for x in [-30,-20,-10,0,10,20,30]:tc('NewsroomMullion'+str(x),(x,-28.3,8),(.5,.7,11),silver)
prism('TechCom_TaperedTower',[(15,40,36,0,4),(105,32,31,0,5),(132,25,27,3,6)],glass,T,tr)
# Vertical blade fins follow taper; north/south elevations and sides.
for f in [-.5,-.25,0,.25,.5]:
 for side in [-1,1]:
  prism('TechCom_VerticalFin',[(15,.65,1.1,f*40,4+side*18.2),(105,.65,1.1,f*32,5+side*15.7),(132,.65,1.1,3+f*25,6+side*13.7)],silver,T,tr)
for z in range(24,129,12):
 t=(z-15)/117;w=40-15*t;dep=36-9*t;tc('RecessedFloorBand'+str(z),(3*t,4+2*t,z),(w+.2,dep+.2,.35),dark)
prism('TechCom_CrownBladeWest',[(128,3,28,-9,6),(145,3,20,-6,7)],silver,T,tr)
prism('TechCom_CrownBladeEast',[(128,3,28,15,6),(138,3,22,14,7)],silver,T,tr)
tc('CrownGlazing',(3,7,135),(17,20,6),glass)
tc('EntryCanopy',(0,-30,5.7),(22,7,1),silver)
for x in [-9,9]:tc('EntryLight'+str(x),(x,-28.6,4),(.4,.3,3),warm)
# Broadcast campus: source-informed reconstruction, no reuse of damaged mesh.
sg('Foundation',(0,0,1),(92,62,2),stone)
for n,x,y,w,d,h in [('StudioA',-23,4,32,42,28),('StudioB',21,8,36,36,19),('Newsroom',0,14,25,25,32)]:
 sg(n,(x,y,2+h/2),(w,d,h),glass if n!='Newsroom' else stone)
 sg(n+'Roof',(x,y,2+h),(w+2,d+2,1),silver)
 for z in range(6,h,6):sg(n+'Band'+str(z),(x,y,2+z),(w+.35,d+.35,.5),silver)
prism('SignalTV_FacetedLobby',[(2,80,18,0,-17),(12,76,16,0,-17)],glass,S,sr)
sg('LobbyCanopy',(0,-20,12.5),(82,20,1),silver)
for x in range(-36,37,9):sg('LobbyMullion'+str(x),(x,-25.8,7),(.5,.5,10),silver)
for x in [-33,33]:sg('LobbyLight'+str(x),(x,-26.1,7),(.35,.2,8),warm)
# Folded studio roof and modest communication mast.
prism('SignalTV_FoldedRoof',[(30,34,44,-23,4),(32.5,22,44,-29,4)],silver,S,sr)
sg('MastBase',(0,14,35),(8,8,2),dark);sg('BroadcastMast',(0,14,41),(.8,.8,12),silver)
for z,w in [(39,6),(43,4)]:sg('Receiver'+str(z),(0,14,z),(w,.6,.6),silver)
# Each dynamic target retains a unique object, material and usable UV map.
def screen(n,pos,size,c,parent):
 m=mat(n,(.085,.22,.29),.15,.5,.3);o=cube(n,pos,size,m,c,parent);o['dynamic_material_target']=True;o['content']='blank';o['public_normal']='-Y';return o
screen('TechCom_Display_Main',(-20,-28.75,8),(18,.3,9),T,tr)
screen('TechCom_Ticker',(0,-30.1,13.5),(54,.3,1.2),T,tr)
screen('SignalTV_Display_Main',(-23,-17.4,21),(23,.3,12),S,sr)
screen('SignalTV_Display_Secondary',(21,-10.4,16),(25,.3,7),S,sr)
screen('SignalTV_Ticker',(0,-30.3,12.6),(70,.3,1.3),S,sr)
# Consolidate architecture by material without merging semantic display targets.
for c,rt in [(T,tr),(S,sr)]:
 for m in [stone,glass,silver,dark,warm]:
  group=[o for o in c.objects if o.type=='MESH' and o.data.materials[0]==m]
  if not group:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();o=group[0];o.name=c.name+'_'+m.name
  transform=o.matrix_basis.copy()
  for v in o.data.vertices:v.co=transform@v.co
  o.matrix_basis=Matrix.Identity(4)
# Six bounded refinements; four other original blocks remain untouched.
changes={}
for i,x,y,w,d,h in [(4,790,145,28,25,28),(5,790,400,28,32,24),(6,945,150,32,28,35),(7,945,260,36,28,28),(8,950,445,28,24,20),(9,945,515,38,26,32)]:
 o=bpy.data.objects['MediaDistrict_Block_%03d'%i];changes[o.name]={'before_position':list(o.location),'before_dimensions':list(o.dimensions),'after_dimensions':[w,d,h],'after_position':[x,y,14+h/2]}
 # Replace placeholder mesh with closed cube while retaining canonical object identity.
 temp=cube('_SupportTemplate',(0,0,0),(w,d,h),stone,support);old=o.data;o.data=temp.data.copy();bpy.data.objects.remove(temp,do_unlink=True);o.location=(x,y,14+h/2)
 for c in list(o.users_collection):c.objects.unlink(o)
 support.objects.link(o);cube(o.name+'_GlazedTerrace',(x,y,14+h+1),(w-4,d-4,2),glass,support)
# Public-space additions stay inside the canonical territory and off cross street y325.
spaces=[('TechCom_EntryWalk',(835,183,14.55),(22,6,.3),fore),('SignalTV_EntryWalk',(860,428,14.55),(36,2,.3),plaza),('TechCom_Forecourt',(840,165,14.55),(68,30,.3),fore),('SignalTV_BroadcastPlaza',(859,395,14.55),(90,64,.3),plaza),('Media_EsplanadeSouth',(978,220,14.55),(10,176,.3),water),('Media_EsplanadeNorth',(978,429,14.55),(10,190,.3),water),('Broadcast_WaterfrontWalk',(935,414,14.55),(70,10,.3),water)]
for n,p,d,c in spaces:cube(n,p,d,stone,c)
for x,y in [(813,153),(867,153),(822,371),(895,371),(822,414),(895,414)]:
 c=fore if y<200 else plaza;cube('Media_Planter',(x,y,15.2),(5,6,1),silver,c);cube('Media_GreenMass',(x,y,16.7),(4,5,2),green,c)
for name in ['Landmark_TechComTower_Massing','Landmark_SignalTV_Massing']:
 o=bpy.data.objects.get(name)
 if o:o.hide_render=True;o.hide_viewport=True
# Metrics and independent GLBs.
metrics={}
for c,rt in [(T,tr),(S,sr)]:
 bpy.context.view_layer.update();pts=[o.matrix_world@Vector(v) for o in c.objects if o.type=='MESH' for v in o.bound_box];lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
 metrics[c.name]={'origin':list(rt.location),'dimensions':[hi[i]-lo[i] for i in range(3)],'bounds':[lo,hi],'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in c.objects if o.type=='MESH'),'mesh_count':sum(o.type=='MESH' for o in c.objects),'materials':sorted({m.name for o in c.objects if o.type=='MESH' for m in o.data.materials}),'textures':0}
 saved=rt.location.copy();rt.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
 for o in c.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=R+'/'+c.name+'/Export/Atlantis_'+c.name+'_v1.glb',use_selection=True,export_format='GLB',export_yup=True);rt.location=saved
json.dump({'assets':metrics,'support_changes':changes,'public_spaces':[{'name':n,'position':p,'dimensions':d} for n,p,d,c in spaces]},open(R+'/clean_audit.json','w'),indent=2)
ref=bpy.data.collections['Reference']
def cam(n,pos,t,ortho):
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);ref.objects.link(o);o.location=pos;o.rotation_euler=(Vector(t)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=ortho;d.clip_end=20000;return o
cam('MediaDistrict_Aerial',(1400,-400,650),(820,325,65),750)
cam('TechCom_Hero',(1030,-60,190),(835,220,82),255)
cam('TechCom_PublicApproach',(835,125,100),(835,220,82),245)
cam('TechCom_Skyline',(1450,-350,190),(550,340,130),950)
cam('SignalTV_Hero',(1010,235,140),(860,460,34),160)
cam('SignalTV_Plaza',(860,330,38),(860,460,32),155)
cam('SignalTV_Waterfront',(1120,260,185),(860,460,35),260)
cam('MediaDistrict_Together',(1270,80,310),(855,340,75),530)
cam('MediaDistrict_ToSpire',(1500,160,390),(430,360,120),1500)
cam('Commerce_ToMedia',(480,-270,200),(850,325,90),900)
s.camera=bpy.data.objects['MediaDistrict_Aerial'];s.render.resolution_x=1200;s.render.resolution_y=900;s.render.resolution_percentage=100
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase3_Masterplan.blend')
print('MEDIA_BUILD_COMPLETE')
