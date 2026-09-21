"""Bounded modular Commerce production; Phase 7 is read-only input."""
import bpy,json,math,ast,os
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));P=json.load(open(R+'/site_plan.json'))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase7/FounderDistrict/Blender/Atlantis_Phase7_Masterplan.blend');s=bpy.context.scene
for path,names in [('Assets/Atlantis/Phase3/MediaDistrict/build_media.py',['col','mat']),('Assets/Atlantis/Phase6/StartupRow/plan.py',['inside','pointseg','orient','segdist','polyseg','polydist','corners'])]:
 t=ast.parse(open(path).read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),path,'exec'))
C=col('Phase8_CommerceProduction',bpy.data.collections['CommerceDistrict']);B=col('Commerce_Buildings',C);U=col('Commerce_PublicRealm',C);V=col('Commerce_ReviewCameras',C);K=col('Commerce_KitLibrary',C);K.hide_render=True;K.hide_viewport=True
mats={k:mat('Commerce_'+k,c,metal,rough) for k,c,metal,rough in [('stone',(.58,.59,.55),0,.7),('silver',(.42,.48,.49),.45,.4),('warm',(.55,.41,.29),.1,.65),('glass',(.07,.19,.24),.35,.25),('metal',(.19,.25,.28),.6,.4),('paving',(.47,.49,.46),0,.8),('lightstone',(.72,.70,.61),0,.7),('planting',(.12,.23,.15),0,.8),('wood',(.30,.21,.13),0,.8),('paint',(.84,.82,.72),0,.8)]}
mats['glow']=mat('Commerce_LobbyHotelGlow',(.93,.70,.42),0,.5,.65);mats['sign']=mat('Commerce_SignageSurface',(.24,.45,.48),.1,.5,.45)
cache={};t=ast.parse(open('Assets/Atlantis/Phase6/StartupRow/build.py').read());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='box'],type_ignores=[]),'box','exec'))
hidden=[]
for o in list(s.objects):
 if o.name.startswith(('CommerceDistrict_Block_','CommerceDistrict_Podium_')) or o.name=='Commerce_CentralPlaza':o.hide_render=True;o.hide_viewport=True;hidden.append(o.name)
