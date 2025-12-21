# Player System

스키 보더 게임의 플레이어 캐릭터 시스템 완전 가이드

## Overview

**현재 버전**: V3 (FSM-based State Management with Auto-Recovery)
**파일**: `scripts/player/player_v3.gd`, `scenes/player/player.tscn`
**스타일**: 로우폴리 치비 비율 (Low-poly chibi proportions)
**주요 기능**: 상태 머신(FSM) 기반 상태 관리, 착지 실패 판정, 자동 회복 시스템

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

## Jump Animation Keyframe Reference

**Source**: ADD.md specification for professional keyframe-based jump animations

**Note**: Current V2 implementation uses **procedural animation** (state machine with lerped poses). This section documents the original keyframe-based specification for potential future implementation or external animation tools.

---

### Rig Constraints

**Hierarchy**:
```
Body (root)
├─ Head
├─ Torso
├─ LeftArm
├─ RightArm
├─ LeftLeg
├─ RightLeg
└─ Skis (children of Legs; Skis at Y = -0.7 from Legs; global ≈ -1.0)
```

**Face Details** (Head children):
- Eyes
- Mouth (optional)

**Relative Y Positions**:
- Head: 0.65
- Arms: 0.3
- Torso: 0.15
- Legs: -0.3
- Skis: -0.7

**Animation Rules**:
- **Upper body**: Head, Torso, LeftArm, RightArm
- **Lower body**: LeftLeg, RightLeg (+ Skis)
- All transforms in **LOCAL space**
- **Head rotation**: FORBIDDEN - only allow small forward/up translation
- **Baseline**: Torso & Arms X = -45° when gliding
- **Frame rate**: 30 FPS
- **Root motion**: OFF
- **Loop**: OFF (one-shot animations)

---

### A) SmallHop (16 frames, one-shot)

**Visual**: 작은 지형에서 톡 튀어 오르는 느낌. 폴은 살짝 뒤로.

**Timing**:
- f0-f4: Crouch (compression) - 4 frames
- f4-f7: Takeoff - 3 frames
- f7-f11: Air phase - 4 frames
- f11-f16: Landing - 5 frames

**Mechanics**:
- Crouch: 무릎 굽힘, Torso X = -55°; Arms sweep back X = -55°
- Takeoff: Torso X = -35°로 복원; 폴 뒤로 스윙
- Air: Skis **parallel**, Roll(Z) ±2° 미세 흔들림
- Land: 무릎 흡수, Torso X = -50°→-40°
- Head: posZ -0.02 on push, posY +0.015 in air; **no rotation**

**Keyframe Table**:

| Frame | Node | rotX | rotY | rotZ | posX | posY | posZ |
|-------|------|------|------|------|------|------|------|
| **f0** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.01 |
| | LeftLeg | 0 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | 0 | 0 | 0 | 0 | 0 | 0 |
| | Skis | 0 | 0 | 0 | 0 | 0 | 0 |
| **f4** | Torso | -55 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -55 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -55 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.02 |
| | LeftLeg | -6 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | -6 | 0 | 0 | 0 | 0 | 0 |
| **f7** | Torso | -35 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -30 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -30 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0.015 | -0.01 |
| | Skis | 0 | 0 | +2 | 0 | 0 | 0 |
| **f11** | Torso | -40 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -20 | 0 | 0 | 0 | 0 | 0 |
| **f16** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | (all return to FORWARD/IDLE pose) |

**Easing**:
- Crouch (f0→f4): easeIn
- Takeoff (f4→f7): easeOut
- Air (f7→f11): linear hold
- Land (f11→f16): easeInOut

---

### B) StandardJump (22 frames, one-shot)

**Visual**: 일반 점프. 공중에서 안정적인 평행 스키.

**Timing**:
- f0-f6: Crouch (강) - 6 frames
- f6-f10: Takeoff - 4 frames
- f10-f16: Air phase - 6 frames
- f16-f22: Landing - 6 frames

