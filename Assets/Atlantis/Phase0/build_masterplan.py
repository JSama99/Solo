import bpy, math, random, json, os
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=os.path.dirname(os.path.abspath(__file__))
random.seed(70)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
 if c.name!='Collection': bpy.data.collections.remove(c)
def col(n,p=None):
 c=bpy.data.collections.new(n); (p.children if p else bpy.context.scene.collection.children).link(c); return c
A=col('Atlantis'); geo=col('Geography',A); terrain=col('Terrain',geo); water=col('Water',geo); bg=col('Background',geo)
infra=col('Infrastructure',A); pri=col('PrimaryRoads',infra); sec=col('SecondaryRoads',infra); local=col('LocalRoads',infra); bridges=col('Bridges',infra); plazas=col('Plazas',infra)
ds=col('Districts',A); landmarks=col('LandmarkPlaceholders',A); rivals=col('RivalHQPlaceholders',A); anchors=col('Atlantis_Anchors',A); ref=col('Reference',A)
def mat(n,c):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); return m
land=mat('TEMP • coastal limestone',(0.45,.53,.46)); sea=mat('TEMP • Atlantis Bay',(.055,.29,.38)); roadmat=mat('TEMP • asphalt',(.12,.17,.2)); route=mat('TEMP • progression boulevard',(.84,.72,.43)); concrete=mat('TEMP • bridge / plaza',(.66,.7,.67)); white=mat('TEMP • landmark',(.83,.91,.92))
def mesh(n,v,f,c,m):
 me=bpy.data.meshes.new(n); me.from_pydata(v,[],f); me.update(); o=bpy.data.objects.new(n,me); c.objects.link(o); o.data.materials.append(m); return o
def box(n,pos,size,c,m):
 x,y,z=size; v=[(a*x/2,b*y/2,d*z/2) for a,b,d in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 o=mesh(n,v,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],c,m); o.location=pos; return o
def island(n,poly,z):
 N=len(poly); v=[(x,y,-12) for x,y in poly]+[(x,y,z) for x,y in poly]; f=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 return mesh(n,v,f,terrain,land)
island('Founder_Shore',[(-1220,-1140),(-580,-1140),(-440,-880),(-490,-610),(-730,-540),(-1120,-620)],8)
island('Central_Peninsula',[(-790,-470),(-400,-670),(-140,-590),(60,-410),(520,-400),(820,-180),(780,60),(390,160),(530,440),(420,680),(80,780),(-330,700),(-710,340)],14)
island('Media_Headland',[(540,80),(850,20),(1060,90),(1060,580),(770,620),(550,540)],14)
island('Unicorn_Raised_Headland',[(510,720),(730,640),(1080,720),(1240,1030),(1090,1270),(580,1210),(410,970)],85)
box('Atlantis_Bay', (0,0,-16),(3000,3000,8),water,sea)
# bounds are parcel envelopes, not final architecture.
spec={
'FounderDistrict':(-850,-850,500,430,8,(.76,.61,.43),9,4,12,'Low / residential start'),
'StartupRow':(-460,-340,520,400,14,(.81,.60,.31),5,12,32,'Medium-low / early offices'),
'VentureDistrict':(-490,180,390,470,14,(.52,.58,.76),5,45,112,'Medium-high / investment'),
'TechCore':(30,330,650,610,14,(.30,.62,.72),7,85,190,'Highest / global technology'),
'CommerceDistrict':(300,-190,500,340,14,(.57,.69,.47),5,28,85,'Medium-high / enterprise and services'),
'MediaDistrict':(800,325,370,430,14,(.71,.48,.61),4,36,90,'Medium-high / waterfront media'),
'UnicornHeights':(820,960,620,400,85,(.61,.56,.75),3,60,135,'Low count / elite headquarters')}
D={}; slots=[]; roads=[]
for n,(x,y,w,d,z,color,count,lo,hi,role) in spec.items():
 c=col(n,ds); c['export_owner']=n; c['future_lods']='LOD0 / LOD1 / LOD2; not authored'; D[n]=(c,mat('TEMP • '+n,color))
 # flat colored district territory outline, disconnected segments keep street connections readable
 for k,(px,py,sx,sy) in enumerate([(x,y-d/2,w,2),(x,y+d/2,w,2),(x-w/2,y,2,d),(x+w/2,y,2,d)]): box(n+'_Boundary_%d'%k,(px,py,z+.12),(sx,sy,.15),c,D[n][1])
