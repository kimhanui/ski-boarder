# Trick System

스키 보더 게임의 공중 트릭 시스템 완전 가이드

**버전**: Player V3
**파일**: `scripts/player/player_v3.gd` (트릭 로직), `scripts/ui/trick_score_display.gd` (UI)

---

## Overview

### 트릭 시스템 소개

스키 보더 게임의 트릭 시스템은 플레이어가 공중에서 화려한 동작을 수행하여 점수를 획득하는 핵심 게임플레이 요소입니다.

**핵심 기능**:
- **Flip 트릭**: 공중에서 전방/후방 회전 (Backflip, Frontflip)
- **Grab 트릭**: 스키나 보드를 잡는 포즈 (Tail Grab)
- **콤보 시스템**: Flip + Grab 동시 수행 가능
- **점수 시스템**: 회전각, 착지 정확도에 따른 점수 계산
- **UI 연동**: 실시간 회전각, 점수 팝업 표시

### Player State Machine 연동

트릭 시스템은 플레이어 상태 머신과 긴밀하게 통합되어 있습니다:

```
PlayerState.JUMP (점프/활공)
  ↓
  조건: trick_mode_enabled AND 높이 >= 1.5m AND (W/S/Shift 입력)
  ↓
PlayerState.FLIP (트릭 수행)
  - 회전 누적
  - 포즈 적용
  - UI 업데이트
  ↓
PlayerState.LANDING (착지)
  - 점수 계산
  - 성공/실패 판정
  - 포즈 리셋
```

### 트릭 모드 토글

**키**: `T` (토글)
**기능**: 트릭 모드 활성화/비활성화
**UI**: `trick_mode_enabled` 표시

**활성화 시**:
- JUMP → FLIP 전환 가능
- 공중에서 W/S/Shift 입력 시 트릭 시작

**비활성화 시**:
- FLIP 전환 불가
- 안전한 점프만 가능

---

## Implemented Tricks

### 1) Backflip

**입력**: `S` 키 (공중에서)
**회전**: `-360°/s` (뒤로)
**조건**: `trick_mode_enabled` + 높이 `>= 1.5m`

**점수 체계**:
- **360°** (1회전): 100점
- **720°** (2회전): 250점
- **1080°** (3회전): 450점
- **Perfect Landing** (±10°): +50점 보너스

**구현 위치**: `player_v3.gd:682-688`

```gdscript
# S → Backflip (backward rotation)
if Input.is_action_pressed("move_backward") and trick_mode_enabled:
    trick_in_progress = true
    if current_trick != "Backflip":
        current_trick = "Backflip"
        print("[Trick] Starting Backflip!")
    trick_flip_speed = -FLIP_ROTATION_SPEED  # -360°/s
```

---

### 2) Frontflip

**입력**: `W` 키 (공중에서)
**회전**: `+360°/s` (앞으로)
**조건**: `trick_mode_enabled` + 높이 `>= 1.5m`

**점수 체계**: Backflip과 동일

**구현 위치**: `player_v3.gd:689-695`

```gdscript
# W → Frontflip (forward rotation)
elif Input.is_action_pressed("move_forward") and trick_mode_enabled:
    trick_in_progress = true
    if current_trick != "Frontflip":
        current_trick = "Frontflip"
        print("[Trick] Starting Frontflip!")
    trick_flip_speed = FLIP_ROTATION_SPEED  # +360°/s
```

---

### 3) Tail Grab

**입력**: `Shift` 키 (공중에서)
**효과**: 레이어로 작동 (Flip과 동시 수행 가능)
**조건**: 공중 상태 (높이 무관)

**포즈 구성**:
- **오른팔**: 뒤로 `-120°` (스키 테일 잡기)
- **왼팔**: 위로 `+45°`, 옆으로 `+30°` (균형 잡기)
- **다리**: 무릎 `-70°` (콤팩트 포즈)
- **상체**: 앞으로 `+35°` (스키 쪽으로 숙임)

**콤보 예시**:
- "Tail Grab" (단독)
- "Backflip + Tail Grab" (콤보)
- "Frontflip + Tail Grab" (콤보)

**구현 위치**:
- 입력 감지: `player_v3.gd:667-680`
- 포즈 적용: `player_v3.gd:728-769`

