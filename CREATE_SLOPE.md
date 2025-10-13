You are generating a snowboarding slope inspired by *Lonely Mountains: Snow Riders* for a Godot 4.x project.

## 0) Project context (from Notion)
- Engine: Godot 4.x (Vulkan)
- Target platform: macOS (later Windows/Linux)
- Visual tone: Low-poly, minimal, bright & friendly colors
- Core vibes: Casual but challenging, strong sense of speed/flow, time-attack friendly
- VFX: GPU particles for snow spray, landing bursts; speed-based intensity; motion blur & dynamic FOV
- Camera: Third-person default, optional first-person; smooth transitions
- Controls (keyboard primary): Left/Right to steer, W/Up accelerate, S/Down brake, Shift crouch (speed up), Space jump, Tab toggle 1P/3P
- Node structure (Godot):
  Main (Node3D)
    ├─ Player (CharacterBody3D)
    │   ├─ BoardMesh (MeshInstance3D)
    │   ├─ SnowParticles (GPUParticles3D)
    │   ├─ Camera3D_ThirdPerson
    │   └─ Camera3D_FirstPerson
    ├─ Environment
    │   ├─ Terrain (StaticBody3D)
    │   ├─ SnowfallParticles (GPUParticles3D)
    │   └─ WorldEnvironment
    └─ UI (SpeedUI, ScoreUI)

## 1) Goal
Generate a procedural mountain slope layout + data suitable for Godot 4.x.
Focus on natural flow, jump timing, corner rhythm, and casual-challenging balance.
The output must include:
- Height field or mesh data for the mountain
- A rideable path spline (Curve3D) that carves a realistic continuous line (no artificial ramps)
- Obstacle placements (rocks, trees) with safe/risk route logic
- Checkpoints with spacing aligned to time-attack pacing
- Metadata (length, vertical drop, slope angles, difficulty)

## 2) Style Reference (Lonely Mountains-like)
- Minimalistic low-poly mountain environment
- Natural continuous slope with gentle S-curves, cliffs, occasional drops
- Emphasize “flow riding”: readable line, rhythm, and risk/reward branches
- Lighting vibe: morning snow ambience

## 3) Technical Parameters (propose defaults if unspecified)
- Terrain length: ~1500 m (Z forward/downhill)
- Vertical drop: ~350 m
- Average slope angle target: 20–35°
- Terrain width: ~400 m
- Path width (rideable corridor): 4–6 m
- Mesh resolution (vertex spacing): ~2.0 m
- Checkpoints: every ~300 m (adjust last segment to finish line)
- Keep center line relatively clean of obstacles; push obstacles to shoulders

## 4) Gameplay Flow & Sections
- Start zone: short flat intro to build speed and teach steering
- Mid: branching segments (safe vs risky), alternating hairpins and rollers
- Final: steeper descent with 2 meaningful jumps and a committing line choice
- Place checkpoints at ~300 m intervals; ensure sightlines before bigger features

## 5) Output Format (STRICT)
Return a single JSON object with these top-level keys:

{
  "terrain": {
    "format": "heightmap",
    "origin": [0,0,0],               // world-space origin
    "cell_size": 2.0,                // meters per grid cell
    "width_m": 400,
    "length_m": 1500,
    "heights": [[...],[...], ...]    // 2D array rows along +X, columns along -Z
  },
  "path_spline": {
    "type": "Curve3D",
    "points": [[x,y,z], ...],        // center line in world coords, dense enough for smooth Curve3D
    "path_width_m": 5.0
  },
  "obstacles": [
    {"type":"rock","pos":[x,y,z],"scale":s},
    {"type":"tree","pos":[x,y,z],"scale":s},
    ...
  ],
  "checkpoints": [
    {"pos":[x,y,z], "radius": 2.5},
    ...
  ],
  "meta": {
    "slope_length_m": 1500,
    "vertical_drop_m": 350,
    "avg_angle_deg": 28,
    "difficulty": "medium",
    "theme": "frozen_morning"
  ],
  "notes": [
    "Explain risk/safe routing logic and how it shapes flow.",
    "List two biggest jumps with approach speed & landing grade.",
    "Mention any sections designed to work well with FOV expansion & motion blur."
  ]
}

