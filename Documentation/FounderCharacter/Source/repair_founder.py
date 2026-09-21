"""Repair the retained Pass A source, preserving canonical bones and slots.

Run Blender --background --python-exit-code 1 --python this_file -- [--render].
This is a source-asset repair, not a replacement anatomy generator.
"""
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector, Matrix

folder = Path(__file__).resolve().parents[1]
source = folder/'Source'
evidence = folder/'Evidence/A1'
sys.path.insert(0, str(source))
from build_founder import active, subset, sphere

bpy.ops.wm.open_mainfile(filepath=str(evidence/'Before/founder_candidate_a.blend'))
rig = bpy.data.objects['Armature']
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    bone.matrix_basis = Matrix.Identity(4)

# Reconstruct the SAME surface, welding only the duplicated partition boundary.
vertices, faces, weights, lookup = [], [], [], {}
old_objects = [bpy.data.objects['BodyMesh'], bpy.data.objects['HeadMesh']]
facial = json.loads((source/'facial_target_a1.json').read_text())
jaw_delta = {tuple(item['position']):Vector(item['delta']) for item in facial['jaw_open']}
for obj in old_objects:
    remap = {}
    for vertex in obj.data.vertices:
        key = tuple(round(float(c), 6) for c in vertex.co)
        if key not in lookup:
            lookup[key] = len(vertices)
            vertices.append(vertex.co.copy())
            weights.append({obj.vertex_groups[g.group].name: g.weight for g in vertex.groups})
        remap[vertex.index] = lookup[key]
    faces += [[remap[i] for i in polygon.vertices] for polygon in obj.data.polygons]
mesh = bpy.data.meshes.new('ContinuousFounderSurface')
mesh.from_pydata(vertices, [], faces)
mesh.update()
continuous = bpy.data.objects.new('ContinuousFounderSurface', mesh)
bpy.context.collection.objects.link(continuous)
continuous.parent = rig
for bone in rig.data.bones:
    group = continuous.vertex_groups.new(name=bone.name)
    for index, influences in enumerate(weights):
        if bone.name in influences:
            group.add([index], influences[bone.name], 'REPLACE')
for polygon in mesh.polygons:
    polygon.use_smooth = True
# Small proportional refinements retain original topology and original rig.
original_positions = [tuple(round(float(c),6) for c in vertex.co) for vertex in mesh.vertices]
for vertex in mesh.vertices:
    x,y,z = vertex.co
    if y < -0.09 and 1.60 < z < 1.70:
        nose = math.exp(-(x/0.021)**4-((z-1.630)/0.023)**4)
        vertex.co.x *= 1-0.035*nose
        cheeks = math.exp(-((abs(x)-0.046)/0.023)**4-((z-1.632)/0.027)**4)
        vertex.co.y -= 0.0015*cheeks
mesh.update()
original_for_repaired = {tuple(round(float(c),6) for c in vertex.co): original_positions[vertex.index] for vertex in mesh.vertices}
normals = {tuple(round(float(c),6) for c in v.co): tuple(v.normal) for v in mesh.vertices}
for obj in old_objects:
    bpy.data.objects.remove(obj, do_unlink=True)
skin = bpy.data.materials['Founder_Skin']
skin.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.68
body = subset(continuous, 'BodyMesh', lambda p: p.z < 1.46 and not (
    (1.075 < p.z < 1.425 and abs(p.x) < 0.155) or
    (0.20 < p.z < 1.0 and abs(p.x) < 0.285) or p.z < 0.115), rig, skin)
head = subset(continuous, 'HeadMesh', lambda p: p.z >= 1.46, rig, skin)
for obj in [body, head]:
    obj.data.normals_split_custom_set_from_vertices([
        normals[tuple(round(float(c),6) for c in v.co)] for v in obj.data.vertices])
    uv = obj.data.uv_layers.new(name='FounderSurfaceUV')
    for loop in obj.data.loops:
        x,y,z = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (0.5+math.atan2(x,-y)/math.tau, (z-1.45)/0.35) if z > 1.48 else (0.02,0.02)
