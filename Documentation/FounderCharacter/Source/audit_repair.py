"""Validate source repair invariants independently of RealityKit screenshots."""
import json
from pathlib import Path
import bpy
from mathutils import Matrix

folder=Path(__file__).resolve().parents[1]
evidence=folder/'Evidence/A1'
bpy.ops.wm.open_mainfile(filepath=str(evidence/'Before/founder_candidate_a.blend'))
before={b.name: (b.parent.name if b.parent else None, b.matrix_local.copy()) for b in bpy.data.objects['Armature'].data.bones}
bpy.ops.wm.open_mainfile(filepath=str(folder/'Source/founder_candidate_a.blend'))
rig=bpy.data.objects['Armature']
assert set(before)=={b.name for b in rig.data.bones}
for bone in rig.data.bones:
    parent,matrix=before[bone.name]
    assert parent==(bone.parent.name if bone.parent else None)
    assert max(abs(matrix[r][c]-bone.matrix_local[r][c]) for r in range(4) for c in range(4))<1e-6
head=bpy.data.objects['HeadMesh']
body=bpy.data.objects['BodyMesh']
assert max(v.co.z for v in body.data.vertices)<1.48, 'Jaw fragment remains in body mask'
assert head.data.has_custom_normals and body.data.has_custom_normals
assert all(key.value==0 for key in head.data.shape_keys.key_blocks if key.name!='Basis')
assert len(head.data.shape_keys.key_blocks)==10
# The former exposed jaw cut is now internal, shared topology within HeadMesh.
edges={tuple(sorted(edge.vertices)):0 for edge in head.data.edges}
for polygon in head.data.polygons:
    for pair in polygon.edge_keys:
        edges[tuple(sorted(pair))]+=1
jaw_open=[]
for pair,count in edges.items():
    if count==1 and all(1.54<head.data.vertices[i].co.z<1.59 for i in pair):
        jaw_open.append(pair)
assert not jaw_open, 'Open topology remains across the jaw'
jaw_normals={}
maximum_split=0
for loop in head.data.loops:
    vertex=head.data.vertices[loop.vertex_index]
    if 1.54<vertex.co.z<1.59:
        normal=head.data.corner_normals[loop.index].vector
        if loop.vertex_index in jaw_normals:
            maximum_split=max(maximum_split,(normal-jaw_normals[loop.vertex_index]).length)
        else:
            jaw_normals[loop.vertex_index]=normal.copy()
assert maximum_split<1e-4, 'Split shading normals remain at the welded jaw'
pose=json.loads((folder/'Intermediate/founder_validation_pose.json').read_text())
for bone in rig.pose.bones:
    local=Matrix(pose['seated'][bone.name])
    bone.matrix=bone.parent.matrix@local if bone.parent else local
    bpy.context.view_layer.update()
graph=bpy.context.evaluated_depsgraph_get()
shoe=bpy.data.objects['ShoeMesh'].evaluated_get(graph)
offset=pose['root_vertical_offset']
soles={side:min(v.co.z+offset for v in shoe.data.vertices if (v.co.x>0)==(side=='L')) for side in ['L','R']}
assert all(abs(height)<0.002 for height in soles.values()),soles
eye_midpoint=[sum(pose['landmarks']['Eye_'+side][axis] for side in ['L','R'])/2 for axis in range(3)]
eye_vertical_error=eye_midpoint[2]-1.18
# Seated placement applies a pi yaw after Blender Z-up/-Y-forward conversion.
eye_world_x=0.34-eye_midpoint[0]
eye_world_z=-0.22+eye_midpoint[1]
eye_horizontal_error=((eye_world_x-0.34)**2+(eye_world_z+0.22)**2)**0.5
assert abs(eye_vertical_error)<=0.015,eye_vertical_error
assert eye_horizontal_error<=0.025,eye_horizontal_error
result={'status':'SOURCE_REPAIR_INVARIANTS_PASS; visual acceptance separate',
        'canonical_bones_and_rest_matrices_unchanged':True,'jaw_boundary_edges':len(jaw_open),
        'maximum_jaw_corner_normal_disagreement':maximum_split,
        'head_body_partition_below_m':max(v.co.z for v in body.data.vertices),
        'custom_surface_normals':True,'neutral_facial_weights_zero':True,
        'seated_sole_heights_m':soles,'seated_landmarks':pose['landmarks'],
        'eye_midpoint_vertical_error_m':eye_vertical_error,
        'eye_midpoint_horizontal_error_m':eye_horizontal_error}
(evidence/'source_repair_audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
