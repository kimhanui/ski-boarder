# Player System

스키 보더 게임의 플레이어 캐릭터 시스템 완전 가이드

## Overview

**현재 버전**: V2 (Enhanced Animation System)
**파일**: `scripts/player/player_v2.gd`, `scenes/player/player.tscn`
**스타일**: 로우폴리 치비 비율 (Low-poly chibi proportions)

---

## Character Model

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

### Coordinate System

**Global Positions** (with Body at Y=0):
- Head: Y=0.65
- Torso: Y=0.15
- Collision bottom: Y=-0.5
- Legs: Y=-0.3
- Foot bottom: Y=-0.7
- Skis: Y=-1.0

---

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
const MIN_TURN_SPEED = 2.0          # Minimum speed to turn
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

**Implementation** (`player_v2.gd:186-198`):
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

**Implementation** (`_update_skating_animation()`):

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
- Body leans back -20°
- Torso leans forward -10° (balance)
- Ski tails converge (not tips) - realistic technique

#### 4. Respawn System

**R Key**: Reset to spawn position

**Features** (`respawn()`):
- Saves initial position/rotation in `_ready()`
- Resets position, rotation, velocity, speed
- Resets all animation states (including jump state)
- Console log for debugging

---

## Animation System V2

**Enhanced procedural animation system** based on PLAYER_MOVEMENT.md specifications.

### Animation Constants

```gdscript
# V2 Animation constants
const TILT_AMOUNT = 30.0
const LEAN_AMOUNT = 20.0
const ANIMATION_SPEED = 10.0
const BREATHING_CYCLE_SPEED = 0.5  # 2 second cycle
const ARM_SWING_SPEED = 1.25  # 0.8 second cycle
const EDGE_CHATTER_SPEED = 8.0  # Fast micro vibrations

# Jump animation constants
const JUMP_CROUCH_DURATION = 0.3  # Crouch before jump
const JUMP_LAUNCH_DURATION = 0.4  # Launch animation
const JUMP_CROUCH_AMOUNT = 0.15  # Body lowering amount
const JUMP_ARM_RAISE_ANGLE = 45.0  # Arms raised angle
```

### IDLE Animation

**Visual**: Soft athletic stance with gentle breathing

**Implementation** (`_update_breathing_cycle()`):
- Torso: -15° ± 3° breathing cycle (2s period)
- Arms: idle swing ±5° with phase offset
- Head: translate Z = -0.02 on inhale (no rotation)
- Legs: slight bend
- Skis: parallel, shoulder-width

**Technical**:
```gdscript
breathing_phase = fmod(breathing_phase + delta * BREATHING_CYCLE_SPEED * TAU, TAU)
var breathing_torso = sin(breathing_phase) * 3.0
torso.rotation_degrees.x = current_upper_lean + breathing_torso
```

### FORWARD Animation

**Visual**: Leaning forward with push-glide arm rhythm

**Implementation** (`_update_arm_swing()`):
- Torso: X = -45° with breathing
- Arms: Push-glide cycle (0.8s)
  - Left arm: -45° (push) → -30° (recover)
  - Right arm: Opposite phase
- Head: translate Z forward on push
- Legs: bend more on push, return on glide

**Technical**:
```gdscript
arm_swing_phase += delta * ARM_SWING_SPEED * TAU
var push_intensity = (sin(arm_swing_phase) + 1.0) * 0.5
var left_arm_angle = lerp(-30.0, -45.0, push_intensity)
```

### TURN Animation

**Visual**: Carving with weight shift and ski edge effects

**Weight Shift** (`_apply_weight_shift()`):
- Left turn: Weight on RIGHT leg → torso shifts right (+0.03)
- Right turn: Weight on LEFT leg → torso shifts left (-0.03)
- Torso yaw: ±10° facing turn direction
- Weighted leg: -6° edge angle
- Trail leg: -3° edge angle

**Ski Edge Effect** (`_apply_ski_edge_effect()`):
- Both skis yaw into turn: ±12° at apex
- Inner ski trails by additional 2°
- Edge chatter: ±2° micro-vibration (high frequency)

**Technical**:
```gdscript
# Weight shift
var target_torso_x = turn_direction * 0.03
torso.position.x = lerp(torso.position.x, target_torso_x, ANIMATION_SPEED * delta)

# Ski edge chatter
edge_chatter_phase += delta * EDGE_CHATTER_SPEED * TAU
var chatter = sin(edge_chatter_phase) * 2.0
left_ski.rotation_degrees.y = base_ski_yaw + chatter
```

