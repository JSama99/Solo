import bpy,bmesh,json,os,ast,math
from mathutils import Vector,Matrix
R=os.path.dirname(os.path.abspath(__file__));A=R+'/PallasAI';bpy.ops.wm.open_mainfile(filepath=R+'/../../Phase4/Rivals/Blender/Atlantis_Phase4_Masterplan.blend');s=bpy.context.scene
srcpath=A+'/Source/PallasAI_Higgsfield_Raw_candidate2.glb';pre=set(s.objects);bpy.ops.import_scene.gltf(filepath=srcpath);imported=set(s.objects)-pre
tr=ast.parse(open(R+'/../../Phase3/MediaDistrict/build_media.py').read());exec(compile(ast.Module(body=[n for n in tr.body if isinstance(n,ast.FunctionDef) and n.name in ['col','mat','cube','prism']],type_ignores=[]),'helpers','exec'))
stage=col('PallasAI_Source',bpy.data.collections['AssetStaging']);asset=col('PallasAI_Production',bpy.data.collections['TechCore']);root=bpy.data.objects.new('PallasAI_HQ_AssetRoot',None);asset.objects.link(root);root.parent=bpy.data.objects['RivalHQ_PallasAI'];root['canonicalCompanyID']='pallas';root['forward']='-Y'
for o in imported:
 for c in list(o.users_collection):c.objects.unlink(o)
 stage.objects.link(o)
