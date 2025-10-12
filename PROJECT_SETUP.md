# 🛠 Godot 4 스노우보드 게임 프로젝트 셋팅 가이드

**GitHub Repository**: https://github.com/kimhanui/ski-boarder.git
**엔진**: Godot 4.4+ (macOS)
**프로젝트명**: ski-boarder

---

## 📋 Claude CLI를 위한 실행 프롬프트

> **Claude CLI에게 전달할 프롬프트**
> 
> 다음 명령어들을 순서대로 실행하여 Godot 프로젝트를 셋팅하세요:
> 
> 1. GitHub 저장소 클론
> 2. 프로젝트 디렉토리 구조 생성
> 3. project.godot 파일 생성 및 설정
> 4. .gitignore 파일 생성
> 5. 기본 씬 구조 생성
> 6. Input Map 설정
> 
> 각 단계는 아래 "상세 실행 가이드" 섹션을 참고하세요.

---

## 🚀 상세 실행 가이드

### Step 1: Git 저장소 초기화

```bash
# 프로젝트 디렉토리로 이동 (또는 새로 생성)
cd ~/Projects  # 또는 원하는 경로
git clone https://github.com/kimhanui/ski-boarder.git
cd ski-boarder

# 또는 이미 디렉토리가 있다면
git init
git remote add origin https://github.com/kimhanui/ski-boarder.git
```

---

### Step 2: 프로젝트 폴더 구조 생성

```bash
# 기본 폴더 구조 생성
mkdir -p scenes/{player,environment,ui,menus}
mkdir -p scripts/{player,environment,ui,autoload}
mkdir -p assets/{models,textures,materials,sounds,fonts}
mkdir -p resources/{materials,physics}

# 구조 확인
tree -L 2  # tree 명령어가 없다면: ls -R
```

**예상 구조**:
```
ski-boarder/
├── scenes/
│   ├── player/
│   ├── environment/
│   ├── ui/
│   └── menus/
├── scripts/
│   ├── player/
│   ├── environment/
│   ├── ui/
│   └── autoload/
├── assets/
│   ├── models/
│   ├── textures/
│   ├── materials/
│   ├── sounds/
│   └── fonts/
└── resources/
    ├── materials/
    └── physics/
```

---

### Step 3: project.godot 파일 생성

**파일 경로**: `project.godot` (프로젝트 루트)

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="Ski Boarder"
config/description="3D 백컨트리 스노우보드 게임 - Godot 4"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.4", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=2
window/stretch/mode="canvas_items"
window/vsync/vsync_mode=1

[input]

# 기본 입력 맵핑은 Step 5에서 UI로 추가됨

[physics]

# 3D 물리 설정
3d/physics_engine="DEFAULT"
3d/default_gravity=9.8
3d/default_linear_damp=0.1
3d/default_angular_damp=0.1

[rendering]

# 3D 렌더링 설정
renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=2
anti_aliasing/quality/msaa_3d=2
anti_aliasing/quality/screen_space_aa=1
environment/defaults/default_clear_color=Color(0.53, 0.81, 0.92, 1)

[layer_names]

# 충돌 레이어 이름 설정
3d_physics/layer_1="Player"
3d_physics/layer_2="Environment"
3d_physics/layer_3="Obstacles"
3d_physics/layer_4="Triggers"
```

---

### Step 4: .gitignore 파일 생성

**파일 경로**: `.gitignore` (프로젝트 루트)

```gitignore
# Godot 4+ specific ignores
.godot/

# Godot-specific ignores
*.translation
*.import
export.cfg
export_presets.cfg

# Imported translations (automatically generated from CSV files)
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json

# System/tool-specific ignores
.DS_Store
*~
*.swp
*.swo
*.bak
*.orig

# Build artifacts
builds/
exports/
*.zip
*.dmg
*.app
*.exe
*.pck

# IDE specific
.vscode/
.idea/
*.sublime-workspace

# macOS specific
.DS_Store
.AppleDouble
.LSOverride
Icon

# Thumbnails
._*

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent
```

---

### Step 5: Input Map 설정

> **중요**: Input Map은 Godot Editor UI에서 설정해야 합니다.
> 프로젝트를 Godot에서 열고 `Project > Project Settings > Input Map`에서 다음을 추가:

**추가할 Input Actions**:

```
1. move_forward
   - W 키
   - 위 화살표
   - Joypad Button 12 (D-Pad Up)

2. move_back
   - S 키
   - 아래 화살표
   - Joypad Button 13 (D-Pad Down)

3. move_left
   - A 키
   - 왼쪽 화살표
   - Joypad Button 14 (D-Pad Left)

4. move_right
   - D 키
   - 오른쪽 화살표
   - Joypad Button 15 (D-Pad Right)

5. jump
   - Space 키
   - Joypad Button 0 (A/Cross)

