import bpy,math,json,os,ast
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));P=json.load(open(R+'/site_plan.json'));M=json.load(open(R+'/../../Phase0/masterplan_manifest.json'))
bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase5/RivalHQs/Blender/Atlantis_Phase5_Masterplan.blend');s=bpy.context.scene
tr=ast.parse(open(R+'/../../Phase3/MediaDistrict/build_media.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name in ['col','mat']],type_ignores=[]),'helpers','exec'))
C=col('Phase6_StartupProduction',bpy.data.collections['StartupRow']);B=col('Startup_Buildings',C);U=col('Startup_PublicRealm',C);L=col('Startup_ProgressionPlanning',C);K=col('Startup_KitLibrary',C);K.hide_render=True;K.hide_viewport=True;V=col('Startup_ReviewCameras',C)
mats={'brick':mat('Startup_WarmBrick',(.42,.19,.11),0,.8),'pale':mat('Startup_PaleConcrete',(.64,.65,.57),0,.7),'concrete':mat('Startup_Concrete',(.4,.44,.42),0,.7),'glass':mat('Startup_Glazing',(.055,.18,.21),.35,.3),'metal':mat('Startup_Metal',(.24,.3,.31),.6,.45),'green':mat('Startup_Planting',(.12,.28,.13),0,.85),'wood':mat('Startup_Wood',(.4,.24,.1),0,.8),'paving':mat('Startup_Paving',(.48,.48,.43),0,.9),'asphalt':mat('Startup_LocalAsphalt',(.12,.15,.16),0,.9),'paint':mat('Startup_CrossingPaint',(.8,.79,.66),0,.8),'glow':mat('Startup_InteriorGlow',(.95,.64,.3),0,.5,.5),'sign':mat('Startup_Signage',(.3,.53,.48),.1,.5,.35)}
# Shared baked dimension meshes; repeated facade elements reuse mesh datablocks.
cache={};components={}
def box(n,pos,size,ma,c=U,parent=None,angle=0):
 key=(tuple(round(v,4) for v in size),ma)
 if key not in cache:
  x,y,z=[v/2 for v in size];vs=[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)];fs=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)];me=bpy.data.meshes.new('Startup_Module_%03d'%len(cache));me.from_pydata(vs,[],fs);me.materials.append(mats[ma]);me.update();uv=me.uv_layers.new(name='UVMap')
  for p in me.polygons:
   for j,li in enumerate(p.loop_indices):uv.data[li].uv=[(0,0),(1,0),(1,1),(0,1)][j]
  cache[key]=me
 o=bpy.data.objects.new(n,cache[key]);c.objects.link(o);o.parent=parent;o.location=pos;o.rotation_euler.z=math.radians(angle);return o
hidden=[]
for o in s.objects:
 if o.type=='MESH' and (o.name.startswith('StartupRow_Block_') or (o.name.startswith('Startup_Block_') and o.name.endswith('_Massing')) or o.name=='RivalHQ_Slot_01_Massing'):
  o.hide_render=True;o.hide_viewport=True;hidden.append(o.name)
# Keep old parcel/locator geometry traceable; hide parcel display meshes only inside Startup.
for o in s.objects:
 if o.type=='MESH' and ((o.name.startswith('Startup_Block_') or o.name=='RivalHQ_Slot_01_Parcel') and o.name.endswith('_Parcel')):o.hide_render=True;o.hide_viewport=True;hidden.append(o.name)
