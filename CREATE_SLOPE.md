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
   - Base height: `350.0 * (1.0 - float(z) / length_cells)` for non-linear slope with varied sections
   - **Varied slope sections** for realistic ski slope experience:
     * 0-25%: Gentle starting area with smooth undulation (+10m variation)
     * 25-40%: First steep drop - moderate descent (-30m)
     * 40-55%: Gentle plateau with mild rolling (+5m variation)
     * 55-70%: Second steep section (-25m)
     * 70-100%: Final approach with gentle bumps (+8m variation)
   - **Smooth multi-layer noise** for natural terrain:
     * Large-scale features (mountains/valleys): freq 0.005, amplitude 8m
     * Medium-scale features (hills/dips): 2 layers, freq 0.012, amplitude 4m
     * Small-scale details (gentle bumps): 2 layers, freq 0.025, amplitude 2m
     * Fixed phase offsets prevent spiky terrain
     * Simplified frequency multipliers (0.5, 0.7, 0.8) for smooth transitions
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

**4. Procedural Noise Algorithm** (CURRENT):
```gdscript
# Smooth multi-layer noise for realistic terrain
var noise_amplitudes = config.get("noise_amplitude", [8.0, 4.0, 2.0])
var noise_freqs = config.get("noise_frequencies", [0.005, 0.012, 0.025])

# Create random seed for noise consistency
var noise_seed = hash(str(width_m) + str(length_m))
var rng = RandomNumberGenerator.new()
rng.seed = noise_seed

# Generate FIXED phase offsets once (not per-vertex!)
var phase_offsets = []
for i in range(6):
    phase_offsets.append(rng.randf() * 6.28)

var noise_val = 0.0

# Large-scale terrain features (mountains, valleys) - very slow frequency
noise_val += sin(world_x * noise_freqs[0] + phase_offsets[0]) * cos(world_z * noise_freqs[0] + phase_offsets[1]) * noise_amplitudes[0]

# Medium-scale features (hills, dips) - smooth patterns, 2 layers
noise_val += sin(world_x * noise_freqs[1] + world_z * noise_freqs[1] * 0.5 + phase_offsets[2]) * noise_amplitudes[1]
noise_val += cos(world_x * noise_freqs[1] * 0.7 + world_z * noise_freqs[1] + phase_offsets[3]) * noise_amplitudes[1] * 0.6

# Small-scale details (gentle bumps) - subtle variation, 2 layers
noise_val += sin(world_x * noise_freqs[2] + world_z * noise_freqs[2] * 0.8 + phase_offsets[4]) * noise_amplitudes[2]
noise_val += cos(world_x * noise_freqs[2] * 0.6 + world_z * noise_freqs[2] + phase_offsets[5]) * noise_amplitudes[2] * 0.4

# Note: Micro-detail random noise removed to prevent spiky terrain
```

**Key design decisions**:
- **Fixed phase offsets**: Calculated once before vertex loop, ensures smooth continuous terrain
- **Lower frequencies**: 0.005/0.012/0.025 create wide, gentle features (3x reduction from previous)
- **Reduced amplitudes**: 8m/4m/2m prevent excessive height variation (50% reduction)
- **Simplified multipliers**: 0.5, 0.6, 0.7, 0.8 avoid high-frequency artifacts
- **No random micro-detail**: Removed per-vertex randomness that caused spiky appearance

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

## 10) Recent Updates (2025-10-14)

### Update 1: Realistic Slope Sections Implementation (Morning)
**Problem**: Original terrain had uniform linear slope with no variety. Lacked the natural flow of real ski slopes.

**Solution**: Implemented varied slope sections that mimic real ski resort terrain:

1. **Non-linear Base Slope** (`terrain_generator.gd:119-140`):
   - Divided slope into 5 distinct sections based on `slope_progress` (0.0 to 1.0)
   - Each section has unique characteristics:
     * **Gentle starter** (0-25%): Smooth undulation for speed building
     * **First steep drop** (25-40%): Moderate descent using quadratic falloff
     * **Plateau rest area** (40-55%): Gentle rolling for catching breath
     * **Second steep section** (55-70%): Another challenging descent
     * **Jump zone** (70-100%): Gentle bumps for finale

