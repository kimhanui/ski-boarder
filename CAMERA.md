# Camera System Implementation

스키 보더 게임의 카메라 시스템 구현 가이드

## Overview

**4가지 카메라 모드**를 지원하며, **F1 키**로 순환 전환:
1. **3인칭 (뒤)** - 플레이어 뒤에서 바라보는 기본 시점
2. **3인칭 (앞)** - 플레이어 앞에서 바라보는 시점 (역방향)
3. **1인칭** - 플레이어 머리 위치에서의 주관적 시점
4. **프리 카메라** - 자유롭게 지형을 탐색하는 관찰자 모드

## Architecture

### Files
- **`scripts/player/player.gd`**: 카메라 모드 관리 및 전환 로직
- **`scripts/camera/free_camera.gd`**: 프리 카메라 독립 스크립트
- **`scenes/player/player.tscn`**: 4개 Camera3D 노드 정의

### Node Structure
```
Player (CharacterBody3D)
├─ Camera3D_ThirdPerson       # Mode 0: 3rd person back
├─ Camera3D_ThirdPersonFront  # Mode 1: 3rd person front
├─ Camera3D_FirstPerson       # Mode 2: 1st person
└─ Camera3D_Free              # Mode 3: Free camera (with script)
```

---

## Camera Mode Definitions

### Mode 0: 3rd Person (Back) - 3인칭 (뒤)

**Purpose**: 기본 게임플레이 시점, 플레이어 뒤에서 따라가며 전방 시야 확보

**Transform** (`player.tscn`, line 147):
```gdscript
transform = Transform3D(1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 3, 5)
```

**Position**:
- Local `(0, 3, 5)` - 플레이어 기준 뒤쪽 5m, 위쪽 3m
- World space: 플레이어 transform 기준 상대 위치

**Rotation**:
- 약 30° 아래쪽을 바라봄 (`0.866025` = cos(30°), `0.5` = sin(30°))
- 플레이어와 지형을 동시에 볼 수 있는 각도

**Use Cases**:
- 기본 게임플레이
- 장애물 회피
- 경로 선택

---

### Mode 1: 3rd Person (Front) - 3인칭 (앞)

**Purpose**: 플레이어를 정면에서 바라보는 시점, 스키 자세와 표정 확인 가능

**Transform** (`player.tscn`, line 151):
```gdscript
transform = Transform3D(-1, 0, 0, 0, 0.866025, 0.5, 0, 0.5, -0.866025, 0, 3, -5)
```

**Position**:
- Local `(0, 3, -5)` - 플레이어 기준 앞쪽 5m, 위쪽 3m
- 플레이어를 정면에서 바라봄

**Rotation**:
- 180° 회전 (`-1` in X basis, `-0.866025` in Z rotation)
- 약 30° 아래쪽 각도 유지
- 플레이어를 향해 바라보는 방향

**Use Cases**:
- 캐릭터 애니메이션 확인
- 스키 자세 (기울기, 숙임) 관찰
- 표정/얼굴 확인 (눈 표시)
- 연출용 시점

---

### Mode 2: 1st Person - 1인칭

**Purpose**: 플레이어 머리 위치에서의 주관적 시점, 몰입감 극대화

**Transform** (`player.tscn`, line 154):
```gdscript
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.65, 0)
```

**Position**:
- Local `(0, 0.65, 0)` - 플레이어 머리 높이
- Head 노드와 동일한 Y 좌표 (`Body/Head`, line 55)

**Rotation**:
- Identity rotation (플레이어 정면 방향)
- 플레이어 회전에 따라 시점 자동 회전

**Key Implementation** (`player.gd`, line 60):
```gdscript
# 1인칭 모드에서도 플레이어 조작 가능
if camera_mode == 3:  # Only disable in free camera
    return
```

**Use Cases**:
- 몰입형 게임플레이
- 빠른 속도감 체험
- 좁은 경로 통과 (1인칭이 더 쉬울 수 있음)

**Rendering Adjustments** (`player.gd`, line 175):
```gdscript
var hide_eyes = (camera_mode in [2, 3])  # Hide eyes in 1st person and free cam
left_eye.visible = !hide_eyes
right_eye.visible = !hide_eyes
```
- 1인칭에서 눈 메시 숨김 (카메라가 눈 안에 있으므로)