### BRAKE Animation

**Visual**: Enhanced emergency stop stance

**Implementation**:
- Lean back: -20° (more pronounced than V1)
- Torso forward: -10° (balance compensation)
- Legs widen: spacing 0.15 → 0.25
- Skis: pizza/wedge with 15° inward angle

### JUMP Animation

**Visual**: Crouch → Launch → Airborne → Landing

**State Machine** (`_update_jump_state()`):

| State | Duration | Description |
|-------|----------|-------------|
| **GROUNDED** | - | Normal ground state |
| **CROUCHING** | 0.3s | Crouch down, bend legs 25° |
| **LAUNCHING** | 0.4s | Extend legs, raise arms 45° |
| **AIRBORNE** | - | Hold air pose, legs bent 10° |
| **LANDING** | 0.3s | Absorb impact, return to ground |

**Implementation** (`_apply_jump_animation()`):
- Body height: Lower by JUMP_CROUCH_AMOUNT during crouch
- Arms: Raise to -45° during launch
- Legs: Progressive bend/extension
- Smooth state transitions

**Technical**:
```gdscript
enum JumpState { GROUNDED, CROUCHING, LAUNCHING, AIRBORNE, LANDING }

# Crouch phase
if jump_state == JumpState.CROUCHING:
    jump_crouch_progress = min(jump_timer / JUMP_CROUCH_DURATION, 1.0)
    body_offset_y = -JUMP_CROUCH_AMOUNT * jump_crouch_progress

# Launch when crouch complete
if jump_timer >= JUMP_CROUCH_DURATION:
    velocity.y = JUMP_VELOCITY
    jump_state = JumpState.LAUNCHING
```

### Animation Functions Reference

| Function | Purpose | Called From |
|----------|---------|-------------|
| `_update_breathing_cycle(delta)` | IDLE breathing | `_physics_process()` |
| `_update_arm_swing(delta)` | Forward arm motion | `_physics_process()` |
| `_apply_weight_shift(turn, delta)` | Turn weight distribution | `_physics_process()` |
| `_reset_weight_shift(delta)` | Return to neutral | `_physics_process()` |
| `_apply_ski_edge_effect(turn, delta)` | Ski carving effects | `_physics_process()` |
| `_update_jump_state(delta)` | Jump state machine | `_physics_process()` |
| `_apply_jump_animation()` | Apply jump poses | `_update_jump_state()` |
| `_update_ski_stance(braking, delta)` | Brake/parallel stance | `_physics_process()` |
| `_update_skating_animation(delta)` | Low-speed skating | `_physics_process()` |
| `_reset_skating_stance(delta, immediate)` | Exit skating | `_physics_process()` |

---

## Ski Positioning Fix

**Problem**: Skis clipping through terrain

**Solution**:
1. **Collision capsule raised**: Y=0.25 → 0.4
   - New bottom: Y=-0.5
2. **Skis positioned at foot bottom**: Y=-0.7 (Leg-relative)
   - Global position: Y=-1.0
   - Always visible above snow surface

**Result**: Player "floats" slightly above visual terrain, skis appear naturally on snow

**Implementation**:
- `CollisionShape3D.position.y = 0.4`
- `Ski.position.y = -0.7` (relative to Leg at Y=-0.3)
- Terrain collision also raised (see SLOPE.md)

---

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

---

## UI Display

### Speed Label

**Location**: Top-left, below camera label

**Format**: `"V2 | 속도: X.X m/s | 스케이팅: ON/OFF (< 4.0)"`

**Update**: Every frame (`_update_speed_ui()`)

**Implementation** (`player_v2.gd:444-452`):
```gdscript
func _update_speed_ui() -> void:
    if speed_label:
        var skating_status = "OFF"
        if current_speed < SKATING_SPEED_THRESHOLD and Input.is_action_pressed("move_forward"):
            skating_status = "ON"

        speed_label.text = "V2 | 속도: %.1f m/s | 스케이팅: %s (< %.1f)" % [
            current_speed, skating_status, SKATING_SPEED_THRESHOLD
        ]
```

**Note**: Camera Mode Label은 CAMERA.md 참조

---

## Version History

### V1 vs V2 Comparison

**Quick Summary**:
- **V1 (player.gd)**: Basic procedural animation with simple body tilts
- **V2 (player_v2.gd)**: Enhanced animation based on PLAYER_MOVEMENT.md specs

### Key Differences

