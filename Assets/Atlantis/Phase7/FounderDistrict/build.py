"""Deterministic Phase 7 authoring. Run with Blender --background --python."""
import bpy, math, json, os, ast
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase6/StartupRow/Blender/Atlantis_Phase6_Masterplan.blend')
s=bpy.context.scene
for file,names in [('Assets/Atlantis/Phase3/MediaDistrict/build_media.py',['col','mat']),('Assets/Atlantis/Phase6/StartupRow/build.py',['box'])]:
 tree=ast.parse(open(file).read());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),file,'exec')) if 'box' not in names else None
C=col('Phase7_FounderProduction',bpy.data.collections['FounderDistrict']);U=col('Founder_PublicRealm',C);B=col('Founder_Buildings',C);V=col('Founder_Phase7_ReviewCameras',C);K=col('Founder_KitLibrary',C);K.hide_render=True;K.hide_viewport=True
mats={k:mat('Founder_'+k,c,0,.8) for k,c in {'siding':(.58,.62,.54),'cream':(.74,.7,.58),'brick':(.40,.22,.16),'paving':(.52,.52,.47),'asphalt':(.12,.14,.15),'glass':(.09,.19,.22),'wood':(.39,.26,.15),'metal':(.22,.27,.28),'lawn':(.22,.33,.16),'leaf':(.12,.26,.13),'paint':(.8,.78,.67)}.items()}
mats['glow']=mat('Founder_OccupiedWindow',(.9,.63,.3),0,.6,.25)
cache={}
tree=ast.parse(open('Assets/Atlantis/Phase6/StartupRow/build.py').read());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='box'],type_ignores=[]),'box','exec'))
box('Founder_NeighborhoodLawn',(-850,-850,7.99),(498,428,.04),'lawn')
hidden=[]
for o in list(s.objects):
 if o.name.startswith(('FounderDistrict_Block_','Founder_Local_Spine_')) or o.name=='FounderGarage_Slot_Parcel':
  o.hide_render=True;o.hide_viewport=True;hidden.append(o.name)