stage.hide_render=True;stage.hide_viewport=True
raw=next(o for o in imported if o.type=='MESH');o=raw.copy();o.data=raw.data.copy();asset.objects.link(o);o.name='PallasAI_GeneratedTower';o.parent=root
b=bmesh.new();b.from_mesh(o.data);bmesh.ops.remove_doubles(b,verts=list(b.verts),dist=.000001)
# Clip away generated campus; retain upper tower surface and UVs.
bmesh.ops.bisect_plane(b,geom=list(b.verts)+list(b.edges)+list(b.faces),dist=.0000001,plane_co=(0,0,-.2),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
# Remove detached debris and seal local source defects.
pending=set(b.verts);groups=[]
while pending:
 stack=[pending.pop()];g=[]
 while stack:
  v=stack.pop();g.append(v)
  for e in v.link_edges:
   q=e.other_vert(v)
   if q in pending:pending.remove(q);stack.append(q)
 groups.append(g)
keep=set(max(groups,key=len));bmesh.ops.delete(b,geom=[v for v in b.verts if v not in keep],context='VERTS')
for attempt in range(4):
 bad=[e for e in b.edges if len(e.link_faces)>2 or len(e.link_faces)==0]
 if bad:bmesh.ops.delete(b,geom=list({v for e in bad for v in e.verts}),context='VERTS')
 bmesh.ops.holes_fill(b,edges=[e for e in b.edges if e.is_boundary],sides=0)
 if all(e.is_manifold for e in b.edges):break
for attempt in range(4):
 bad=[e for e in b.edges if not e.is_manifold]
 if not bad:break
 bmesh.ops.delete(b,geom=list({v for e in bad for v in e.verts}),context='VERTS')
 bmesh.ops.holes_fill(b,edges=[e for e in b.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(b,faces=list(b.faces));lo=Vector([min(v.co[i] for v in b.verts) for i in range(3)]);hi=Vector([max(v.co[i] for v in b.verts) for i in range(3)]);factor=142/(hi.z-lo.z);rot=Matrix.Rotation(math.pi/2,4,'Z')
for v in b.verts:v.co=rot@(v.co-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*factor+Vector((0,0,18))
b.to_mesh(o.data);b.free()
# Copy source materials/images before reducing final dependencies.
for idx,m in enumerate(o.data.materials):
 m=m.copy();o.data.materials[idx]=m;m.name='PallasAI_TowerFacade'
 for node in m.node_tree.nodes:
  if node.type=='TEX_IMAGE' and node.image:
   im=node.image.copy();im.name='PallasAI_Final_'+im.name;im.scale(2048,2048);im.pack();node.image=im
 for node in m.node_tree.nodes:
  if node.type=='BSDF_PRINCIPLED':
   for link in list(node.inputs['Normal'].links):m.node_tree.links.remove(link)
# Final material remap removes generated atlas artifacts; original atlases remain in staging.
facade=mat('PallasAI_RefinedTowerGlass',(.095,.20,.27),.55,.3)
o.data.materials.clear();o.data.materials.append(facade)
for polygon in o.data.polygons:polygon.material_index=0;polygon.use_smooth=False
# Generated shell has corrugated facade artifacts. Preserve it as a study and
# reconstruct its stepped slender silhouette with planar architectural panels.
asset.objects.unlink(o);stage.objects.link(o);o.name='PallasAI_RepairedTowerStudy'
prism('PallasAI_TowerRetopology',[(18,42,34,0,0),(130,38,30,0,0),(143,32,28,0,0),(150,32,28,0,0)],facade,asset,root)

# Replace normal-map usage with geometric normals; base/ORM retained. Export excludes unused maps.
stone=mat('PallasAI_PodiumStone',(.63,.62,.56),0,.6);glass=mat('PallasAI_PodiumGlass',(.08,.19,.25),.5,.25);metal=mat('PallasAI_Bronze',(.45,.34,.18),.65,.35);glow=mat('PallasAI_ArchitecturalGlow',(.9,.65,.32),0,.4,.8)
def box(n,p,d,m):return cube('PallasAI_'+n,p,d,m,asset,root)
box('TowerSeat',(0,0,17.5),(44,36,1),stone)
box('Foundation',(0,0,1),(58,40,2),stone);box('NewsLobby',(0,0,9),(54,36,14),glass)
for z in [2.5,9,16.5]:box('PodiumBand',(0,0,z),(56,38,1),stone)
for x in range(-24,25,6):box('PodiumMullion',(x,-18.25,9),(.45,.6,13),metal)
for f in [-.45,-.3,-.15,0,.15,.3,.45]:
 for side in [-1,1]:prism('PallasAI_VerticalFin',[(18,.5,1,f*42,side*17),(130,.5,1,f*38,side*15),(143,.5,1,f*32,side*14)],metal,asset,root)
box('CrownCap',(0,0,155),(32,28,10),metal)
box('EntryCanopy',(0,-18.5,5),(18,3,1),metal)
for x in [-8,8]:box('LobbyLight',(x,-18.7,5),(.3,.2,4),glow)
for n,p,d in [('Signage_Main',(0,-18.5,12.5),(12,.25,2)),('LobbyDisplay',(18,-18.5,6),(5,.25,3)),('CrownMark',(0,-14.2,147),(3,.3,3))]:
 ma=mat('PallasAI_'+n,(.55,.46,.3),.2,.4,.4);q=box(n,p,d,ma);q['dynamic_material_target']=True;q['content']='blank'
# Per-material consolidation for authored podium (source tower preserved separately).
for ma in [stone,glass,metal,glow]:
 group=[q for q in asset.objects if q.type=='MESH' and q.data.materials[0]==ma];bpy.ops.object.select_all(action='DESELECT')
 for q in group:q.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();q=group[0];trans=q.matrix_basis.copy()
 for v in q.data.vertices:v.co=trans@v.co
 q.matrix_basis=Matrix.Identity(4);q.name=ma.name
bpy.context.view_layer.update();geo=[]
for q in asset.objects:
 if q.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(q.data);geo.append({'name':q.name,'nonmanifold':sum(not e.is_manifold for e in bm.edges),'zero_area':sum(f.calc_area()<1e-8 for f in bm.faces),'volume':bm.calc_volume(signed=True)});bm.free()
json.dump({'geometry':geo,'source_tower_uniform_scale':factor,'source_rotation_z_degrees':90,'source_cut_z':-.2,'authored_podium_height':18},open(A+'/Blender/cleanup_audit.json','w'),indent=2);assert all(g['nonmanifold']==0 and g['zero_area']==0 and g['volume']>0 for g in geo),geo
# Keep original blockout until scene/export checks; candidate master is explicitly provisional.
parent=root.parent;root.parent=None;root.location=(0,0,0);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for q in asset.objects:q.select_set(True)
bpy.ops.export_scene.gltf(filepath=A+'/Export/Atlantis_PallasAI_HQ_v1.glb',use_selection=True,export_format='GLB',export_yup=True);root.parent=parent;root.location=(0,0,0)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=A+'/Blender/PallasAI_Integration_Candidate.blend')
print('PALLAS_CANDIDATE_BUILT')
