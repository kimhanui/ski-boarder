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