# Top-surface ribbons use exact sloped vertices, avoiding floating flat segments.
paths=[]
def ribbon(name,pts,width,material='paving',record=True):
 for i,(aa,bb) in enumerate(zip(pts,pts[1:])):
  a,b=Vector(aa),Vector(bb);d=b-a;n=Vector((-d.y,d.x,0)).normalized()*width/2
  top=[a-n,b-n,b+n,a+n];bottom=[Vector((p.x,p.y,min(p.z-.18,7.99) if max(a.y,b.y)<-590 else p.z-.18)) for p in top];verts=[list(p) for p in top+bottom]
  me=bpy.data.meshes.new(name);me.from_pydata(verts,[],[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);me.materials.append(mats[material]);o=bpy.data.objects.new(name+'_%02d'%i,me);U.objects.link(o)
 if record:paths.append({'name':name,'points':pts,'width':width,'max_grade':max(abs(b[2]-a[2])/math.dist(a[:2],b[:2]) for a,b in zip(pts,pts[1:]))})
# V7 (x,Y-up,z) maps to Atlantis (x,-z,Y), with unchanged slot translation.
box('Founder_GarageReservation',(-875,-1028,7.98),(80,56,.04),'lawn')['planning_reference_only']=True
box('Founder_GarageFootprint',(-875,-1030,8.015),(5,5.5,.03),'paving')['not_a_garage_proxy']=True
ribbon('Founder_GarageDriveway',[[-875,-1032.75,8.03],[-875,-1040.9,8.03]],3.5)
ribbon('Founder_GarageApron',[[-875,-1040.9,8.03],[-875,-1043.6,8.16]],3.5)
ribbon('Founder_GarageSeam',[[-895,-1040.1,8.03],[-855,-1040.1,8.03]],2.0)
ribbon('Founder_OriginStreetWest',[[-1080,-1044,8.16],[-876.75,-1044,8.16]],5.9,'asphalt',False)
ribbon('Founder_OriginStreetEast',[[-873.25,-1044,8.16],[-820,-1044,8.16]],5.9,'asphalt',False)
ribbon('Founder_OriginStreetApronLanding',[[-875,-1043.6,8.16],[-875,-1046.95,8.16]],3.5,'asphalt',False)
# Bypass the full reservation on its east side; progressively denser northern streets.
ribbon('Founder_LocalBypass',[[-820,-1044,8.16],[-820,-920,8.45],[-875,-850,9.15]],6,'asphalt',False)
ribbon('Founder_Connector',[[-875,-850,9.15],[-790,-660,9.35],[-710,-590,16.35]],10,'asphalt',False)
for y,z in [(-965,8.25),(-740,9.2)]:ribbon('Founder_ResidentialLane',[[-1080,y,z],[-640,y,z]],6,'asphalt',False)
# Main pedestrian route joins the existing bridge deck; bridge infrastructure stays unchanged.
route=[[-875,-1040.1,8.03],[-825,-1040.1,8.03],[-825,-970,8.25],[-825,-960,8.25],[-825,-920,8.5],[-890,-860,9.15],[-890,-845,9.15],[-852,-754,9.2],[-850,-700,9.3],[-842,-677,10.4],[-785,-648,13.0],[-748,-615,15.0],[-716,-584,16.35],[-616,-484,16.35],[-625.443359375,-488.67626953125,16.440000534057617]]
ribbon('Founder_ToStartup_Walk',route,3)
# Crossings are flush, with low approach grades instead of tall decorative curbs.
for y,x,z in [(-965,-825,8.25),(-850,-890,9.15),(-740,-851.5,9.23)]:
 for dy in [-2,-1,0,1,2]:box('Founder_Crossing',(x,y+dy,z+.025),(3,.5,.025),'paint')
for y,z in [(-965,8.25),(-850,9.15),(-740,9.2)]:
 for side in [-1,1]:ribbon('Founder_ConnectedSidewalk',[[-1080,y+side*5,z],[-640,y+side*5,z]],2.5)
# Cross-street walks meet main route; local spine east sidewalk has a continuous grade.
ribbon('Founder_EastWalk',[[-815,-1044,8.03],[-815,-970,8.25],[-815,-960,8.25],[-815,-920,8.5],[-868,-850,9.15]],2.5)
# One small neighborhood green alongside the primary walking route.
box('Founder_NeighborhoodGreen',(-916,-921,8.04),(32,26,.08),'lawn')
ribbon('Founder_GreenPath',[[-932,-921,8.2],[-900,-921,8.2],[-851,-896,8.76]],2.5)
for x in [-926,-912]:
 box('Founder_GreenBench',(x,-928,8.65),(2,.6,.45),'wood');box('Founder_BenchBack',(x,-928.3,9),(2,.12,.6),'wood')
for x in [-926,-912]:
 for dx in [-.7,.7]:box('Founder_BenchLeg',(x+dx,-928,8.25),(.14,.45,.42),'metal')
# Modest kit: consistent door/window scale, roof profiles, porches and limited workspace cues.
types={'Founder_HomeGarage_A':(12,10,1,'siding'),'Founder_HomeGarage_B':(11,10,2,'cream'),'Founder_Duplex_A':(17,12,2,'brick'),'Founder_SmallApartment_A':(19,14,3,'siding'),'Founder_Workshop_A':(14,12,1,'brick'),'Founder_CornerStore_A':(14,12,1,'cream'),'Founder_MixedUseEdge_A':(19,14,4,'brick')}
sites=[]
def home(x,y,typ,face=0):
 w,d,f,finish=types[typ];i=len(sites);rt=bpy.data.objects.new('Founder_Building_%02d'%i,None);B.objects.link(rt);base=8.8 if y in [-872,-828] else 8.9 if y in [-760,-720] else 8.2;rt.location=(x,y,base);rt.rotation_euler.z=math.radians(face);rt['typology']=typ;rt['floors']=f
 def q(n,pos,size,ma):return box(rt.name+'_'+n,pos,size,ma,B,rt)
 h=f*3.05;q('Shell',(0,0,h/2),(w,d,h),finish);q('Plinth',(0,0,-(base-8)/2),(w+.3,d+.3,base-8),'paving')
 for side in [-1,1]:
  for level in range(f):
   for wx in range(-int(w/2)+2,int(w/2)-1,3):
    q('WindowTrim',(wx,side*(d/2+.05),level*3.05+1.7),(1.65,.18,1.65),'cream');q('Window',(wx,side*(d/2+.16),level*3.05+1.7),(1.35,.08,1.35),'glow' if (wx+level+i)%7==0 else 'glass')
    q('Mullion',(wx,side*(d/2+.22),level*3.05+1.7),(.05,.05,1.4),'metal')
  for level in range(f):q('SideWindow',(side*(w/2+.05),0,level*3.05+1.7),(.12,1.4,1.4),'glass')
 q('FrontDoor',(1,-d/2-.12,1.1),(1,.12,2.2),'wood');q('Porch',(1,-d/2-1,.03),(3,2,.06),'paving');q('PorchRoof',(1,-d/2-.6,2.7),(3.4,1.8,.15),'metal');q('PorchFixture',(2,-d/2-.2,2.2),(.18,.2,.3),'glow')
 if f<=2:
  me=bpy.data.meshes.new('Founder_Gable');me.from_pydata([(-w/2,-d/2,h),(w/2,-d/2,h),(-w/2,d/2,h),(w/2,d/2,h),(-w/2,0,h+1.3),(w/2,0,h+1.3)],[],[(0,4,2),(1,3,5),(0,1,5,4),(4,5,3,2),(0,2,3,1)]);me.materials.append(mats[finish]);g=bpy.data.objects.new(rt.name+'_Gable',me);B.objects.link(g);g.parent=rt
  for sign in [-1,1]:
   roof=q('RoofSlope',(0,sign*d/4,h+.65),(w+1,d/2+.5,.18),'metal');roof.rotation_euler.x=-sign*math.atan(1.3/(d/2))
 else:q('FlatRoof',(0,0,h+.12),(w+.5,d+.5,.24),'metal')
 if 'HomeGarage' in typ or 'Workshop' in typ:
  q('GarageDoor',(-w*.26,-d/2-.19,1.15),(3.1,.18,2.3),'metal')
  for z in [.4,.8,1.2,1.6,2]:q('DoorJoint',(-w*.26,-d/2-.3,z),(3,.025,.03),'cream')
 if typ=='Founder_Workshop_A' or i%9==0:
  q('SolarPanel',(0,1,h+1.25),(3,2,.12),'glass');q('ServiceBox',(w/2+.3,2,.7),(.6,1,1.4),'metal')
 if typ in ['Founder_CornerStore_A','Founder_MixedUseEdge_A']:
  q('ShopWindow',(-3,-d/2-.3,1.5),(4,.12,2),'glass');q('SmallSign',(-3,-d/2-.4,2.9),(4,.15,.5),'wood')
 sites.append({'name':rt.name,'position':[x,y,base],'typology':typ,'width':w,'depth':d,'floors':f,'face':face,'height':h+1.4 if f<=2 else h+.24})
 return rt
# Rows face the three neighborhood streets. Intentional irregular spacing is deterministic.
for row,y in enumerate([-1024,-986,-943,-872,-828,-760,-720]):
 xs=[-1060,-1016,-970,-925,-780,-730,-676] if y<-900 else [-1060,-1027,-992,-954,-918,-750,-713,-670,-627]
 for j,x in enumerate(xs):
  if -920<x<-805 and y<-998:continue
  if -938<x<-890 and -942<y<-898:continue
  # Preserve a wide low-height view cone from the Founder camera toward the Spire.
  line_x=-875+(y+1020)*925/1440
  if abs(x-line_x)<24:continue
  typ=['Founder_HomeGarage_A','Founder_HomeGarage_B','Founder_Duplex_A'][ (j+row)%3]
  if y>-780:typ='Founder_SmallApartment_A' if j%3==0 else 'Founder_Duplex_A'
  if (row,j) in [(2,1),(4,2)]:typ='Founder_Workshop_A'
  if (row,j)==(3,2):typ='Founder_CornerStore_A'
  if (row,j)==(6,5):typ='Founder_MixedUseEdge_A'
  home(x,y,typ,0 if row%2==0 else 180)
# Individual paths/driveways connect every property to its nearest street sidewalk.
for i,a in enumerate(sites):
 x,y,z=a['position'];front=y+(-1 if a['face']==0 else 1)*(a['depth']/2+2);street=min([(-1044,8.03),(-965,8.25),(-850,9.15),(-740,9.2)],key=lambda p:abs(front-p[0]));sy,sz=street;end=sy+(5 if front>sy else -5)
 ribbon('Founder_Frontage_%02d'%i,[[x,front,z],[x,end,sz]],3.5 if 'HomeGarage' in a['typology'] else 2)
 box('Founder_Yard',(x,y,(8+z-.12)/2),(a['width']+10,a['depth']+10,z-.12-8),'lawn')
 if i%3==0:box('Founder_LowFence',(x-a['width']/2-3,y,8.55),(.15,a['depth']+5,.9),'wood')
# Mobile-friendly shared low-poly trees; exclude protected viewing corridor and footpaths.
canopy=None;trees=0
for i,a in enumerate(sites):
 x,y,_=a['position'];x+=a['width']/2+4;y+=(-1 if a['face']==0 else 1)*(a['depth']/2+2)
 line_x=-875+(y+1020)*925/1440
 if abs(x-line_x)<26:continue
 box('Founder_TreeTrunk',(x,y,9.6),(.24,.24,3.2),'wood')
 if canopy is None:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1);o=bpy.context.object;canopy=o.data;canopy.materials.append(mats['leaf'])
  for c in list(o.users_collection):c.objects.unlink(o)
 else:o=bpy.data.objects.new('Founder_TreeCanopy',canopy)
 o.name='Founder_TreeCanopy';U.objects.link(o);o.location=(x,y,11.8);o.scale=(2.6,2.4,2.3);trees+=1
 if i%2==0:box('Founder_YardHedge',(x-2,y+3,8.7),(3,1,.9),'leaf')
