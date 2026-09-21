"""Deterministic bounded site plan, metre coordinates; no external packages."""
import json,math
from pathlib import Path
R=Path(__file__).resolve().parent
manifest=json.loads((R/'../../Phase0/masterplan_manifest.json').read_text())
land=[(-790,-470),(-400,-670),(-140,-590),(60,-410),(520,-400),(820,-180),(780,60),(390,160),(530,440),(420,680),(80,780),(-330,700),(-710,340)]
def inside(p,poly):
 x,y=p[:2];c=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:c=not c
 return c
def pointseg(p,a,b):
 dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/max(dx*dx+dy*dy,1e-12)));return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
def orient(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def segdist(a,b,c,d):
 if orient(a,b,c)*orient(a,b,d)<0 and orient(c,d,a)*orient(c,d,b)<0:return 0
 return min(pointseg(a,c,d),pointseg(b,c,d),pointseg(c,a,b),pointseg(d,a,b))
def polyseg(poly,a,b):
 if inside(a,poly) or inside(b,poly):return 0
 return min(segdist(c,d,a,b) for c,d in zip(poly,poly[1:]+poly[:1]))
def polydist(p,q):
 if inside(p[0],q) or inside(q[0],p):return 0
 return min(polyseg(p,a,b) for a,b in zip(q,q[1:]+q[:1]))
def corners(x,y,w,d,angle=0):
 a=math.radians(angle);c,s=math.cos(a),math.sin(a)
 return [(x+u*c-v*s,y+u*s+v*c) for u,v in [(-w/2,-d/2),(w/2,-d/2),(w/2,d/2),(-w/2,d/2)]]
newroads=[{'id':'Startup_ResearchLane','width_m':12,'points':[[-680,-270,15.1],[-390,-270,15.1]]},{'id':'Startup_NorthAccess','width_m':12,'points':[[-540,-340,15.1],[-540,-270,15.1]]}]
newroads.append({'id':'Startup_SouthLane','width_m':10,'points':[[-443,-391,15.1],[-443,-465,15.1],[-218,-465,15.1]]})
roads=manifest['roads']+newroads
kit={'Cowork_A':(32,24,5,'pale'),'Cowork_B':(28,26,6,'concrete'),'Office_A':(30,22,4,'brick'),'Office_B':(32,24,7,'pale'),'MakerSpace':(40,28,3,'concrete'),'Incubator':(42,32,8,'pale'),'LabSmall':(30,24,5,'concrete'),'MixedUse_A':(30,22,4,'brick'),'MixedUse_B':(34,24,6,'brick'),'AnchorMidrise':(38,30,9,'concrete'),'Cafe':(12,10,1,'brick')}
sites=[];rejected=[]
def add(id,typ,x,y,angle=0,progression=None,floors=None,reason='Repeated street frontage'):
 w,d,n,finish=kit[typ];n=floors or n;p=corners(x,y,w+2,d+2,angle)
 if not all(-716<=u<=-204 and -536<=v<=-144 and inside((u,v),land) for u,v in p):rejected.append([id,'boundary']);return False
 for road in roads:
  for a,b in zip(road['points'],road['points'][1:]):
   if polyseg(p,a,b)<road['width_m']/2+4:rejected.append([id,'road '+road['id']]);return False
 for site in sites:
  if polydist(p,site['clearance_polygon'])<6:rejected.append([id,'neighbor '+site['id']]);return False
 h=(6+4*(n-1) if typ=='MakerSpace' else 4*n)+.6
 sites.append({'id':id,'typology':'Startup_'+typ,'position':[x,y,15.4],'rotation_degrees':angle,'width':w,'depth':d,'floors':n,'height':h,'finish':finish,'progression':progression,'reason':reason,'clearance_polygon':p});return True
# The five progression contexts, all within Startup Row; no runtime keys are consumed.
add('LoftContext','MixedUse_A',-602,-444,31,'Progression_Loft',4,'First professional address at bridge arrival')
add('SmallOfficeContext','Office_A',-620,-307,0,'Progression_SmallOffice',5,'First formal cross-street office frontage')
add('OfficeContext','Cowork_B',-450,-307,0,'Progression_Office',7,'Core coworking and shared-service intersection')
add('SmallBuildingContext','AnchorMidrise',-500,-220,0,'Progression_SmallBuilding',9,'Research lane anchor with an independent forecourt')
add('BigBuildingContext','AnchorMidrise',-350,-220,0,'Progression_BigBuilding',12,'Premium transition edge inside Startup, outside prime Tech Core')
add('IncubatorAnchor','Incubator',-650,-220,0,None,8,'Western research lane meeting/event anchor')
add('ArrivalCafe','Cafe',-642,-456,31,reason='Small social shell at arrival')
add('CoreCafe','Cafe',-504,-371,0,reason='Founder/investor courtyard meeting shell')
add('LaunchCafe','Cafe',-306,-380,0,reason='Networking shell on the eastern progression edge')
# Repeated typologies form compact runs rather than unique hero buildings.
for i,(x,y,t,a) in enumerate([(-566,-415,'Cowork_A',31),(-529,-388,'MixedUse_B',31),(-563,-509,'Office_A',211),(-519,-485,'MixedUse_A',211),(-473,-457,'Cowork_B',211),(-670,-307,'MixedUse_A',0),(-570,-307,'Cowork_A',0),(-500,-307,'LabSmall',0),(-400,-307,'Office_A',0),(-350,-307,'MixedUse_A',0),(-590,-220,'MakerSpace',0),(-550,-218,'LabSmall',0),(-446,-220,'Office_B',0),(-398,-220,'Cowork_A',0),(-695,-170,'Office_A',0),(-600,-170,'MixedUse_A',0),(-548,-170,'Office_A',0),(-495,-170,'MixedUse_A',0),(-442,-170,'Office_A',0),(-395,-170,'LabSmall',0),(-255,-180,'Office_B',0),(-685,-388,'MixedUse_A',0),(-680,-470,'Office_A',0),(-405,-495,'Office_A',0),(-350,-495,'MixedUse_B',0),(-290,-495,'Office_A',0),(-235,-495,'MixedUse_A',0),(-405,-437,'LabSmall',0),(-350,-430,'Cowork_A',0),(-290,-438,'Office_B',0),(-235,-425,'MixedUse_B',0),(-250,-370,'Office_A',0)]):add('Building_%02d'%i,t,x,y,a)
plan={'bounds':[-720,-540,-200,-140],'core':[-500,-365,15.4],'kit':kit,'new_roads':newroads,'sites':sites,'rejected_candidates':rejected,'route':[[-875,-1030,8],[-875,-850,8.7],[-790,-660,9],[-710,-590,16],[-610,-490,16],[-460,-400,15],[-190,-270,15],[-170,-80,15],[0,100,15],[50,300,15]],'public_spaces':[{'id':'Arrival_Forecourt','center':[-642,-438,15.4],'size':[22,16]},{'id':'Core_Courtyard','center':[-502,-366,15.4],'size':[42,34]},{'id':'PocketPark','center':[-610,-380,15.4],'size':[44,40]},{'id':'Launch_Court','center':[-305,-394,15.4],'size':[36,22]}]}
(R/'site_plan.json').write_text(json.dumps(plan,indent=2));print('Accepted',len(sites),'buildings');print('Rejected:',rejected);print('Progression:',[(s['progression'],s['position']) for s in sites if s['progression']])