**Mechanics**:
- Crouch: Torso X = -58°, COM drop Y -0.02
- Takeoff: Torso X = -38°; Arms forward X = -20°
- Air: Skis parallel; **nose-up** 미세 Roll +3°, Yaw ±1° 노이즈
- Land: 깊게 흡수 후 -45°로 복원
- Head: f6 posZ -0.03, f10 posY +0.025, f22 baseline

**Keyframe Table**:

| Frame | Node | rotX | rotY | rotZ | posX | posY | posZ |
|-------|------|------|------|------|------|------|------|
| **f0** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -25 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -25 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.01 |
| **f6** | Torso | -58 | 0 | 0 | 0 | -0.02 | 0 |
| | LeftArm | -60 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -60 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.03 |
| | LeftLeg | -8 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | -8 | 0 | 0 | 0 | 0 | 0 |
| **f10** | Torso | -38 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0.025 | -0.01 |
| | Skis | 0 | 0 | +3 | 0 | 0 | 0 |
| **f16** | Torso | -50 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -45 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -45 | 0 | 0 | 0 | 0 | 0 |
| | LeftLeg | -10 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | -10 | 0 | 0 | 0 | 0 | 0 |
| **f22** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | (return to FORWARD pose) |

**Easing**:
- Crouch (f0→f6): easeIn
- Takeoff (f6→f10): easeOut
- Air (f10→f16): linear
- Land (f16→f22): easeInOut

---

### C) BigJump / Drop (30 frames, one-shot)

**Visual**: 높은 지형. 비행시간 길고 착지 충격 큼.

**Timing**:
- f0-f8: Deep Crouch - 8 frames
- f8-f12: Powerful Takeoff - 4 frames
- f12-f22: Long Air - 10 frames
- f22-f30: Hard Landing - 8 frames

**Mechanics**:
- Deep Crouch: Torso X = -62°, Arms X = -60°, COM drop Y -0.03
- Powerful Takeoff: Torso X = -35°; Arms 전방 스윙 X = -10°
- Long Air: Skis parallel; 공중 안정 위해 Torso 미세 Roll(Z) ±2°; Skis Roll(Z) +3° 유지
- Hard Landing: 무릎 크게 굽힘; Torso X = -60° → -45°로 회복; 폴 끝이 지면 가까이
- 착지 2프레임 전 Y -0.01 급락(충격감), 이후 4프레임 동안 댐핑 복원

**Keyframe Table**:

| Frame | Node | rotX | rotY | rotZ | posX | posY | posZ |
|-------|------|------|------|------|------|------|------|
| **f0** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -30 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -30 | 0 | 0 | 0 | 0 | 0 |
| **f8** | Torso | -62 | 0 | 0 | 0 | -0.03 | 0 |
| | LeftArm | -60 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -60 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.04 |
| | LeftLeg | -12 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | -12 | 0 | 0 | 0 | 0 | 0 |
| **f12** | Torso | -35 | 0 | ±2 | 0 | 0 | 0 |
| | LeftArm | -10 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -10 | 0 | 0 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0.03 | -0.02 |
| | Skis | 0 | 0 | +3 | 0 | 0 | 0 |
| **f20** | (Hold air pose) |
| | Torso | -35 | 0 | ±2 | 0 | 0 | 0 |
| | Head | 0 | 0 | 0 | 0 | 0 | -0.01 |
| **f22** | Torso | -60 | 0 | 0 | 0 | -0.01 | 0 |
| | LeftLeg | -15 | 0 | 0 | 0 | 0 | 0 |
| | RightLeg | -15 | 0 | 0 | 0 | 0 | 0 |
| **f26** | Torso | -55 | 0 | 0 | 0 | -0.005 | 0 |
| | LeftArm | -40 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -40 | 0 | 0 | 0 | 0 | 0 |
| **f30** | Torso | -45 | 0 | 0 | 0 | 0 | 0 |
| | (return to FORWARD pose) |

**Easing**:
- Deep Crouch (f0→f8): easeIn
- Takeoff (f8→f12): easeOut
- Long Air (f12→f22): linear
- Landing impact (f22→f26): easeIn (sharp)
- Recovery (f26→f30): easeOut

---

### D) Safety Cancel (18 frames, optional)