bpy.data.objects.remove(continuous, do_unlink=True)

# One bounded, portable 1K skin-color map. No normal maps or expensive skin shader.
size = 1024
u,v = np.meshgrid((np.arange(size)+0.5)/size, (np.arange(size)+0.5)/size)
angle=(u-0.5)*math.tau
x,z = np.sin(angle)*0.17, 1.45+v*0.35
front=np.exp(-(angle/0.95)**8)
base = np.zeros((size,size,4), dtype=np.float32)
base[:,:,:3] = [0.39,0.215,0.145]
base[:,:,3] = 1
lip = front*np.exp(-(x/0.027)**6-((z-1.587)/0.006)**4)
blush = front*np.exp(-((np.abs(x)-0.044)/0.025)**4-((z-1.631)/0.022)**4)
stubble = front*np.exp(-(x/0.060)**4-((z-1.563)/0.022)**4)*0.018
base[:,:,:3] += lip[:,:,None]*np.array([0.006,-0.012,-0.006])
base[:,:,:3] += blush[:,:,None]*np.array([0.012,-0.004,-0.002])
base[:,:,:3] -= stubble[:,:,None]
# Deterministic restrained micro variation, baked rather than procedural at runtime.
noise = np.random.default_rng(19).normal(0,0.0015,(size,size))
base[:,:,:3] += noise[:,:,None]
image = bpy.data.images.new('FounderSkin_A1_1K', width=size, height=size, alpha=False)
image.colorspace_settings.name = 'Non-Color'
# Store linear values as non-color texture to match constant-color body samples.
image.pixels.foreach_set(base.ravel())
image.filepath_raw = str(source/'FounderSkin_A1_1K.png')
image.file_format = 'PNG'
image.save()
image.pack()
nodes = skin.node_tree.nodes
texture = nodes.new('ShaderNodeTexImage')
texture.image = image
skin.node_tree.links.new(texture.outputs['Color'], nodes.get('Principled BSDF').inputs['Base Color'])

# Solid irises were missing pupils. Add pupil geometry inside existing iris modules.
hair = bpy.data.objects['HairMesh']
hairmat = bpy.data.materials['Founder_Hair']
for vertex in hair.data.vertices:
    vertex.co -= vertex.normal * 0.002
active(hair)
smooth = hair.modifiers.new('ScalpSilhouette', 'SUBSURF')
smooth.levels = 1
bpy.ops.object.modifier_apply(modifier=smooth.name)
eye_positions = {side: rig.data.bones['Eye_'+side].head_local.copy() for side in ['L','R']}
white = bpy.data.materials['Founder_EyeWhite']
white.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.46
white.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (0.65,0.62,0.57,1)
for side,pos in eye_positions.items():
    iris = bpy.data.objects['IrisMesh_'+side]
    pupil_mesh = bpy.data.meshes.new('Pupil_'+side)
    center = pos+Vector((0,-0.0136,0))
    ring = [center+Vector((0.00255*math.cos(i*math.tau/32),0,0.00255*math.sin(i*math.tau/32))) for i in range(32)]
    pupil_mesh.from_pydata(ring,[],[list(range(32))])
    pupil = bpy.data.objects.new('Pupil_'+side,pupil_mesh)
    bpy.context.collection.objects.link(pupil)
    pupil.data.materials.append(hairmat)
    pupil.vertex_groups.new(name='Eye_'+side).add(list(range(32)),1,'REPLACE')
    active(iris)
    pupil.select_set(True)
    bpy.ops.object.join()
    # Narrow brow ribbons follow the existing forehead surface via ray projection.
    verts, polys = [], []
    sign = 1 if side == 'L' else -1
    for index in range(13):
        t = index/12
        bx = sign*(0.015+0.044*t)
        bz = pos.z+0.023+0.004*math.sin(t*math.pi)-0.004*t
        width = 0.0035*(0.45+0.55*math.sin(math.pi*t)**0.5)
        for dz in [-width/2,width/2]:
            hit, point, normal, face = head.ray_cast(Vector((bx,-0.4,bz+dz)), Vector((0,1,0)))
            assert hit, 'Brow projection missed the source forehead'
            verts.append(point+normal*0.0008)
        if index:
            a = 2*index
            face=(a-2,a-1,a+1,a)
            polys.append(tuple(reversed(face)) if side=='L' else face)
    browmesh = bpy.data.meshes.new('Brow_'+side)
    browmesh.from_pydata(verts,[],polys)
    brow = bpy.data.objects.new('Brow_'+side,browmesh)
    bpy.context.collection.objects.link(brow)
    brow.data.materials.append(hairmat)
    brow.vertex_groups.new(name='Head').add(list(range(len(verts))),1,'REPLACE')
    active(head)
    brow.select_set(True)
    bpy.ops.object.join()