def slot(n,d,x,y,w,dep,hmin,hmax,h,kind='hero'):
 z=spec[d][4]; o=bpy.data.objects.new(n,None); anchors.objects.link(o); o.location=(x,y,z); o.empty_display_type='ARROWS'; o.empty_display_size=20
 rec=dict(id=n,district=d,origin=[x,y,z],rotation_degrees=[0,0,0],forward='-Y (Blender); +Z after glTF conversion',footprint_m=[w,dep],target_height_m=[hmin,hmax],max_bbox_m=[w,dep,hmax],placeholder_height_m=(h+68 if n=='Landmark_TheSpire' else h),kind=kind)
 for k,v in rec.items(): o[k]=v
 slots.append(rec)
 c=rivals if kind.startswith('Rival') else landmarks
 p=box(n+'_Parcel',(x,y,z+.3),(w,dep,.6),c,concrete); p['district']=d; p['slot_id']=n
 if n!='FounderGarage_Slot':
  b=box(n+'_Massing',(x,y,z+h/2),(w*.65,dep*.65,h),c,D[d][1]); b['district']=d; b['slot_id']=n
  if n=='Landmark_TheSpire':
   b.scale.x=.75; b.scale.y=.75
   box(n+'_Crown',(x,y,z+h+22),(16,16,44),c,white)['district']=d
   box(n+'_Needle',(x,y,z+h+56),(4,4,24),c,white)['district']=d
 return o
slot('FounderGarage_Slot','FounderDistrict',-875,-1030,32,38,3,12,0)
slot('Landmark_TheSpire','TechCore',50,420,70,70,280,350,280)
slot('Landmark_VentureHall','VentureDistrict',-520,110,90,75,30,65,40)
alias=bpy.data.objects.new('VentureHall_Anchor',None); anchors.objects.link(alias); alias.location=(-520,110,14); alias['alias_of']='Landmark_VentureHall'
slot('Landmark_TechComTower','MediaDistrict',835,220,75,70,120,180,160)
slot('Landmark_SignalTV','MediaDistrict',860,460,95,65,25,60,38)
for i,(d,x,y,w,h,kind) in enumerate([('StartupRow',-610,-360,52,24,'Small'),('VentureDistrict',-350,300,65,75,'Medium'),('TechCore',-100,520,65,155,'Major'),('TechCore',220,300,65,175,'Major'),('CommerceDistrict',430,-240,75,70,'Medium')],1):
 ran={'Small':(15,30),'Medium':(40,90),'Major':(100,180)}[kind]; slot('RivalHQ_Slot_%02d'%i,d,x,y,w,60,*ran,h,'RivalHQ_'+kind)
for i,(x,y) in enumerate([(620,990),(810,1070),(1030,1040)],1): slot('UnicornHQ_Slot_%02d'%i,'UnicornHeights',x,y,110,95,80,150,110+i*7)
slot('Player_UnicornHQ_Slot','UnicornHeights',970,850,140,115,100,180,155)
for i,(x,y) in enumerate([(-650,-220),(-500,-220),(-350,-220),(-290,-430)]): slot('Startup_Block_'+chr(65+i),'StartupRow',x,y,55,45,12,48,22+i*5,'module')
def path(n,pts,width,c,m):
 length=0
 for i,(a,b) in enumerate(zip(pts,pts[1:])):
  a,b=Vector(a),Vector(b); delta=b-a; length+=delta.length
  o=box(n+'_%02d'%i,(a+b)/2,(width,delta.length,.7),c,m); o.rotation_mode='QUATERNION'; o.rotation_quaternion=delta.to_track_quat('Y','Z'); o['route']=n
 roads.append(dict(id=n,width_m=width,length_m=round(length,1),points=pts,collection=c.name))
