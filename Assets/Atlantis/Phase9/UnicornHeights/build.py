"""Deterministic, bounded Phase 9 authoring; Phase 8 remains read-only."""
import bpy,json,math,ast,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));P=json.load(open(R+'/site_plan.json'))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase8/CommerceDistrict/Blender/Atlantis_Phase8_Masterplan.blend');s=bpy.context.scene
for path,names in [('Assets/Atlantis/Phase3/MediaDistrict/build_media.py',['col','mat'])]:
 t=ast.parse(open(path).read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),path,'exec'))
C=col('Phase9_UnicornProduction',bpy.data.collections['UnicornHeights']);B=col('Unicorn_Campuses',C);U=col('Unicorn_PublicRealm',C);V=col('Unicorn_ReviewCameras',C);K=col('Unicorn_KitLibrary',C);K.hide_render=True;K.hide_viewport=True;L=col('Unicorn_PlayerContract',C)
mats={k:mat('Unicorn_'+k,c,metal,rough) for k,c,metal,rough in [('stone',(.69,.68,.60),0,.65),('glass',(.075,.20,.23),.4,.23),('metal',(.31,.36,.34),.6,.35),('paving',(.57,.58,.51),0,.8),('lawn',(.20,.32,.18),0,.9),('leaves',(.11,.25,.13),0,.9),('wood',(.31,.21,.12),0,.8),('road',(.18,.22,.22),0,.85),('water',(.10,.28,.29),.35,.2)]}
mats['glow']=mat('Unicorn_QuietLobbyGlow',(.90,.73,.48),0,.5,.6)
cache={};t=ast.parse(open('Assets/Atlantis/Phase6/StartupRow/build.py').read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='box'],type_ignores=[]),'box','exec'))
hidden=[]
for o in list(s.objects):
 if o.type=='MESH' and (o.name.startswith(('UnicornHeights_Block_','Heights_Boulevard_')) or ((o.name.startswith('UnicornHQ_Slot_') or o.name.startswith('Player_UnicornHQ_Slot_')) and o.name.endswith(('_Massing','_Parcel')))):
  o.hide_render=True;o.hide_viewport=True;hidden.append(o.name)