2. **Multi-layer Noise System** (`terrain_generator.gd:142-154`):
   - 6 noise layers with different frequencies and amplitudes
   - Attempted to create natural irregular terrain variation
   - Used random phase offsets and frequency multipliers

**Initial Results**:
- Successfully generates terrain with varied sections
- Creates gameplay pacing variation
- However, terrain appeared too spiky/jagged (see Update 2)

---

### Update 2: Smooth Terrain Fix (Afternoon)
**Problem**: Terrain appeared "spiky like thorns" - sharp, irregular peaks everywhere. Not smooth enough for skiing.

**Root causes identified**:
1. **Per-vertex random phase offsets**: `rng.randf() * 6.28` calculated inside vertex loop
   - Destroyed continuity between adjacent vertices
   - Created jagged, discontinuous surface
2. **Too high frequencies**: 0.015/0.03/0.08 created tight, close-spaced bumps
3. **Too large amplitudes**: 15m/8m/4m excessive height variation
4. **Complex frequency multipliers**: 1.3, 1.7, 2.1 created high-frequency artifacts
5. **Per-vertex random micro-detail**: `(rng.randf() - 0.5) * amplitude` added noise to every vertex
6. **Excessive section variations**: 60m/45m drops too dramatic

**Solution - 6 Key Changes**:

| Aspect | Before (Spiky) | After (Smooth) | Improvement |
|--------|----------------|----------------|-------------|
| **Phase Offsets** | `rng.randf()` per vertex | Fixed array, calculated once | Continuous terrain |
| **Frequencies** | [0.015, 0.03, 0.08] | [0.005, 0.012, 0.025] | 3x wider features |
| **Amplitudes** | [15.0, 8.0, 4.0] | [8.0, 4.0, 2.0] | 50% reduction |
| **Freq Multipliers** | 1.3, 1.7, 2.1 | 0.5, 0.6, 0.7, 0.8 | Simplified, gentler |
| **Micro-detail** | ±0.6m random | Removed entirely | No vertex noise |
| **Section Heights** | ±60m, ±45m | ±30m, ±25m | 50% reduction |

**Code Changes** (`terrain_generator.gd:88-154`):

```gdscript
# CRITICAL FIX: Calculate phase offsets ONCE, not per-vertex
var phase_offsets = []
for i in range(6):
    phase_offsets.append(rng.randf() * 6.28)

# Use FIXED offsets in noise calculation
noise_val += sin(world_x * noise_freqs[0] + phase_offsets[0]) * ...  # Not rng.randf()!
```

**DifficultyConfig Updates** (`difficulty_config.gd`):

```gdscript
Easy:   noise_amplitude=[6.0, 3.0, 1.5],  noise_frequencies=[0.003, 0.008, 0.018]
Medium: noise_amplitude=[8.0, 4.0, 2.0],  noise_frequencies=[0.005, 0.012, 0.025]
Hard:   noise_amplitude=[12.0, 6.0, 3.0], noise_frequencies=[0.008, 0.018, 0.035]
```

**Results**:
- Terrain now smooth and ski-able
- Wide, gentle hills and valleys (not tight bumps)
- Natural mountain appearance maintained
- No spiky artifacts
- Successfully tested with 37,500 vertices

**Lessons Learned**:
- Random values must be fixed outside vertex loops for continuous surfaces
- Lower frequencies (< 0.01) essential for natural-looking terrain
- Per-vertex randomness destroys mesh smoothness
- Moderation in amplitude critical for playable slopes

---

### Update 3: Sparkling Snow Material (2025-10-15)
**Problem**: Terrain looked dull and didn't capture the luminous, sparkling quality of real snow under sunlight.

**Goal**: Make snow terrain sparkle and glow like real snow on a sunny winter day.

**Solution**: Enhanced StandardMaterial3D properties for snow surface:

**Material Changes** (`terrain_generator.gd:259-268`):