# Refit procedural deltas to actual eye pivots and the neutral lip line.
head.shape_key_add(name='Basis', from_mix=False)
shape_names = ['Blink_L','Blink_R','JawOpen','Smile','Frown','BrowRaise','BrowLower','MouthNarrow','MouthWide']
for name in shape_names:
    target = head.shape_key_add(name=name, from_mix=False)
    target.value = 0
    for point in target.data:
        x,y,z = point.co
        if y > -0.08:
            continue
        if name.startswith('Blink'):
            pos = eye_positions[name[-1]]
            strength = math.exp(-((x-pos.x)/0.017)**6-((z-pos.z)/0.014)**4)
            point.co.z += (pos.z-z)*strength*0.98
            point.co.y -= 0.0015*strength
        elif name == 'JawOpen':
            original_key = original_for_repaired.get(tuple(round(float(c),6) for c in point.co))
            point.co += jaw_delta.get(original_key,Vector())
        elif name in ['Smile','Frown']:
            strength = math.exp(-((abs(x)-0.024)/0.011)**4-((z-1.593)/0.012)**4)
            point.co.z += (0.006 if name=='Smile' else -0.004)*strength
        elif name.startswith('Brow'):
            strength = math.exp(-((abs(x)-0.034)/0.025)**4-((z-1.692)/0.016)**4)
            point.co.z += (0.006 if name=='BrowRaise' else -0.004)*strength
        else:
            strength = math.exp(-(x/0.040)**4-((z-1.593)/0.012)**4)
            point.co.x += x*strength*(0.13 if name=='MouthWide' else -0.13)

# Level the shirt's lower edge without altering rig or expanding the wardrobe.
top = bpy.data.objects['TopMesh']
for vertex in top.data.vertices:
    if 0.98 < vertex.co.z < 1.06 and abs(vertex.co.x)<0.24:
        vertex.co.z = 1.025+(vertex.co.z-1.025)*0.2
top.data.update()

def reset():
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

def aim(name, direction):
    """Align in armature space; avoids assuming mirrored bones share local axes."""
    bone = rig.pose.bones[name]
    bpy.context.view_layer.update()
    current = bone.matrix.copy()
    delta = (bone.tail-bone.head).rotation_difference(Vector(direction))
    rotation = delta.to_matrix().to_4x4()
    rotation.translation = bone.head-rotation.to_3x3()@bone.head
    bone.matrix = rotation@current
    bpy.context.view_layer.update()

