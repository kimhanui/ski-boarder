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
