# S3 Shot 4 cross-asset surface/depth audit

Date: 2026-09-24. The accepted Founder location is approximately `(-874.8, 8.03, 1037.9)` and the production camera is at Z `1035.6`. Atlantis and Garage V8 are in one RealityView. The Garage local origin maps to Atlantis `(-875, 8, 1030)`. Bounds below are metres in Atlantis world coordinates. The Garage bounds were read from `founder_garage_v8.usdz` with USD world transforms; the Founder bounds and individual triangle normals are recorded in [the full Blender audit](S3_SHOT4_GEOMETRY_AUDIT.json).

| Rendered mesh | Package / material | World bounds `[min]→[max]` | Top Y | Role |
| --- | --- | --- | ---: | --- |
| `Founder_GarageDriveway_00` | `founder_district.usdz` / `Founder_paving` | `[-876.75,7.85,1032.75]→[-873.25,8.03,1040.90]` | 8.03 | Visible; traversal walkable |
| `Founder_GarageApron_00` | Founder / `Founder_paving` | `[-876.75,7.85,1040.90]→[-873.25,8.16,1043.60]` | 8.03–8.16 | Visible; traversal walkable |
| `Founder_GarageSeam_00` | Founder / `Founder_paving` | `[-895,7.85,1039.10]→[-855,8.03,1041.10]` | 8.03 | Visible; traversal walkable |
| `Founder_ToStartup_Walk_00` | Founder / `Founder_paving` | `[-875,7.85,1038.60]→[-825,8.03,1041.60]` | 8.03 | Visible; traversal walkable |
| `Founder_GarageReservation` | Founder / `Founder_lawn` | `[-915,7.96,1000]→[-835,8.00,1056]` | 8.00 | Visible planning reference; no separate route authority |
| `Founder_NeighborhoodLawn` | Founder / `Founder_lawn` | `[-1099,7.97,636]→[-601,8.01,1064]` | 8.01 | Visible ground; visual-only in runtime traversal |
| `Founder_Shore` | Founder / coastal limestone | `[-1220,-12,540]→[-440,8.00,1140]` | 8.00 | Visible ground; runtime traversal has its original fallback triangles |
| `Driveway_mesh_001` | `founder_garage_v8.usdz` / `MAT_Concrete_Sealed` | `[-876.75,7.85,1032.90]→[-873.25,8.00,1039.38]` | 8.00 | Garage exterior visual; not Atlantis traversal authority |
| `LotGround_mesh` | Garage V8 / `MAT_Grass_Lawn` | `[-915,7.86,1000]→[-835,7.98,1039.40]` | 7.98 | Garage exterior visual |
| `Sidewalk_mesh` | Garage V8 / `MAT_Concrete_Sealed` | `[-889,7.88,1039.40]→[-861,8.00,1040.80]` | 8.00 | Garage exterior visual |
| `DrivewayApron_CurbCut_mesh_001` | Garage V8 / `MAT_Concrete_Sealed` | `[-877.28,7.76,1040.82]→[-872.72,8.00,1041.35]` | 8.00 | Garage exterior visual |
| `Street_mesh` | Garage V8 / `MAT_Asphalt_Road` | `[-895,7.80,1041.05]→[-855,7.90,1046.95]` | 7.90 | Garage exterior visual |

The Garage driveway and Atlantis driveway top triangles project over the same `22.68 m²` rectangle, separated vertically by only `0.03 m`. Garage Sidewalk and Atlantis seam project over `39.2 m²`, also separated by `0.03 m`. Their horizontal top normals are `+Y`; the tops do not geometrically intersect, and no duplicate faces were found within the audited meshes. The Garage meshes are six-face box solids, not collision-only meshes. The exact depth conflict arises when two independently loaded visual packages stay visible in the same camera. Neither Garage imported visual mesh nor this repair owns Atlantis's traversal triangles; Garage movement uses its separate camera/spatial controller.

The original Founder source also contains exact coplanar projected overlap among `Founder_GarageSeam_00`, `Founder_ToStartup_Walk_00`, and `Founder_GarageDriveway_00` at Y `8.03` (40.0, 6.30, and 4.03 m² pairwise). `Founder_GarageReservation` and `Founder_Shore` share Y `8.00`. Those were audited and temporarily cut during diagnosis, but **all Founder Blender sources, generated packages, and traversal data were restored byte for byte** before final verification. The successful final repair scopes only the Garage exterior ground visual family to the Garage camera. The remaining authored district overlap did not reproduce the visible Shot 4 glitch after the Garage ground handoff.
