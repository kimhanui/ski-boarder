# Player Implementation

**File**: `scripts/player/player.gd`, `scenes/player/player.tscn`

## Character Model

**Style**: Low-poly, chibi proportions (치비 스타일)

### Body Structure

| Part | Mesh Type | Position (Body-relative) | Size/Details |
|------|-----------|-------------------------|--------------|
| **Head** | SphereMesh | Y=0.65 | radius=0.25, 살구색 피부 |
| **Eyes** | CSGSphere3D | Y=0.7, X=±0.1 | radius=0.04, 검은색 |
| **Torso** | CapsuleMesh | Y=0.15 | radius=0.25, height=0.8, 파란 재킷 |
| **Arms** | Node3D + CapsuleMesh | Y=0.3, X=±0.35 | UpperArm + LowerArm + SkiPole |
| **Legs** | Node3D + CapsuleMesh | Y=-0.3, X=±0.15 | UpperLeg + LowerLeg (height=0.5 each) |
| **Skis** | PrismMesh | Y=-0.7 (Leg 기준) | size=(0.15, 0.05, 1.2), 빨간색 |

### Collision Setup

- **CollisionShape3D**: CapsuleShape3D, height=1.8
- **Position**: Y=0.4 (상향 조정)
- **Bottom**: Y=-0.5
- **Purpose**: 스키가 지형에 파묻히지 않도록 충돌 캡슐을 위로 올림

## Movement System

### Control Scheme

**Rotation-Based Movement** (not strafe):
- **A/D (Left/Right)**: Y-axis rotation (turning only)
- **W (Forward)**: Accelerate forward
- **S (Back)**: Brake (does not reverse)
- **Space**: Jump
- **R**: Respawn at start position
- **F1**: Cycle camera modes

### Physics Constants

```gdscript
const MAX_SPEED = 15.0
const TURN_SPEED = 1.5              # Reduced for better control
const ACCELERATION = 5.0
const SLOPE_ACCELERATION_FACTOR = 0.5
const BRAKE_DECELERATION = 10.0
const FRICTION = 2.0
const SKATING_SPEED_THRESHOLD = 4.0  # Skating animation threshold
const JUMP_VELOCITY = 6.0
const GRAVITY = 9.8
```

### Movement Features

#### 1. Slope-Based Gradual Acceleration

**Implementation** (`player.gd:114-137`):
```gdscript
# Calculate slope angle
var floor_normal = get_floor_normal()
var slope_angle = acos(floor_normal.dot(Vector3.UP))
var slope_factor = sin(slope_angle) * SLOPE_ACCELERATION_FACTOR

# Gradual acceleration
var acceleration = ACCELERATION + slope_factor * 20.0
current_speed = min(current_speed + acceleration * delta, MAX_SPEED)
```

**Characteristics**:
- Starts slow, builds up gradually
- Steeper slopes = faster acceleration
- Natural, continuous speed changes

#### 2. Low-Speed Skating Animation

**When Active**: `current_speed < 4.0` and moving forward

**Effect**: Alternating push motion (한 발씩 밀기)

**Implementation** (`_update_skating_animation()`, lines 248-297):

| Phase | Left Leg | Right Leg | Left Ski Angle | Right Ski Angle |
|-------|----------|-----------|----------------|-----------------|
| 0.0-0.5 | Push out (0.15→0.30) | Center (0.15) | +20° | 0° |
| 0.5-1.0 | Center (0.15) | Push out (0.15→0.30) | 0° | -20° |

- Phase cycles smoothly using `sin(phase * PI)`
- Automatic transition to parallel stance at high speed

#### 3. Braking System

**Back Key (S) Behavior**:
- Decelerates at `BRAKE_DECELERATION = 10.0 m/s²`
- Does **NOT** move backward
- Stops at zero speed

**Brake Animations**:
- Legs widen (0.15 → 0.25 spacing)
- Skis angle inward 15° (pizza/wedge position)
- Body leans back -15°
- Ski tails converge (not tips) - realistic technique

#### 4. Respawn System

**R Key**: Reset to spawn position

**Features** (`respawn()`, lines 316-333):
- Saves initial position/rotation in `_ready()`
- Resets position, rotation, velocity, speed
- Resets all animation states
- Console log for debugging

### Body Animation

**Automatic Tilt & Lean**:

| Action | Animation | Amount |
|--------|-----------|--------|
| **Turn left/right** | Roll (Z-axis) | ±30° |
| **Forward** | Pitch forward | +20° |
| **Brake** | Pitch backward | -15° |
| **Neutral** | Upright | 0° |

**Interpolation**: Smooth `lerp()` at `ANIMATION_SPEED = 10.0`

## Camera System

**Modes** (cycle with F1):
0. Third-person back (default)
1. Third-person front
2. First-person
3. Free camera (movement disabled)

**Implementation**: Eye visibility automatically adjusted for first/third person views

## UI Display

### Speed Label

**Location**: Top-left, below camera label

**Format**: `"속도: X.X m/s | 스케이팅: ON/OFF (< 4.0)"`

**Update**: Every frame (`_update_speed_ui()`)

## Terrain Interaction

### Collision Layers

- **Player**: `collision_mask = 2` (detects Environment layer)
- **Terrain**: `collision_layer = 2` (Environment)

### Ski Positioning Fix

**Problem**: Skis clipping through terrain

**Solution**:
1. **Collision capsule raised**: Y=0.25 → 0.4
   - New bottom: Y=-0.5
2. **Terrain collision shape raised**: `collision_shape.position.y = 0.5`
   - Visual terrain remains at original height
   - Collision surface 50cm above visual surface
3. **Skis positioned at foot bottom**: Y=-0.7 (Leg-relative)
   - Global position: Y=-1.0
   - Always visible above snow surface

**Result**: Player "floats" 50cm above visual terrain, skis appear naturally on snow

## Input Actions

**Required in `project.godot`**:

| Action | Keys | Physical Keycode |
|--------|------|------------------|
| `move_forward` | W / ↑ | 87 / 4194320 |
| `move_back` | S / ↓ | 83 / 4194322 |
| `move_left` | A / ← | 65 / 4194319 |
| `move_right` | D / → | 68 / 4194321 |
| `jump` | Space | 32 |
| `respawn` | R | 82 |
| `toggle_camera` | F1 | 4194306 |

## Technical Notes

### Coordinate System

**Global Positions** (with Body at Y=0):
- Head: Y=0.65
- Torso: Y=0.15
- Collision bottom: Y=-0.5
- Legs: Y=-0.3
- Foot bottom: Y=-0.7
- Skis: Y=-1.0

### Animation Priority

1. **Skating** overrides brake stance when speed < 4.0
2. **Braking** takes precedence when active
3. **High-speed** returns to parallel stance

### Debug Features

- Fall detection: `if global_position.y < -50`
- Respawn console log
- Speed display on screen

## Future Enhancements

- [ ] Speed-based animation scaling
- [ ] Edge carving at high speeds
- [ ] Trick system (air rotation)
- [ ] Landing impact feedback
- [ ] Collision reaction (bounce off obstacles)
- [ ] Professional 3D model replacement