```gdscript
# Shift → Tail Grab (레이어로 작동)
if Input.is_key_pressed(KEY_SHIFT):
    tail_grab_intensity = lerp(tail_grab_intensity, 1.0, 0.15)
    if not trick_in_progress:
        trick_in_progress = true
        current_trick = "Tail Grab"
        print("[Trick] Starting Tail Grab!")
    elif not current_trick.contains("Tail Grab"):
        # 콤보 감지
        current_trick = current_trick + " + Tail Grab"
        print("[Trick] Combo: %s!" % current_trick)
else:
    tail_grab_intensity = lerp(tail_grab_intensity, 0.0, 0.15)
```

**포즈 적용 함수**:

```gdscript
func _apply_tail_grab_pose(intensity: float) -> void:
    if not (right_arm and left_arm and right_leg and left_leg and torso):
        return

    # 오른팔: 뒤로 뻗어 오른쪽 스키 테일 잡기
    right_arm.rotation_degrees.x = lerp(right_arm.rotation_degrees.x, -120.0 * intensity, 0.2)
    right_arm.rotation_degrees.y = lerp(right_arm.rotation_degrees.y, -30.0 * intensity, 0.2)

    # 왼팔: 균형 잡기 위해 위로 들기
    left_arm.rotation_degrees.x = lerp(left_arm.rotation_degrees.x, 45.0 * intensity, 0.2)
    left_arm.rotation_degrees.z = lerp(left_arm.rotation_degrees.z, 30.0 * intensity, 0.2)

    # 다리: 무릎 강하게 굽히기 (콤팩트 포즈)
    right_leg.rotation_degrees.x = lerp(right_leg.rotation_degrees.x, -70.0 * intensity, 0.2)
    left_leg.rotation_degrees.x = lerp(left_leg.rotation_degrees.x, -70.0 * intensity, 0.2)

    # 상체: 스키 쪽으로 숙이기
    torso.rotation_degrees.x = lerp(torso.rotation_degrees.x, 35.0 * intensity, 0.2)
```

---

## Trick System Architecture

### State Machine Integration

#### JUMP → FLIP 전환 조건

**위치**: `player_v3.gd:478-490`

```gdscript
# JUMP 상태에서 트릭 입력 감지 시 FLIP으로 전환
if state == PlayerState.JUMP:
    if velocity.y < 0 and global_position.y - last_ground_y >= MIN_TRICK_HEIGHT:
        if trick_mode_enabled and (
            Input.is_action_pressed("move_forward") or
            Input.is_action_pressed("move_backward") or
            Input.is_key_pressed(KEY_SHIFT)
        ):
            _transition_to(PlayerState.FLIP)
```

**조건**:
1. `state == PlayerState.JUMP` (점프 중)
2. `velocity.y < 0` (하강 중)
3. `높이 >= MIN_TRICK_HEIGHT` (1.5m)
4. `trick_mode_enabled == true` (트릭 모드 활성화)
5. `W` or `S` or `Shift` 입력

#### FLIP 상태 처리

**위치**: `player_v3.gd:538-554`

```gdscript
PlayerState.FLIP:
    _apply_air_physics(delta)
    _detect_trick_inputs()  # 입력 감지 및 트릭 시작
    _apply_air_trick_rotations()  # Flip 회전 적용

    # Tail Grab 포즈 적용 (독립적)
    if tail_grab_intensity > 0.01:
        _apply_tail_grab_pose(tail_grab_intensity)

    # 착지 감지
    if is_on_floor():
        _transition_to(PlayerState.LANDING)
```

#### LANDING 상태 처리

**위치**: `player_v3.gd:556-575`

```gdscript
PlayerState.LANDING:
    if trick_in_progress:
        var score = _calculate_trick_score()  # 점수 계산
        trick_performed.emit(current_trick, score)  # UI에 시그널
        trick_in_progress = false
        current_trick = ""

    _reset_body_pose()  # 포즈 리셋
    # ... 착지 성공/실패 판정
```

---

### Input Detection

#### _detect_trick_inputs() 함수

**위치**: `player_v3.gd:655-711`

**역할**: FLIP 상태에서 매 프레임 입력 감지 및 트릭 시작

**로직**:
1. **Shift (Tail Grab)** 먼저 체크 (레이어 처리)
   - 이미 다른 트릭 중이면 콤보 생성
   - 트릭 없으면 Tail Grab 단독 시작
2. **W/S (Flip)** 체크
   - Backflip/Frontflip 시작
   - `trick_flip_speed` 설정
