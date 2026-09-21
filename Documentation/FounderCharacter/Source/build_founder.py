"""Reproducible Blender authority for SOLO Founder Character candidate A.

Run Blender --background --factory-startup --python build_founder.py --
    --mpfb /path/to/mpfb2 [--render]
MPFB checkout must be commit 437dd513888a92399d1d3200d2e80859fae55abc.
No addon/preferences are installed or saved. Generated assets are CC0-derived.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
REPO = HERE.parents[2]
PIN = '437dd513888a92399d1d3200d2e80859fae55abc'


def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    return mat


def empty(name, parent, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    obj.empty_display_size = 0.06
    return obj


def subset(source, name, predicate, parent, mat, offset=0):
    faces = [p for p in source.data.polygons if predicate(p.center)]
    indices = sorted({i for p in faces for i in p.vertices})
    lookup = {old: new for new, old in enumerate(indices)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([source.data.vertices[i].co + source.data.vertices[i].normal * offset
                     for i in indices], [], [[lookup[i] for i in p.vertices] for p in faces])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(mat)
    groups = {g.index: obj.vertex_groups.new(name=g.name) for g in source.vertex_groups
              if g.name in parent.data.bones}
    for old, new in lookup.items():
        weights = [(groups[g.group], g.weight) for g in source.data.vertices[old].groups
                   if g.group in groups and g.weight > 0.00001]
        weights.sort(key=lambda item: -item[1])
        weights = weights[:4]
        total = sum(w for _, w in weights)
        if not total:
            raise ValueError(f'Unweighted vertex {name}:{old}')
        for group, weight in weights:
            group.add([new], weight / total, 'REPLACE')
    modifier = obj.modifiers.new('CanonicalSkin', 'ARMATURE')
    modifier.object = parent
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def sphere(name, center, scale, mat, rig, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.parent = rig
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('CanonicalSkin', 'ARMATURE').object = rig
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def rounded_box(name, center, size, bevel, mat, rig, bone):
    bpy.ops.mesh.primitive_cube_add(location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(size) / 2
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    modifier = obj.modifiers.new('SoftConstruction', 'BEVEL')
    modifier.width = bevel
    modifier.segments = 4
    active(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.parent = rig
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('CanonicalSkin', 'ARMATURE').object = rig
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def soften_boundary(obj, iterations=6):
    """Relax patch boundaries without modifying canonical body topology/weights."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    boundary = [v for v in bm.verts if v.is_boundary]
    for _ in range(iterations):
        positions = {v: sum((e.other_vert(v).co for e in v.link_edges if e.is_boundary), Vector()) /
                     max(1, sum(e.is_boundary for e in v.link_edges)) for v in boundary}
        for v, pos in positions.items():
            v.co = v.co.lerp(pos, 0.45)
    bm.to_mesh(obj.data)
    bm.free()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--mpfb', required=True)
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    upstream = Path(args.mpfb)
    assert subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip() == PIN
    sys.path.insert(0, str(upstream / 'src'))
    # MPFB is an extension, but this reproducible batch job runs from a checkout.
    bpy.utils.extension_path_user = lambda *a, **k: '/tmp/solo-founder-mpfb-user'
    import addon_utils
    addon_utils.enable('mpfb', default_set=True)
    from mpfb.services.humanservice import HumanService
    from mpfb.services.targetservice import TargetService
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    macro = TargetService.get_default_macro_info_dict()
    macro.update(gender=0.8, age=0.35, muscle=0.52, weight=0.48)
    human = HumanService.create_human(macro_detail_dict=macro)
    rig = HumanService.add_builtin_rig(human, 'game_engine')
    # Freeze authored phenotype before topology separation, preserving fitted rig.
    active(human)
    bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    # Fit eyes to the authored phenotype's joint helpers, before removing helpers.
    helper_indices = {'joint-l-eye': set(), 'joint-r-eye': set()}
    group = ''
    for line in (upstream/'src/mpfb/data/3dobjs/base.obj').read_text().splitlines():
        if line.startswith('g '):
            group = line[2:].strip()
        elif line.startswith('f ') and group in helper_indices:
            helper_indices[group].update(int(v.split('/')[0])-1 for v in line.split()[1:])
    eye_centers = {side: sum((human.data.vertices[i].co for i in helper_indices[f'joint-{side.lower()}-eye']), Vector()) /
                   len(helper_indices[f'joint-{side.lower()}-eye']) for side in ['L', 'R']}
    bpy.ops.object.modifier_apply(modifier='Hide helpers')
    human.data.update()
    minimum = min(v.co.z for v in human.data.vertices)
    maximum = max(v.co.z for v in human.data.vertices)
    factor = 1.79 / (maximum - minimum)
    for v in human.data.vertices:
        v.co = Vector((v.co.x * factor, v.co.y * factor, (v.co.z - minimum) * factor))
    human.data.update()
    active(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    rename = {'pelvis': 'Hips', 'spine_01': 'Spine01', 'spine_02': 'Spine02',
              'spine_03': 'Chest', 'neck_01': 'Neck', 'head': 'Head'}
    for side in ['l', 'r']:
        for src, dst in [('clavicle', 'Clavicle'), ('upperarm', 'UpperArm'), ('lowerarm', 'LowerArm'),
                         ('hand', 'Hand'), ('thigh', 'Thigh'), ('calf', 'Calf'), ('foot', 'Foot'), ('ball', 'Toe')]:
            rename[f'{src}_{side}'] = f'{dst}_{side.upper()}'
        for finger in ['thumb', 'index', 'middle', 'ring', 'pinky']:
            for joint in range(1, 4):
                rename[f'{finger}_{joint:02}_{side}'] = f'{finger.title()}{joint:02}_{side.upper()}'
    for bone in rig.data.edit_bones:
        bone.head = Vector((bone.head.x * factor, bone.head.y * factor, (bone.head.z - minimum) * factor))
        bone.tail = Vector((bone.tail.x * factor, bone.tail.y * factor, (bone.tail.z - minimum) * factor))
        bone.name = rename.get(bone.name, bone.name)
    bpy.ops.object.mode_set(mode='OBJECT')
    for old, new in rename.items():
        if old in human.vertex_groups:
            human.vertex_groups[old].name = new
    root = empty('FounderRoot', None)
    rig.name = rig.data.name = 'Armature'
    rig.parent = root
    rig.show_in_front = True
    skin = material('Founder_Skin', (0.36, 0.19, 0.115), 0.57)
    shirt = material('Founder_Crewneck', (0.025, 0.085, 0.095), 0.8)
    pants = material('Founder_Chinos', (0.11, 0.13, 0.16), 0.84)
    shoes = material('Founder_Sneakers', (0.65, 0.64, 0.60), 0.73)
    hairmat = material('Founder_Hair', (0.026, 0.017, 0.012), 0.78)
    white = material('Founder_EyeWhite', (0.8, 0.77, 0.71), 0.3)
    iris = material('Founder_Iris', (0.07, 0.042, 0.022), 0.28)
    split = 1.565
    body = subset(human, 'BodyMesh', lambda p: p.z < split, rig, skin)
    head = subset(human, 'HeadMesh', lambda p: p.z >= split, rig, skin)
    top = subset(human, 'TopMesh', lambda p: 1.01 < p.z < 1.51 and
                 (abs(p.x) < 0.20 or p.z > 1.29), rig, shirt, 0.008)
    bottom = subset(human, 'BottomMesh', lambda p: 0.135 < p.z < 1.035 and abs(p.x) < 0.32,
                    rig, pants, 0.010)
    shoe_parts = []
    for side, sign in [('L', 1), ('R', -1)]:
        upper = rounded_box(f'ShoeUpper_{side}', (sign*0.195, -0.112, 0.069),
                            (0.145, 0.315, 0.115), 0.048, shoes, rig, f'Foot_{side}')
        sole = rounded_box(f'ShoeSole_{side}', (sign*0.195, -0.112, 0.018),
                           (0.154, 0.326, 0.035), 0.014, white, rig, f'Foot_{side}')
        shoe_parts += [upper, sole]
    active(shoe_parts[0])
    for part in shoe_parts:
        part.select_set(True)
    bpy.ops.object.join()
    shoe_parts[0].name = 'ShoeMesh'
    # Geometry cap follows the scalp, with a clean curved frontal hairline.
    hair = subset(human, 'HairMesh', lambda p: p.z > 1.705 + max(0, -p.y - 0.055) * 0.48,
                  rig, hairmat, 0.006)
    for patch in [top, bottom, hair]:
        soften_boundary(patch)
    bpy.data.objects.remove(human, do_unlink=True)
    # Separate eye meshes and independent eye bones are stable future gaze targets.
    eye_positions = {}
    for side, point in eye_centers.items():
        eye_positions[side] = (point.x * factor, point.y * factor, (point.z-minimum) * factor)
    active(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    for side, pos in eye_positions.items():
        bone = rig.data.edit_bones.new(f'Eye_{side}')
        bone.head = pos
        bone.tail = Vector(pos) + Vector((0, -0.025, 0))
        bone.parent = rig.data.edit_bones['Head']
    bpy.ops.object.mode_set(mode='OBJECT')
    for side, pos in eye_positions.items():
        sphere(f'EyeMesh_{side}', pos, (0.0125, 0.0125, 0.0125), white, rig, f'Eye_{side}')
        sphere(f'IrisMesh_{side}', (pos[0], pos[1]-0.0115, pos[2]), (0.0057, 0.0018, 0.0057), iris, rig, f'Eye_{side}')
    anchors = {'HairSlot': ('Head', (0, 0, 1.78)), 'TopSlot': ('Chest', (0, 0, 1.40)),
               'BottomSlot': ('Hips', (0, 0, 0.97)), 'ShoeSlot': ('Root', (0, 0, 0)),
               'AccessorySlot': ('Hand_R', (-0.45, -0.18, 1.10))}
    for name, (bone, pos) in anchors.items():
        slot = empty(name, root, pos)
        slot['follow_joint'] = bone
        slot['space'] = 'FounderRoot bind space; runtime resolves follow_joint'
    # Real delta targets; future expression controller intentionally absent.
    head.shape_key_add(name='Basis', from_mix=False)
    shape_names = ['Blink_L', 'Blink_R', 'JawOpen', 'Smile', 'Frown', 'BrowRaise', 'BrowLower', 'MouthNarrow', 'MouthWide']
    for name in shape_names:
        key = head.shape_key_add(name=name, from_mix=False)
        key.value = 0
        for point in key.data:
            x, y, z = point.co
            if y > -0.065:
                continue
            if name.startswith('Blink'):
                cx = eye_positions[name[-1]][0]
                influence = math.exp(-((x-cx)/0.019)**4 - ((z-1.683)/0.021)**4)
                point.co.z += (1.683-z) * influence * 0.92
            elif name == 'JawOpen':
                influence = math.exp(-(x/0.055)**4 - ((z-1.60)/0.047)**4)
                point.co.z -= 0.022 * influence
                point.co.y -= 0.006 * influence
            elif name in ['Smile', 'Frown']:
                influence = math.exp(-((abs(x)-0.021)/0.013)**4 - ((z-1.625)/0.02)**4)
                point.co.z += (0.009 if name == 'Smile' else -0.007) * influence
            elif name.startswith('Brow'):
                influence = math.exp(-((abs(x)-0.031)/0.023)**4 - ((z-1.709)/0.015)**4)
                point.co.z += (0.008 if name == 'BrowRaise' else -0.006) * influence
            else:
                influence = math.exp(-(x/0.042)**4 - ((z-1.625)/0.02)**4)
                point.co.x += x * influence * (0.16 if name == 'MouthWide' else -0.16)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.scene.cycles.samples = 24
    bpy.context.scene.render.resolution_x = 900
    bpy.context.scene.render.resolution_y = 1100
    bpy.context.scene.render.resolution_percentage = 100
    # Validation actions only. They are not gameplay clips and export is bind-only.
    poses = {
        'A_Neutral': {},
        'B_ArmsRaised': {'UpperArm_L': (0, 0, 0.85), 'UpperArm_R': (0, 0, -0.85)},
        'C_Seated': {'Thigh_L': (-1.45, 0, 0), 'Thigh_R': (-1.45, 0, 0),
                     'Calf_L': (1.5, 0, 0), 'Calf_R': (1.5, 0, 0)},
        'D_Stride': {'Thigh_L': (-0.45, 0, 0), 'Thigh_R': (0.38, 0, 0), 'Calf_R': (0.55, 0, 0)},
        'E_HeadTurn': {'Head': (0, 1.3, 0)},
        'F_Elbow': {'LowerArm_L': (1.3, 0, 0), 'LowerArm_R': (1.3, 0, 0)},
        'G_FingerCurl': {f'{f}{j:02}_{s}': (0.85, 0, 0) for f in ['Thumb','Index','Middle','Ring','Pinky'] for j in range(1,4) for s in ['L','R']}
    }
    for name, rotations in poses.items():
        rig.animation_data_clear()
        for bone in rig.pose.bones:
            bone.rotation_mode = 'XYZ'
            bone.rotation_euler = rotations.get(bone.name, (0, 0, 0))
            bone.keyframe_insert('rotation_euler', frame=1)
        rig.animation_data.action.name = f'VALIDATION_ONLY_{name}'
        rig.animation_data.action.use_fake_user = True
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    report = {'upstream_commit': PIN, 'height_m': 1.79, 'bind_pose': 'A-pose with relaxed bent elbows',
              'bones': [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                         'head': list(b.head_local), 'tail': list(b.tail_local)} for b in rig.data.bones],
              'meshes': {o.name: {'vertices': len(o.data.vertices), 'triangles': sum(len(p.vertices)-2 for p in o.data.polygons)} for o in meshes},
              'materials': [m.name for m in bpy.data.materials if m.users], 'textures': [],
              'blendshapes': shape_names, 'slots': anchors,
              'export': 'Blender Z-up, -Y forward -> USD Y-up, +Z forward; positive unit scale',
              'poses': poses, 'status': 'candidate; requires deformation and RealityKit acceptance'}
    (OUT/'Intermediate'/'blender_contract.json').write_text(json.dumps(report, indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'founder_candidate_a.blend'))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.usd_export(filepath=str(OUT/'Intermediate'/'founder_candidate_a.usdc'),
        selected_objects_only=True, export_armatures=True, only_deform_bones=False,
        export_shapekeys=True, export_animation=False, export_materials=True,
        generate_preview_surface=True, generate_materialx_network=False,
        convert_orientation=True, export_global_forward_selection='NEGATIVE_Z', export_global_up_selection='Y',
        root_prim_path='', meters_per_unit=1.0, convert_scene_units='METERS')
    if args.render:
        bpy.ops.object.camera_add(location=(2.5, -4.8, 2.25))
        camera = bpy.context.object
        camera.rotation_euler = (Vector((0, 0, 1.0))-camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.type = 'ORTHO'
        camera.data.ortho_scale = 2.25
        bpy.context.scene.camera = camera
        for name, pos, energy, size in [('Key',(2,-3,4),450,4),('Fill',(-3,-2,2),250,3),('Rim',(1,2,3),550,2)]:
            bpy.ops.object.light_add(type='AREA', location=pos)
            lamp = bpy.context.object
            lamp.name=name
            lamp.data.energy=energy
            lamp.data.shape='DISK'
            lamp.data.size=size
            lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
        bpy.context.scene.world.color=(0.16,0.16,0.16)
        for name, rotations in poses.items():
            for bone in rig.pose.bones:
                bone.rotation_euler = rotations.get(bone.name, (0,0,0))
            bpy.context.view_layer.update()
            bpy.context.scene.render.filepath=str(OUT/'Evidence'/f'{name}.png')
            bpy.ops.render.render(write_still=True)
    print('SOLO_FOUNDER_BUILD_COMPLETE', json.dumps(report['meshes']))


if __name__ == '__main__':
    main()
