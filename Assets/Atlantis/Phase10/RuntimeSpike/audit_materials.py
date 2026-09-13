import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(R/'../../Phase9/UnicornHeights/Blender/Atlantis_Phase9_Masterplan.blend'))
result={}
for m in bpy.data.materials:
 if m.name in ['TEMP • Atlantis Bay','TEMP • coastal limestone']:
  result[m.name]={'viewportColor':list(m.diffuse_color),'nodes':[{'type':n.type,'name':n.name,'baseColor':list(n.inputs['Base Color'].default_value) if 'Base Color' in n.inputs else None} for n in m.node_tree.nodes] if m.node_tree else []}
(R/'material_audit.json').write_text(json.dumps(result,indent=2));print(result)