# Joined endpoints make the progression network explicit and audit-able.
path('Founder_Local_Spine',[(-875,-1060,8.7),(-875,-850,8.7),(-790,-660,9),(-710,-590,16)],10,local,roadmat)
path('AtlantisBridge_Main',[(-710,-590,16),(-610,-490,16)],26,bridges,concrete)
path('Progression_Startup',[(-610,-490,16),(-460,-400,15),(-190,-270,15),(-170,-80,15),(0,100,15),(50,300,15)],26,pri,route)
path('Venture_Boulevard',[(-190,-270,15),(-460,-50,15),(-430,180,15),(-250,330,15),(0,100,15)],24,pri,roadmat)
path('Commerce_Boulevard',[(-190,-270,15),(200,-340,15),(500,-150,15),(420,40,15),(0,100,15)],24,pri,roadmat)
path('Tech_Ring',[(50,300,15),(320,190,15),(360,470,15),(100,650,15),(-250,550,15),(-250,330,15),(0,100,15)],26,pri,roadmat)
path('Bridge_Media',[(420,40,15),(640,110,15)],24,bridges,concrete)
path('Media_Boulevard',[(640,110,15),(730,260,15),(740,490,15),(660,560,15)],24,pri,roadmat)
path('Bridge_TechCore',[(360,470,15),(600,760,86)],26,bridges,concrete)
path('Heights_Boulevard',[(600,760,86),(710,850,86),(820,960,86),(1100,920,86)],24,pri,roadmat)
for r in list(roads):
 if r['collection']=='Bridges':
  a,b=map(Vector,[r['points'][0],r['points'][-1]])
  for t in [.2,.5,.8]:
   p=a.lerp(b,t); box(r['id']+'_Pier_'+str(t),(p.x,p.y,(p.z-10)/2),(9,14,p.z+10),bridges,concrete)
# Secondary cross streets link to primary network and subdivide districts.
for n,(x,y,w,d,z,color,count,lo,hi,role) in spec.items():
 if n=='UnicornHeights': continue
 path(n+'_CrossStreet',[(x-w*.45,y,z+.8),(x+w*.45,y,z+.8)],14 if n!='FounderDistrict' else 8,sec if n!='FounderDistrict' else local,roadmat)
path('Startup_Link',[(-460,-340,15),(-460,-400,15)],14,sec,roadmat)
path('Commerce_Link',[(300,-190,15),(420,40,15)],14,sec,roadmat)
path('Tech_Link',[(30,330,15),(50,300,15)],14,sec,roadmat)
path('Media_Link',[(800,325,15),(740,325,15)],14,sec,roadmat)
# Collision-clear massing: protect every road corridor and reserved footprint.
def segdist(x,y,a,b):
 p=Vector((x,y)); a=Vector(a[:2]); b=Vector(b[:2]); d=b-a; t=max(0,min(1,(p-a).dot(d)/d.length_squared)); return (p-a-d*t).length
counts={}
for n,(x,y,w,d,z,color,count,lo,hi,role) in spec.items():
 c,m=D[n]; built=0
 for ix in range(count):
  for iy in range(count):
   px=x-w*.42+ix*w*.84/max(1,count-1); py=y-d*.42+iy*d*.84/max(1,count-1)
   bw=22 if n=='FounderDistrict' else (48 if n=='UnicornHeights' else 32); bd=bw*.85
   if n=='FounderDistrict' and segdist(px,py,(-875,-1030,8),(50,420,14))<42: continue
   if any(abs(px-s['origin'][0])<(bw+s['footprint_m'][0])/2+12 and abs(py-s['origin'][1])<(bd+s['footprint_m'][1])/2+12 for s in slots): continue
   if any(segdist(px,py,a,b)<r['width_m']/2+bw*.72+4 for r in roads for a,b in zip(r['points'],r['points'][1:])): continue
   h=random.uniform(lo,hi); o=box(n+'_Block_%03d'%built,(px,py,z+h/2),(bw,bd,h),c,m); o['district']=n; o['height_m']=h; built+=1
   if n in ['TechCore','CommerceDistrict']:
    box(n+'_Podium_%03d'%built,(px,py,z+5),(bw+8,bd+8,10),c,m)['district']=n
 counts[n]=built
# Plazas keep districts open and signal landmark importance.
for n,x,y,sx,sy,z in [('Spire_Plaza',50,420,110,110,14),('Commerce_CentralPlaza',220,-170,85,75,14),('Venture_Forum',-520,30,110,60,14),('Media_Waterfront',940,350,65,120,14)]: box(n,(x,y,z+.2),(sx,sy,.3),plazas,concrete)
# Cameras and embedded reference.
def camera(n,pos,target,lens=45,ortho=None):
 dat=bpy.data.cameras.new(n); o=bpy.data.objects.new(n,dat); ref.objects.link(o); o.location=pos; o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler(); dat.lens=lens; dat.clip_end=20000
 if ortho: dat.type='ORTHO'; dat.ortho_scale=ortho
 return o