3. **입력 없으면**
   - `trick_flip_speed` 감쇠 (0.9 배수)
   - `tail_grab_intensity` 감소 (lerp)

**코드**:

```gdscript
func _detect_trick_inputs() -> void:
    # Shift → Tail Grab (레이어로 작동)
    if Input.is_key_pressed(KEY_SHIFT):
        tail_grab_intensity = lerp(tail_grab_intensity, 1.0, 0.15)
        if not trick_in_progress:
            trick_in_progress = true
            current_trick = "Tail Grab"
        elif not current_trick.contains("Tail Grab"):
            current_trick = current_trick + " + Tail Grab"
    else:
        tail_grab_intensity = lerp(tail_grab_intensity, 0.0, 0.15)

    # S → Backflip
    if Input.is_action_pressed("move_backward") and trick_mode_enabled:
        trick_in_progress = true
        if current_trick != "Backflip":
            current_trick = "Backflip"
        trick_flip_speed = -FLIP_ROTATION_SPEED

    # W → Frontflip
    elif Input.is_action_pressed("move_forward") and trick_mode_enabled:
        trick_in_progress = true
        if current_trick != "Frontflip":
            current_trick = "Frontflip"
        trick_flip_speed = FLIP_ROTATION_SPEED

    # 입력 없으면 회전 감쇠
    else:
        trick_flip_speed *= 0.9
```

---

### Rotation System

#### 핵심 변수

| 변수 | 타입 | 설명 |
|------|------|------|
| `air_pitch` | `float` | Body X축 회전 (도, -180~180) |
| `trick_rotation_x_total` | `float` | 총 회전각 (도, 누적) |
| `trick_flip_speed` | `float` | 회전 속도 (도/초) |
| `FLIP_ROTATION_SPEED` | `const float` | 기본 회전 속도 (360.0) |

#### _apply_air_trick_rotations() 함수

**위치**: `player_v3.gd:713-726`

**역할**: FLIP 상태에서 매 프레임 회전 적용 및 누적

**로직**:
1. 회전각 계산: `rotation_delta = trick_flip_speed * delta`
2. 총 회전각 누적: `trick_rotation_x_total += abs(rotation_delta)`
3. Body 회전 적용: `air_pitch += rotation_delta`
4. Body 노드 적용: `body.rotation_degrees.x = air_pitch`

**코드**:

```gdscript
func _apply_air_trick_rotations() -> void:
    if trick_flip_speed != 0.0:
        var rotation_delta = trick_flip_speed * delta
        trick_rotation_x_total += abs(rotation_delta)
        air_pitch += rotation_delta

    # Body에 회전 적용
    body.rotation_degrees.x = air_pitch
    body.rotation.y = 0.0
    body.rotation_degrees.z = 0.0
```

---

### Score Calculation

#### _calculate_trick_score() 함수

**위치**: `player_v3.gd:826-876`

**역할**: 착지 시 트릭 점수 계산

**점수 공식**:

```
base_score = f(trick_rotation_x_total)
landing_error = abs(air_pitch % 360)  (0~180°)
perfect_landing = landing_error <= 10°
good_landing = landing_error <= 30°

if perfect_landing:
    total_score = base_score + 50
elif good_landing:
    total_score = base_score
else:
    total_score = 0 (착지 실패)
```

**회전각 → 점수 매핑**:

| 회전각 | 점수 |
|--------|------|
| 180° ~ 540° | 100점 |
| 540° ~ 900° | 250점 |
| 900° ~ | 450점 |

**코드**:

```gdscript
func _calculate_trick_score() -> int:
    if not trick_in_progress:
        return 0

    var base_score = 0

    # 회전각에 따른 기본 점수
    if trick_rotation_x_total >= 900:
        base_score = 450  # Triple flip
    elif trick_rotation_x_total >= 540:
        base_score = 250  # Double flip
    elif trick_rotation_x_total >= 180:
        base_score = 100  # Single flip

    # 착지 오차 계산
    var landing_error_raw = abs(fmod(air_pitch, 360.0))
    var landing_error = min(landing_error_raw, 360.0 - landing_error_raw)

    # Perfect Landing 보너스
    if landing_error <= 10.0:
        base_score += 50
        print("[Trick] Perfect Landing! +50 bonus")
    elif landing_error > 30.0:
        print("[Trick] Poor landing, no score")
        return 0

    return base_score
```

---

## Adding New Tricks

### Step-by-Step Guide

새로운 트릭을 추가하려면 다음 단계를 따르세요.