---

### Mode 3: Free Camera - 프리 카메라

**Purpose**: 자유로운 지형 탐색 및 디버깅, 플레이어 조작 비활성화

**Script**: `scripts/camera/free_camera.gd` (119 lines)

**Initial Transform** (`player.tscn`, line 157):
```gdscript
transform = Transform3D(1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 8, 10)
```

**Export Variables** (lines 6-9):
```gdscript
@export var move_speed: float = 50.0              # Base movement speed
@export var fast_speed_multiplier: float = 3.0    # Shift key multiplier
@export var mouse_sensitivity: float = 0.003      # Mouse rotation sensitivity
@export var initial_position: Vector3 = Vector3(0, 100, 100)
```

#### Activation Behavior

**On Activate** (`activate()`, lines 87-102):
```gdscript
func activate() -> void:
    _is_active = true
    current = true

    # Position camera to face player
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var player_pos = player.global_position
        # Position camera behind and above player
        global_position = player_pos + Vector3(0, 5, 10)
        # Look at player
        look_at(player_pos, Vector3.UP)
        # Update rotation variables to match
        _rotation_y = rotation.y
        _rotation_x = rotation.x
```
- 플레이어 뒤쪽 10m, 위쪽 5m로 자동 이동
- 플레이어를 향해 바라보도록 회전
- 안내 메시지 출력

**On Deactivate** (`deactivate()`, lines 106-112):
```gdscript
func deactivate() -> void:
    _is_active = false
    current = false
    if _mouse_captured:
        _mouse_captured = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

#### Control System

**Mouse Rotation** (lines 31-35):
```gdscript
if event is InputEventMouseMotion and _mouse_captured:
    _rotation_y -= event.relative.x * mouse_sensitivity
    _rotation_x -= event.relative.y * mouse_sensitivity
    _rotation_x = clamp(_rotation_x, -PI/2, PI/2)
    _update_camera_rotation()
```
- **우클릭 + 드래그**: 카메라 회전
- X축 회전 제한: -90° ~ +90° (과도한 회전 방지)

**Mouse Capture** (lines 38-45):
```gdscript
if event.button_index == MOUSE_BUTTON_RIGHT:
    if event.pressed:
        _mouse_captured = true
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    else:
        _mouse_captured = false
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

**Keyboard Movement** (lines 55-84):
```gdscript
# WASD movement (relative to camera orientation)
if Input.is_action_pressed("move_forward"):
    input_dir.z += 1
if Input.is_action_pressed("move_back"):
    input_dir.z -= 1
if Input.is_action_pressed("move_left"):
    input_dir.x -= 1
if Input.is_action_pressed("move_right"):
    input_dir.x += 1

# Vertical movement
if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
    input_dir.y += 1
if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
    input_dir.y -= 1

# Speed boost with Shift
var speed = move_speed
if Input.is_action_pressed("sprint"):
    speed *= fast_speed_multiplier
```

**Control Summary**:
| Input | Action |
|-------|--------|
| **Right Click + Drag** | Rotate camera view |
| **W / Up** | Move forward (relative to view) |
| **S / Down** | Move backward |
| **A / Left** | Move left |
| **D / Right** | Move right |
| **Space / E** | Move up (world Y+) |
| **Ctrl / Q** | Move down (world Y-) |
| **Shift + Movement** | Fast movement (3x speed) |
| **F1** | Exit free camera mode |

**Use Cases**:
- 지형 구조 확인
- 디버깅 (플레이어 위치, 장애물 배치)
- 스크린샷 촬영
- 레벨 디자인 평가

---

## Camera Mode Switching

### Implementation

**Main Handler** (`player.gd`, lines 119-125):
```gdscript
func _input(event: InputEvent) -> void:
    # Cycle through camera modes with F1 key
    if event.is_action_pressed("toggle_camera"):
        camera_mode = (camera_mode + 1) % 4
        _apply_camera_mode()
        camera_mode_changed.emit(_get_camera_mode_name())
```