cams=[camera('Atlantis_Master_Aerial',(2700,-3600,2900),(0,100,0),ortho=3450),camera('Founder_To_City',(-875,-1020,9.8),(-10,270,100),38),camera('TechCore_Skyline',(-700,-1100,100),(50,380,145),45),camera('Atlantis_Waterfront',(2000,-1400,800),(330,260,70),45),camera('UnicornHeights_View',(1500,1700,700),(30,250,70),42),camera('Atlantis_Top_Down',(0,80,4000),(0,80,0),ortho=4100)]
refpath='/var/folders/_w/_ch6yjtx2436llbpxvjc_0z80000gn/T/codex-clipboard-9fe0af8a-74de-44fa-a1c6-6f21bdac6b7f.png'
if os.path.exists(refpath):
 im=bpy.data.images.load(refpath); im.pack(); o=bpy.data.objects.new('Atlantis_Concept_Reference',None); ref.objects.link(o); o.empty_display_type='IMAGE'; o.data=im; o.location=(0,0,-100); o.hide_render=True; o.hide_viewport=True
scene=bpy.context.scene; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1; scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'; scene.display.shading.studiolight_rotate_z=.3; scene.display.shading.color_type='MATERIAL'; scene.display.shading.show_shadows=True; scene.display.shading.show_cavity=True; scene.display.shading.cavity_type='BOTH'; scene.display.shading.background_type='WORLD'; scene.world.color=(.12,.16,.2)
scene.render.resolution_x=1600; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'; scene.camera=cams[0]
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  area.spaces.active.region_3d.view_perspective='CAMERA'; area.spaces.active.clip_end=15000
# Actual geometry bounds / counts and conservative visibility audit.
bpy.context.view_layer.update(); meshes=[o for o in scene.objects if o.type=='MESH']; verts=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
for s in slots:
 s['view_visibility']={}
 for cam in cams:
  point=Vector(s['origin'])+Vector((0,0,max(2,s['placeholder_height_m']*.85))); ndc=world_to_camera_view(scene,cam,point)
  direction=point-cam.location; hit,loc,*_=scene.ray_cast(bpy.context.evaluated_depsgraph_get(),cam.location,direction.normalized(),distance=max(0,direction.length-1))
  s['view_visibility'][cam.name]='outside frame' if not (ndc.z>0 and 0<ndc.x<1 and 0<ndc.y<1) else ('occluded at upper-center sample' if hit else 'upper-center sample visible')
report=dict(blender=bpy.app.version_string,units='meters; Blender Z-up; north +Y; glTF maps (x,y,z) to (x,z,-y)',object_count=len(scene.objects),mesh_count=len(meshes),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),world_bounds=[[min(v[i] for v in verts) for i in range(3)],[max(v[i] for v in verts) for i in range(3)]],districts={n:dict(center=[v[0],v[1],v[4]],bounds_xy=[v[0]-v[2]/2,v[1]-v[3]/2,v[0]+v[2]/2,v[1]+v[3]/2],size_m=v[2:4],generic_building_count=counts[n],height_range_m=v[7:9],role=v[9]) for n,v in spec.items()},slots=slots,roads=roads)
with open(os.path.join(ROOT,'masterplan_manifest.json'),'w') as f: json.dump(report,f,indent=2)
t=bpy.data.texts.new('READ_ME • Atlantis Phase 0'); t.write('Planning only. Metric Z-up, north +Y. Temporary color-coded massing. Slot origins are foundation centers; rotation zero; facade forward -Y. See masterplan_manifest.json. Replace geometry by slot_id and district metadata, never merge city into one mesh. Reference image packed. Camera views are planning views, not RealityKit cameras. No final assets or gameplay.\n'+json.dumps(report,indent=2))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Atlantis_Phase0_Masterplan.blend'))
for cam in cams:
 scene.camera=cam; scene.render.filepath=os.path.join(ROOT,'review',cam.name+'.png'); bpy.ops.render.render(write_still=True)
print('ATLANTIS_BUILD_DONE',json.dumps({k:report[k] for k in ['object_count','mesh_count','triangles','world_bounds']}))