# Landscape overlay respects the existing headland; terrain geometry is untouched.
me=bpy.data.meshes.new('Unicorn_LandscapeGround');me.from_pydata([(520,770,85.025),(1090,770,85.025),(1120,830,85.025),(1120,1150,85.025),(550,1150,85.025),(520,1110,85.025)],[],[(0,1,2,3,4,5)]);me.materials.append(mats['lawn']);o=bpy.data.objects.new('Unicorn_LandscapeGround',me);U.objects.link(o)
paths=[]
def ribbon(name,points,width,ma='paving',record=True):
 for i,(aa,bb) in enumerate(zip(points,points[1:])):
  a,b=Vector(aa),Vector(bb);d=b-a;n=Vector((-d.y,d.x,0)).normalized()*width/2;top=[a-n,b-n,b+n,a+n];vs=[list(p) for p in top]+[[p.x,p.y,85] for p in top];me=bpy.data.meshes.new(name);me.from_pydata(vs,[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);me.materials.append(mats[ma]);o=bpy.data.objects.new(name+'_%02d'%i,me);U.objects.link(o)
 if record:paths.append({'name':name,'points':points,'width':width,'max_grade':max(abs(b[2]-a[2])/math.dist(a[:2],b[:2]) for a,b in zip(points,points[1:]))})
ribbon('Unicorn_ArrivalRoad',[[600,760,86.344],[600,775,85.6],[1098,775,85.6]],16,'road',False)
ribbon('Unicorn_BoulevardWalk',[[585,790,85.6],[1105,790,85.6]],5)
# Match the actual tilted bridge deck at the arrival edge, rather than its bounding box.
bpy.context.view_layer.update();bridge=bpy.data.objects['Bridge_TechCore_00'];end_y=max(v.co.y for v in bridge.data.vertices);top_z=max(v.co.z for v in bridge.data.vertices)
options=[bridge.matrix_world@Vector((x,end_y-1,top_z)) for x in [-10.5,10.5]];landing=min(options,key=lambda p:p.x)
ribbon('Unicorn_BridgeWalk',[list(landing),[587,790,85.6]],5)
ribbon('Unicorn_CampusSpine',[[710,790,85.6],[710,1150,85.6],[1108,1150,85.6]],6)
ribbon('Unicorn_CampusCrosswalk',[[520,920,85.6],[1110,920,85.6]],5)
ribbon('Unicorn_WestGardenWalk',[[520,790,85.6],[520,1110,85.6],[550,1150,85.6],[710,1150,85.6]],5)
ribbon('Unicorn_OverlookLink',[[520,825,85.6],[585,825,85.6],[585,790,85.6]],5)
ribbon('Unicorn_PlazaArrival',[[850,790,85.6],[850,920,85.6]],6)
ribbon('Unicorn_PlayerArrival',[[890,850,85.6],[900,850,85.6]],6)
ribbon('Unicorn_PlayerFrontage',[[970,790,85.6],[970,792.5,85.6]],6)
for space in P['public_spaces']:
 x,y,z=space['center'];w,d=space['size'];box(space['name'],(x,y,85.3),(w,d,.6),'paving')
# The original parcel is reserved lawn, without any tower or permanent support structure.
box('Unicorn_PlayerReservedLawn',(970,850,85.25),(140,115,.5),'lawn')
slot=bpy.data.objects['Player_UnicornHQ_Slot']
for n,pos,size in [('PlayerHQ_Parcel',(0,0,0),(140,115,0)),('PlayerHQ_Forward',(0,-57.5,0),(0,-1,0)),('PlayerHQ_PlazaAnchor',(-120,0,.6),(80,70,0)),('PlayerHQ_SignageAnchor',(0,-54,3),(18,.2,2)),('PlayerHQ_GrowthEnvelope',(0,0,90),(140,115,180))]:
 o=bpy.data.objects.new(n,None);L.objects.link(o);o.parent=slot;o.location=pos;o.empty_display_type='ARROWS' if 'Forward' in n else 'CUBE';o.empty_display_size=1;o['dimensions_m']=size;o['planning_only']=True;o['reserved_for_future_asset']=True
 if 'Growth' in n:o['height_limit_m']=180;o['future_states']='empty / construction / completed / upgraded';o['allocation']='Tower 64x58; podium 104x76; annex 28x44; garden 30x40; forecourt 110x22, final design to reconcile within parcel'
o=bpy.data.objects.new('PlayerUnicornHQ_Signage_Main',None);L.objects.link(o);o.parent=bpy.data.objects['PlayerHQ_SignageAnchor'];o['dynamic_company_identity']=True
frontages=[]
for a in P['sites']:
 n=a['id'];x,y,z=a['position'];w,d,h=a['width'],a['depth'],a['height'];rt=bpy.data.objects.new(n,None);B.objects.link(rt);rt.location=a['position'];rt['typology']=a['typology'];rt['height_m']=h;rt['future_lods']='LOD0 / LOD1 / LOD2; not authored'
 def q(part,pos,size,ma):return box(n+'_'+part,pos,size,ma,B,rt)
 q('Foundation',(0,0,-.3),(w,d,.6),'stone');q('Podium',(0,0,4),(w,d,8),'stone')
 sw,sd=w-12,d-12;q('GlassVolume',(0,0,(8+h-.6)/2),(sw,sd,h-8-.6),'glass');q('Crown',(0,0,h-.3),(sw+1,sd+1,.6),'stone')
 q('RoofGarden',(0,0,h+.12),(sw-4,sd-4,.24),'lawn')
 for side in [-1,1]:
  for zz in range(12,int(h),5):q('FloorLine',(0,side*(sd/2+.12),zz),(sw,.3,.32),'metal')
  for xx in [-sw/2,0,sw/2]:q('VerticalPier',(xx,side*(sd/2+.25),(h+8)/2),(.6,.6,h-8),'stone')
  for zz in range(12,int(h),5):q('SideLine',(side*(sw/2+.12),0,zz),(.3,sd,.32),'metal')
  q('LobbyBand',(0,side*(d/2+.08),3),(w-6,.16,4.8),'glass')
 q('EntryApron',(0,-d/2-1.5,-.3),(6,3,.6),'paving');q('Lobby',(0,-d/2-.12,2.8),(8,.1,4),'glow');q('Canopy',(0,-d/2-1,5.3),(16,3,.3),'metal')
 sign=q('Identity',(w*.28,-d/2-.15,4.7),(8,.15,.8),'metal');sign['semantic_target']='Unicorn_CampusIdentity_'+n[-2:]
 # Broad landscape campus base; gardens stop before entry routes.
 box(n+'_Landscape',(x,y,85.15),(w+20,d+20,.3),'lawn')
 start=[x,y-d/2-3,85.6]
 # Each entrance heads south to its nearest unobstructed east-west public route.
 ty=790 if y<900 else 920 if y<1100 else 1150
 if ty==1150:
  route=[start,[x-w/2-14,start[1],85.6],[x-w/2-14,1150,85.6]]
  if n=='Unicorn_Campus_08':route=[start,[520,start[1],85.6]]
 else:route=[start,[x,ty,85.6]]
 if n=='Unicorn_Campus_02':route=[start,[710,start[1],85.6]]
 if n=='Unicorn_Campus_03':route=[start,[1030,920,85.6]]
 ribbon('Unicorn_Frontage_'+n,route,4);frontages.append({'building':n,'points':route})
# A single shared faceted canopy mesh replaces cube vegetation.
import bmesh
bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
for v in bm.verts:v.co.x*=4;v.co.y*=4;v.co.z*=5
canopy=bpy.data.meshes.new('Unicorn_SharedTreeCanopy');bm.to_mesh(canopy);bm.free();canopy.materials.append(mats['leaves'])
# Repeated low-poly tree geometry, deterministic spacing with clear pedestrian corridors.
trees=[]
for x,y in [(610,807),(640,807),(680,807),(745,807),(780,807),(1060,805),(550,880),(575,880),(600,880),(680,895),(745,890),(780,890),(805,875),(895,950),(930,950),(965,950),(1000,950),(580,1050),(665,1045),(750,1030),(875,1080),(875,1110),(1000,1120),(1060,1120),(1100,1080),(1095,865),(1095,900)]:
 box('Unicorn_TreeTrunk',(x,y,87),( .5,.5,4),'wood');o=box('Unicorn_TreeCanopy',(x,y,91),(7,7,6),'leaves');o.data=canopy;o['vegetation']=True;trees.append([x,y])
t=ast.parse(open('Assets/Atlantis/Phase6/StartupRow/plan.py').read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in ['inside','pointseg','orient','segdist','polyseg','polydist','corners']],type_ignores=[]),'geometry','exec'))
for x in range(550,1100,22):
 for y in [805,895,1020,1135]:
  if not inside((x,y),P['terrain_polygon']) or 892<x<1048 and 784<y<916:continue
  if any(abs(x-a['position'][0])<a['width']/2+9 and abs(y-a['position'][1])<a['depth']/2+9 for a in P['sites']):continue
  if any(pointseg((x,y),a,b)<p['width']/2+5 for p in paths for a,b in zip(p['points'],p['points'][1:])):continue
  if any(math.dist((x,y),pt)<11 for pt in trees) or 802<x<898 and 807<y<908:continue
  box('Unicorn_TreeTrunk',(x,y,87),(.5,.5,4),'wood');o=bpy.data.objects.new('Unicorn_TreeCanopy',canopy);U.objects.link(o);o.location=(x,y,91);o['vegetation']=True;trees.append([x,y])