#### Step 1: 상수 추가 (필요 시)

**위치**: `player_v3.gd:34-40`

트릭에 고정 값이 필요하면 상수로 정의:

```gdscript
# Trick system constants
const FLIP_ROTATION_SPEED = 360.0  # degrees per second
const MIN_TRICK_HEIGHT = 1.5       # meters
const SIDE_GRAB_ANGLE = 90.0       # 예시: Side Grab 각도
```

#### Step 2: 변수 추가

**위치**: `player_v3.gd:111-122`

트릭 상태를 추적할 변수 추가:

```gdscript
# Trick state
var trick_in_progress: bool = false
var current_trick: String = ""
var tail_grab_intensity: float = 0.0  # 0.0~1.0
var side_grab_intensity: float = 0.0  # 예시: Side Grab 강도
```

**변수 명명 규칙**:
- `[trick_name]_intensity`: Grab 트릭 강도 (0.0~1.0)
- `[trick_name]_active`: 트릭 활성화 플래그 (bool)
- `[trick_name]_rotation`: 회전 트릭 각도 (float)

#### Step 3: 입력 감지 (_detect_trick_inputs)

**위치**: `player_v3.gd:655-711`

`_detect_trick_inputs()` 함수에 입력 처리 추가:

```gdscript
func _detect_trick_inputs() -> void:
    # 기존 Tail Grab, Flip 코드...

    # 새 트릭: Side Grab (Q 키)
    if Input.is_key_pressed(KEY_Q):
        side_grab_intensity = lerp(side_grab_intensity, 1.0, 0.15)
        if not trick_in_progress:
            trick_in_progress = true
            current_trick = "Side Grab"
            print("[Trick] Starting Side Grab!")
        elif not current_trick.contains("Side Grab"):
            current_trick = current_trick + " + Side Grab"
            print("[Trick] Combo: %s!" % current_trick)
    else:
        side_grab_intensity = lerp(side_grab_intensity, 0.0, 0.15)
```

**입력 우선순위**:
1. Grab 트릭 (Shift, Q 등) - 레이어로 작동
2. Flip 트릭 (W, S) - 배타적 (하나만 선택)

#### Step 4: 포즈 함수 작성

**위치**: `player_v3.gd:728-769` 이후

새 트릭의 포즈 적용 함수 작성:

```gdscript
func _apply_side_grab_pose(intensity: float) -> void:
    """
    Side Grab 포즈 적용
    - 왼팔: 왼쪽으로 뻗어 스키 잡기
    - 오른팔: 균형 잡기
    - 상체: 왼쪽으로 기울이기
    """
    if not (left_arm and right_arm and torso):
        return

    # 왼팔: 왼쪽으로 뻗어 스키 잡기
    left_arm.rotation_degrees.x = lerp(left_arm.rotation_degrees.x, -100.0 * intensity, 0.2)
    left_arm.rotation_degrees.z = lerp(left_arm.rotation_degrees.z, -90.0 * intensity, 0.2)

    # 오른팔: 균형 잡기
    right_arm.rotation_degrees.x = lerp(right_arm.rotation_degrees.x, 30.0 * intensity, 0.2)
    right_arm.rotation_degrees.z = lerp(right_arm.rotation_degrees.z, 20.0 * intensity, 0.2)

    # 상체: 왼쪽으로 기울이기
    torso.rotation_degrees.z = lerp(torso.rotation_degrees.z, -25.0 * intensity, 0.2)
```

**포즈 설계 팁**:
- `lerp(current, target, 0.15~0.2)`: 부드러운 전환
- `intensity`: 0.0~1.0 범위로 포즈 강도 조절
- Torso, Arms, Legs 노드만 조작 (Body는 Flip에서 사용)
- 실제 스키 동작 참고 (유튜브 등)

#### Step 5: 포즈 호출 추가

**위치**: `player_v3.gd:708-710` (FLIP 상태 처리 내)

FLIP 상태에서 포즈 적용 함수 호출:

```gdscript
PlayerState.FLIP:
    # ... 기존 코드 ...

    # Grab 포즈 적용 (독립적)
    if tail_grab_intensity > 0.01:
        _apply_tail_grab_pose(tail_grab_intensity)

    if side_grab_intensity > 0.01:  # 새 트릭 추가
        _apply_side_grab_pose(side_grab_intensity)
```

#### Step 6: 포즈 리셋 (_reset_body_pose)

