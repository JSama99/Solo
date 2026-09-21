"""Render deterministic Founder facial and pose acceptance fixtures."""
import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector


FOLDER = Path(__file__).resolve().parents[1]


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blend", type=Path, default=FOLDER / "Source/founder_candidate_a.blend")
    parser.add_argument("--pose", type=Path, default=FOLDER / "Intermediate/founder_validation_pose.json")
    parser.add_argument("--output", type=Path, default=FOLDER / "Evidence/A2/AcceptanceFixture")
    parser.add_argument("--seated-only", action="store_true")
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(values)


def point_camera(camera, location, target):
    camera.location = location
    camera.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()


args = arguments()
args.blend = args.blend.resolve()
args.pose = args.pose.resolve()
args.output = args.output.resolve()
bpy.ops.wm.open_mainfile(filepath=str(args.blend))
pose = json.loads(args.pose.read_text())
rig = bpy.data.objects["Armature"]
head = bpy.data.objects["HeadMesh"]
rest_locals = {
    bone.name: (bone.parent.matrix.inverted() @ bone.matrix if bone.parent else bone.matrix.copy())
    for bone in rig.pose.bones
}

for bone in rig.pose.bones:
    local = Matrix(pose["seated"][bone.name])
    bone.matrix = bone.parent.matrix @ local if bone.parent else local
bpy.context.view_layer.update()
seated_locals = {
    bone.name: (bone.parent.matrix.inverted() @ bone.matrix if bone.parent else bone.matrix.copy())
    for bone in rig.pose.bones
}


def set_rig(locals_by_name):
    for pose_bone in rig.pose.bones:
        local = locals_by_name[pose_bone.name]
        pose_bone.matrix = pose_bone.parent.matrix @ local if pose_bone.parent else local
    bpy.context.view_layer.update()

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world.color = (0.055, 0.06, 0.075)

bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.lens = 62
scene.camera = camera

for name, location, energy, size in (
    ("A2_Key", (2.2, -3.0, 3.6), 700, 3.0),
    ("A2_Fill", (-2.8, -2.0, 2.2), 350, 3.0),
    ("A2_Rim", (1.0, 2.5, 3.2), 600, 2.0),
):
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 1.2)) - light.location).to_track_quat("-Z", "Y").to_euler()

views = {
    "SeatedFront": ((0.0, -3.2, 1.25), (0.0, 0.0, 0.9)),
    "SeatedThreeQuarter": ((2.25, -2.8, 1.45), (0.0, 0.0, 0.95)),
    "SeatedProfile": ((3.2, 0.0, 1.35), (0.0, 0.0, 0.95)),
}
if not args.seated_only:
    views.update({
        "PortraitFront": ((0.0, -1.45, 1.64), (0.0, 0.0, 1.62)),
        "PortraitThreeQuarterLeft": ((0.72, -1.25, 1.68), (0.0, 0.0, 1.62)),
        "PortraitThreeQuarterRight": ((-0.72, -1.25, 1.68), (0.0, 0.0, 1.62)),
        "PortraitProfile": ((1.4, 0.0, 1.66), (0.0, 0.0, 1.62)),
    })

args.output.mkdir(parents=True, exist_ok=True)
for key in head.data.shape_keys.key_blocks:
    key.value = 0
for name, (location, target) in views.items():
    set_rig(seated_locals if name.startswith("Seated") else rest_locals)
    point_camera(camera, location, target)
    scene.render.filepath = str(args.output / f"{name}.png")
    bpy.ops.render.render(write_still=True)

if not args.seated_only:
    set_rig(rest_locals)
    for expression, targets in (("Blink", ("Blink_L", "Blink_R")), ("JawOpen", ("JawOpen",))):
        for key in head.data.shape_keys.key_blocks:
            key.value = 1 if key.name in targets else 0
        point_camera(camera, (0.0, -1.45, 1.64), (0.0, 0.0, 1.62))
        scene.render.filepath = str(args.output / f"{expression}.png")
        bpy.ops.render.render(write_still=True)

    for key in head.data.shape_keys.key_blocks:
        key.value = 0
    set_rig(rest_locals)
    point_camera(camera, (2.5, -4.8, 2.25), (0.0, 0.0, 1.0))
    scene.render.filepath = str(args.output / "Standing.png")
    bpy.ops.render.render(write_still=True)

metadata = {
    "schema": 1,
    "device_profile": "Blender deterministic authoring fixture",
    "runtime": bpy.app.version_string,
    "resolution": [800, 800],
    "engine": scene.render.engine,
    "display_scale": 1,
    "simulation_seed": None,
    "garage_state": "authoring fixture; runtime Garage captures required separately",
    "camera_state": "fixed transforms in render_acceptance_fixture.py",
    "animation_state": "authored seated pose at t=0",
    "lighting": "A2_Key/A2_Fill/A2_Rim fixed area lights",
    "time_of_day": "fixed neutral world",
    "door_state": "not present",
    "reduce_motion": False,
    "pose": str(args.pose.relative_to(FOLDER)),
}
(args.output / "fixture.json").write_text(json.dumps(metadata, indent=2) + "\n")
print("FOUNDER_ACCEPTANCE_FIXTURE " + json.dumps(metadata, sort_keys=True))
