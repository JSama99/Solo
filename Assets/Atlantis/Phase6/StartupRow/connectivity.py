# Executed by build.py with its scene helpers. Exact footprint checks protect 3m clear paths.
import heapq
tr=ast.parse(open(R+'/plan.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name in ['inside','pointseg','orient','segdist','polyseg','corners']],type_ignores=[]),'site_geometry','exec'))
obstacles=[(a['id'],corners(a['position'][0],a['position'][1],a['width']+4,a['depth']+4,a['rotation_degrees'])) for a in P['sites']]
def clear(a,b,ignore):return all(n==ignore or polyseg(poly,a,b)>.01 for n,poly in obstacles)
paths=[];missing=[]
for site in P['sites']:
 x,y,z=site['position'];ang=math.radians(site['rotation_degrees']);start=Vector((x+math.sin(ang)*(site['depth']/2+3),y-math.cos(ang)*(site['depth']/2+3),15.4));options=[]
 for road in used:
  for aa,bb in zip(road['points'],road['points'][1:]):
   aa,bb=Vector(aa),Vector(bb);v=bb-aa;u=Vector((v.x,v.y,0));length=u.length;u.normalize()
   for shift in [0,-15,15,-35,35,-60,60]:
    proj=max(0,min(length,(start-aa).dot(u)+shift));center=aa+v*(proj/length);normal=start-center;normal.z=0
    if normal.length<.001:continue
    normal.normalize();end=center+normal*(road['width_m']/2+2.5);end.z=center.z+.44
    if not(-713<end.x<-207 and -533<end.y<-147):continue
    for route in [[start,end],[start,Vector((start.x,end.y,15.4)),end],[start,Vector((end.x,start.y,15.4)),end]]:
     total=sum((b-a).xy.length for a,b in zip(route,route[1:]))
     if total<1 or abs(end.z-start.z)/total>1/20:continue
     if all(clear(a,b,site['id']) for a,b in zip(route,route[1:])):options.append((total,route))
 if not options:missing.append(site['id']);continue
 total,route=min(options,key=lambda a:a[0]);travel=0;startz=route[0].z;endz=route[-1].z
 for i in range(1,len(route)-1):travel+=(route[i]-route[i-1]).xy.length;route[i].z=startz+(endz-startz)*travel/total
 for a,b in zip(route,route[1:]):
  delta=b-a
  if delta.length<.1:continue
  q=box('Startup_FrontagePath',(a+b)/2-Vector((0,0,.07)),(delta.length,3,.14),'paving');q.rotation_euler=delta.to_track_quat('X','Z').to_euler()
 paths.append({'building':site['id'],'points':[list(a) for a in route],'width':3,'grade':abs(endz-startz)/total})
print('PEDESTRIAN_PATHS',len(paths),'missing',missing)