6. crouch
   - Left Shift
   - Left Ctrl
   - Joypad Button 1 (B/Circle)

7. toggle_camera
   - Tab 키
   - Joypad Button 3 (Y/Triangle)

8. brake
   - S 키 (move_back와 동일)
   - 아래 화살표
```

**CLI에서 직접 추가하려면** (project.godot 파일의 [input] 섹션에):

```ini
[input]

move_forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
crouch={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194325,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194326,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
toggle_camera={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

---

### Step 6: 기본 씬 구조 생성

> **주의**: 씬 파일(.tscn)은 Godot Editor에서 생성하는 것이 가장 안전합니다.
> CLI로 생성하려면 아래 템플릿을 사용하되, 반드시 Godot Editor로 검증하세요.

#### 6-1. Main Scene 생성

**파일 경로**: `scenes/main.tscn`

```
[gd_scene format=3 uid="uid://main_scene_001"]

[node name="Main" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707107, 0.707107, 0, -0.707107, 0.707107, 0, 10, 0)
shadow_enabled = true
```

#### 6-2. Player Scene 템플릿

**파일 경로**: `scenes/player/player.tscn`

```
[gd_scene format=3 uid="uid://player_scene_001"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.5
height = 1.8

[node name="Player" type="CharacterBody3D"]
collision_layer = 1
collision_mask = 2

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("CapsuleShape3D_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]

[node name="Camera3D_ThirdPerson" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.866025, 0.5, 0, -0.5, 0.866025, 0, 3, 5)
current = true

[node name="Camera3D_FirstPerson" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)

[node name="SnowParticles" type="GPUParticles3D" parent="."]
```

---

### Step 7: README.md 생성

**파일 경로**: `README.md` (프로젝트 루트)

```markdown
# 🏂 Ski Boarder

3D 백컨트리 스노우보드 게임 - Godot 4 프로젝트

## 📋 프로젝트 개요
- **엔진**: Godot 4.4+
- **장르**: 3D 레이싱/스포츠
- **플랫폼**: macOS (추후 확장)
- **개발 기간**: 2025.10 ~

## 🎮 핵심 기능
- 1인칭/3인칭 시점 전환
- 물리 기반 스노우보드 조작
- 눈가루 파티클 효과
- 산악 구조 미션 시스템

## 🛠 개발 환경 설정

### 필수 요구사항
- Godot 4.4 이상
- macOS 12+ (Apple Silicon 권장)
- Git

### 프로젝트 셋업
```bash
git clone https://github.com/kimhanui/ski-boarder.git
cd ski-boarder
# Godot Editor로 프로젝트 열기
```

## 📁 프로젝트 구조
```
ski-boarder/
├── scenes/          # 씬 파일
├── scripts/         # GDScript 파일
├── assets/          # 모델, 텍스처, 사운드
├── resources/       # 머티리얼, 물리 리소스
└── project.godot    # 프로젝트 설정
```

## 🎯 개발 로드맵
- [x] 프로젝트 초기 셋팅
- [ ] 기본 지형 및 플레이어 이동
- [ ] 카메라 시스템
- [ ] 파티클 시스템
- [ ] 미션 시스템

## 📝 라이선스
MIT License
```

---

## ✅ 셋팅 완료 체크리스트

완료 후 다음을 확인하세요:

- [ ] Git 저장소가 올바르게 연결되었는가?
- [ ] 폴더 구조가 정상적으로 생성되었는가?
- [ ] project.godot 파일이 존재하는가?
- [ ] .gitignore가 올바르게 설정되었는가?
- [ ] Godot Editor에서 프로젝트가 열리는가?
- [ ] Input Map 설정이 완료되었는가?
- [ ] Main Scene이 실행되는가?

---

## 🚨 트러블슈팅

### 문제 1: Godot에서 프로젝트가 열리지 않음
**해결**: project.godot 파일의 `config_version=5`가 정확한지 확인

### 문제 2: Input이 동작하지 않음
**해결**: Project Settings > Input Map에서 직접 설정 필요

### 문제 3: .godot 폴더가 Git에 추가됨
**해결**: `.gitignore`에 `.godot/` 포함 여부 확인

### 문제 4: 씬이 로드되지 않음
**해결**: Main Scene 경로가 `res://scenes/main.tscn`인지 확인

---

## 📚 다음 단계

셋팅이 완료되었다면:
1. Godot Editor에서 프로젝트 열기
2. Main Scene 실행 (F5)
3. Player Scene 작성 시작
4. 첫 커밋 푸시: `git add . && git commit -m "Initial project setup" && git push`

---

## 🔗 관련 문서
- [Godot 공식 문서](https://docs.godotengine.org/en/stable/)
- [프로젝트 기획서](https://www.notion.so/28adfd12eb0f8169bac5ef9d5514f4f0)
- [CCL 7기 페이지](https://www.notion.so/289dfd12eb0f80e5bda9-eb9a7303f3af)