**Mode Application** (`_apply_camera_mode()`, lines 128-152):
```gdscript
func _apply_camera_mode() -> void:
    match camera_mode:
        0:  # Third person back
            camera_third_person.current = true
            camera_third_person_front.current = false
            camera_first_person.current = false
            camera_free.deactivate()
        1:  # Third person front
            camera_third_person.current = false
            camera_third_person_front.current = true
            camera_first_person.current = false
            camera_free.deactivate()
        2:  # First person
            camera_third_person.current = false
            camera_third_person_front.current = false
            camera_first_person.current = true
            camera_free.deactivate()
        3:  # Free camera
            camera_third_person.current = false
            camera_third_person_front.current = false
            camera_first_person.current = false
            camera_free.activate()

    _update_eye_visibility()
```

### Cycle Order

**F1 키 순환**:
```
Mode 0 (3rd Back) → Mode 1 (3rd Front) → Mode 2 (1st Person) → Mode 3 (Free Cam) → Mode 0 ...
```

**Name Mapping** (`_get_camera_mode_name()`, lines 155-167):
```gdscript
func _get_camera_mode_name() -> String:
    match camera_mode:
        0: return "3인칭 (뒤)"
        1: return "3인칭 (앞)"
        2: return "1인칭"
        3: return "프리 카메라"
        _: return "알 수 없음"
```

---

## UI Integration

### Camera Mode Label

**Scene Setup** (`player.tscn`, lines 167-173):
```gdscript
[node name="CameraModeLabel" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 10.0
offset_right = 200.0
offset_bottom = 40.0
theme_override_font_sizes/font_size = 20
text = "카메라: 3인칭 (뒤)"
```

**Signal Connection** (`player.gd`, lines 47-48):
```gdscript
# Connect camera mode signal to UI update
camera_mode_changed.connect(_on_camera_mode_changed)
```

**Update Handler** (`_on_camera_mode_changed()`, lines 208-211):
```gdscript
func _on_camera_mode_changed(mode_name: String) -> void:
    if camera_mode_label:
        camera_mode_label.text = "카메라: " + mode_name
```

**Display Position**: 화면 좌측 상단 (10, 10)

---

## Player Control Integration

### Movement Lock Logic

**Critical Rule** (`player.gd`, lines 58-61):
```gdscript
func _physics_process(delta: float) -> void:
    # Only disable player control in free camera mode
    if camera_mode == 3:
        return
```

**Behavior by Mode**:
| Camera Mode | Player Movement | Use Case |
|-------------|----------------|----------|
| **0: 3rd Back** | ✅ Enabled | Normal gameplay |
| **1: 3rd Front** | ✅ Enabled | Character observation while playing |
| **2: 1st Person** | ✅ Enabled | Immersive gameplay |
| **3: Free Cam** | ❌ Disabled | Terrain inspection only |

**Rationale**:
- Modes 0-2: 게임플레이 중심, 플레이어가 직접 조작
- Mode 3: 관찰 모드, 플레이어는 정지 상태로 카메라만 이동

---

## Eye Visibility System

### Purpose
1인칭 및 프리 카메라에서 눈이 카메라 내부에 있으므로 가시성 문제 방지

### Implementation

**Handler** (`_update_eye_visibility()`, lines 170-177):
```gdscript
func _update_eye_visibility() -> void:
    # Hide eyes in first-person and free camera views
    # Show eyes in third-person views
    if left_eye and right_eye:
        var hide_eyes = (camera_mode in [2, 3])
        left_eye.visible = !hide_eyes
        right_eye.visible = !hide_eyes
```

**Visibility Rules**:
| Camera Mode | Eyes Visible | Reason |
|-------------|-------------|--------|
| **0: 3rd Back** | ✅ Yes | 플레이어를 뒤에서 봄 |
| **1: 3rd Front** | ✅ Yes | 플레이어를 앞에서 봄 |
| **2: 1st Person** | ❌ No | 카메라가 머리 안에 있음 |
| **3: Free Cam** | ❌ No | 카메라가 자유롭게 이동 (가까이 가면 시야 방해) |

---

## Input Mapping

### Required Actions (project.godot)