for site in P['sites']:
 n=site['id'];w,d,f=site['width'],site['depth'],site['floors'];h=site['height'];t=site['typology'];root=bpy.data.objects.new('Startup_'+n,None);B.objects.link(root);root.location=site['position'];root.rotation_euler.z=math.radians(site['rotation_degrees']);root['typology']=t;root['planning_only']=True;root['floor_count']=f
 def q(part,pos,size,ma):return box('Startup_'+n+'_'+part,pos,size,ma,B,root)
 setback=('Cowork' in t or 'Anchor' in t or 'Incubator' in t) and f>4
 split=h-8.6 if setback else h-.6
 q('Foundation',(0,0,-.7),(w,d,1.4),site['finish'])
 q('Shell',(0,0,split/2),(w,d,split),site['finish'])
 if setback:q('UpperSetback',(0,2,(split+h-.6)/2),(w-4,d-4,h-.6-split),site['finish'])
 # Broad storefront, repeatable 4m upper floor glazing, no interiors.
 for side in [-1,1]:
  q('Storefront',(0,side*(d/2+.04),2),(w-2,.12,3.4),'glass')
  for z in range(6,int(h)-1,4):
   off=2 if setback and z>split else 0
   q('WindowBand',(0,2*(off>0)+side*(d/2-off+.06),z),(w-2-2*off,.16,2.5),'glass')
   if (int(z)+len(n))%12==0:q('ActiveWindow',(-w*.2,2*(off>0)+side*(d/2-off+.16),z),(3,.08,2.1),'glow')
  for x in range(-int(w/2)+2,int(w/2),5):q('Frame',(x,side*(d/2+.18),split/2),(.25,.3,split),'metal')
 for side in [-1,1]:
  for z in range(6,int(h)-1,4):
   off=2 if setback and z>split else 0
   q('SideBand',(side*(w/2-off+.06),2*(off>0),z),(.16,d-2-2*off,2.5),'glass')
 q('Roof',(0,2 if setback else 0,h-.3),(w-3 if setback else w+1,d-3 if setback else d+1,.6),'pale')
 if setback:
  q('Terrace',(0,-d/2+1.7,split+.1),(w+1,4,.2),'wood')
  q('TerraceRail',(0,-d/2+.1,split+.7),(w,.15,1.2),'metal')
 if 'MixedUse' in t:
  for x in [-w/3,w/3]:q('StoreAwning',(x,-d/2-.6,3.4),(7,1.5,.2),'wood')
 if 'Maker' in t:
  for x in [-12,0,12]:q('RoofLight',(x,0,h+.5),(6,d-4,1),'glass')
 if f>3 and ('Cowork' in t or 'MixedUse' in t or 'Incubator' in t):
  q('RoofGarden',(-w*.2,0,h+.05),(w*.35,d*.55,.1),'green')
  q('RoofUtility',(w*.25,d*.2,h+.65),(5,4,1.3),'metal')
 q('Canopy',(0,-d/2-.5,3.8),(min(12,w-2),1.8,.25),'metal')
 q('LobbyGlow',(0,-d/2-.13,2),(3,.12,3),'glow')
 sign=q('Signage',(0,-d/2-.2,4.5),(min(w-4,10),.2,.8),'sign');sign['semantic_target']='Startup_Signage_'+n;sign['dynamic_material_target']=True
 if 'MakerSpace' in t:
  for x in [-10,0,10]:
   q('WorkshopDoor',(x,-d/2-.2,2.5),(7,.25,4.5),'metal')
   for z in [1,2,3,4]:q('DoorSlat',(x,-d/2-.36,z),(6.8,.1,.1),'pale')
 if 'Cowork' in t or 'Incubator' in t:q('EventGlazing',(w/2+.16,0,3),(.2,d-4,5),'glass')
 if site['progression']:
  p=bpy.data.objects.new(site['progression'],None);L.objects.link(p);p.location=site['position'];p['context_building']=root.name;p['planning_only']=True;p['runtime_binding']='none';p['footprint_m']=[w+4,d+4];p['stories']=f
# Street strips follow actual existing road heights, split into 3m modules at intersections.
roads=M['roads']+P['new_roads'];used=[r for r in roads if r['id'] in ['Progression_Startup','StartupRow_CrossStreet','Startup_Link','Startup_ResearchLane','Startup_NorthAccess','Startup_SouthLane']]
def dist(p,a,b):
 v=Vector(b[:2])-Vector(a[:2]);u=Vector(p[:2])-Vector(a[:2]);t=max(0,min(1,u.dot(v)/v.length_squared));return (u-v*t).length
for road in P['new_roads']:
 for aa,bb in zip(road['points'],road['points'][1:]):
  a,b=Vector(aa),Vector(bb);v=b-a;mid=(a+b)/2;box(road['id'],mid,(v.xy.length,road['width_m'],.6),'asphalt',angle=math.degrees(math.atan2(v.y,v.x)))
walk=[]
for road in used:
 for a,b in zip(road['points'],road['points'][1:]):
  a,b=Vector(a),Vector(b);v=b-a;length=v.xy.length;u=Vector((v.x/length,v.y/length,0));normal=Vector((-u.y,u.x,0));count=int(length/3)
  for i in range(count):
   p=a+v*((i+.5)/count)
   if not(-712<p.x<-208 and -532<p.y<-148):continue
   for side in [-1,1]:
    center=p+normal*side*(road['width_m']/2+2.5)
    if not(-715<center.x<-205 and -535<center.y<-145):continue
    if any(r['id']!=road['id'] and any(dist(center,c,d)<r['width_m']/2+1 for c,d in zip(r['points'],r['points'][1:])) for r in used):continue
    center.z=p.z+.37;box('Startup_Sidewalk',center,(length/count+.05,5,.14),'paving',angle=math.degrees(math.atan2(u.y,u.x)));walk.append(list(center))
# Flat forecourt platforms meet building entrance levels; approach paths are gently sloped.
for site in P['sites']:
 x,y,z=site['position'];w,d=site['width'],site['depth'];ang=math.radians(site['rotation_degrees']);front=Vector((x+math.sin(ang)*(d/2+3),y-math.cos(ang)*(d/2+3),15.35));box('Startup_EntranceWalk',front,(w+1,5,.1),'paving',angle=site['rotation_degrees'])