def seated():
    reset()
    # Ground the sole, bend at anatomical knee, keep pelvis above the seat cushion.
    for side,sign in [('L',1),('R',-1)]:
        aim('Thigh_'+side, (sign*0.015,-0.42,-0.01))
        aim('Calf_'+side, (sign*0.005,0.035,-0.44))
        foot = rig.pose.bones['Foot_'+side]
        matrix = rig.data.bones['Foot_'+side].matrix_local.copy()
        matrix.translation = foot.head
        foot.matrix = matrix
        bpy.context.view_layer.update()
    for side,sign in [('L',1),('R',-1)]:
        aim('UpperArm_'+side, (sign*0.035,-0.035,-0.27))
        aim('LowerArm_'+side, (sign*0.018,-0.26,0.025))
        aim('Hand_'+side, (0,-0.055,-0.008))
    head_bone=rig.pose.bones['Head']
    pivot=head_bone.head.copy()
    head_bone.matrix=Matrix.Translation(pivot)@Matrix.Rotation(math.atan2(-1.08,0.86),4,'Z')@Matrix.Translation(-pivot)@head_bone.matrix
    bpy.context.view_layer.update()

    # Pass A.2 canonical-POV fit. Preserve the accepted A.1 limbs and torso,
    # move the pelvis within the production chair footprint, solve both legs
    # back to their exact ankle contacts, and cap the residual spine correction.
    baseline_ankles={side:rig.pose.bones['Foot_'+side].head.copy() for side in ['L','R']}
    baseline_knees={side:rig.pose.bones['Calf_'+side].head.copy() for side in ['L','R']}
    baseline_feet={side:rig.pose.bones['Foot_'+side].matrix.copy() for side in ['L','R']}
    locals={bone.name:(bone.parent.matrix.inverted()@bone.matrix if bone.parent else bone.matrix.copy())
            for bone in rig.pose.bones}
    locals['Hips'].translation += Vector((0.066231,0.105467,-0.040000))
    corrections={
        'Spine01':(-2.0,-4.5,0.0),
        'Spine02':(0.0,11.0,0.0),
        'Chest':(-3.0,0.0,0.0),
        'Neck':(12.0,12.0,12.0),
    }
    for name,(x,y,z) in corrections.items():
        for angle,axis in zip((x,y,z),'XYZ'):
            locals[name] = locals[name] @ Matrix.Rotation(math.radians(angle),4,axis)
    for bone in rig.pose.bones:
        local=locals[bone.name]
        bone.matrix=bone.parent.matrix@local if bone.parent else local
    bpy.context.view_layer.update()
    for side in ['L','R']:
        thigh=rig.pose.bones['Thigh_'+side]
        calf=rig.pose.bones['Calf_'+side]
        hip=thigh.head.copy()
        ankle=baseline_ankles[side]
        line=ankle-hip
        distance=line.length
        direction=line.normalized()
        along=(thigh.length**2-calf.length**2+distance**2)/(2*distance)
        height=math.sqrt(max(0,thigh.length**2-along**2))
        bend=baseline_knees[side]-hip
        perpendicular=bend-direction*bend.dot(direction)
        knee=hip+direction*along+perpendicular.normalized()*height
        aim('Thigh_'+side,knee-hip)
        aim('Calf_'+side,ankle-rig.pose.bones['Calf_'+side].head)
        foot=rig.pose.bones['Foot_'+side]
        matrix=baseline_feet[side].copy()
        matrix.translation=foot.head
        foot.matrix=matrix
        bpy.context.view_layer.update()

def locals_for_pose():
    return {bone.name: [list(row) for row in
            (bone.parent.matrix.inverted()@bone.matrix if bone.parent else bone.matrix)]
            for bone in rig.pose.bones}

seated()
depsgraph = bpy.context.evaluated_depsgraph_get()
shoe = bpy.data.objects['ShoeMesh'].evaluated_get(depsgraph)
sole = min(v.co.z for v in shoe.data.vertices)
offset = -sole
landmarks = {b: list(rig.pose.bones[b].head+Vector((0,0,offset))) for b in
             ['Hips','Thigh_L','Thigh_R','Calf_L','Calf_R','Foot_L','Foot_R','Eye_L','Eye_R','Hand_L','Hand_R']}