for x,y in [(-929,-913),(-915,-913),(-901,-913)]:
 box('Founder_TreeTrunk',(x,y,9.6),(.24,.24,3.2),'wood');o=bpy.data.objects.new('Founder_TreeCanopy',canopy);U.objects.link(o);o.location=(x,y,11.8);o.scale=(2.6,2.4,2.3);trees+=1
for x,y,z in [(-832,-1020,8.2),(-832,-978,8.2),(-900,-850,9.15),(-864,-752,9.2),(-828,-691,9.8),(-787,-640,13.2)]:
 box('Founder_StreetlightPole',(x,y,z+2.3),(.13,.13,4.6),'metal');box('Founder_StreetlightFixture',(x,y,z+4.6),(.65,.4,.15),'glow')['semantic_target']='future_streetlight'
for x,y in [(-993,-948),(-962,-866),(-702,-723)]:
 box('Founder_UtilityCabinet',(x,y,8.8),(1,.7,1.2),'metal');box('Founder_RecyclingEnclosure',(x+2,y,8.7),(1.8,1.2,1),'wood');box('Founder_Drain',(x,y-2,8.23),(.6,.4,.04),'metal')
# Consolidate each building into architecture and semantic light-surface meshes.
bpy.context.view_layer.update()
component_count=sum(o.type=='MESH' for o in B.objects)
for rt in [o for o in B.objects if o.type=='EMPTY']:
 for semantic in [False,True]:
  obs=[o for o in rt.children if o.type=='MESH' and any(m.name=='Founder_OccupiedWindow' for m in o.data.materials)==semantic]
  if not obs:continue
  vs=[];fs=[];mi=[];materials=[]
  for ob in obs:
   offset=len(vs);vs.extend([list(ob.matrix_basis@v.co) for v in ob.data.vertices])
   for face in ob.data.polygons:
    fs.append([offset+i for i in face.vertices]);ma=ob.data.materials[face.material_index]
    if ma not in materials:materials.append(ma)
    mi.append(materials.index(ma))
  me=bpy.data.meshes.new(rt.name+'_Combined');me.from_pydata(vs,[],fs)
  for ma in materials:me.materials.append(ma)
  for face,idx in zip(me.polygons,mi):face.material_index=idx
  me.update();ob=bpy.data.objects.new(rt.name+('_LightingSurfaces' if semantic else '_Architecture'),me);B.objects.link(ob);ob.parent=rt
  for old in obs:bpy.data.objects.remove(old,do_unlink=True)