paths=[]
def ribbon(name,points,width,ma='paving',record=True):
 for i,(aa,bb) in enumerate(zip(points,points[1:])):
  a,b=Vector(aa),Vector(bb);d=b-a;n=Vector((-d.y,d.x,0)).normalized()*width/2;top=[a-n,b-n,b+n,a+n];vs=[list(p) for p in top]+[[p.x,p.y,14] for p in top];me=bpy.data.meshes.new(name);me.from_pydata(vs,[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);me.materials.append(mats[ma]);o=bpy.data.objects.new(name+'_%02d'%i,me);U.objects.link(o)
 if record:paths.append({'name':name,'points':points,'width':width,'max_grade':max(abs(b[2]-a[2])/math.dist(a[:2],b[:2]) for a,b in zip(points,points[1:]))})
# Reuse the primary road authority. Sidewalk extensions stay in its immediate right-of-way.
walks=[]
for road in P['roads']:
 for j,(aa,bb) in enumerate(zip(road['points'],road['points'][1:])):
  a,b=Vector(aa),Vector(bb)
  if road['id']=='Commerce_Boulevard' and j==3:continue
  d=b-a;n=Vector((-d.y,d.x,0)).normalized();width=5 if road['width_m']==24 else 4
  for side in [-1,1]:
   pa=a+n*side*(road['width_m']/2+width/2);pb=b+n*side*(road['width_m']/2+width/2);pa.z=pb.z=15.4
   # Avoid covering any part of Flashpoint's immutable parcel.
   if polyseg(corners(430,-240,75,60),pa,pb)<width/2:
    # Boulevard north/west shoulder continues; south/east shoulder is interrupted at the protected parcel.
    if road['id']=='Commerce_Boulevard' and j==1 and side==-1:
     continue
   ribbon('Commerce_Sidewalk_'+road['id']+'_'+str(j)+'_'+str(side),[list(pa),list(pb)],width);walks.append({'a':list(pa),'b':list(pb),'width':width})
# Customer and event spaces are level with public walks, with structural skirts to terrain.
for space in P['public_spaces']:
 x,y,z=space['center'];w,d=space['size'];box('Commerce_'+space['name']+'_Surface',(x,y,(14+z)/2),(w,d,z-14),'paving')
# Deliberate plaza connections; no changes to Flashpoint's approved parcel or geometry.
ribbon('Commerce_PlazaToCrossStreet',[[213,-132,15.4],[213,-200.5,15.4]],6)
ribbon('Commerce_EventApproach',[[106,-225,15.4],[106,-179.5,15.4]],5)
ribbon('Commerce_MarketWalk',[[213,-132,15.4],[265,-132,15.4],[288,-153,15.4],[288,-179.5,15.4]],4)
ribbon('Commerce_FlashpointArrival',[[452,-303,15.4],[479,-303,15.4],[479,-280,15.4],[474,-260,14.6],[467.5,-260,14.6]],4)
# Flashpoint source parcel surface is 14.6; a long approach drops at under 5%.
ribbon('Commerce_FlashpointToCrossStreet',[[474,-260,14.6],[478,-260,14.6],[478,-240,15.4],[478,-179.5,15.4]],4)
# Building kit: setback office/hotel slabs, commercial podiums, separated signs and occupied surfaces.
for site in P['sites']:
 n=site['id'];typ=site['typology'];w,d,h=site['width'],site['depth'],site['height'];finish=site['material'];rt=bpy.data.objects.new(n,None);B.objects.link(rt);rt.location=site['position'];rt.rotation_euler.z=math.radians(site['angle']);rt['typology']=typ;rt['height_m']=h;rt['planning_only']=True
 def q(part,pos,size,ma):return box(n+'_'+part,pos,size,ma,B,rt)
 podium=8 if h>20 else 5;hotel='Hotel' in typ;conference='Conference' in typ;retail='Retail' in typ
 q('Foundation',(0,0,-.7),(w,d,1.4),'stone');q('Podium',(0,0,podium/2),(w,d,podium),finish)
 sw,sd=(w-6,d-6) if h>20 else (w,d)
 if h>podium:q('UpperSlab',(0,1,(podium+h-.6)/2),(sw,sd,h-.6-podium),finish)
 for side in [-1,1]:
  q('RetailGlazing',(0,side*(d/2+.05),2.6),(w-2,.12,4.2),'glass')
  for x in range(-int(w/2)+2,int(w/2),5):q('RetailPier',(x,side*(d/2+.15),2.6),(.4,.3,4.4),'lightstone')
  if hotel:
   for level,z in enumerate(range(11,int(h)-2,3)):
    for ix,x in enumerate(range(-int(sw/2)+2,int(sw/2)-1,3)):
     q('HotelWindow',(x,1+side*(sd/2+.08),z),(1.5,.14,1.8),'glow' if (ix+level)%9==0 else 'glass')
   for x in [-sw/2+1,sw/2-1]:q('HotelEdge',(x,1+side*(sd/2+.15),(h+podium)/2),(.5,.3,h-podium),'lightstone')
  elif h>20:
   for z in range(11,int(h)-1,4):
    q('OfficeBand',(0,1+side*(sd/2+.08),z),(sw-1.2,.16,2.7),'glass');q('Spandrel',(0,1+side*(sd/2+.2),z-1.6),(sw,.25,.35),'silver')
   for x in range(-int(sw/2)+1,int(sw/2),6):q('FacadeFin',(x,1+side*(sd/2+.23),(h+podium)/2),(.25,.55,h-podium),'lightstone')
  if h>20:
   for z in range(11,int(h)-1,4):q('SideBand',(side*(sw/2+.08),1,z),(.14,sd-2,2.4),'glass')
 q('EntryApron',(0,-d/2-1.25,-.7),(6,2.5,1.4),'paving')
 q('Lobby',(0,-d/2-.15,2.4),(5,.16,4.5),'glow');q('EntryCanopy',(0,-d/2-.8,4.8),(min(16,w-2),2,.22),'metal');q('Roof',(0,1 if h>20 else 0,h-.3),(sw+1,sd+1,.6),'lightstone')
 if conference:
  for x in [-24,-12,0,12,24]:q('RoofSpan',(x,0,h+.3),(1.2,d+1,.6),'silver')
  q('Clerestory',(0,0,h+.4),(w-8,8,.7),'glass')
 if h>20:q('RoofPlant',(sw*.22,1,h+.2),(4,5,.4),'metal')
 sign=q('SemanticSign',(0,-d/2-.35,6 if h>20 else 4.8),(min(18,w-4),.18,.9),'sign');sign['semantic_target']=('Commerce_Hotel_Signage_' if hotel else 'Commerce_Event_Marquee_' if conference else 'Commerce_Enterprise_Display_')+n[-2:];sign['dynamic_material_target']=True
 # Generic hospitality/event lettering, separate from all canonical brands.
 if hotel or conference:
  cu=bpy.data.curves.new(n+'_Label','FONT');cu.body='HOTEL' if hotel else 'CONFERENCE';cu.align_x='CENTER';cu.size=1.05;cu.extrude=.01;o=bpy.data.objects.new(n+'_Label',cu);B.objects.link(o);o.parent=rt;o.location=(0,-d/2-.5,6 if hotel else 4.8);o.rotation_euler=(math.pi/2,0,0);cu.materials.append(mats['lightstone'])
# Route each entrance around footprints to an actual public sidewalk.
obstacles=[(a['id'],corners(*a['position'][:2],a['width']+2,a['depth']+2,a['angle'])) for a in P['sites']]+[('Flashpoint',corners(430,-240,75,60))]
def clear(a,b,ignore):return all(n==ignore or polyseg(poly,a,b)>2 for n,poly in obstacles)
frontages=[];missing=[]
for site in P['sites']:
 x,y,z=site['position'];ang=math.radians(site['angle']);start=Vector((x+math.sin(ang)*(site['depth']/2+2.5),y-math.cos(ang)*(site['depth']/2+2.5),15.4));options=[]
 for walk in walks:
  a,b=Vector(walk['a']),Vector(walk['b']);v=b-a;u=v.normalized()
  for shift in [0,-15,15,-35,35,-65,65]:
   t=max(0,min(v.length,(start-a).dot(u)+shift));end=a+u*t
   if not(52<end.x<548 and -357<end.y<-20):continue
   for route in [[start,end],[start,Vector((start.x,end.y,15.4)),end],[start,Vector((end.x,start.y,15.4)),end]]:
    length=sum((b-a).length for a,b in zip(route,route[1:]))
    if length>1 and all(clear(a,b,site['id']) for a,b in zip(route,route[1:])):options.append((length,route))
 if not options:missing.append(site['id']);continue
 _,route=min(options,key=lambda p:p[0]);points=[list(p) for i,p in enumerate(route) if i==0 or (p-route[i-1]).length>.01];ribbon('Commerce_Frontage_'+site['id'],points,4);frontages.append({'building':site['id'],'points':points})
# Minimal fixtures kept at plaza margins; seating has actual supports.
for x,y in [(181,-112),(245,-112),(181,-152),(250,-140),(81,-222),(131,-222),(410,-304),(500,-304)]:
 box('Commerce_Planter',(x,y,15.8),(3,3,.8),'stone');box('Commerce_Shrub',(x,y,16.5),(2.5,2.5,.6),'planting')
for x,y in [(190,-107),(235,-107),(417,-305),(496,-305)]:
 box('Commerce_Seat',(x,y,15.93),(3,.7,.18),'wood')
 for dx in [-1,1]:box('Commerce_SeatSupport',(x+dx,y,15.63),(.2,.5,.46),'metal')
for x,y in [(175,-106),(250,-106),(174,-158),(250,-146),(395,-303),(515,-303),(80,-221)]:
 box('Commerce_PlazaLightPole',(x,y,17.65),(.14,.14,4.5),'metal');o=box('Commerce_PlazaLightFixture',(x,y,20),(.8,.8,.2),'glow');o['semantic_target']='Commerce_PlazaFixture'
# Raised crossings keep the continuous 15.4m pedestrian datum; road approach wedges preserve future transport.
crossings=[]
def cross(name,center,roadwidth,angle,roadtop):
 x,y=center;box('Commerce_Crossing_'+name,(x,y,14.7),(6,roadwidth+9,1.4),'paving',angle=angle)
 for dy in range(-int(roadwidth/2),int(roadwidth/2),2):
  a=math.radians(angle);pos=(x-math.sin(a)*dy,y+math.cos(a)*dy,15.415);box('Commerce_CrossingPaint',pos,(4,.8,.03),'paint',angle=angle)
 for side in [-1,1]:
  # Vehicle ramps run along street direction, 6m long at <=4.17%.
  a=math.radians(angle);u=Vector((math.cos(a),math.sin(a),0));start=Vector((x,y,15.4))+u*side*3;end=Vector((x,y,roadtop))+u*side*9;ribbon('Commerce_VehicleRamp',[list(start),list(end)],roadwidth,'paving',False)
 crossings.append({'name':name,'position':[x,y],'road_width':roadwidth,'rise':15.4-roadtop,'ramp_length':6})
cross('CustomerPlaza',(213,-190),14,0,15.15);cross('Conference',(106,-190),14,0,15.15);cross('Market',(288,-190),14,0,15.15);cross('Flashpoint',(478,-190),14,0,15.15)
# Two transverse connections join the isolated arrival and eastern hotel sidewalks.
for name,x,y,angle in [('Arrival',170,-334.615384615,-10.17551084),('Hotel',470,-78.75,112.83365418)]:
 a=math.radians(angle);normal=Vector((-math.sin(a),math.cos(a),0));center=Vector((x,y,15.4));ribbon('Commerce_BoulevardCrossing_'+name,[list(center-normal*16.5),list(center+normal*16.5)],5);cross(name,(x,y),24,angle,15.35)
# Union coplanar paving tops through Blender's constrained triangulator.
# Preserve skirts and graded ramps; one triangulated top eliminates overlapping faces.
from mathutils.geometry import delaunay_2d_cdt
bpy.context.view_layer.update();flat_vertices=[];flat_faces=[]
for ob in list(U.objects):
 if ob.type!='MESH':continue
 remove=[]
 for face in ob.data.polygons:
  pts=[ob.matrix_world@ob.data.vertices[i].co for i in face.vertices]
  if ob.data.materials[face.material_index]!=mats['paving'] or not all(abs(p.z-15.4)<.0001 for p in pts):continue
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
me=bpy.data.meshes.new('Commerce_ContinuousPaving');me.from_pydata([(v.x,v.y,15.4) for v in verts],[],kept);me.materials.append(mats['paving']);me.update();ob=bpy.data.objects.new('Commerce_ContinuousPaving',me);U.objects.link(ob)
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
cams=[('Commerce_Aerial',(740,-850,670),(300,-180,35),720),('Commerce_MainBoulevard',(225,-304,17.1),(430,-226,45),0),('Commerce_FlashpointCorridor',(388,-303,17.1),(435,-235,44),0),('Commerce_CustomerPlaza',(205,-171,17.1),(225,-70,43),0),('Startup_To_Commerce',(-185,-287,17.1),(260,-239,40),0),('Commerce_To_TechCore',(260,-26,17.1),(50,420,210),0),('Commerce_To_Media',(484,-128,17.1),(835,220,100),0),('Commerce_NightPreview',(388,-303,17.1),(435,-235,44),0),('Commerce_Conference',(126,-215,17.1),(108,-264,24),0),('Commerce_HotelCorridor',(335,-302,17.1),(370,-332,49),0),('Commerce_FlashpointContext',(405,-285,17.1),(430,-240,39),0)]
for n,pos,target,ortho in cams:
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);V.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=28;d.clip_start=.5;d.clip_end=10000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0
A={'hidden_original_objects':hidden,'paths':paths,'frontages':frontages,'missing_frontages':missing,'crossings':crossings,'authored_components':components,'shared_box_modules':len(cache),'review_cameras':[a[0] for a in cams]}
json.dump(A,open(R+'/build_audit.json','w'),indent=2);bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase8_Masterplan.blend');print('BUILT',len(P['sites']),'missing',missing)