**위치**: `player_v3.gd:309-320`

착지 시 포즈 리셋에 새 변수 추가:

```gdscript
func _reset_body_pose() -> void:
    air_pitch = 0.0
    tail_grab_intensity = 0.0
    side_grab_intensity = 0.0  # 새 변수 리셋

    # Body, arms, legs rotation 리셋
    if body:
        body.rotation = Vector3.ZERO
    if left_arm and right_arm:
        left_arm.rotation = Vector3.ZERO
        right_arm.rotation = Vector3.ZERO
    # ...
```

#### Step 7: 점수 계산 수정 (선택사항)

**위치**: `player_v3.gd:826-876`

Grab 트릭에 점수를 부여하려면 수정:

```gdscript
func _calculate_trick_score() -> int:
    var base_score = 0

    # 기존 Flip 점수 계산...

    # Grab 보너스 (선택사항)
    if current_trick.contains("Tail Grab"):
        base_score += 20
    if current_trick.contains("Side Grab"):
        base_score += 20

    return base_score
```

---

### Example: Side Grab 전체 구현

```gdscript
# === Step 1: 상수 (필요 시) ===
const SIDE_GRAB_ANGLE = 90.0

# === Step 2: 변수 ===
var side_grab_intensity: float = 0.0

# === Step 3: 입력 감지 (_detect_trick_inputs 내) ===
if Input.is_key_pressed(KEY_Q):
    side_grab_intensity = lerp(side_grab_intensity, 1.0, 0.15)
    if not trick_in_progress:
        trick_in_progress = true
        current_trick = "Side Grab"
    elif not current_trick.contains("Side Grab"):
        current_trick = current_trick + " + Side Grab"
else:
    side_grab_intensity = lerp(side_grab_intensity, 0.0, 0.15)

# === Step 4: 포즈 함수 ===
func _apply_side_grab_pose(intensity: float) -> void:
    if not (left_arm and right_arm and torso):
        return

    left_arm.rotation_degrees.x = lerp(left_arm.rotation_degrees.x, -100.0 * intensity, 0.2)
    left_arm.rotation_degrees.z = lerp(left_arm.rotation_degrees.z, -90.0 * intensity, 0.2)
    right_arm.rotation_degrees.x = lerp(right_arm.rotation_degrees.x, 30.0 * intensity, 0.2)
    torso.rotation_degrees.z = lerp(torso.rotation_degrees.z, -25.0 * intensity, 0.2)

# === Step 5: 포즈 호출 (FLIP 상태 내) ===
if side_grab_intensity > 0.01:
    _apply_side_grab_pose(side_grab_intensity)

# === Step 6: 리셋 (_reset_body_pose 내) ===
side_grab_intensity = 0.0
```

---

## UI Integration

### TrickScoreDisplay

**파일**: `scripts/ui/trick_score_display.gd`
**씬**: `scenes/ui/trick_score_display.tscn`

**기능**:
- 실시간 트릭 이름 표시
- 실시간 회전각 표시 (색상 코드)
- 착지 시 점수 팝업 (2초 페이드)
- 누적 점수 표시

**Signal 연결**:

```gdscript
func _ready():
    var player = get_node("/root/Main/Player")
    player.trick_performed.connect(_on_trick_performed)
```

**주요 함수**:

| 함수 | 역할 |
|------|------|
| `_on_trick_performed(trick_name, score)` | 점수 팝업 표시 |
| `_update_trick_display()` | 실시간 트릭 정보 업데이트 |
| `_get_rotation_color(rotation)` | 회전각에 따른 색상 |

---

### Display Elements

#### 1. Trick Name Label

**노드**: `TrickNameLabel` (Label)
**표시**: 현재 수행 중인 트릭 이름
**조건**: FLIP 상태에서만 표시

```gdscript
if player.state == PlayerState.FLIP:
    trick_name_label.text = player.current_trick
    trick_name_label.visible = true
else:
    trick_name_label.visible = false
```

#### 2. Rotation Label

**노드**: `RotationLabel` (Label)
**표시**: 현재 회전각 (도)
**색상 코드**:
- `< 360°`: 흰색
- `360° ~ 720°`: 노란색
- `720° ~ 1080°`: 주황색
- `>= 1080°`: 빨간색

```gdscript
func _get_rotation_color(rotation: float) -> Color:
    if rotation >= 1080:
        return Color.RED
    elif rotation >= 720:
        return Color.ORANGE
    elif rotation >= 360:
        return Color.YELLOW
    else:
        return Color.WHITE
```