| Property | Before | After | Effect |
|----------|--------|-------|--------|
| **albedo_color** | `(0.95, 0.95, 1.0)` | `(1.0, 1.0, 1.0)` | Pure white for brighter snow |
| **roughness** | `0.7` | `0.3` | Smooth surface for reflective sparkle |
| **emission_enabled** | `false` | `true` | Enable self-illumination |
| **emission** | N/A | `Color(0.15, 0.15, 0.2)` | Subtle blue-white glow |
| **emission_energy_multiplier** | N/A | `0.5` | Gentle luminance intensity |

**Code Implementation**:
```gdscript
# Create material with sparkling snow properties
var material = StandardMaterial3D.new()
material.albedo_color = Color(1.0, 1.0, 1.0)  # Pure white for bright snow
material.roughness = 0.3  # Smooth surface for reflective sparkle
material.metallic = 0.0
material.emission_enabled = true
material.emission = Color(0.15, 0.15, 0.2)  # Subtle blue-white glow
material.emission_energy_multiplier = 0.5  # Gentle emission
material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
array_mesh.surface_set_material(0, material)
```

**Visual Results**:
- ✨ **Sparkle Effect**: Lower roughness (0.3) creates smooth, reflective surface that catches light
- 💎 **Bright Snow**: Pure white albedo maximizes light reflection
- 🌟 **Self-Illumination**: Subtle emission simulates snow's natural luminosity
- ❄️ **Cold Atmosphere**: Blue-white emission tint conveys winter coldness
- 🏔️ **Natural Glow**: Gentle emission energy (0.5) prevents over-brightness

**Lighting Integration**:
Works in conjunction with DirectionalLight3D settings (from earlier update):
- `light_energy = 1.5` - Strong sunlight
- `shadow_enabled = true` - Depth and contrast
- `shadow_opacity = 0.6` - Soft shadows

**Technical Notes**:
- Emission is view-independent, provides consistent glow from all angles
- Low roughness increases specular highlights under directional light
- Per-pixel shading ensures smooth light falloff across terrain
- No performance impact - material properties are GPU-efficient

**Design Rationale**:
Real snow sparkles due to ice crystal reflection and scattering. The combination of:
1. High albedo (brightness)
2. Low roughness (smoothness)
3. Subtle emission (self-glow)

...simulates this natural phenomenon in a low-poly, stylized way that matches the game's aesthetic.

---

## 11) Player Movement Implementation

### Architecture
**File**: `scripts/player/player.gd`
**Node**: CharacterBody3D with collision detection

### Core Movement System

**1. Physics Constants** (lines 4-7):
```gdscript
const SPEED = 8.0              # Base horizontal movement speed
const TURN_SPEED = 3.0         # Turning/steering speed
const JUMP_VELOCITY = 6.0      # Vertical jump impulse
const GRAVITY = 9.8            # Gravity acceleration
```

**2. Main Physics Loop** (`_physics_process(delta)`, lines 58-112):

**Control Lock Logic**:
```gdscript
# Only disable player control in free camera mode (mode 3)
if camera_mode == 3:
    return
```
- **Modes 0-2** (3rd person back, 3rd person front, 1st person): Player **can move**
- **Mode 3** (free camera): Player **cannot move** (camera inspection mode)

**Gravity Application** (lines 64-65):
```gdscript
if not is_on_floor():
    velocity.y -= GRAVITY * delta
```

**Jump Handling** (lines 68-69):
```gdscript
if Input.is_action_just_pressed("jump") and is_on_floor():
    velocity.y = JUMP_VELOCITY
```

**Input Processing** (lines 72-73):
```gdscript
var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
```

**Movement Application** (lines 104-109):
```gdscript
if direction:
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
else:
    velocity.x = move_toward(velocity.x, 0, SPEED * delta)
    velocity.z = move_toward(velocity.z, 0, SPEED * delta)
```

**Physics Update** (line 112):
```gdscript
move_and_slide()  # CharacterBody3D built-in collision-aware movement
```

### Animation System

**3. Animation Constants** (lines 10-12):
```gdscript
const TILT_AMOUNT = 30.0      # degrees - left/right lean
const LEAN_AMOUNT = 20.0      # degrees - forward/backward lean
const ANIMATION_SPEED = 10.0  # interpolation speed
```

**4. Body Animations** (lines 75-98):