**Visual**: 공중에서 착지 직전 스노우플라우로 전환.

**Timing**:
- f0-f12: Normal air phase (from jump)
- f12-f18: Brake preparation - 6 frames

**Mechanics**:
- 마지막 6f 동안 Skis Yaw: Left +12°, Right -12°로 **A자 준비**
- 착지 시 Torso X = -25°(뒤로), Arms X = -20°(앞으로)
- 다음 클립 "BRAKE"에 4f 블렌드

**Keyframe Table**:

| Frame | Node | rotX | rotY | rotZ | posX | posY | posZ |
|-------|------|------|------|------|------|------|------|
| **f0-f11** | (Continue from jump air phase) |
| **f12** | Torso | -40 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | LeftSki | 0 | +12 | 0 | 0 | 0 | 0 |
| | RightSki | 0 | -12 | 0 | 0 | 0 | 0 |
| **f18** | Torso | -25 | 0 | 0 | 0 | 0 | 0 |
| | LeftArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | RightArm | -20 | 0 | 0 | 0 | 0 | 0 |
| | LeftSki | 0 | +15 | 0 | 0 | 0 | 0 |
| | RightSki | 0 | -15 | 0 | 0 | 0 | 0 |
| | (blend to BRAKE in 4f) |

**Easing**:
- Brake prep (f12→f18): easeInOut

---

### Blending Rules

**Entry Blends**:
- FORWARD → SmallHop/Standard/BigJump: 4-6 frames, easeOut
- Any state → SafetyCancel: Immediate (triggered in air)

**Exit Blends**:
- Jump → FORWARD: 6 frames
- Jump → BRAKE: 4 frames (higher priority)
- SafetyCancel → BRAKE: 4 frames

**Additive Layer**:
- Lower-body can have terrain-response vibrations (±1-2°)
- **Head rotation FORBIDDEN** - only translation allowed
- Upper-body follows core animation

---

### Implementation Notes for Godot

**AnimationPlayer Setup**:
1. Create 4 animations: "SmallHop", "StandardJump", "BigJump", "SafetyCancel"
2. Set frame rate to 30 FPS in import settings
3. Disable root motion, disable looping
4. Set `auto_advance = false` (manual control)

**Keyframe Format**:
```gdscript
# Track: "Body/Torso:rotation_degrees"
# Time 0.0 (f0 @ 30fps): Vector3(-45, 0, 0)
# Time 0.133 (f4): Vector3(-55, 0, 0)
# Easing: In (for crouch phase)
```

**Blending Code Example**:
```gdscript
# Entry blend
animation_player.play("StandardJump")
animation_tree.set("parameters/jump_blend/blend_amount", 0.0)
var tween = create_tween()
tween.tween_property(animation_tree, "parameters/jump_blend/blend_amount", 1.0, 0.2)

# Exit blend
animation_player.queue("FORWARD")  # Blend over 6 frames (0.2s at 30fps)
```

**Trigger Logic**:
```gdscript
# Determine jump size based on velocity/context
if abs(velocity.y) < 3.0:
    animation_player.play("SmallHop")
elif abs(velocity.y) < 8.0:
    animation_player.play("StandardJump")
else:
    animation_player.play("BigJump")

# Safety cancel (user presses brake in air)
if is_airborne and Input.is_action_pressed("move_back"):
    animation_player.play("SafetyCancel")
```

---

### Current V2 vs Keyframe Approach

**V2 Procedural** (current implementation):
- ✅ Fully responsive to physics
- ✅ Smooth transitions
- ✅ Adapts to any jump height
- ❌ Less precise posing
- ❌ Cannot achieve complex choreography

**Keyframe-Based** (this specification):
- ✅ Precise control over every pose
- ✅ Professional-quality motion
- ✅ Easier for animators to tweak
- ❌ Fixed timings may not match physics
- ❌ Requires more asset management

**Hybrid Approach** (recommended for future):
- Use keyframe animations for core poses
- Apply procedural layer for physics response
- Blend based on context (small vs big jump)
- Use additive animation for terrain reactions

---

## Trick System