#### 3. Score Popup

**노드**: `ScorePopup` (Label)
**표시**: 착지 시 획득 점수
**애니메이션**: 2초 페이드 아웃

```gdscript
func _on_trick_performed(trick_name: String, score: int):
    score_popup.text = "+%d" % score
    score_popup.modulate.a = 1.0
    score_popup.visible = true

    # 2초 페이드 아웃
    var tween = create_tween()
    tween.tween_property(score_popup, "modulate:a", 0.0, 2.0)
```

#### 4. Total Score Label

**노드**: `TotalScoreLabel` (Label)
**표시**: 누적 점수
**업데이트**: `trick_performed` 시그널 수신 시

---

## Code Reference

### Key Functions

| 함수 | 위치 | 역할 |
|------|------|------|
| `_detect_trick_inputs()` | 655-711 | 입력 감지 및 트릭 시작 |
| `_apply_air_trick_rotations()` | 713-726 | Flip 회전 적용 |
| `_apply_tail_grab_pose(intensity)` | 728-769 | Tail Grab 포즈 적용 |
| `_calculate_trick_score()` | 826-876 | 점수 계산 |
| `_reset_body_pose()` | 309-320 | 착지 시 포즈 리셋 |

---

### Key Variables

| 변수 | 타입 | 설명 | 위치 |
|------|------|------|------|
| `trick_in_progress` | `bool` | 트릭 수행 중 플래그 | 111 |
| `current_trick` | `String` | 현재 트릭 이름 (예: "Backflip + Tail Grab") | 112 |
| `air_pitch` | `float` | Body X축 회전 (도, -180~180) | 113 |
| `trick_rotation_x_total` | `float` | 총 회전각 (도, 누적) | 115 |
| `trick_flip_speed` | `float` | 회전 속도 (도/초) | 116 |
| `tail_grab_intensity` | `float` | Tail Grab 강도 (0.0~1.0) | 121 |
| `trick_mode_enabled` | `bool` | 트릭 모드 활성화 플래그 | 118 |

---

### Key Constants

| 상수 | 값 | 설명 | 위치 |
|------|-----|------|------|
| `FLIP_ROTATION_SPEED` | `360.0` | Flip 회전 속도 (도/초) | 34 |
| `MIN_TRICK_HEIGHT` | `1.5` | 트릭 시작 최소 높이 (m) | 35 |

---

### Key Signals

| 시그널 | 파라미터 | 설명 | 위치 |
|--------|----------|------|------|
| `trick_performed` | `(trick_name: String, score: int)` | 트릭 완료 시 발생 | 90 |
| `trick_mode_changed` | `(enabled: bool)` | 트릭 모드 토글 시 발생 | 91 |

---

## Performance Considerations

### 부드러운 전환

**Lerp 사용**:
- `tail_grab_intensity = lerp(current, target, 0.15)`: 부드러운 강도 전환
- 포즈 적용: `rotation = lerp(current, target, 0.2)`: 자연스러운 회전

**장점**:
- 갑작스러운 포즈 변화 방지
- 자연스러운 애니메이션 효과
- 프레임 독립적 (delta 사용 시)

### 높이 기반 회전 감쇠

**위치**: `player_v3.gd:697-702`

```gdscript
# 낮은 높이에서 회전 속도 감쇠
var current_height = global_position.y - last_ground_y
if current_height < MIN_TRICK_HEIGHT:
    trick_flip_speed *= 0.9
```

**목적**: 착지 직전 과도한 회전 방지

### 점수 계산 최적화

**LANDING 상태에서만 계산**:
- 공중에서는 회전각만 누적
- 착지 시 한 번만 점수 계산
- 불필요한 연산 방지

---

## Known Issues & Limitations

### 현재 제약사항

1. **Grab 트릭 점수 없음**
   - Tail Grab 단독 수행 시 점수 없음
   - Flip과 콤보 시에만 의미 있음

2. **복잡한 콤보 점수 미구현**
   - "Double Backflip + Tail Grab" 같은 복잡한 콤보 점수 계산 없음
   - 현재는 Flip 점수만 반영

3. **애니메이션 시스템**
   - Procedural 애니메이션만 사용 (Node3D 회전)
   - Skeleton + AnimationPlayer 미사용
   - PLAYER_ANIMATION.md의 Skeleton 기반 명세는 구현 안 됨

