# CLAUDE.md

이 파일은 이 저장소의 코드 작업 시 Claude Code (claude.ai/code)에 가이드를 제공합니다.

## 프로젝트 개요

스키 보더 게임을 위한 Godot 게임 프로젝트입니다. 현재 초기 설정 단계에 있습니다.

## 개발 명령어

### 게임 실행하기
```bash
# Godot 에디터에서 프로젝트 열기
godot --editor --path .

# 게임 직접 실행
godot --path .

# 특정 씬 실행
godot --path . --scene path/to/scene.tscn
```

### 빌드/내보내기
```bash
# 특정 플랫폼으로 내보내기 (내보내기 프리셋 구성 필요)
godot --export "Platform Name" output_path

# 헤드리스 내보내기 (에디터 창 없음)
godot --headless --export "Platform Name" output_path
```

### 테스트
GDScript 테스트는 일반적으로 GUT (Godot Unit Test) 또는 gdUnit4를 사용합니다:
```bash
# GUT 사용 시 (설치 후)
godot --path . -s addons/gut/gut_cmdln.gd

# gdUnit4 사용 시 (설치 후)
godot --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd
```

## Godot 프로젝트 구조

### 씬 구성
- **scenes/**: 메인 게임 씬 (.tscn 파일)
  - 기능/레벨별로 구성 (예: scenes/levels/, scenes/ui/, scenes/player/)

### 스크립트 구성
- **scripts/**: GDScript 파일 (.gd)
  - 씬 구성을 반영해야 함
  - 전역 스크립트/오토로드는 일반적으로 scripts/autoload/에 위치

### 리소스 구성
- **assets/**: 게임 에셋
  - **sprites/**: 2D 스프라이트 및 텍스처
  - **models/**: 3D 모델 및 메시
  - **audio/**: 효과음 및 음악
  - **fonts/**: 폰트 파일

- **resources/**: Godot 리소스 파일 (.tres)
  - 재사용 가능한 리소스 (재질, 애니메이션, 테마 등)

## 이 프로젝트의 주요 Godot 개념

### 노드 구조
Godot는 트리 기반 노드 시스템을 사용합니다. 스키 보더 게임의 일반적인 노드:
- **CharacterBody2D/3D**: 물리 효과가 적용된 플레이어 스키 보더용
- **Area2D/3D**: 트리거 및 수집 아이템용
- **TileMap**: 지형/슬로프용 (2D)
- **MeshInstance3D**: 지형용 (3D)
- **Camera2D/3D**: 플레이어 추적용

### 시그널
노드 간 분리된 통신을 위한 Godot의 옵저버 패턴입니다. 스크립트 상단에 시그널을 정의합니다:
```gdscript
signal player_crashed
signal trick_completed(trick_name, score)
```

### 오토로드 (싱글톤)
project.godot에 정의된 어디서나 접근 가능한 전역 스크립트입니다. 일반적인 용도:
- 게임 상태 관리
- 점수/진행 상황 추적
- 오디오 관리
- 씬 전환 처리

### 물리 및 움직임
- 플레이어 움직임과 물리에는 `_physics_process(delta)` 사용
- CharacterBody2D/3D는 충돌 인식 움직임을 위한 `move_and_slide()` 제공
- 스키 물리를 위해 중력, 가속도, 운동량을 고려

## GDScript 규칙

### 파일 구조
```gdscript
extends NodeType  # 또는 class_name ClassName

# 시그널
signal signal_name

# 상수
const CONSTANT_NAME = value

# 내보낸 변수 (에디터에 표시됨)
@export var variable_name: Type = default_value

# 공개 변수
var public_variable: Type

# 비공개 변수 (밑줄 접두사)
var _private_variable: Type

# Onready 변수 (노드가 준비되면 초기화)
@onready var _node_ref = $NodePath

# 내장 콜백
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

# 공개 메서드
func public_method() -> void:
    pass

# 비공개 메서드
func _private_method() -> void:
    pass
```

### 명명 규칙
- 파일: snake_case.gd (예: player_controller.gd)
- 클래스: PascalCase (예: PlayerController)
- 변수/함수: snake_case (예: jump_force, calculate_speed())
- 상수: SCREAMING_SNAKE_CASE (예: MAX_SPEED)
- 비공개 멤버: 밑줄 접두사 (예: _internal_state)
- 시그널: 과거형, snake_case (예: health_changed, enemy_died)

## 프로젝트 구성

project.godot 파일에는 다음이 포함됩니다:
- 프로젝트 설정 및 메타데이터
- 오토로드 구성
- 입력 매핑
- 디스플레이/렌더링 설정
- 물리 레이어 이름

컨트롤을 구현할 때는 항상 project.godot에서 입력 액션 이름을 확인하세요.

## Godot 버전

project.godot의 `config_version`과 `features`를 확인하여 Godot 버전을 파악하세요. GDScript 구문은 Godot 3.x와 4.x 간에 차이가 있습니다:
- Godot 4.x는 `@export`, `@onready`, `@tool` 어노테이션 사용
- Godot 3.x는 `export`, `onready`, `tool` 키워드 사용

## Godot 3D 좌표계

**중요**: Godot 3D 좌표계는 특정 방향 규칙을 따릅니다. 속도/이동 벡터 계산 시 반드시 주의해야 합니다.

### 좌표축 방향
- **전방 (Forward)**: -Z 축 (음수 Z 방향)
- **오른쪽 (Right)**: +X 축 (양수 X 방향)
- **위쪽 (Up)**: +Y 축 (양수 Y 방향)

### Y축 회전 값 (Yaw)
- `rotation.y = 0`: 전방 방향 (-Z)
- `rotation.y = PI/2` (90도): 왼쪽 방향 (+X)
- `rotation.y = -PI/2` (-90도): 오른쪽 방향 (-X)
- `rotation.y = PI` (180도): 후방 방향 (+Z)

### 속도 벡터 계산 시 주의사항

**잘못된 예시** (전방 대신 후방으로 이동):
```gdscript
# ❌ 잘못됨: 이렇게 하면 전방(W) 입력 시 뒤로 이동합니다!
var heading = rotation.y
var velocity_dir = Vector3(sin(heading), 0, cos(heading))
velocity = velocity_dir * speed
```

**올바른 예시** (의도한 대로 전방으로 이동):
```gdscript
# ✅ 올바름: Godot의 forward = -Z를 고려하여 부호 반전
var heading = rotation.y
var velocity_dir = Vector3(-sin(heading), 0, -cos(heading))
velocity = velocity_dir * speed
```

### 권장 방법: transform.basis 사용

수학적 계산 대신 Godot의 내장 transform을 사용하면 좌표계 문제를 피할 수 있습니다:
```gdscript
# ✅ 가장 안전한 방법: transform.basis 사용
var forward_dir = -transform.basis.z  # 객체의 전방 방향
var right_dir = transform.basis.x     # 객체의 오른쪽 방향
var up_dir = transform.basis.y        # 객체의 위쪽 방향

# 전방으로 이동
velocity = forward_dir * speed
```

### 실전 예시

**플레이어 이동** (player_v2.gd 참조):
```gdscript
# 스키 방향(velocity_heading)으로 이동할 때
var velocity_dir = Vector3(-sin(velocity_heading), 0, -cos(velocity_heading))
velocity.x = velocity_dir.x * current_speed
velocity.z = velocity_dir.z * current_speed
```

**회전 후 전방으로 이동**:
```gdscript
# 플레이어가 30도 왼쪽으로 회전한 상태에서 전방으로 이동
rotation.y = deg_to_rad(30)  # 30도 회전
var forward = -transform.basis.z
velocity = forward * speed  # 회전된 전방 방향으로 이동
```

### 디버깅 팁

좌표계 문제가 의심될 때:
1. `print("Forward: ", -transform.basis.z)`로 전방 벡터 확인
2. `print("Rotation Y: ", rotation.y)`로 회전 값 확인
3. `print("Velocity: ", velocity)`로 최종 속도 벡터 확인
4. 씬 뷰에서 화살표 기즈모로 축 방향 시각적 확인

## ADD.md 파일 관리

**목적**: Claude Code를 위한 프롬프트 및 작업 명세 파일

**위치**: 프로젝트 루트 (`ADD.md`)

**버전 관리**:
- `.gitignore`에 추가되어 Git에 커밋되지 않음
- 로컬 환경에만 존재하는 개인 작업 파일

**사용 가이드**:
1. **새 기능 개발 시**: Claude에게 전달할 상세 명세를 ADD.md에 작성
2. **작업 중**: 필요에 따라 내용 업데이트
3. **작업 완료 후**: 파일을 **삭제하지 않고 보관** (다음 작업 참조용)
4. **팀 협업**: 각 개발자가 개별적으로 관리 (공유 불필요)

**주의사항**:
- ❌ 절대 Git에 커밋하지 말것 (`.gitignore`에 이미 등록됨)
- ❌ 작업 완료 후 삭제하지 말것
- ✅ 로컬에 계속 유지하며 필요시 참조
- ✅ 새 프롬프트 작성 시 기존 내용 덮어쓰기 가능

**예시 워크플로우**:
```bash
# 1. 새로운 기능 명세 작성
# ADD.md에 Claude용 프롬프트 작성

# 2. Claude Code에 작업 요청
# Claude가 ADD.md를 참조하여 작업 수행

# 3. 작업 완료 후
# ADD.md는 그대로 두고, 필요시 다음 작업 명세로 업데이트

# 4. Git 상태 확인
git status  # ADD.md가 목록에 나타나지 않아야 함 (.gitignore 적용)
```

## Godot 4 그림자 렌더링 설정

Godot 4에서 3D 그림자가 제대로 렌더링되려면 여러 설정이 올바르게 구성되어야 합니다.

### ⚠️ 중요 주의사항 (이 프로젝트 전용)

**CRITICAL**: 이 프로젝트에서는 다음 설정을 **절대 사용하지 말 것**:

```gdscript
# ❌ 절대 사용 금지 - 그림자가 완전히 사라짐
directional_light.light_angular_distance = 0.5  # NEVER USE THIS!
```

**원인**: 프로젝트 특정 설정이나 Godot 버전 이슈로 `light_angular_distance` 설정 시 그림자가 사라지는 현상 확인됨

**필수 고정값**:
```gdscript
# ✅ 반드시 이 값으로 고정
directional_light.directional_shadow_max_distance = 500.0
```
- 이 값을 변경하면 그림자가 사라지거나 품질이 저하됨
- 500m 외의 값은 테스트 결과 그림자 렌더링 실패

**참고**: `scenes/main.gd`의 `_enforce_shadow_settings()` 함수에 경고 주석 포함

### 필수 프로젝트 설정 (project.godot)

렌더러 및 그림자 품질 설정:
```ini
[rendering]
renderer/rendering_method="forward_plus"
lights_and_shadows/directional_shadow/size=4096
lights_and_shadows/directional_shadow/soft_shadow_filter_quality=3
shadows/positional_shadow/atlas_size=2048
shadows/positional_shadow/atlas_quadrant_0_subdiv=2
shadows/positional_shadow/atlas_quadrant_1_subdiv=2
shadows/positional_shadow/atlas_quadrant_2_subdiv=2
shadows/positional_shadow/atlas_quadrant_3_subdiv=2
```

**핵심 설정**:
- `forward_plus`: Godot 4의 고품질 렌더러 (그림자 지원 필수)
- `directional_shadow/size`: 방향성 광원 그림자 해상도 (4096 권장)
- `soft_shadow_filter_quality`: 부드러운 그림자 필터 품질 (3 = 최고)

### DirectionalLight3D 설정

광원 노드에 필수 설정:
```gdscript
shadow_enabled = true
shadow_opacity = 1.0                       # 그림자 진하기 (1.0 = 완전 불투명)
shadow_bias = 0.1                          # 섀도우 아크네 방지
shadow_normal_bias = 1.0                   # 노말 기반 바이어스
directional_shadow_max_distance = 3000.0   # 그림자 렌더링 거리
directional_shadow_fade_start = 0.8        # 페이드 시작 지점 (0.8 = 80%)
```

**수직 광원 설정** (정수리에서 아래로):
```gdscript
# Transform3D for vertical downward light (rotation_degrees = -90, 0, 0)
transform = Transform3D(1, 0, 0, 0, -4.37114e-08, 1, 0, -1, -4.37114e-08, 0, 10, 0)
```

### 메시 그림자 설정

#### 그림자를 생성하는 메시 (MeshInstance3D)
```gdscript
mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
```

#### 그림자를 받는 메시 (지형 등)
```gdscript
mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON  # 자체 그림자도 생성
mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC  # 그림자 수신 활성화

# 머티리얼도 올바르게 설정
material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # Unshaded 아님!
```

### 런타임에서 플레이어 메시 그림자 활성화

플레이어의 모든 메시에 그림자를 활성화하는 예시 (player_v2.gd:1119-1175):
```gdscript
func _enable_player_shadows() -> void:
	# 모든 MeshInstance3D 노드 수집
	var mesh_nodes = []

	# Body 파트 메시 추가
	if head and head is MeshInstance3D:
		mesh_nodes.append(head)
	if torso and torso is MeshInstance3D:
		mesh_nodes.append(torso)

	# 팔, 다리, 스키 등 모든 메시 추가...

	# 모든 메시에 그림자 활성화
	for node in mesh_nodes:
		if node:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	print("[Player] Shadows enabled for %d meshes" % mesh_nodes.size())

# _ready()에서 호출
func _ready() -> void:
	_enable_player_shadows()
```

### 지형 머티리얼 설정

순백색 눈 지형 (terrain_generator.gd:259-268):
```gdscript
var material = StandardMaterial3D.new()
material.albedo_color = Color(1.0, 1.0, 1.0)  # 순백색
material.roughness = 0.3
material.metallic = 0.0
material.emission_enabled = true
material.emission = Color(1.0, 1.0, 1.0)  # 순백색 emission (회색 피하기)
material.emission_energy_multiplier = 0.3
material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
```

**중요**: `emission` 색상이 회색이면 지형이 회색으로 보입니다. 순백색 눈을 표현하려면 `Color(1.0, 1.0, 1.0)` 사용.

### 문제 해결 체크리스트

그림자가 보이지 않을 때:

1. **프로젝트 설정**
   - ✅ `rendering_method = "forward_plus"`
   - ✅ `directional_shadow/size ≥ 4096`
   - ✅ `soft_shadow_filter_quality ≥ 1`

2. **광원 설정**
   - ✅ `shadow_enabled = true`
   - ✅ `directional_shadow_max_distance` 충분히 큼 (≥ 2000)
   - ✅ `shadow_bias`, `shadow_normal_bias` 설정됨

3. **메시 설정**
   - ✅ 그림자 생성 메시: `cast_shadow = ON`
   - ✅ 그림자 수신 메시: `cast_shadow = ON`, `gi_mode = STATIC`
   - ✅ 머티리얼: `shading_mode = PER_PIXEL` (Unshaded 아님)

4. **레이어/마스크**
   - ✅ MeshInstance3D의 `layers`와 Light3D의 `light_cull_mask`가 교집합 있음

### 참고 파일

- `project.godot`: 렌더링 설정
- `scenes/main.tscn`: DirectionalLight3D 설정
- `scripts/player/player_v2.gd`: 플레이어 메시 그림자 활성화
- `scripts/terrain/terrain_generator.gd`: 지형 메시 및 머티리얼

## Godot 부모-자식 Transform 규칙

**중요**: Godot의 씬 트리에서 자식 노드는 부모의 transform(위치, 회전, 스케일)을 자동으로 상속받습니다. 이 규칙을 무시하면 예상치 못한 버그가 발생합니다.

### 핵심 원칙

1. **자식은 부모 transform을 자동 상속**
   - 부모 노드가 회전하면 자식도 자동으로 회전
   - 부모 노드가 이동하면 자식도 자동으로 이동
   - 추가 코드 불필요 - 씬 트리가 자동 처리

2. **자식의 transform은 로컬 좌표계**
   - `child.position` = 부모 기준 상대 위치
   - `child.rotation` = 부모 기준 상대 회전
   - `child.global_position` = 월드 좌표계 절대 위치

3. **부모 회전 시 자식의 로컬 축도 회전**
   - 부모가 180° 회전하면 자식의 Z축도 반대 방향을 가리킴
   - 이 상태에서 `child.position.z`를 수정하면 예상과 다른 방향으로 이동

### 자식 노드 조작 시 주의사항

#### ❌ 하지 말 것

**1. 부모가 회전 중일 때 자식 position을 독립적으로 수정**
```gdscript
# ❌ 버그 발생 코드
func apply_flip():
    body.rotation_degrees.x = 180.0  # Body가 뒤집힘
    head.position.z = -1.0  # Head의 Z축도 뒤집혀서 반대 방향으로 이동!
```

**2. 부모 회전을 무시하고 자식 rotation을 강제로 0으로 설정**
```gdscript
# ❌ 버그 발생 코드
func apply_flip():
    body.rotation_degrees.x = 180.0
    head.rotation = Vector3.ZERO  # 로컬 회전만 0, 글로벌로는 여전히 180° 회전됨
```

**3. 로컬/글로벌 좌표계 혼동**
```gdscript
# ❌ 헷갈리는 코드
head.position.y = 0.5  # 로컬 좌표 (부모 기준)
head.global_position.y = 10.0  # 글로벌 좌표 (월드 기준)
# 위 두 줄이 동시에 실행되면 충돌 발생
```

#### ✅ 해야 할 것

**1. 부모-자식 관계를 최대한 활용 (자동 상속)**
```gdscript
# ✅ 올바른 코드
func apply_flip():
    body.rotation_degrees.x = air_pitch  # Body가 회전
    # Head는 자식이므로 자동으로 따라 회전 - 추가 코드 불필요!
```

**2. 특별한 이유 없이 자식을 독립 제어하지 않음**
```gdscript
# ✅ 올바른 코드 - 의도가 명확한 경우만 수정
func apply_breathing_animation():
    # 호흡 애니메이션: 머리를 앞뒤로 미세하게 움직임
    # 이것은 의도된 독립 제어
    head.position.z = sin(breathing_phase) * 0.02
```

**3. 수정 전 체크리스트 확인**
```gdscript
# ✅ Transform 수정 전 자문
# 1. 이 노드의 부모는? (print(node.get_parent().name))
# 2. 부모가 회전/이동 중인가? (print(parent.rotation))
# 3. 로컬 vs 글로벌 의도가 명확한가?
# 4. 내가 원하는 효과가 이미 부모에서 처리되는가?
```

### 실제 버그 사례: Flip 시 머리 떨어지는 버그

**버그 상황**:
- 플레이어가 backflip 트릭 수행 시 머리가 몸에서 떨어져 나가는 것처럼 보임

**씬 구조**:
```
Player (CharacterBody3D)
└── Body (Node3D)  ← 회전 적용 대상
    ├── Head (MeshInstance3D)  ← Body의 자식
    ├── Torso
    ├── Arms
    └── Legs
```

**버그 코드** (player_v2.gd:936-939):
```gdscript
func _apply_air_trick_rotations() -> void:
    body.rotation_degrees.x = air_pitch  # Body가 회전
    body.rotation.y = 0.0
    body.rotation_degrees.z = 0.0

    # ❌ 버그: Head position을 독립적으로 수정
    head.rotation = Vector3.ZERO
    var head_forward_offset = -air_pitch * 0.01
    head.position.z = head_forward_offset  # ← 문제 발생!
```

**버그 원인**:
1. Body가 180° 회전 → Head의 로컬 Z축도 180° 회전하여 반대 방향을 가리킴
2. `head.position.z = -1.8` 설정 → 회전된 Z축 방향으로 이동 = 반대로 밀려남
3. 결과: 머리가 몸에서 떨어져 나간 것처럼 보임

**수정 코드**:
```gdscript
func _apply_air_trick_rotations() -> void:
    body.rotation_degrees.x = air_pitch  # Body가 회전
    body.rotation.y = 0.0
    body.rotation_degrees.z = 0.0

    # ✅ 수정: Head는 자식이므로 자동으로 body 회전을 따라감
    # head.position이나 head.rotation을 별도로 수정하지 않음
    if head:
        head.rotation = Vector3.ZERO  # 리셋용 (착지 후)
        # head.position.z 수정 삭제됨
```

### 코드 작성 시 체크리스트

Transform 관련 코드를 작성할 때 다음을 확인하세요:

1. **계층 구조 확인**
   ```gdscript
   print("Parent: ", node.get_parent().name)
   print("Children: ", node.get_children())
   ```

2. **부모 상태 확인**
   ```gdscript
   var parent = node.get_parent()
   print("Parent rotation: ", parent.rotation)
   print("Parent position: ", parent.position)
   ```

3. **로컬 vs 글로벌 명확히**
   ```gdscript
   # 로컬 좌표 (부모 기준)
   node.position = Vector3(1, 0, 0)

   # 글로벌 좌표 (월드 기준)
   node.global_position = Vector3(10, 5, 0)
   ```

4. **자문하기**
   - "부모가 이미 이 변형을 하고 있는가?"
   - "자식을 독립적으로 제어해야 할 명확한 이유가 있는가?"
   - "의도한 효과가 부모 변형만으로 달성 가능한가?"

### 디버깅 팁

Transform 버그 의심 시:

```gdscript
# 현재 transform 상태 출력
print("=== Transform Debug ===")
print("Node: ", node.name)
print("Parent: ", node.get_parent().name)
print("Local position: ", node.position)
print("Global position: ", node.global_position)
print("Local rotation: ", node.rotation_degrees)
print("Global rotation: ", node.global_rotation_degrees)
print("Local basis.z: ", node.transform.basis.z)
print("Global basis.z: ", node.global_transform.basis.z)
```

### 요약

- **원칙**: 자식은 부모를 따라간다 - 추가 조작 최소화
- **주의**: 부모 회전 중일 때 자식 position/rotation 수정 금지
- **체크**: Transform 수정 전 부모 상태 확인
- **디버그**: 로컬/글로벌 좌표 차이 확인

## Godot 입력 처리 규칙

**중요**: Godot의 입력 처리 시스템에서는 GUI와 게임 로직이 입력 우선권을 공유합니다. 잘못된 입력 메서드 사용 시 UI 버튼이 작동하지 않는 버그가 발생합니다.

### 핵심 원칙

**게임 로직 (플레이어, 카메라 등)**: `_unhandled_input()` 사용
**GUI 내부 (버튼 클릭 처리)**: `_gui_input()` 또는 Signal 사용
**저수준 입력 (거의 안 씀)**: `_input()` 사용

### Godot 입력 처리 흐름

```
사용자 입력 (마우스 클릭, 키보드 등)
  ↓
1. _input() ← 원시 입력 (저수준 처리용)
  ↓
2. GUI 처리 ← Button, TextEdit 등이 여기서 처리
  ↓ (GUI가 처리했으면 여기서 멈춤)
  ↓
3. _unhandled_input() ← GUI가 처리 안 한 것만 여기로
  ↓
4. _unhandled_key_input() ← 키보드만
```

### 입력 메서드 비교

| 메서드 | 용도 | GUI 우선권 | 사용 대상 |
|--------|------|-----------|----------|
| `_input()` | 원시 입력 (저수준) | ❌ GUI보다 먼저 | 거의 사용 안 함 |
| `_gui_input()` | GUI 노드 전용 | ✅ GUI 내부 | Button, Control 등 |
| `_unhandled_input()` | 게임 로직 | ✅ GUI 이후 | **Player, Camera 등** |
| `_unhandled_key_input()` | 키보드만 | ✅ GUI 이후 | 키보드 전용 처리 |

### 입력 메서드 선택 가이드

#### ❌ 하지 말 것

**잘못된 예시 1: 게임 로직에 _input() 사용**
```gdscript
# ❌ 잘못: Player에서 _input() 사용
extends CharacterBody3D

func _input(event):
    if event.is_action_pressed("jump"):
        jump()  # 문제: GUI 버튼 클릭 시에도 이 코드가 먼저 실행됨!
```

**문제점**:
- UI에 Button이 있을 때 마우스 클릭이 Player._input()으로 먼저 감
- Button까지 이벤트가 전달 안 됨 → **버튼 클릭 안 됨**
- Space 키로 Button 클릭 시도 → Player가 점프 → **버튼 클릭 안 됨**

#### ✅ 해야 할 것

**올바른 예시 1: 게임 로직에 _unhandled_input() 사용**
```gdscript
# ✅ 올바름: Player에서 _unhandled_input() 사용
extends CharacterBody3D

func _unhandled_input(event):
    if event.is_action_pressed("jump"):
        jump()  # GUI가 먼저 처리하고, 처리 안 한 것만 여기로 옴
```

**장점**:
- UI Button 클릭 시 GUI가 먼저 처리 → Player는 이벤트를 받지 않음
- Space 키로 Button 클릭 시 Button이 먼저 처리 → Player는 반응 안 함
- 마우스, 키보드, 터치스크린 모두 자동으로 처리됨

**올바른 예시 2: GUI에서 Signal 사용**
```gdscript
# ✅ 올바름: Button에서 Signal 사용
extends Button

func _ready():
    pressed.connect(_on_button_pressed)

func _on_button_pressed():
    print("Button clicked!")
```

### 실제 버그 사례: UI 버튼 클릭 안 됨

**버그 상황**:
- DifficultySelector, DensityControls 버튼 클릭 안 됨
- 마우스 커서는 버튼 위에 있고 hover 효과도 보이지만 클릭 안 됨

**씬 구조**:
```
Main (Node3D)
├─ Player (CharacterBody3D) ← _input() 사용 중
└─ UI (CanvasLayer)
   ├─ DifficultySelector (Control)
   │  └─ EasyButton (Button)
   └─ DensityControls (VBoxContainer)
      └─ IncreaseButton (Button)
```

**버그 코드** (player_v3.gd:928):
```gdscript
# ❌ 버그 발생 코드
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_camera"):
        camera_mode = (camera_mode + 1) % 4
        # ...

    if event.is_action_pressed("respawn"):
        respawn()

    # 문제: Player가 모든 입력을 먼저 받음 → GUI까지 전달 안 됨
```

**버그 원인**:
1. 사용자가 Button 클릭 (마우스)
2. Player._input()이 먼저 받음
3. `is_action_pressed()` 체크 시 이벤트를 "터치"함
4. Godot가 "이 이벤트는 처리됨"으로 간주할 수 있음
5. GUI까지 이벤트가 전달 안 됨 → **Button 클릭 안 됨**

**수정 코드**:
```gdscript
# ✅ 수정: _input() → _unhandled_input()
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_camera"):
        camera_mode = (camera_mode + 1) % 4
        # ...

    if event.is_action_pressed("respawn"):
        respawn()

    # GUI가 먼저 처리하고, 처리 안 한 것만 여기로 옴
```

**수정 후 동작**:
1. 사용자가 Button 클릭
2. GUI가 먼저 처리 (Button 클릭 처리)
3. GUI가 처리했으므로 _unhandled_input()은 **호출 안 됨**
4. ✅ **Button 정상 작동**

### 추가 시나리오: 키보드 입력

**시나리오**: TextEdit에 "hello" 입력

**_input() 사용 시 (버그)**:
```
사용자: "h" 입력
  ↓
Player._input()이 "h" 받음
  ↓
"h"가 move_left 액션에 매핑되어 있다면?
  → Player가 왼쪽으로 이동!
  ↓
TextEdit에 "h" 안 들어가거나 동시에 Player 이동
```

**_unhandled_input() 사용 시 (정상)**:
```
사용자: "h" 입력
  ↓
GUI 체크: TextEdit에 포커스 있는가?
  ↓
YES → TextEdit이 "h" 처리 → 끝!
  ↓
Player._unhandled_input()은 호출 안 됨
```

### 코드 작성 시 체크리스트

입력 처리 코드를 작성할 때 다음을 확인하세요:

1. **노드 타입 확인**
   - CharacterBody3D, Camera3D, Area3D 등 게임 로직? → `_unhandled_input()`
   - Button, Control, TextEdit 등 GUI? → `_gui_input()` 또는 Signal

2. **GUI 존재 확인**
   - 프로젝트에 UI 버튼이 있는가? → `_unhandled_input()` 필수
   - 미래에 UI 추가 가능성? → `_unhandled_input()` 사용

3. **입력 타입 고려**
   - 마우스만? → `_unhandled_input()`
   - 키보드도? → `_unhandled_input()`
   - 터치스크린? → `_unhandled_input()`
   - **결론**: 항상 `_unhandled_input()` 사용

4. **자문하기**
   - "이 노드가 GUI 입력을 가로챌 수 있는가?"
   - "UI 버튼과 입력이 충돌할 가능성이 있는가?"
   - "YES"라면 → `_unhandled_input()` 사용

### 디버깅 팁

UI 버튼 클릭 안 될 때:

```gdscript
# 입력 처리 디버깅
func _input(event):
    print("[_input] Event: ", event)  # 모든 이벤트 출력

func _unhandled_input(event):
    print("[_unhandled_input] Event: ", event)  # GUI 처리 후 남은 이벤트 출력
```

**정상 동작 시**:
```
# Button 클릭 시
[_input] Event: InputEventMouseButton (Button 0, Pressed)
# [_unhandled_input] 출력 없음 ← GUI가 처리했으므로

# 빈 공간 클릭 시
[_input] Event: InputEventMouseButton (Button 0, Pressed)
[_unhandled_input] Event: InputEventMouseButton (Button 0, Pressed)
```

### 요약

- **게임 로직**: `_unhandled_input()` 사용 (Player, Camera 등)
- **GUI 로직**: `_gui_input()` 또는 Signal 사용 (Button, Control 등)
- **원칙**: GUI가 먼저 처리하게 하라
- **재발 방지**: CharacterBody3D, Area3D 등에서 `_input()` 사용 금지

## 디버깅 및 문제 분석 규칙

**중요**: 코드를 읽고 문제를 추측하는 것은 좋지만, **검증 없는 가정은 위험**합니다. 반드시 실제 동작을 확인하고, 근거 있는 결론만 내려야 합니다.

### 핵심 원칙

1. **검증 없는 가정 금지**
   - 코드를 읽고 가설을 세우되, 반드시 검증
   - "이게 문제일 것이다" → "이게 문제인지 확인한다"

2. **실제 동작 확인 우선**
   - 사용자 보고를 듣고 바로 추측하지 말고
   - 실제로 재현되는지 확인
   - 재현 안 되면 사용자에게 재확인

3. **Godot 공식 문서 참조**
   - 추측하지 말고 공식 문서 확인
   - 예: "_input()이 이벤트를 소비하는가?" → 문서 확인

### Godot 입력 이벤트 소비 규칙

**잘못된 이해** (흔한 오해):
```gdscript
func _input(event):
    # 이 함수가 호출되면 이벤트가 소비된다? ← 틀림!
    if not active:
        return  # 이것도 이벤트를 차단한다? ← 틀림!
```

**올바른 이해**:
```gdscript
func _input(event):
    # _input()이 호출되어도 이벤트는 계속 전파됨
    if not active:
        return  # 단순히 함수 종료, 이벤트는 GUI로 전파됨

    # 이벤트를 명시적으로 소비하려면:
    get_viewport().set_input_as_handled()  # ← 이걸 호출해야 소비됨
```

**핵심**:
- `_input()` 호출 ≠ 이벤트 소비
- `return`만으로는 이벤트 차단 안 됨
- 명시적으로 `get_viewport().set_input_as_handled()` 호출해야 소비

### 실제 오판 사례: free_camera.gd

**상황**:
- 사용자: "UI 버튼이 안 눌린다"
- player_v3.gd를 `_unhandled_input()`으로 바꿨는데도 안 된다는 보고

**잘못된 분석 과정**:
1. "다른 곳에 `_input()` 있나?" 검색
2. free_camera.gd에서 `_input()` 발견
3. → **"이게 문제다!"** (검증 없이 결론)

**왜 틀렸나**:
```gdscript
# free_camera.gd:26-28
func _input(event: InputEvent) -> void:
    if not _is_active:
        return  # ← 조기 반환하면 이벤트는 계속 전파됨!
```

**실제**:
- free_camera가 비활성일 때 `return`만 함
- `set_input_as_handled()` 호출 안 함
- → 이벤트는 GUI로 정상 전파됨
- → **UI 버튼 클릭 가능**

**교훈**:
- ❌ 코드만 보고 "이게 문제다" 단정
- ✅ 실제로 테스트해서 확인
- ✅ Godot 메커니즘 정확히 이해

### 문제 분석 체크리스트

사용자가 버그를 보고할 때:

#### 1. 재현 확인
```markdown
- [ ] 실제로 버그가 재현되는가?
- [ ] 어떤 상황에서 발생하는가?
- [ ] 에러 메시지가 있는가?
- [ ] 재현 안 되면 사용자에게 재확인 요청
```

#### 2. 증거 수집
```gdscript
# 디버그 출력으로 실제 동작 확인
func _input(event):
    print("[_input] Called: ", event)

func _gui_input(event):
    print("[GUI] Received: ", event)  # ← 이게 출력되면 이벤트 전파됨
```

#### 3. 가설 검증
```markdown
- [ ] "이게 문제일 것 같다" → 가설
- [ ] 가설을 테스트로 검증
- [ ] 검증 안 된 가설은 "추측"일 뿐
- [ ] 확신 없으면 "추측입니다" 명시
```

#### 4. 근거 확인
```markdown
- [ ] "이게 문제다"라는 근거가 있는가?
- [ ] 코드 실행 흐름을 추적했는가?
- [ ] Godot 공식 문서를 확인했는가?
- [ ] 반대 증거는 없는가?
```

### 올바른 접근법

**사용자**: "버튼이 안 눌린다"

**올바른 대응**:
1. **재현 확인**: "어떤 버튼이 안 눌리나요? 어떤 상황인가요?"
2. **실제 테스트**: 코드 실행해서 직접 확인
3. **증거 수집**: 콘솔 로그, 디버그 출력
4. **가설 검증**: "이게 문제일 것 같다" → 테스트로 확인
5. **해결책 제시**: 검증된 해결책만 제시

**하지 말아야 할 것**:
- ❌ "아마 이게 문제일 겁니다" (검증 없이)
- ❌ "이렇게 수정하면 됩니다" (테스트 없이)
- ❌ "틀림없이..." (확신 근거 없이)

### 코드 리뷰 시 자문

#### 문제 분석 전
```markdown
1. "이게 문제다"라고 말하기 전
   - [ ] 실제로 테스트해봤는가?
   - [ ] Godot 공식 문서를 확인했는가?
   - [ ] 코드 실행 흐름을 추적했는가?

2. "이렇게 수정하면 된다"라고 말하기 전
   - [ ] 왜 이게 해결책인지 설명할 수 있는가?
   - [ ] 부작용은 없는가?
   - [ ] 실제로 테스트했는가?

3. 오판 가능성 체크
   - [ ] 내 가정에 근거가 있는가?
   - [ ] 반대 증거는 없는가?
   - [ ] 확신이 없다면 "추측입니다" 명시
```

### 디버깅 팁

#### 입력 이벤트 추적
```gdscript
# 어떤 순서로 입력이 처리되는지 확인
func _input(event):
    print("[Node: %s] _input: %s" % [name, event])

func _gui_input(event):
    print("[Node: %s] _gui_input: %s" % [name, event])

func _unhandled_input(event):
    print("[Node: %s] _unhandled_input: %s" % [name, event])
```

#### 이벤트 소비 여부 확인
```gdscript
func _input(event):
    print("[BEFORE] Event consumed: ", get_viewport().is_input_handled())
    # ... 코드 ...
    print("[AFTER] Event consumed: ", get_viewport().is_input_handled())
```

### 요약

- **원칙**: 검증 없는 가정 금지
- **방법**: 실제 동작 확인, 문서 참조, 테스트
- **교훈**: "_input() 호출 ≠ 이벤트 소비" (명시적 호출 필요)
- **재발 방지**: 체크리스트 사용, 근거 있는 결론만

---

## Transform 참조 규칙

### 원칙: 실제로 회전하는 노드의 transform 사용

Godot의 부모-자식 노드 계층에서 transform은 **독립적**으로 관리됩니다.
부모 노드의 transform은 자식 노드의 회전을 자동으로 반영하지 않습니다.

### 올바른 Transform 참조

**잘못된 예시**: Body 노드가 회전하는데 CharacterBody3D의 transform 사용
```gdscript
# ❌ 틀림: 부모 노드 transform (회전 안 함)
var player_up = transform.basis.y
var tilt = acos(player_up.dot(Vector3.UP))  # 항상 0° (부모는 회전 안 함)
```

**올바른 예시**: 실제로 회전하는 Body 노드의 transform 사용
```gdscript
# ✅ 올바름: 자식 Body 노드 transform (회전함)
var player_up = body.transform.basis.y
var tilt = acos(player_up.dot(Vector3.UP))  # 실제 기울기 반영
```

### Transform 계층 구조 이해

```
CharacterBody3D "Player" (transform)
  └─ Node3D "Body" (body.transform) ← 이게 회전함
      ├─ MeshInstance3D "Head"
      ├─ MeshInstance3D "Torso"
      └─ ...
```

**공중 트릭 시**:
- `_apply_air_trick_rotations()`에서 `body.rotation.x = air_pitch` 설정
- **Body 노드**만 회전, CharacterBody3D는 회전 안 함
- 따라서 `transform.basis.y`는 항상 Vector3.UP 유지
- `body.transform.basis.y`만 실제 회전 반영

### 체크리스트

회전/기울기 관련 코드 작성 시:
1. ✅ **어느 노드가 실제로 회전하는가?**
   - `body.rotation` 변경 → Body 노드 회전
   - `rotation` 변경 → CharacterBody3D 회전
2. ✅ **그 노드의 transform을 참조하는가?**
   - Body 회전 체크 → `body.transform.basis`
   - Player 전체 이동 체크 → `transform`
3. ✅ **UI 표시와 로직이 같은 transform을 사용하는가?**
   - UI: `body.transform.basis.y`
   - 로직: `body.transform.basis.y` ✅ 일치
   - 불일치 시 버그 발생!

### 일관성 검증

**같은 개념을 여러 곳에서 사용할 때**:
- **몸체 기울기 (Tilt)**: 모든 곳에서 `body.transform.basis.y` 사용
  - UI 표시: `body.transform.basis.y`
  - 착지 판정: `body.transform.basis.y`
  - 디버그 로그: `body.transform.basis.y`

**다른 transform 사용 시 발생하는 버그**:
```gdscript
# UI: Tilt = 90° 표시
var ui_tilt = acos(body.transform.basis.y.dot(Vector3.UP))  # 90°

# 착지 판정: Tilt = 0°로 체크 (버그!)
var landing_tilt = acos(transform.basis.y.dot(Vector3.UP))  # 0° (부모는 회전 안 함)

# 결과: UI는 90°인데 착지 성공 (버그)
```

### 주석으로 의도 명시

**권장 주석 스타일**:
```gdscript
# 몸체 기울기 계산
# Body 노드가 실제 회전하므로 body.transform 사용
# (CharacterBody3D의 transform은 회전하지 않음)
var player_up = body.transform.basis.y
var ground_normal = get_floor_normal()
var dot = player_up.dot(ground_normal)
```

### 케이스 스터디: 착지 판정 Transform 불일치 버그

**증상**: UI에서 Tilt 90°인데도 착지 성공

**원인**:
- UI: `body.transform.basis.y` 사용 (올바름)
- 착지 판정: `transform.basis.y` 사용 (틀림)

**교훈**:
1. 같은 개념(몸체 기울기)은 모든 곳에서 같은 transform 참조
2. UI 추가는 로직 검증 기회 - 표시값과 로직이 일치하는지 확인
3. Transform 계층을 항상 의식 - 부모/자식 중 누가 회전하는가?

**수정**:
```gdscript
# Before (버그)
var player_up = transform.basis.y  # CharacterBody3D (회전 안 함)

# After (수정)
var player_up = body.transform.basis.y  # Body 노드 (회전함)
```

**참고**: `PLAYER.md` "Landing Failure Detection" 섹션