**버전**: V3
**파일**: `scripts/player/player_v3.gd` (트릭 로직), `scripts/ui/trick_score_display.gd` (UI)
**상세 문서**: [TRICKS.md](./TRICKS.md)

### Quick Overview

**구현된 트릭**:
- **Backflip** (S) - 뒤로 회전 (360°/720°/1080°)
- **Frontflip** (W) - 앞으로 회전 (360°/720°/1080°)
- **Tail Grab** (Shift) - 스키 테일 잡기 (콤보 가능)

**트릭 모드**: T 키로 토글 (활성화 시에만 JUMP → FLIP 전환 가능)

**점수 시스템**:
- 360° = 100점, 720° = 250점, 1080° = 450점
- Perfect Landing (±10°) = +50점 보너스
- Good Landing (±30°) = 점수 인정

**주요 기능**:
- Flip과 Grab 동시 수행 가능 (콤보: "Backflip + Tail Grab")
- 실시간 회전각 및 점수 UI 표시
- 착지 정확도 기반 점수 계산

**상세 내용**: 트릭 추가 방법, 아키텍처, 포즈 설계, UI 연동 등은 [TRICKS.md](./TRICKS.md) 참조

---

## Player V3: State Machine (FSM)

**버전**: V3
**파일**: `scripts/player/player_v3.gd`
**목적**: 명확한 상태 구분으로 디버깅 용이, 착지 실패 판정 및 자동 회복

### PlayerState Enum

```gdscript
enum PlayerState {
    IDLE,      // 0 - 정지 상태 (속도 0)
    RIDING,    // 1 - 스키 타는 중
    JUMP,      // 2 - 공중 점프 (트릭 없음)
    FLIP,      // 3 - 공중 트릭 수행 중
    LANDING,   // 4 - 착지 판정 중
    FALLEN,    // 5 - 착지 실패, 넘어짐
    RECOVER    // 6 - 일어나는 중
}
```

---

### State Transition Diagram

```
                          ┌─────────┐
                          │  IDLE   │
                          └────┬────┘
                               │ speed > 0
                               ▼
                          ┌─────────┐
                ┌────────►│ RIDING  │◄────────┐
                │         └────┬────┘         │
                │              │               │
                │              │ Space or      │ Landing success
                │              │ !is_on_floor()│
                │              ▼               │
                │         ┌─────────┐          │
                │         │  JUMP   │          │
                │         └────┬────┘          │
                │              │               │
                │              │ trick_mode ON │
                │              │ height >= 1.5m│
                │              │ W or S pressed│
                │              ▼               │
                │         ┌─────────┐          │
                │         │  FLIP   │          │
                │         └────┬────┘          │
                │              │               │
                │              │ is_on_floor() │
                │              ▼               │
                │         ┌─────────┐          │
                │         │ LANDING │──────────┤
                │         └────┬────┘          │
                │              │               │
                │              │ Landing failed│
                │              ▼               │
                │         ┌─────────┐          │
                │         │ FALLEN  │          │
                │         └────┬────┘          │
                │              │ 1.5s or anim  │
                │              ▼               │
                │         ┌─────────┐          │
                └─────────│ RECOVER │──────────┘
                          └─────────┘
                               │ 1.0s or anim
                               ▼
                          (back to RIDING)
```

---

### State Details

#### IDLE (정지)
- **진입**: `current_speed <= 0` (RIDING에서 전환)
- **입력**: W/S (속도 증가/감소)
- **역할**: 호흡 애니메이션, 입력 대기
- **전환**: `current_speed > 0` → RIDING

#### RIDING (스키 타기)
- **진입**: IDLE에서 `speed > 0` 또는 LANDING/RECOVER 성공 후
- **입력**: W/S/A/D/Space
- **역할**: 일반 스키 이동, 회전, 속도 제어
- **전환**:
  - Space 또는 `!is_on_floor()` → JUMP
  - `current_speed <= 0` → IDLE

#### JUMP (공중 점프)
- **진입**: RIDING에서 Space 또는 낙하
- **입력**: A/D (수평 회전), W/S (FLIP 전환 조건)
- **역할**: 공중 수평 이동 유지
- **트릭**: W/S 입력이 회전 로직 실행 **안 함** (FLIP 전환만)
- **전환**:
  - `trick_mode ON` + `height >= 1.5m` + `W or S` → FLIP
  - `is_on_floor()` → LANDING

