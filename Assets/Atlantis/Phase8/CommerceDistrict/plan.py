import json,math,ast
from pathlib import Path
R=Path(__file__).resolve().parent
tr=ast.parse(Path('Assets/Atlantis/Phase6/StartupRow/plan.py').read_text());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'geometry','exec'))
M=json.loads(Path('Assets/Atlantis/Phase0/masterplan_manifest.json').read_text());roads=[r for r in M['roads'] if r['id'] in ['Commerce_Boulevard','CommerceDistrict_CrossStreet','Commerce_Link']]
kit={'EnterpriseOffice_A':(38,30,48,'stone'),'EnterpriseOffice_B':(40,32,64,'silver'),'Hotel_A':(34,28,60,'warm'),'Hotel_B':(40,32,108,'warm'),'ServiceTower_A':(32,28,72,'stone'),'MixedUse_A':(36,30,28,'warm'),'MixedUse_B':(38,30,40,'stone'),'ConferenceCenter':(68,42,19,'stone'),'RetailPodium_A':(30,24,12,'warm'),'BusinessAnchor_A':(42,34,96,'silver')}
spaces=[{'name':'CustomerPlaza','center':[213,-132,15.4],'size':[82,70]},{'name':'EventForecourt','center':[106,-225,15.4],'size':[66,20]},{'name':'FlashpointCorridor','center':[452,-303,15.4],'size':[142,22]}]
sites=[];rejected=[]
def addsite(typ,x,y,angle=0):
 w,d,h,ma=kit[typ];p=corners(x,y,w+2,d+4,angle)
 if not all(53<a<547 and -357<b<-23 for a,b in p):rejected.append([typ,x,y,'bounds']);return
 if polydist(p,corners(430,-240,79,64))<4:rejected.append([typ,x,y,'Flashpoint']);return
 if any(polydist(p,corners(*a['center'][:2],*a['size']))<3 for a in spaces):rejected.append([typ,x,y,'plaza']);return
 if any(polyseg(p,a,b)<r['width_m']/2+7 for r in roads for a,b in zip(r['points'],r['points'][1:])):rejected.append([typ,x,y,'road']);return
 if any(polydist(p,a['polygon'])<7 for a in sites):rejected.append([typ,x,y,'neighbor']);return
 sites.append({'id':'Commerce_Building_%02d'%len(sites),'typology':'Commerce_'+typ,'position':[x,y,15.4],'angle':angle,'width':w,'depth':d,'height':h,'material':ma,'polygon':p})
# Calmer northern anchors, broad southern event shell, hotels in three corridor contexts.
for args in [('BusinessAnchor_A',90,-55),('Hotel_B',292,-55),('Hotel_A',515,-57),('ConferenceCenter',106,-264,180),('EnterpriseOffice_A',193,-265,180),('MixedUse_A',285,-329,180),('Hotel_A',358,-329,180),('EnterpriseOffice_B',480,-338,180),('RetailPodium_A',518,-260),('EnterpriseOffice_B',410,-115),('ServiceTower_A',90,-124),('MixedUse_B',160,-55),('EnterpriseOffice_A',228,-55),('MixedUse_A',295,-132),('RetailPodium_A',160,-126),('ServiceTower_A',355,-238,31),('MixedUse_A',520,-120),('MixedUse_A',278,-236,0),('MixedUse_B',335,-100,0)]:addsite(*args)
for args in [('MixedUse_A',290,-330,31),('RetailPodium_A',142,-133),('EnterpriseOffice_A',220,-93),('RetailPodium_A',295,-126),('MixedUse_A',530,-123,23),('MixedUse_B',345,-64,28),('RetailPodium_A',80,-332)]:addsite(*args)
P={'bounds':[50,-360,550,-20],'kit':kit,'sites':sites,'roads':roads,'public_spaces':spaces,'rejected':rejected}
(R/'site_plan.json').write_text(json.dumps(P,indent=2));print('ACCEPTED',len(sites));print('REJECTED',rejected);print([(a['typology'],a['position']) for a in sites])