### Requirements for the JSON:
- All coordinates are consistent (Y up). Path points should hug carved terrain.
- Carve the terrain near the path (lower/flatten slightly) to suggest a natural line, not glued-on ramps.
- Keep obstacles > (path_width_m * 1.5) from spline center, except intentional risk apex objects (few).
- Ensure checkpoints sit slightly above local ground (y + 1.0~2.0).

## 6) Godot 4.x Integration Snippet (RETURN IN ADDITION to the JSON)
After the JSON, ALSO return a GDScript snippet that:
- Builds a MeshInstance3D “TerrainMesh” from the heightmap (ArrayMesh surface from a triangle grid).
- Adds a StaticBody3D with a ConcavePolygonShape3D generated from the same mesh for collisions.
- Creates a Path3D “RidePath” and populates it with a Curve3D using the provided points.
- Instantiates obstacles as MeshInstance3D children (use IcosahedronMesh for rocks, simple Cylinder+Cone for trees).
- Places checkpoints as TorusMesh (or thin Cylinder) at given positions.
- Adds TODO comments for connecting GPU particles, camera rigs, and speed/FOV effects per project.

Return EXACTLY in this order:
1) The JSON block (only the JSON, no code fences)
2) A single GDScript block named `apply_slope_data(data: Dictionary) -> Node3D` that consumes the JSON and returns a Node3D with children set up as described.

## 7) Quality Bar / Acceptance
- Natural, readable line with consistent downhill grade (no dead-flat plateaus nor uphill traps).
- At least 2 optional risk branches with tighter turns or gap jumps.
- Sightlines before big features; staging space before jumps.
- JSON validates as Godot-friendly numeric arrays; GDScript compiles without edits (placeholders allowed for meshes).
- Keep it minimalistic & low-poly; no textures are required.

## 8) Implementation Notes & Bug Fixes

### Critical Z-Offset Solution
**Problem**: Player was falling through terrain at start position because terrain Z range was [0, -1500] but player started at Z=0, leaving no ground in front.

**Solution**: Added `z_offset = 50.0` to extend terrain range to [+50, -1450]:
```gdscript
// In _generate_heightmap() and _build_terrain_mesh():
var z_offset = 50.0  # meters of terrain before start point
var world_z = origin[2] + z_offset - z * cell_size
```

This ensures terrain exists both in front of and behind the start point. Player spawns at approximately Z=-30 with 50m of terrain ahead.

### Current Implementation Architecture

**Files**:
- `scripts/terrain/terrain_generator.gd`: Core heightmap generation, mesh building, collision
- `scenes/environment/procedural_slope.gd/.tscn`: JSON loader and scene builder
- `resources/slope_data.json`: Terrain configuration data

**Key Technical Details**:
1. **Heightmap Generation** (`_generate_heightmap()`):
   - Nested loops create width_cells × length_cells grid
   - Base height: `350.0 * (1.0 - float(z) / length_cells)` for linear slope
   - Noise layers: Multiple sin/cos waves for natural variation (3 frequencies)
   - Path carving: Reduces height near path points for smooth riding line
   - Z-offset: Critical 50m extension for terrain coverage

2. **Mesh Building** (`_build_terrain_mesh()`):
   - ArrayMesh with vertices, normals, UVs, and triangle indices
   - ConcavePolygonShape3D collision from mesh faces
   - Collision layers: StaticBody3D layer=2, Player mask=2

3. **Auto-Positioning** (`procedural_slope.gd`):
   - Reads start point from JSON path_spline.points[0]
   - Positions player at `start_point + Y+5.0 + Z-10.0`
   - Ensures player always starts above terrain

4. **Debug Tools**:
   - Red sphere markers at terrain corners for boundary visualization
   - Console logging for heightmap dimensions and collision face count