for x,y in [(818,825),(882,825),(818,875),(882,875),(548,815),(573,815)]:
 box('Unicorn_Seat',(x,y,86.1),(3,.7,.2),'wood')
 for dx in [-1,1]:box('Unicorn_SeatSupport',(x+dx,y,85.8),(.2,.5,.4),'metal')
for x,y in [(810,850),(890,875),(552,838),(575,838),(735,797),(800,797),(1065,797)]:
 box('Unicorn_LightBase',(x,y,86.2),(.25,.25,1.2),'metal');o=box('Unicorn_LandscapeLight',(x,y,86.85),(.4,.4,.1),'glow');o['semantic_target']='Unicorn_Night_Landscape'
box('Unicorn_ReflectingPool',(825,900,85.4),(32,10,.8),'stone');box('Unicorn_PoolSurface',(825,900,85.82),(30,8,.04),'water')
# Scenic edge guard, outside the clear overlook floor.
box('Unicorn_OverlookGuard',(560,840,86.15),(44,.2,1.1),'metal')

# Union coplanar paving tops through Blender's constrained triangulator.
# Preserve skirts and graded ramps; one triangulated top eliminates overlapping faces.
from mathutils.geometry import delaunay_2d_cdt
bpy.context.view_layer.update();flat_vertices=[];flat_faces=[]
for ob in list(U.objects):
 if ob.type!='MESH':continue
 remove=[]
 for face in ob.data.polygons:
  pts=[ob.matrix_world@ob.data.vertices[i].co for i in face.vertices]
  if ob.data.materials[face.material_index]!=mats['paving'] or not all(abs(p.z-85.6)<.0001 for p in pts):continue
  signed=sum(a.x*b.y-b.x*a.y for a,b in zip(pts,pts[1:]+pts[:1]))
  if abs(signed)<.00001:continue
  if signed<0:pts.reverse()
  off=len(flat_vertices);flat_vertices.extend(Vector((p.x,p.y)) for p in pts);flat_faces.append(list(range(off,off+len(pts))));remove.append(face.index)
 if remove:
  old=ob.data;me=bpy.data.meshes.new(ob.name+'_Skirt');keep=[f for f in old.polygons if f.index not in remove];me.from_pydata([list(v.co) for v in old.vertices],[],[list(f.vertices) for f in keep])
  for ma in old.materials:me.materials.append(ma)
  for f,prior in zip(me.polygons,keep):f.material_index=prior.material_index
  me.update();ob.data=me