pose_data = {'schema':1,'coordinate_space':'Blender Z-up, -Y forward; USD local joint transforms',
             'root_vertical_offset':offset,'seated':locals_for_pose(),'landmarks':landmarks,
             'sole_floor_error':sole+offset}
(folder/'Intermediate/founder_validation_pose.json').write_text(json.dumps(pose_data,indent=2))
(evidence/'seated_source_measurements.json').write_text(json.dumps(pose_data,indent=2))
reset()

# Preserve canonical names, hierarchy, anchors, and rest transforms verbatim.
contract = json.loads((evidence/'Before/blender_contract.json').read_text())
meshes = [o for o in bpy.data.objects if o.type=='MESH']
contract['meshes'] = {o.name:{'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in meshes}
contract['textures'] = [{'name':'FounderSkin_A1_1K.png','width':1024,'height':1024,'channels':3}]
contract['repair'] = 'Pass A.1: welded jaw; collar partition; source normals; facial refinements; anatomically aimed seated fixture'
contract['seated_fit'] = 'Pass A.2: canonical POV fit; grounded two-bone leg solve; bounded spine correction'
(folder/'Intermediate/blender_contract.json').write_text(json.dumps(contract,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(source/'founder_candidate_a.blend'))
bpy.ops.object.select_all(action='SELECT')
authoring_world = bpy.context.scene.world
bpy.context.scene.world = None
bpy.ops.wm.usd_export(filepath=str(folder/'Intermediate/founder_candidate_a.usdc'),
    selected_objects_only=True,export_armatures=True,only_deform_bones=False,
    export_shapekeys=True,export_animation=False,export_materials=True,
    generate_preview_surface=True,generate_materialx_network=False,
    convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',
    root_prim_path='',meters_per_unit=1.0,convert_scene_units='METERS')
bpy.context.scene.world = authoring_world

if '--render' in sys.argv:
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.render.resolution_x,scene.render.resolution_y = 900,1100
    bpy.ops.object.camera_add(location=(0.4,-1.5,1.69))
    camera = bpy.context.object
    camera.data.type='ORTHO'
    camera.data.ortho_scale=0.54
    scene.camera=camera
    for name,pos,energy,size in [('Key',(2,-3,4),450,4),('Fill',(-3,-2,2),250,3),('Rim',(1,2,3),550,2)]:
        bpy.ops.object.light_add(type='AREA',location=pos)
        light=bpy.context.object
        light.name=name
        light.data.energy=energy
        light.data.size=size
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.world.color=(0.16,0.16,0.16)
    views = [('Face',0,0),('HeadLeft',0,0.75),('HeadRight',0,-0.75),('HeadDown',0.15,0),('HeadUp',-0.15,0),('Blink',0,0),('JawOpen',0,0),('Standing',0,0),('Seated',0,0)]
    for name,tilt,turn in views:
        reset()
        for key in head.data.shape_keys.key_blocks:
            key.value=0
        if name=='Blink':
            head.data.shape_keys.key_blocks['Blink_L'].value=1
            head.data.shape_keys.key_blocks['Blink_R'].value=1
        if name=='JawOpen':
            head.data.shape_keys.key_blocks['JawOpen'].value=1
        if name=='Seated':
            seated()
        elif tilt or turn:
            bone=rig.pose.bones['Head']
            bone.matrix_basis=Matrix.Rotation(turn,4,'Y')@Matrix.Rotation(tilt,4,'X')
        close=name not in ['Standing','Seated']
        camera.location=(0.4,-1.5,1.69) if close else (2.5,-4.8,2.25)
        camera.rotation_euler=(Vector((0,-0.035,1.63) if close else (0,0,1.0))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=0.54 if close else 2.25
        bpy.context.view_layer.update()
        scene.render.filepath=str(evidence/(name+'.png'))
        bpy.ops.render.render(write_still=True)
print('FOUNDER_A1_REPAIR',json.dumps({'meshes':contract['meshes'],'seated_landmarks':landmarks,'vertical_offset':offset}))