# Shared kit assemblies remain available for subsequent production work.
for typ in types:
 src=next(o for o in B.objects if o.type=='EMPTY' and o.get('typology')==typ);rt=bpy.data.objects.new(typ,None);K.objects.link(rt)
 for child in src.children:
  o=child.copy();o.data=child.data;K.objects.link(o);o.parent=rt
cams=[('FounderDistrict_Aerial',(-1280,-1330,510),(-850,-850,12),600),('FounderGarage_Context',(-940,-1100,49),(-862,-1010,8),0),('Founder_To_Startup_Phase7',(-825,-1010,9.7),(-600,-480,32),0),('Founder_To_Spire',(-875,-1020,9.8),(50,420,220),0),('Founder_StreetLevel',(-1010,-969,9.95),(-955,-946,11),0),('Founder_GreenSpace',(-936,-935,9.85),(-908,-920,9),0),('Founder_NightPreview',(-1010,-969,9.95),(-955,-946,11),0),('Garage_Transition_Seam',(-885,-1042,9.65),(-871,-1033,8.1),0)]
for n,pos,target,ortho in cams:
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);V.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=30;d.clip_start=1;d.clip_end=10000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
bpy.context.view_layer.update();s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0
json.dump({'sites':sites,'paths':paths,'hidden_original_objects':hidden,'tree_count':trees,'authored_building_components':component_count,'reusable_dimension_material_meshes':len(cache),'typologies':types,'review_cameras':[c[0] for c in cams],'envelope':{'bounds':[[-915,-1056,7.76],[-835,-1000,15.9]],'width':80,'depth':56,'ground':8,'forward':'-Y','slot':[-875,-1030,8]}},open(R+'/build_audit.json','w'),indent=2)
bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase7_Masterplan.blend');print('PHASE7_BUILT',len(sites),'buildings')
