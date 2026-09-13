import bpy,json,os,collections
from mathutils import Vector
R=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend');bpy.context.view_layer.update()
def visible(o):return not o.hide_render and not any(c.hide_render for c in o.users_collection)
obs=[]
for o in bpy.context.scene.objects:
 if not visible(o):continue
 d=dict(name=o.name,type=o.type,parent=o.parent.name if o.parent else None,collections=[c.name for c in o.users_collection],position=list(o.matrix_world.translation),props={k:str(v) for k,v in o.items()})
 if o.type in ['MESH','FONT']:
  pts=[o.matrix_world@Vector(v) for v in o.bound_box];d['bounds']=[[min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]]
 if o.type=='MESH':d.update(mesh=o.data.name,triangles=sum(len(p.vertices)-2 for p in o.data.polygons),materials=[m.name if m else '' for m in o.data.materials])
 obs.append(d)
a=dict(units=bpy.context.scene.unit_settings.system,scale=bpy.context.scene.unit_settings.scale_length,collections={c.name:[x.name for x in c.children] for c in bpy.data.collections},objects=obs,images=[dict(name=i.name,size=list(i.size),path=i.filepath,packed=bool(i.packed_file)) for i in bpy.data.images],usd_options=[p.identifier for p in bpy.ops.wm.usd_export.get_rna_type().properties])
json.dump(a,open(R+'/source_audit.json','w'),indent=2)
print('COLLECTIONS',json.dumps(a['collections']));print('SHARED_MESHES',len([n for n,v in collections.Counter(o.get('mesh') for o in obs if o['type']=='MESH').items() if v>1]));print('IMAGES',a['images']);print('USD_OPTIONS',a['usd_options'])
try:import pxr;print('PXR_AVAILABLE',pxr.__path__)
except Exception as e:print('NO_PXR',str(e))