| Feature | V1 | V2 |
|---------|----|----|
| **IDLE** | Static upright | ✅ Breathing cycle, athletic stance |
| **FORWARD** | Static arms | ✅ Push-glide arm swing |
| **TURN** | Simple tilt | ✅ Weight shift + ski edge + chatter |
| **BRAKE** | -15° lean | ✅ -20° lean + torso balance |
| **JUMP** | ❌ Not implemented | ✅ Full 5-state animation |
| **Code Size** | ~379 lines | ~613 lines (+234 for enhancements) |

### Switch to V1

To revert to V1, change `scenes/player/player.tscn` line 3:
```
From: [ext_resource type="Script" path="res://scripts/player/player_v2.gd" id="1_player_script"]
To:   [ext_resource type="Script" uid="uid://lf14tmup8yax" path="res://scripts/player/player.gd" id="1_player_script"]
```

### Recommendation

**Use V2 if**:
- ✅ You want realistic skiing animations
- ✅ You value visual polish and immersion
- ✅ You're building a simulation-focused game

**Use V1 if**:
- ✅ You prefer simpler, arcade-style gameplay
- ✅ You need minimal animation complexity

---

## Development History

### MVP Character Modeling Plan

**Branch**: `feat/character-modeling`

**Goal**: MVP용 치비 스타일 스키 플레이어 캐릭터 구현

**Implementation Approach**: Godot 내장 프리미티브 활용 (외부 3D 소프트웨어 불필요)

#### Character Parts

1. **Body Group**
   - `Head`: SphereMesh (반지름 0.3) - 살구색 피부
   - `UpperBody`: BoxMesh (0.4×0.4×0.25) - 파란색 재킷
   - `LeftLeg`, `RightLeg`: CylinderMesh (높이 0.4) - 검은 바지

2. **Equipment Group**
   - `SkiLeft`, `SkiRight`: BoxMesh (0.15×0.05×1.0) - 빨간 스키
   - `PoleLeft`, `PoleRight`: CylinderMesh (반지름 0.015, 높이 0.8) - 회색 폴

3. **Face Group** (Head의 자식)
   - `LeftEye`, `RightEye`: SphereMesh (반지름 0.1) - 큰 검은 눈
   - `Mouth`: SphereMesh (반지름 0.06, 납작) - 작은 입

#### File Changes
- `scenes/player/player.tscn`:
  - 기존 CapsuleMesh 제거
  - 모듈러 메시 노드들 추가
  - SubResource로 각 메시 및 머티리얼 정의

#### Test Method
1. Godot 에디터에서 `scenes/player/player.tscn` 열기
2. 3D 뷰에서 캐릭터 외형 확인
   - 치비 비율 (큰 머리)
   - 스키와 폴이 적절히 배치됨
   - 무릎이 약간 구부러진 자세

---

## Future Enhancements

### Professional 3D Model Replacement

현재는 프로그래밍으로 생성한 간단한 메시를 사용하지만,
향후 전문 3D 아티스트가 제작한 모델로 교체 가능합니다.

**상세 명세**: `CREATE_PLAYER.json`

**주요 사양**:
- 로우폴리 치비 스타일 (3,000-8,000 폴리곤)
- 모듈화 시스템: 모자/재킷/바지/스키/폴 분리 메시
- Human/Cat 두 가지 변형 버전
- FBX/GLB 익스포트 포맷

**Integration Steps**:
1. Blender에서 CREATE_PLAYER.json 명세 따라 모델링
2. FBX/GLB로 익스포트
3. `Body`, `Equipment` 노드에 임포트된 메시로 교체
4. 기존 스크립트 그대로 작동 (노드 구조 동일)

### Planned Features

- [ ] Speed-based animation scaling
- [ ] Edge carving at high speeds
- [ ] Trick system (air rotation)
- [ ] Landing impact feedback
- [ ] Collision reaction (bounce off obstacles)
- [ ] Emergency stop (double-tap S)
- [ ] Variable animation speed based on slope
- [ ] Head look-ahead during high-speed turns

---

## Technical Notes

### Animation Priority
1. **Jump** overrides all other animations when active
2. **Skating** overrides brake stance when speed < 4.0
3. **Braking** takes precedence when active
4. **High-speed** returns to parallel stance

### Debug Features
- Fall detection: `if global_position.y < -50`
- Respawn console log
- Speed display on screen
- Version indicator in UI ("V2")

### Performance
- V2 adds ~3 animation phases (breathing, arm swing, edge chatter)
- Additional calculations are minimal (sine waves, lerps)
- No noticeable FPS difference from V1

---

**Last updated**: 2025-10-18 (Jump animation added)