**Tilt (Left/Right Turning)** (line 79):
```gdscript
target_tilt = -input_dir.x * TILT_AMOUNT  # ±30° based on horizontal input
```

**Lean (Forward/Backward)** (lines 82-90):
```gdscript
if is_braking:
    target_lean = -15.0   # Lean back during brake
elif Input.is_action_pressed("move_forward"):
    target_lean = LEAN_AMOUNT  # Lean forward when accelerating
else:
    target_lean = 0.0     # Neutral stance
```

**Smooth Interpolation** (lines 93-94):
```gdscript
current_tilt = lerp(current_tilt, target_tilt, ANIMATION_SPEED * delta)
current_lean = lerp(current_lean, target_lean, ANIMATION_SPEED * delta)
```

**Apply Rotation** (lines 97-98):
```gdscript
body.rotation_degrees.z = current_tilt  # Roll
body.rotation_degrees.x = current_lean  # Pitch
```

### Ski Braking System

**5. Ski Stance Animation** (`_update_ski_stance()`, lines 181-205):

**Purpose**: Animate skis into "pizza/wedge" position when braking

**Parameters** (lines 183-189):
```gdscript
var target_ski_rotation_x = 0.0   # Normal: parallel skis
var target_ski_spacing = 0.15     # Normal: narrow stance

if is_braking:
    target_ski_rotation_x = 15.0  # Wedge angle
    target_ski_spacing = 0.25     # Wider leg stance
```

**Leg Spacing** (lines 192-196):
```gdscript
var current_leg_spacing = $Body/LeftLeg.position.x
var new_spacing = lerp(abs(current_leg_spacing), target_ski_spacing, ANIMATION_SPEED * delta)

$Body/LeftLeg.position.x = -new_spacing
$Body/RightLeg.position.x = new_spacing
```

**Ski Rotation** (lines 199-205):
```gdscript
var current_ski_rot = left_ski.rotation_degrees.y
var new_ski_rot = lerp(current_ski_rot, target_ski_rotation_x, ANIMATION_SPEED * delta)

# Left ski rotates right (positive), right ski rotates left (negative)
# This creates a reverse wedge shape with ski tails pointing inward
left_ski.rotation_degrees.y = new_ski_rot
right_ski.rotation_degrees.y = -new_ski_rot
```

**Critical Detail**: Ski **tails** point inward (not tips), matching real skiing technique.

### Input Mapping

**Required Actions** (defined in `project.godot`):
- `move_forward`: W key / Up arrow
- `move_back`: S key / Down arrow
- `move_left`: A key / Left arrow
- `move_right`: D key / Right arrow
- `jump`: Space key
- `toggle_camera`: F1 key

### Collision Setup

**Player** (`player.tscn`, line 45):
```gdscript
collision_mask = 2  # Collides with environment layer
```

**Terrain** (`terrain_generator.gd`, line 276):
```gdscript
collision_layer = 2  # Environment layer
collision_mask = 0   # Doesn't check collisions (static)
```

### Key Design Decisions

1. **Camera-Based Movement Control**:
   - Movement enabled in all camera modes except free camera
   - Allows 1st person skiing experience
   - Free camera mode for terrain inspection only

2. **Smooth Animation System**:
   - All rotations use `lerp()` for smooth transitions
   - Prevents jerky, instantaneous pose changes
   - `ANIMATION_SPEED = 10.0` provides responsive but smooth feel

3. **Physics-Based Movement**:
   - Uses CharacterBody3D's `move_and_slide()` for collision handling
   - Gravity applied when airborne
   - Jump only when grounded (`is_on_floor()`)

4. **Realistic Ski Mechanics**:
   - Braking widens stance and creates wedge
   - Ski tails converge (not tips) - matches real technique
   - Body leans match movement direction (forward/back/left/right)

### Debugging Features

**Fall Detection** (lines 115-116):
```gdscript
if global_position.y < -50:
    print("Player fell through terrain! Position: ", global_position)
```

### Future Enhancements (TODO)
- Speed-based animation scaling (faster = more lean)
- Edge carving (sharper turns at higher speeds)
- Trick system (rotation in air)
- Landing impact feedback
- Speed boost zones
- Collision reaction (bounce off obstacles)