for space in P['public_spaces']:
 x,y,z=space['center'];w,d=space['size'];box('Startup_'+space['id'],(x,y,15.25),(w,d,.3),'paving')
 for dx in [-w/2+3,w/2-3]:
  box('Startup_Seat',(x+dx,y,15.65),(3,1,.5),'wood')
  box('Startup_Planter',(x+dx,y+d/2-3,15.6),(3,3,.4),'concrete');box('Startup_Planting',(x+dx,y+d/2-3,16.05),(2.6,2.6,.5),'green')
# Street trees are set back from the clear center of the sidewalk.
for j,p in enumerate(walk):
 if j%22:continue
 x,y,z=p
 nearest=[]
 for road in used:
  for aa,bb in zip(road['points'],road['points'][1:]):
   a,b=Vector(aa),Vector(bb);v=b-a;v.z=0;u=Vector((x,y,z))-a;t=max(0,min(1,u.dot(v)/v.length_squared));q=a+v*t;delta=Vector((x-q.x,y-q.y,0));nearest.append((delta.length,delta))
 _,delta=min(nearest,key=lambda a:a[0])
 if delta.length:delta.normalize();x-=delta.x*1.8;y-=delta.y*1.8
 if any(math.hypot(x-a['position'][0],y-a['position'][1])<max(a['width'],a['depth'])/2+4 for a in P['sites']):continue
 box('Startup_TreeTrunk',(x,y,z+1.7),(.35,.35,3.4),'wood');bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=2,location=(x,y,z+4));tree=bpy.context.object;tree.name='Startup_TreeCanopy'
 for old in list(tree.users_collection):old.objects.unlink(tree)
 U.objects.link(tree);tree.data.materials.append(mats['green'])
# Flush crossing markings over the original cross street.
for x in [-650,-540,-460]:
 for y in range(-346,-333,2):box('Startup_Crossing',(x,y,15.16),(4,.9,.02),'paint')

exec(compile(open(R+'/connectivity.py').read(),'connectivity','exec'))
# Curb transitions: 2m-long shallow wedges join cross-street sidewalk to road.
for x in [-650,-540,-460]:
 for side in [-1,1]:
  q=box('Startup_CurbTransition',(x,-340+side*8,15.21),(4,2,.12),'paving');q.rotation_euler.x=side*math.atan(.08/2)

# Give new raised walking surfaces solid skirts down to existing terrain, avoiding floating slabs.
bpy.context.view_layer.update()
for o in list(U.objects):
 if o.type=='MESH' and o.data.materials[0].name in ['Startup_Paving','Startup_LocalAsphalt']:
  o.data=o.data.copy();inv=o.matrix_world.inverted()
  for v in list(o.data.vertices)[:4]:
   world=o.matrix_world@v.co;world.z=14;v.co=inv@world
# Road-relative camera positions, all new planning views; old cameras remain untouched.
cams=[('StartupRow_Aerial',(-850,-850,650),(-465,-335,20),740),('Founder_To_Startup',(-710,-590,21),(-485,-345,30),0),('Startup_To_TechCore',(-460,-400,20),(50,420,180),0),('Startup_MainBoulevard',(-600,-484,20),(-430,-360,25),0),('Startup_Core',(-540,-340,20),(-455,-307,24),0),('Startup_ProgressionParcels',(-850,-760,470),(-480,-310,20),680),('Startup_NightPreview',(-710,-600,170),(-490,-335,25),570)]
for n,pos,target,ortho in cams:
 d=bpy.data.cameras.new(n);o=bpy.data.objects.new(n,d);V.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.clip_end=20000;d.lens=28
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
# One hidden prototype per typology is a linked copy of a realized building assembly.
for typ in sorted({a['typology'] for a in P['sites']}):
 source=next(a for a in P['sites'] if a['typology']==typ);rt=bpy.data.objects['Startup_'+source['id']];prototype=bpy.data.objects.new(typ,None);K.objects.link(prototype);prototype['typology']=typ
 for child in rt.children:
  o=child.copy();o.data=child.data;K.objects.link(o);o.parent=prototype
 components[typ]=len(rt.children)
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;bpy.context.preferences.filepaths.save_version=0
json.dump({'hidden_original_meshes':hidden,'kit_components':components,'unique_dimension_material_meshes':len(cache),'sidewalk_modules':len(walk),'frontage_paths':paths},open(R+'/build_audit.json','w'),indent=2)
bpy.ops.wm.save_as_mainfile(filepath=R+'/Blender/Atlantis_Phase6_Masterplan.blend');print('PHASE6_BUILT')