4. **360° 미만 트릭 미지원**
   - 180° Spin, 90° Turn 등 미구현
   - 최소 180° 이상 회전해야 점수

5. **Y/Z축 회전 트릭 없음**
   - 현재는 X축 회전 (Flip)만 지원
   - Roll, Yaw 트릭 미구현

---

## Future Enhancements

### 계획된 기능

- [ ] **180° Spin 트릭**: 360° 미만 회전 점수 시스템
- [ ] **스키 분리 트릭**: 크로스, 스프레드 포즈
- [ ] **Y축 회전 트릭**: 360°/720° Spin (좌우 회전)
- [ ] **Z축 회전 트릭**: Roll (몸통 굴리기)
- [ ] **Grab 트릭 점수**: Tail Grab, Side Grab 독립 점수
- [ ] **복잡한 콤보 점수**: "Double Backflip + Tail Grab" = 점수 배수
- [ ] **AnimationPlayer 통합**: 키프레임 애니메이션 시스템
- [ ] **트릭 튜토리얼**: 트릭 연습 모드
- [ ] **트릭 리플레이**: 멋진 트릭 다시 보기

### 확장 아이디어

**새로운 Grab 트릭**:
- **Mute Grab**: 앞쪽 스키 잡기
- **Stalefish**: 뒤쪽 다리 사이 잡기
- **Japan Air**: 무릎 굽히고 스키 잡기

**새로운 Flip 트릭**:
- **Misty Flip**: 비스듬한 Backflip
- **Cork**: 비스듬한 Frontflip
- **Rodeo**: 후방 회전 + Spin

**트릭 시스템 개선**:
- 트릭 난이도 시스템 (Easy/Medium/Hard)
- 트릭 언락 시스템 (튜토리얼 클리어 시)
- 트릭 체인 시스템 (연속 트릭 보너스)

---

## Related Documentation

- **[PLAYER.md](./PLAYER.md)** - 플레이어 시스템 전체 가이드
  - 상태 머신 (FSM)
  - 착지 판정
  - 물리 시스템

- **[UI.md](./UI.md)** - UI 시스템 가이드
  - TrickScoreDisplay 상세
  - 기타 UI 요소

- **[PLAYER_ANIMATION.md](./PLAYER_ANIMATION.md)** - Tail Grab 애니메이션 명세
  - Skeleton 기반 애니메이션 설계 (미구현)
  - 외부 참조용 프롬프트

- **[CLAUDE.md](./CLAUDE.md)** - 개발 가이드
  - Godot 프로젝트 구조
  - GDScript 규칙
  - Transform 규칙

---

## Troubleshooting

### 트릭이 시작 안 됨

**체크리스트**:
1. ✅ 트릭 모드 활성화? (`T` 키, `trick_mode_enabled == true`)
2. ✅ 높이 충분? (1.5m 이상)
3. ✅ FLIP 상태? (콘솔에 "[State] FLIP" 확인)
4. ✅ 키 입력 정상? (project.godot 입력 매핑 확인)

### 회전이 누적 안 됨

**원인**: FLIP 상태 전환 실패

**해결**:
```gdscript
# player_v3.gd에서 디버그 출력 확인
print("[State] Current: ", PlayerState.keys()[state])
print("[Trick] Height: ", global_position.y - last_ground_y)
print("[Trick] Mode: ", trick_mode_enabled)
```

### 점수가 0점

**원인**: 착지 오차 > 30°

**해결**:
- 회전각을 360°의 배수에 가깝게 착지
- Perfect Landing (±10°) 연습
- 콘솔에서 `landing_error` 확인

### Grab 포즈가 안 보임

**원인**: intensity가 0.01 이하

**해결**:
```gdscript
# _detect_trick_inputs()에서 디버그 출력
print("[Tail Grab] Intensity: ", tail_grab_intensity)
```

**체크**:
- Shift 키 입력 확인
- `tail_grab_intensity > 0.01` 조건 확인
- `_apply_tail_grab_pose()` 호출 확인

---

## Version History

- **V3 (Current)**: 트릭 시스템 완전 구현
  - Backflip, Frontflip, Tail Grab 추가
  - 점수 시스템 및 UI 연동
  - 콤보 시스템 (레이어)

- **V2**: 기본 점프 및 착지 시스템

- **V1**: 프로토타입

---

**마지막 업데이트**: 2025-12-21
**작성자**: Claude Code