## 9) Difficulty System Design (Planned)

### Goal
Generate unique terrain for each playthrough with three difficulty levels: **Easy**, **Medium**, **Hard**.

### Difficulty Parameters

| Aspect | Easy | Medium | Hard |
|--------|------|--------|------|
| **Terrain Roughness** | 5-8m noise amplitude | 10-15m noise amplitude | 20-30m noise amplitude |
| **Slope Steepness** | 200m drop, ~8° avg | 350m drop, ~13° avg | 500m drop, ~18° avg |
| **Path Width** | 8m rideable zone | 5m rideable zone | 3m rideable zone |
| **Path Curvature** | Gentle S-curves, 10-15° max deviation | Moderate turns, 20-30° max deviation | Sharp hairpins, 40-50° max deviation |
| **Obstacle Count** | 5-8 obstacles | 15-20 obstacles | 30-40 obstacles |
| **Obstacle Distance** | 15-30m from path | 8-20m from path | 3-15m from path (some very close!) |

### Implementation Plan

**1. Create Difficulty Configuration** (`scripts/terrain/difficulty_config.gd`):
```gdscript
class_name DifficultyConfig

static func get_config(difficulty: String) -> Dictionary:
    match difficulty:
        "easy": return {
            "noise_amplitude": [5.0, 3.0, 1.5],
            "vertical_drop": 200.0,
            "path_width": 8.0,
            "turn_sharpness": 0.3,
            "obstacle_count_range": [5, 8],
            "obstacle_min_distance": 15.0
        }
        "medium": return { ... }
        "hard": return { ... }
```

**2. Modify TerrainGenerator**:
- Add `difficulty` parameter to `apply_slope_data()`
- Implement `_generate_procedural_path(difficulty_config, seed)`:
  - Use Perlin-like noise for natural curves
  - Scale turn sharpness based on difficulty
  - Ensure smooth transitions and no uphill sections
- Implement `_generate_procedural_obstacles(path_points, difficulty_config, seed)`:
  - RandomNumberGenerator with optional seed
  - Place obstacles based on distance-from-path rules
  - Vary rock/tree ratios and scales

**3. Update ProceduralSlope Scene**:
- Add `@export var difficulty: String = "medium"`
- Add `@export var random_seed: int = -1` (use time if -1)
- Make `slope_data_path` optional (procedural by default)
- Allow JSON override for designer-crafted slopes

**4. Procedural Noise Algorithm**:
```gdscript
# Difficulty-scaled terrain noise
var noise_layers = difficulty_config.noise_amplitude
var noise_val = 0.0
noise_val += sin(world_x * 0.1) * cos(world_z * 0.05) * noise_layers[0]
noise_val += sin(world_x * 0.05 + world_z * 0.03) * noise_layers[1]
noise_val += sin(world_x * 0.2) * sin(world_z * 0.15) * noise_layers[2]

# Hard mode: add sharp bumps/dips
if difficulty == "hard":
    noise_val += sin(world_x * 0.3) * sin(world_z * 0.25) * 10.0
```

**5. Procedural Path Curvature**:
```gdscript
var rng = RandomNumberGenerator.new()
rng.seed = seed if seed != -1 else Time.get_ticks_msec()

var path_points = []
var current_x = 0.0
var current_z = 0.0

for i in range(num_segments):
    current_z -= segment_length

    # Apply difficulty-based lateral drift
    var drift = rng.randf_range(-1.0, 1.0) * turn_sharpness * 20.0
    current_x = clamp(current_x + drift, -width_m/2 + 20, width_m/2 - 20)

    var height = calculate_height_at(current_x, current_z)
    path_points.append([current_x, height, current_z])
```

### Benefits
- **Replayability**: Unique terrain every run
- **Balanced Progression**: Easy for learning, Hard for mastery
- **Reproducible**: Optional seed for debugging/sharing specific runs
- **Designer Override**: JSON still works for hand-crafted slopes
