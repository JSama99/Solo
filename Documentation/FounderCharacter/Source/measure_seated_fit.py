"""Measure the authored Founder seated fixture in canonical Garage coordinates.

Run with Blender in background mode. The script is read-only and writes a compact
JSON record suitable for Pass A.2 evidence and contract tests.
"""
import argparse
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


FOLDER = Path(__file__).resolve().parents[1]
DEFAULT_BLEND = FOLDER / "Source/founder_candidate_a.blend"
DEFAULT_POSE = FOLDER / "Intermediate/founder_validation_pose.json"
DEFAULT_OUTPUT = FOLDER / "Evidence/A2/seated_fit_measurement.json"

CAMERA = Vector((0.34, 1.18, -0.22))
SEAT_ROOT = Vector((0.34, 0.0, -0.22))
CHAIR_SEAT_Y = 0.45
CHAIR_BACK_Z = -0.0276
DESK_UNDERSIDE_Y = 0.72
DESKTOP_Y = 0.7575


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blend", type=Path, default=DEFAULT_BLEND)
    parser.add_argument("--pose", type=Path, default=DEFAULT_POSE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    values = []
    if "--" in __import__("sys").argv:
        values = __import__("sys").argv[__import__("sys").argv.index("--") + 1 :]
    return parser.parse_args(values)


def world_point(point, root_vertical_offset):
    # Blender Z-up/-Y-forward -> RealityKit Y-up, then the seated placement's pi yaw.
    local = Vector((point.x, point.z + root_vertical_offset, -point.y))
    return SEAT_ROOT + Vector((-local.x, local.y, -local.z))


def vector_angle_degrees(a, b):
    return math.degrees(a.normalized().angle(b.normalized()))


args = arguments()
args.blend = args.blend.resolve()
args.pose = args.pose.resolve()
args.output = args.output.resolve()
bpy.ops.wm.open_mainfile(filepath=str(args.blend))
pose = json.loads(args.pose.read_text())
rig = bpy.data.objects["Armature"]
for bone in rig.pose.bones:
    local = Matrix(pose["seated"][bone.name])
    bone.matrix = bone.parent.matrix @ local if bone.parent else local
    bpy.context.view_layer.update()

offset = pose["root_vertical_offset"]


def bone_point(name):
    return world_point(rig.pose.bones[name].head, offset)


landmarks = {
    "pelvis": bone_point("Hips"),
    "spine_01": bone_point("Spine01"),
    "spine_02": bone_point("Spine02"),
    "chest": bone_point("Chest"),
    "neck": bone_point("Neck"),
    "head": bone_point("Head"),
    "left_knee": bone_point("Calf_L"),
    "right_knee": bone_point("Calf_R"),
    "left_ankle": bone_point("Foot_L"),
    "right_ankle": bone_point("Foot_R"),
    "left_hand": bone_point("Hand_L"),
    "right_hand": bone_point("Hand_R"),
    "left_eye": bone_point("Eye_L"),
    "right_eye": bone_point("Eye_R"),
}
landmarks["eye_midpoint"] = (landmarks["left_eye"] + landmarks["right_eye"]) / 2

graph = bpy.context.evaluated_depsgraph_get()
shoe = bpy.data.objects["ShoeMesh"].evaluated_get(graph)
foot_contacts = {}
for side, positive_x in (("left", True), ("right", False)):
    points = [world_point(vertex.co, offset) for vertex in shoe.data.vertices if (vertex.co.x > 0) == positive_x]
    floor_y = min(point.y for point in points)
    candidates = [point for point in points if point.y <= floor_y + 0.001]
    foot_contacts[side] = sum(candidates, Vector()) / len(candidates)
    foot_contacts[side].y = floor_y

eye = landmarks["eye_midpoint"]
pelvis = landmarks["pelvis"]
hip_to_knee = ((landmarks["left_knee"] - bone_point("Thigh_L")) +
               (landmarks["right_knee"] - bone_point("Thigh_R"))) / 2
spine = bone_point("Chest") - pelvis
neck = bone_point("Head") - bone_point("Neck")
head_forward = eye - bone_point("Head")


def rounded(point):
    return [round(value, 6) for value in point]


measurement = {
    "schema": 1,
    "fixture": {
        "blend": str(args.blend.relative_to(FOLDER)),
        "pose": str(args.pose.relative_to(FOLDER)),
        "garage_state": "production v8 canonical anchors",
        "camera_state": "founderPOV",
        "animation_state": "authored seated validation pose at t=0",
        "lighting": "not applicable to skeletal measurement",
        "door_state": "closed",
        "reduce_motion": False,
    },
    "references_world_m": {
        "camera": rounded(CAMERA),
        "chair_seat": rounded(Vector((SEAT_ROOT.x, CHAIR_SEAT_Y, SEAT_ROOT.z))),
        "chair_back": rounded(Vector((SEAT_ROOT.x, CHAIR_SEAT_Y, CHAIR_BACK_Z))),
        "desk_underside": [None, DESK_UNDERSIDE_Y, None],
        "desktop": [None, DESKTOP_Y, None],
        "floor_y": 0.0,
    },
    "landmarks_world_m": {name: rounded(point) for name, point in landmarks.items()},
    "foot_contacts_world_m": {name: rounded(point) for name, point in foot_contacts.items()},
    "errors_m": {
        "eye_camera_vertical": round(eye.y - CAMERA.y, 6),
        "eye_camera_horizontal": round(Vector((eye.x - CAMERA.x, eye.z - CAMERA.z)).length, 6),
        "pelvis_above_chair_seat": round(pelvis.y - CHAIR_SEAT_Y, 6),
        "pelvis_horizontal_from_chair_seat": round(Vector((pelvis.x - SEAT_ROOT.x, pelvis.z - SEAT_ROOT.z)).length, 6),
        "left_knee_clearance_below_desk": round(DESK_UNDERSIDE_Y - landmarks["left_knee"].y, 6),
        "right_knee_clearance_below_desk": round(DESK_UNDERSIDE_Y - landmarks["right_knee"].y, 6),
        "left_foot_floor": round(foot_contacts["left"].y, 6),
        "right_foot_floor": round(foot_contacts["right"].y, 6),
        "left_hand_above_desktop": round(landmarks["left_hand"].y - DESKTOP_Y, 6),
        "right_hand_above_desktop": round(landmarks["right_hand"].y - DESKTOP_Y, 6),
    },
    "angles_degrees": {
        "hip_flexion_from_vertical": round(vector_angle_degrees(hip_to_knee, Vector((0, -1, 0))), 3),
        "spine_from_vertical": round(vector_angle_degrees(spine, Vector((0, 1, 0))), 3),
        "neck_from_vertical": round(vector_angle_degrees(neck, Vector((0, 1, 0))), 3),
        "head_pitch_proxy": round(math.degrees(math.atan2(head_forward.y, max(1e-6, Vector((head_forward.x, 0, head_forward.z)).length))), 3),
        "head_yaw_proxy": round(math.degrees(math.atan2(head_forward.x, -head_forward.z)), 3),
    },
    "spine_chain": {
        name: {
            "parent": rig.pose.bones[name].parent.name if rig.pose.bones[name].parent else None,
            "length_m": round(rig.pose.bones[name].length, 6),
            "head_world_m": rounded(bone_point(name)),
            "tail_world_m": rounded(world_point(rig.pose.bones[name].tail, offset)),
        }
        for name in ("Hips", "Spine01", "Spine02", "Chest", "Neck", "Head")
    },
    "standing_height_m": 1.792,
    "standing_pose_modified": False,
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(measurement, indent=2) + "\n")
print("FOUNDER_SEATED_FIT " + json.dumps(measurement, sort_keys=True))