verts,edges,faces,_,_,orig_faces=delaunay_2d_cdt(flat_vertices,[],flat_faces,1,.00001,True)
kept=[f for f,ids in zip(faces,orig_faces) if ids]
me=bpy.data.meshes.new('Unicorn_ContinuousPaving');me.from_pydata([(v.x,v.y,85.6) for v in verts],[],kept);me.materials.append(mats['paving']);me.update();ob=bpy.data.objects.new('Unicorn_ContinuousPaving',me);U.objects.link(ob)
assert kept,'Paving union must contain interior faces'
# Consolidate new building surfaces only, retaining semantic signage as separate objects.
bpy.context.view_layer.update();components=sum(o.type=='MESH' for o in B.objects)
for rt in [o for o in B.objects if o.type=='EMPTY']:
 for light in [False,True]:
  obs=[o for o in rt.children if o.type=='MESH' and not o.get('semantic_target') and any(m==mats['glow'] for m in o.data.materials)==light]
  if not obs:continue
  vs=[];fs=[];idx=[];ms=[]
  for ob in obs:
   offset=len(vs);vs.extend([list(ob.matrix_basis@v.co) for v in ob.data.vertices])
   for f in ob.data.polygons:
    fs.append([offset+i for i in f.vertices]);ma=ob.data.materials[f.material_index]
    if ma not in ms:ms.append(ma)
    idx.append(ms.index(ma))
  me=bpy.data.meshes.new(rt.name+'_Combined');me.from_pydata(vs,[],fs)
  for ma in ms:me.materials.append(ma)
  for f,i in zip(me.polygons,idx):f.material_index=i
  me.update();ob=bpy.data.objects.new(rt.name+('_OccupiedSurfaces' if light else '_Architecture'),me);B.objects.link(ob);ob.parent=rt
  for o in obs:bpy.data.objects.remove(o,do_unlink=True)
for typ in sorted({a['typology'] for a in P['sites']}):
 src=next(o for o in B.objects if o.type=='EMPTY' and o.get('typology')==typ);rt=bpy.data.objects.new(typ,None);K.objects.link(rt)
 for child in src.children:
  o=child.copy();o.data=child.data;K.objects.link(o);o.parent=rt

cams=[('UnicornHeights_Aerial',(1480,420,650),(820,970,95),760),('UnicornHeights_Entry',(600,782,87.3),(970,850,105),0),('UnicornHeights_MainBoulevard',(725,790,87.3),(1080,790,100),0),('PlayerHQ_Slot_Hero',(1140,695,245),(965,860,85),0),('PlayerHQ_To_Spire',(970,793,87.3),(50,380,220),0),('Unicorn_FounderPlaza',(847,817,87.3),(850,875,100),0),('Unicorn_ScenicOverlook',(548,832,87.3),(40,350,140),0),('Unicorn_NightPreview',(740,805,105),(840,1030,145),0),('Unicorn_Approach',(460,590,180),(770,940,135),0),('Unicorn_CampusReview',(710,1045,87.3),(810,1070,125),0),('Unicorn_To_TechCore',(585,790,87.3),(130,360,120),0),('Unicorn_WalkingRoute',(850,792,87.3),(850,850,88),0)]
for n,pos,target,ortho in cams:
 assert not bpy.data.objects.get(n),n
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);V.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=28;d.clip_start=.2;d.clip_end=10000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0
A={'hidden_original_objects':hidden,'paths':paths,'frontages':frontages,'authored_components':components,'shared_box_modules':len(cache),'vegetation_count':len(trees),'review_cameras':[a[0] for a in cams]}
json.dump(A,open(R+'/build_audit.json','w'),indent=2);bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase9_Masterplan.blend');print('PHASE9_BUILT')