#### FLIP (트릭 수행)
- **진입**: JUMP에서 트릭 입력 (W/S) + 조건 충족
- **입력**: W/S (트릭 회전), A/D (수평 회전)
- **역할**: 플립 트릭 수행, 회전 누적
- **트릭**: `_detect_trick_inputs()` 호출, `air_pitch` 누적 (360°/s)
- **전환**: `is_on_floor()` → LANDING

#### LANDING (착지 판정)
- **진입**: JUMP 또는 FLIP에서 착지
- **입력**: 없음 (자동 판정)
- **역할**: 착지 성공/실패 판정
- **판정 조건**:
  - **성공**: `player_up · ground_normal >= 0.7` AND `|pitch/roll| <= 60°` AND `speed >= 1.0`
  - **실패**: 조건 중 하나라도 미충족
- **전환**:
  - 성공 → RIDING
  - 실패 → FALLEN

#### FALLEN (넘어짐)
- **진입**: LANDING 실패
- **입력**: 없음 (자동 대기)
- **역할**: 넘어진 애니메이션 재생
- **물리**: `velocity = 0`, 중력 50% 감소
- **전환**: 1.5초 또는 fall 애니메이션 종료 → RECOVER

#### RECOVER (일어남)
- **진입**: FALLEN 후 자동
- **입력**: 없음 (자동 복귀)
- **역할**: 일어나는 애니메이션 재생, rotation 보정
- **전환**: 1.0초 또는 recover 애니메이션 종료 → RIDING

---

### JUMP vs FLIP 차이점

| 항목 | JUMP 상태 | FLIP 상태 |
|------|-----------|-----------|
| **목적** | 공중 수평 이동만 | 트릭(플립) 수행 |
| **W/S 입력** | FLIP 전환 조건으로만 작동 | 회전 로직 실행 (360°/s) |
| **_detect_trick_inputs()** | 호출 안 함 | 매 프레임 호출 |
| **air_pitch** | 0 유지 | 매 프레임 누적 |
| **trick_rotation_x_total** | 0 유지 | 총 회전각 누적 |
| **착지 점수** | 없음 | _calculate_trick_score() 호출 |
| **중력** | GRAVITY * delta | GRAVITY * delta (동일) |

**핵심**: JUMP는 W/S를 눌러도 회전 안 함. FLIP로 전환만 가능.

---

### Landing Failure Detection

#### 착지 판정 기준 (Tilt-only)

**단일 조건**: 몸체 기울기 (Tilt) 60도 이내

```gdscript
const LANDING_TILT_THRESHOLD = 0.5  # 60° (dot product)

func _check_landing_failed() -> bool:
    # Check body tilt against ground normal
    # IMPORTANT: Use body.transform (rotating Body node), NOT transform (static CharacterBody3D)
    var player_up = body.transform.basis.y
    var ground_normal = get_floor_normal()
    var dot = player_up.dot(ground_normal)

    if dot < LANDING_TILT_THRESHOLD:
        return true  # 착지 실패

    return false  # 착지 성공
```

#### 착지 성공/실패 기준

| 조건 | 성공 | 실패 |
|------|------|------|
| **Tilt** | ≤ 60° (dot ≥ 0.5) | > 60° (dot < 0.5) |
| **Pitch** | ~~제거됨~~ | ~~제거됨~~ |
| **Roll** | ~~제거됨~~ | ~~제거됨~~ |
| **속도** | ~~제거됨~~ | ~~제거됨~~ |

**Transform 주의사항**:
- ✅ **올바름**: `body.transform.basis.y` (회전하는 Body 노드)
- ❌ **틀림**: `transform.basis.y` (고정된 CharacterBody3D)
- Flip 시 Body 노드만 회전하므로 반드시 `body.transform` 사용

---

### Auto Recovery System

**착지 실패 시 자동 회복 흐름**:

