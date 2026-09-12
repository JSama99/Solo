#!/usr/bin/env python3
"""Build the bounded Phase 12 streaming/traversal derivative.

Phase 0-11 assets are inputs. This script owns the repaired Tech/Unicorn bridge,
the far Spire proxy, and runtime metadata consumed by the debug-only Atlantis path.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
APP = ROOT / "App/RealityKit/Atlantis"
APP_MANIFEST = APP / "atlantis_manifest.json"
EXPORT_MANIFEST = ROOT / "Assets/Atlantis/Phase10/RuntimeSpike/export_manifest.json"
MASTERPLAN = ROOT / "Assets/Atlantis/Phase0/masterplan_manifest.json"

ADJACENCY = {
    "FounderDistrict": ["StartupRow"],
    "StartupRow": ["FounderDistrict", "CommerceDistrict", "VentureDistrict", "TechCore"],
    "CommerceDistrict": ["StartupRow", "VentureDistrict", "TechCore", "MediaDistrict"],
    "VentureDistrict": ["StartupRow", "CommerceDistrict", "TechCore"],
    "MediaDistrict": ["CommerceDistrict"],
    "TechCore": ["StartupRow", "CommerceDistrict", "VentureDistrict", "UnicornHeights"],
    "UnicornHeights": ["TechCore"],
}

# RealityKit coordinates. The long switchback preserves the endpoints and rise,
# while keeping every segment below the 8% Phase 12 walking threshold.
BRIDGE = [
    [360.0, 15.0, -470.0], [600.0, 29.2, -530.0],
    [360.0, 43.4, -590.0], [600.0, 57.6, -650.0],
    [360.0, 71.8, -710.0], [600.0, 86.0, -760.0],
]


def ribbon(points, width, district, source, surface_class="walkable"):
    edges = []
    for index, point in enumerate(points):
        before = points[max(0, index - 1)]
        after = points[min(len(points) - 1, index + 1)]
        dx, dz = after[0] - before[0], after[2] - before[2]
        length = math.hypot(dx, dz)
        nx, nz = -dz / length * width / 2, dx / length * width / 2
        edges.append(([point[0] + nx, point[1], point[2] + nz], [point[0] - nx, point[1], point[2] - nz]))
    triangles = []
    for index, ((al, ar), (bl, br)) in enumerate(zip(edges, edges[1:])):
        triangles += [
            {"district": district, "source": f"{source}_{index:02d}", "surfaceClass": surface_class, "points": [al, br, ar]},
            {"district": district, "source": f"{source}_{index:02d}", "surfaceClass": surface_class, "points": [al, bl, br]},
        ]
    return triangles


def classify(source, district):
    if district == "WorldContext":
        return "visualOnly"
    if source in {"Founder_Shore", "Unicorn_Raised_Headland"} or "Streetlight" in source:
        return "visualOnly"
    if source in {"Bridge_TechCore_00", "Unicorn_BridgeWalk_00"}:
        return "visualOnly"
    tokens = ("Road", "Boulevard", "Bridge", "Walk", "Sidewalk", "Cross", "Link", "Paving", "Driveway", "Apron", "Seam")
    return "walkable" if any(token in source for token in tokens) else "visualOnly"


def usda_mesh(name, triangles, color):
    points, indices = [], []
    for triangle in triangles:
        for point in triangle["points"]:
            indices.append(len(points)); points.append(tuple(point))
    point_text = ",\n            ".join(f"({x:.4f}, {y:.4f}, {z:.4f})" for x, y, z in points)
    index_text = ", ".join(map(str, indices))
    counts = ", ".join("3" for _ in triangles)
    return f'''#usda 1.0
(
    defaultPrim = "{name}"
    metersPerUnit = 1
    upAxis = "Y"
)
def Xform "{name}" {{
    def Mesh "Surface" {{
        uniform token subdivisionScheme = "none"
        bool doubleSided = true
        point3f[] points = [
            {point_text}
        ]
        int[] faceVertexCounts = [{counts}]
        int[] faceVertexIndices = [{index_text}]
        color3f[] primvars:displayColor = [({color[0]}, {color[1]}, {color[2]})] (interpolation = "constant")
    }}
}}
'''


def spire_usda():
    cx, base_y, cz, height, sides = 50.0, 14.0, -420.0, 280.0, 8
    rings = [(0, 18), (190, 11), (250, 5), (280, 0.7)]
    points = []
    for y, radius in rings:
        points.extend((cx + radius * math.cos(i * 2 * math.pi / sides), base_y + y,
                       cz + radius * math.sin(i * 2 * math.pi / sides)) for i in range(sides))
    counts, indices = [], []
    for ring in range(len(rings) - 1):
        for i in range(sides):
            counts.append(4)
            indices += [ring*sides+i, ring*sides+(i+1)%sides, (ring+1)*sides+(i+1)%sides, (ring+1)*sides+i]
    points_text = ",\n            ".join(f"({x:.4f}, {y:.4f}, {z:.4f})" for x,y,z in points)
    return f'''#usda 1.0
(
    defaultPrim = "SpireFarProxy"
    metersPerUnit = 1
    upAxis = "Y"
)
def Xform "SpireFarProxy" {{
    def Xform "TheSpireFarAnchor" {{
        double3 xformOp:translate = (50, 14, -420)
        uniform token[] xformOpOrder = ["xformOp:translate"]
    }}
    def Mesh "SpireSilhouette" {{
        uniform token subdivisionScheme = "none"
        bool doubleSided = true
        point3f[] points = [
            {points_text}
        ]
        int[] faceVertexCounts = [{', '.join(map(str, counts))}]
        int[] faceVertexIndices = [{', '.join(map(str, indices))}]
        color3f[] primvars:displayColor = [(0.23, 0.48, 0.64)] (interpolation = "constant")
    }}
}}
'''


def package(stem, source):
    usda = OUT / f"{stem}.usda"
    usdc = APP / f"{stem}.usdc"
    usdz = APP / f"{stem}.usdz"
    usda.write_text(source)
    subprocess.run(["/usr/bin/usdcat", str(usda), "-o", str(usdc)], check=True)
    # usdzip preserves the source timestamp. Normalize it so repeated exports
    # produce byte-identical support packages and stable manifest checksums.
    os.utime(usdc, (946684800, 946684800))
    subprocess.run(["/usr/bin/usdzip", str(usdz), str(usdc)], check=True)
    return {"package": stem, "bytes": usdz.stat().st_size, "sha256": hashlib.sha256(usdz.read_bytes()).hexdigest()}


def route_length(points):
    return sum(math.dist(a, b) for a, b in zip(points, points[1:]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(APP_MANIFEST.read_text())
    master = json.loads(MASTERPLAN.read_text())

    manifest["traversal"]["triangles"] = [
        triangle for triangle in manifest["traversal"]["triangles"]
        if not triangle["source"].startswith(("Tech_Ring_Phase12", "TechUnicornBridge_Repaired", "PrimaryRouteSupport_Phase12", "InteractionSupport_Phase13"))
    ]

    for triangle in manifest["traversal"]["triangles"]:
        triangle["surfaceClass"] = classify(triangle["source"], triangle["district"])

    roads = {road["id"]: road for road in master["roads"]}
    tech_ring = [[p[0], p[2], -p[1]] for p in roads["Tech_Ring"]["points"]]
    tech_triangles = ribbon(tech_ring, roads["Tech_Ring"]["width_m"], "TechCore", "Tech_Ring_Phase12")
    bridge_triangles = ribbon(BRIDGE, 13.0, "TechUnicornBridge", "TechUnicornBridge_Repaired")
    manifest["traversal"]["triangles"] += tech_triangles + bridge_triangles
    progression = (
        next(r["points"] for r in manifest["traversal"]["routes"] if r["name"] == "Founder_ToStartup_Walk")
        + [[-610,16,490],[-460,15,400],[-190,15,270],[0,15,-100],[50,15,-300],[360,15,-470]]
        + BRIDGE[1:]
        + [[710,86,-850],[820,86,-960],[970,85,-850]]
    )
    manifest["traversal"]["routes"] = [r for r in manifest["traversal"]["routes"] if r["name"] != "FounderGarage_To_PlayerUnicornHQ"]
    manifest["traversal"]["routes"].append({"name":"FounderGarage_To_PlayerUnicornHQ", "points": progression})
    manifest["traversal"]["triangles"] += ribbon(
        progression, 3.0, "PrimaryRouteSupport", "PrimaryRouteSupport_Phase12", "collisionOnly"
    )
    for name,point in (("Pallas",[220,15,-268]),("Northwind",[-100,15,-486])):
        x,y,z=point;size=4
        manifest["traversal"]["triangles"] += [
            {"district":"TechCore","source":f"InteractionSupport_Phase13_{name}","surfaceClass":"collisionOnly","points":[[x-size,y,z-size],[x+size,y,z+size],[x+size,y,z-size]]},
            {"district":"TechCore","source":f"InteractionSupport_Phase13_{name}","surfaceClass":"collisionOnly","points":[[x-size,y,z-size],[x-size,y,z+size],[x+size,y,z+size]]},
        ]
    manifest["traversal"]["surfaces"] = [
        {"district": district, "source": source, "classification": classification}
        for district, source, classification in sorted({
            (t["district"], t["source"], t["surfaceClass"]) for t in manifest["traversal"]["triangles"]
        })
    ]

    bridge_asset = package("tech_unicorn_bridge_repaired", usda_mesh("TechUnicornBridgeRepaired", bridge_triangles, (0.18,0.32,0.38)))
    spire_asset = package("spire_far_proxy", spire_usda())
    bridge_length = route_length(BRIDGE)
    grades = [abs(b[1]-a[1]) / math.hypot(b[0]-a[0], b[2]-a[2]) for a,b in zip(BRIDGE,BRIDGE[1:])]
    support = {
        "TechUnicornBridge": {**bridge_asset, "kind":"traversalSupport"},
        "SpireFarProxy": {**spire_asset, "kind":"farLandmark"},
    }
    manifest["supportPackages"] = support
    manifest["streaming"] = {
        "policy": "previousCurrentNext",
        "adjacency": ADJACENCY,
        "prefetchSafetyFactor": 1.5,
        "walkingSpeedMetersPerSecond": 1.4,
        "hardwareLoadSeconds": {"StartupRow":5.372,"CommerceDistrict":7.541,"TechCore":3.703,"UnicornHeights":6.789},
        "transitionRoutes": [
            {"from":"FounderDistrict","to":"StartupRow","boundary":[-610,16,490]},
            {"from":"StartupRow","to":"CommerceDistrict","boundary":[-190,15,270]},
            {"from":"CommerceDistrict","to":"TechCore","boundary":[0,15,-100]},
            {"from":"TechCore","to":"UnicornHeights","boundary":[360,15,-470]},
        ],
        "semanticAnchors": {
            "FounderDistrict":["FounderGarageSlot"],
            "CommerceDistrict":["FlashpointHQ","RivalHQ_Slot_05"], "VentureDistrict":["VentureHall"],
            "MediaDistrict":["TechComTower","SignalTV"], "TechCore":["TheSpire","PallasAIHQ","NorthwindLabsHQ","RivalHQ_Slot_03","RivalHQ_Slot_04"],
            "UnicornHeights":["PlayerUnicornHQSlot"]
        },
    }
    APP_MANIFEST.write_text(json.dumps(manifest, separators=(",", ":")))
    export = json.loads(EXPORT_MANIFEST.read_text())
    export.update({"traversal":manifest["traversal"], "streaming":manifest["streaming"], "supportPackages":support})
    EXPORT_MANIFEST.write_text(json.dumps(export, indent=2) + "\n")
    audit = {
        "sourceOfTruth":"Assets/Atlantis/Phase0/masterplan_manifest.json",
        "adjacency":ADJACENCY, "residencyPolicy":"previous + current + next",
        "surfaceCounts":{kind:sum(1 for x in manifest["traversal"]["surfaces"] if x["classification"]==kind) for kind in ("walkable","collisionOnly","visualOnly")},
        "bridge":{"points":BRIDGE,"riseMeters":71.0,"routeLengthMeters":bridge_length,"maximumGradePercent":max(grades)*100,"classification":"comfortable","widthMeters":13.0,"package":bridge_asset},
        "spire":{"worldPosition":[50,14,-420],"heightMeters":280,"sides":8,"package":spire_asset},
        "continuousRoute":{"name":"FounderGarage_To_PlayerUnicornHQ","pointCount":len(progression),"lengthMeters":route_length(progression)},
    }
    (OUT / "streaming_manifest.json").write_text(json.dumps(audit, indent=2) + "\n")
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
