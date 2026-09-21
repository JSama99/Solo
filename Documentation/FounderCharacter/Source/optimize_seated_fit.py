"""Find a bounded spine-only correction for the authored seated pose.

This authoring helper performs deterministic coordinate descent, caps every added
joint rotation, and writes a candidate pose for independent measurement. It does
not modify the source blend or runtime asset.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


FOLDER = Path(__file__).resolve().parents[1]
CAMERA = Vector((0.34, 1.18, -0.22))
SEAT_ROOT = Vector((0.34, 0.0, -0.22))
JOINTS = ("Spine01", "Spine02", "Chest", "Neck")
AXES = ("X", "Y", "Z")
LIMIT = math.radians(12)
# Correct the eye's measured horizontal displacement and lower the pelvis only
# 40 mm, retaining 42 mm of hip-joint clearance above the cushion. The legs are
# solved back to their original ankle contacts below.
HIP_TRANSLATION = Vector((0.066231, 0.105467, -0.040000))


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blend", type=Path, default=FOLDER / "Source/founder_candidate_a.blend")
    parser.add_argument("--pose", type=Path, default=FOLDER / "Intermediate/founder_validation_pose.json")
    parser.add_argument("--output", type=Path, default=FOLDER / "Intermediate/founder_validation_pose_a2_candidate.json")
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(values)


def world_point(point, offset):
    local = Vector((point.x, point.z + offset, -point.y))
    return SEAT_ROOT + Vector((-local.x, local.y, -local.z))


args = arguments()
bpy.ops.wm.open_mainfile(filepath=str(args.blend))
pose = json.loads(args.pose.read_text())
rig = bpy.data.objects["Armature"]
parameters = {(joint, axis): 0.0 for joint in JOINTS for axis in AXES}


def apply_raw(values, translate_hips):
    for bone in rig.pose.bones:
        local = Matrix(pose["seated"][bone.name])
        if bone.name == "Hips" and translate_hips:
            local.translation += HIP_TRANSLATION
        if bone.name in JOINTS:
            for axis in AXES:
                local = local @ Matrix.Rotation(values[(bone.name, axis)], 4, axis)
        bone.matrix = bone.parent.matrix @ local if bone.parent else local
    bpy.context.view_layer.update()


apply_raw(parameters, False)
baseline_ankles = {side: rig.pose.bones["Foot_" + side].head.copy() for side in ("L", "R")}
baseline_knees = {side: rig.pose.bones["Calf_" + side].head.copy() for side in ("L", "R")}
baseline_foot_matrices = {side: rig.pose.bones["Foot_" + side].matrix.copy() for side in ("L", "R")}


def aim(name, direction):
    bone = rig.pose.bones[name]
    current = bone.matrix.copy()
    delta = (bone.tail - bone.head).rotation_difference(Vector(direction))
    rotation = delta.to_matrix().to_4x4()
    rotation.translation = bone.head - rotation.to_3x3() @ bone.head
    bone.matrix = rotation @ current
    bpy.context.view_layer.update()


def solve_leg(side):
    thigh = rig.pose.bones["Thigh_" + side]
    calf = rig.pose.bones["Calf_" + side]
    hip = thigh.head.copy()
    ankle = baseline_ankles[side]
    line = ankle - hip
    distance = line.length
    direction = line.normalized()
    upper, lower = thigh.length, calf.length
    along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    height = math.sqrt(max(0.0, upper * upper - along * along))
    bend = baseline_knees[side] - hip
    perpendicular = bend - direction * bend.dot(direction)
    if perpendicular.length < 1e-6:
        perpendicular = Vector((0, -1, 0))
    knee = hip + direction * along + perpendicular.normalized() * height
    aim("Thigh_" + side, knee - hip)
    aim("Calf_" + side, ankle - rig.pose.bones["Calf_" + side].head)
    foot = rig.pose.bones["Foot_" + side]
    matrix = baseline_foot_matrices[side].copy()
    matrix.translation = foot.head
    foot.matrix = matrix
    bpy.context.view_layer.update()


def apply(values):
    apply_raw(values, True)
    solve_leg("L")
    solve_leg("R")


def point(name):
    return world_point(rig.pose.bones[name].head, pose["root_vertical_offset"])


def score(values):
    apply(values)
    eye = (point("Eye_L") + point("Eye_R")) / 2
    eye_delta = eye - CAMERA
    eye_cost = eye_delta.length_squared
    hands = (point("Hand_L"), point("Hand_R"))
    hand_cost = sum(max(0.0, abs(hand.y - 0.7575) - 0.05) ** 2 for hand in hands) * 2.0
    rotation_cost = sum(value * value for value in values.values()) * 0.00012
    return eye_cost + hand_cost + rotation_cost


best = score(parameters)
for step_degrees in (10, 5, 2, 1, 0.5, 0.25):
    step = math.radians(step_degrees)
    changed = True
    while changed:
        changed = False
        for key in parameters:
            origin = parameters[key]
            for candidate in (max(-LIMIT, origin - step), min(LIMIT, origin + step)):
                if candidate == origin:
                    continue
                parameters[key] = candidate
                candidate_score = score(parameters)
                if candidate_score + 1e-12 < best:
                    best = candidate_score
                    origin = candidate
                    changed = True
                else:
                    parameters[key] = origin

apply(parameters)
candidate_pose = dict(pose)
candidate_pose["schema"] = 2
candidate_pose["pass_a2_spine_adjustments_degrees"] = {
    joint: {axis.lower(): round(math.degrees(parameters[(joint, axis)]), 4) for axis in AXES}
    for joint in JOINTS
}
candidate_pose["pass_a2_hips_translation_blender_m"] = list(HIP_TRANSLATION)
candidate_pose["seated"] = {
    bone.name: [list(row) for row in (bone.parent.matrix.inverted() @ bone.matrix if bone.parent else bone.matrix)]
    for bone in rig.pose.bones
}
candidate_pose["landmarks"] = {
    name: list(rig.pose.bones[name].head + Vector((0, 0, pose["root_vertical_offset"])))
    for name in ("Hips", "Thigh_L", "Thigh_R", "Calf_L", "Calf_R", "Foot_L", "Foot_R", "Eye_L", "Eye_R", "Hand_L", "Hand_R")
}
args.output.write_text(json.dumps(candidate_pose, indent=2) + "\n")
eye = (point("Eye_L") + point("Eye_R")) / 2
print("FOUNDER_SEATED_OPTIMIZATION " + json.dumps({
    "score": best,
    "adjustments_degrees": candidate_pose["pass_a2_spine_adjustments_degrees"],
    "eye_world_m": list(eye),
    "eye_camera_delta_m": list(eye - CAMERA),
    "left_hand_world_m": list(point("Hand_L")),
    "right_hand_world_m": list(point("Hand_R")),
}, sort_keys=True))