```
LANDING (실패 판정)
    ↓
FALLEN (1.5초 대기)
    ↓ fall 애니메이션 종료
RECOVER (1.0초 대기)
    ↓ recover 애니메이션 종료
RIDING (정상 복귀)
```

**FALLEN 상태** (`_process_fallen`):
- `velocity = Vector3.ZERO` (움직임 정지)
- 중력 50% 감소 (`GRAVITY * 0.5`)
- `fallen_timer` 카운트 (1.5초)
- fall 애니메이션 재생

**RECOVER 상태** (`_process_recover`):
- `velocity = Vector3.ZERO` (계속 정지)
- `body.rotation` 보정 (0으로 리셋)
- `recover_timer` 카운트 (1.0초)
- recover 애니메이션 재생

**장점**:
- 플레이어 입력 없이 자동 복귀
- 게임 흐름 끊김 최소화
- 상태 전환 명확

---

### trick_mode와 State Transition

#### trick_mode = false
```
RIDING → JUMP → LANDING → RIDING
         (W/S 입력 무시, FLIP 전환 불가)
```

#### trick_mode = true
```
RIDING → JUMP → FLIP → LANDING → RIDING
         (W/S 입력 시 FLIP 전환)
```

#### JUMP → FLIP 전환 조건

3가지 모두 충족 필요:
1. `trick_mode_enabled = true`
2. `_get_height_above_ground() >= MIN_TRICK_HEIGHT` (1.5m)
3. `Input.is_action_pressed("move_back")` OR `Input.is_action_pressed("move_forward")`

**MIN_TRICK_HEIGHT** (1.5m):
- 너무 낮은 점프에서 트릭 방지
- FLIP 상태에서도 높이 < 1.5m이면 회전 속도 감쇠

---

### State Processing Pattern

**일관된 처리 순서**:

```gdscript
func _process_STATE(delta):
    # 1. 물리 계산 (중력, 점프 속도 등)
    if [physical_condition]:
        velocity.y = ...

    # 2. 입력 처리
    var input = Input.get_...()

    # 3. 로직 실행
    _handle_turning(...)
    _handle_speed(...)

    # 4. velocity 적용
    _apply_velocity(delta)

    # 5. 애니메이션
    _update_animations(...)

    # 6. 상태 전환 (마지막)
    if [transition_condition]:
        set_state(NewState)
```

**핵심 원칙**:
- velocity 적용은 **상태 전환 전**
- 상태 전환은 **함수 마지막**
- 즉시 전환 필요 시 velocity 먼저 적용 후 `return`

---

### Debugging

#### State Label (UI)
```gdscript
@onready var state_label = $UI/StateLabel
func _update_state_ui():
    state_label.text = "State: " + PlayerState.keys()[state]
```

화면에 실시간 상태 표시 (노란색 Label)

#### Console Logs
```
[FSM] IDLE → RIDING
[RIDING] Entered - Ready to ride
[JUMP] Entered - Jumping
[Trick] Starting Backflip!
[LANDING] SUCCESS - All conditions passed
[LANDING] FAILED - Pitch=120.0° (threshold=60.0°)
[FALLEN] Entered - Player fell down
[RECOVER] Entered - Getting back up
[FSM] Resetting body pose to default
```

---

### V2 vs V3 비교

| 기능 | V2 (player_v2.gd) | V3 (player_v3.gd) |
|------|-------------------|-------------------|
| **상태 관리** | JumpState (5개) | PlayerState FSM (7개) |
| **착지 실패** | 없음 | 3가지 조건 체크 |
| **자동 회복** | 없음 | FALLEN → RECOVER → RIDING |
| **UI 상태 표시** | 없음 | StateLabel 실시간 표시 |
| **애니메이션** | Procedural만 | AnimationPlayer + Procedural |
| **디버깅** | 제한적 | 상태 전환 로그 상세 |
| **코드 구조** | 순차 처리 | 상태별 독립 함수 |

---

**Last updated**: 2025-11-15
- V3 FSM added with landing failure detection and auto-recovery
- Landing simplified to tilt-only check (60° threshold)
- Transform bug fixed: use body.transform instead of transform