**Camera Control**:
```gdscript
toggle_camera = F1 key  # Cycle through all 4 modes
```

**Player Movement** (shared with movement system):
```gdscript
move_forward = W / Up
move_back = S / Down
move_left = A / Left
move_right = D / Right
sprint = Shift  # Only used in free camera for fast movement
```

---

## Scene Setup Checklist

### player.tscn Requirements

1. **4 Camera3D Nodes** as children of Player (CharacterBody3D):
   - `Camera3D_ThirdPerson` (mode 0)
   - `Camera3D_ThirdPersonFront` (mode 1)
   - `Camera3D_FirstPerson` (mode 2)
   - `Camera3D_Free` (mode 3, with `free_camera.gd` script)

2. **UI Layer** for camera mode display:
   - `UI` (CanvasLayer)
     - `CameraModeLabel` (Label)

3. **Player Script References** (`player.gd`, lines 15-18):
   ```gdscript
   @onready var camera_third_person = $Camera3D_ThirdPerson
   @onready var camera_third_person_front = $Camera3D_ThirdPersonFront
   @onready var camera_first_person = $Camera3D_FirstPerson
   @onready var camera_free = $Camera3D_Free
   ```

4. **UI Reference** (line 28):
   ```gdscript
   @onready var camera_mode_label = $UI/CameraModeLabel
   ```

5. **Eye References** (lines 24-25):
   ```gdscript
   @onready var left_eye = $Body/Head/LeftEye
   @onready var right_eye = $Body/Head/RightEye
   ```

6. **Initial Camera Mode** (`_ready()`, lines 50-52):
   ```gdscript
   camera_mode = 0
   _apply_camera_mode()
   ```

---

## Debugging & Testing

### Console Output

**Free Camera Activation**:
```
Free camera activated - Right-click and drag to rotate, WASD to move, Space/Ctrl for up/down, Shift for speed
```

**Free Camera Deactivation**:
```
Free camera deactivated
```

**Main Scene Reminder** (`main.gd`, line 18):
```
Press F1 to cycle camera modes
```

### Testing Checklist

- [ ] F1 키로 모든 4개 모드 순환 작동
- [ ] 각 카메라 모드에서 올바른 시점 표시
- [ ] 3인칭(뒤): 플레이어 뒤에서 바라봄
- [ ] 3인칭(앞): 플레이어 앞에서 바라봄
- [ ] 1인칭: 머리 위치에서 정면 바라봄
- [ ] 프리 카메라: 우클릭 드래그로 회전
- [ ] 프리 카메라: WASD로 이동
- [ ] 프리 카메라: Space/Ctrl로 상하 이동
- [ ] 프리 카메라: Shift로 빠른 이동
- [ ] 카메라 모드 라벨 정확히 표시
- [ ] 1인칭/프리카메라에서 눈 숨김
- [ ] 3인칭 모드에서 눈 표시
- [ ] 프리 카메라에서 플레이어 조작 비활성화
- [ ] 다른 모드에서 플레이어 조작 가능

---

## Known Issues & Solutions

### Issue 1: Free Camera Player Position Lost
**Problem**: 프리 카메라로 멀리 이동 후 다른 모드로 전환하면 플레이어 위치를 찾기 어려움

**Solution**: 프리 카메라 비활성화 시 자동으로 플레이어 근처로 이동하는 기능 고려 (TODO)

### Issue 2: 1st Person Motion Sickness
**Problem**: 1인칭 시점에서 빠른 회전/점프 시 멀미 유발 가능

**Potential Solutions**:
- FOV 조정 (좁은 FOV = 덜 멀미)
- Motion blur 감소
- Head bob 애니메이션 제거 (현재 구현 없음)

### Issue 3: Free Camera Mouse Capture
**Problem**: 우클릭 시 마우스가 사라져 처음 사용자는 당황할 수 있음

**Solution**: 초기 안내 메시지로 해결됨 (activate() 시 print)

---

## Future Enhancements (TODO)

### Planned Features

1. **Smooth Camera Transitions**:
   - 모드 전환 시 lerp를 사용한 부드러운 이동
   - 현재: 즉시 전환 (순간 이동)

2. **Dynamic 3rd Person Camera**:
   - 속도에 따라 거리 자동 조절
   - 빠를수록 더 멀리, 넓은 시야

3. **Follow Camera Smoothing**:
   - Spring arm 사용한 부드러운 추적
   - 충돌 감지 및 카메라 위치 조정

4. **Cinematic Camera Mode**:
   - 자동 카메라 경로 재생
   - 리플레이 시스템과 연동

5. **Picture-in-Picture**:
   - 프리 카메라 사용 중 작은 화면에 플레이어 시점 표시
   - ViewportTexture 활용

6. **FOV Dynamic Adjustment**:
   - 속도가 빠를수록 FOV 증가 (터널 비전 효과)
   - 점프 중 FOV 변화

7. **Camera Shake**:
   - 착지 시 카메라 흔들림
   - 충돌 시 임팩트 효과

---

## Performance Considerations

### Current Implementation
- **4 Camera3D nodes**: 항상 존재하지만 하나만 active
- **Minimal overhead**: inactive camera는 렌더링 비용 없음
- **Free camera script**: `_is_active` flag로 불필요한 연산 방지

### Optimization Tips
- 카메라가 멀리 있을 때 LOD 시스템 고려
- Shadow distance 조절로 렌더링 부하 감소
- Culling mask 활용하여 특정 레이어만 렌더링

---

## Integration with Other Systems

### Player Animation
- 카메라 모드에 따라 애니메이션 표시 여부 결정
- 1인칭에서는 몸체 애니메이션 불필요 (보이지 않음)

### UI System
- 카메라 모드 라벨 외에 추가 UI 고려
  - 속도계 (3인칭 모드만)
  - 크로스헤어 (1인칭 모드만)
  - 미니맵 (모든 모드)

### Audio System
- 1인칭 모드에서 AudioListener 위치 변경
- 프리 카메라 모드에서 AudioListener를 카메라에 부착

---

## Code References

### Key Functions

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| `_input()` | player.gd | 119-125 | F1 키 입력 처리 |
| `_apply_camera_mode()` | player.gd | 128-152 | 카메라 활성화/비활성화 |
| `_get_camera_mode_name()` | player.gd | 155-167 | UI 표시 텍스트 생성 |
| `_update_eye_visibility()` | player.gd | 170-177 | 눈 가시성 제어 |
| `activate()` | free_camera.gd | 87-102 | 프리 카메라 활성화 |
| `deactivate()` | free_camera.gd | 106-112 | 프리 카메라 비활성화 |
| `_input()` | free_camera.gd | 26-45 | 마우스 회전 입력 |
| `_physics_process()` | free_camera.gd | 48-84 | 키보드 이동 입력 |

### Signal Flow

```
User presses F1
    ↓
player.gd: _input() detects "toggle_camera"
    ↓
camera_mode = (camera_mode + 1) % 4
    ↓
_apply_camera_mode()
    ↓
Set current camera, activate/deactivate free cam
    ↓
_update_eye_visibility()
    ↓
camera_mode_changed.emit(_get_camera_mode_name())
    ↓
_on_camera_mode_changed() updates UI label
```

---

## Summary

**4-Camera System**:
- **3인칭 (뒤)**: 기본 게임플레이, 전방 시야 확보
- **3인칭 (앞)**: 캐릭터 관찰, 연출용
- **1인칭**: 몰입감, 주관적 시점
- **프리 카메라**: 지형 탐색, 디버깅

**Key Features**:
- F1 키 순환 전환
- 프리 카메라만 플레이어 조작 비활성화
- 1인칭/프리카메라에서 눈 숨김
- UI 라벨로 현재 모드 표시
- 우클릭 드래그 회전 (프리 카메라)
- WASD + Space/Ctrl 이동 (프리 카메라)

**Design Philosophy**:
- **간단하고 직관적**: 하나의 키로 모든 모드 접근
- **유연성**: 다양한 플레이 스타일 지원
- **디버깅 친화적**: 프리 카메라로 레벨 디자인 검증
- **확장 가능**: 추가 카메라 모드 쉽게 추가 가능
