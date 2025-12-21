# 3D 모델 아이템 추가 가이드

이 폴더에 3D 모델링 파일을 넣으면 게임 내 아이템으로 사용할 수 있습니다.

## 폴더 구조

```
assets/models/
├─ jackets/     # 재킷 3D 모델
├─ skis/        # 스키 3D 모델
├─ helmets/     # 헬멧 3D 모델
└─ poles/       # 폴 3D 모델
```

## 지원 파일 형식

- **GLB/GLTF** (권장): Godot 4에서 가장 잘 지원됨
- **OBJ**: 간단한 모델용
- **FBX**: Blender에서 내보낼 때 사용

## 사용 방법

### 1단계: 모델 파일 준비

Blender 등에서 모델링한 파일을 GLB/GLTF로 내보내기:

**Blender 내보내기 설정:**
- File → Export → glTF 2.0 (.glb/.gltf)
- Format: glTF Binary (.glb) 선택
- Include: Selected Objects 체크
- Transform: +Y Up 체크
- Export 클릭

### 2단계: 파일 복사

모델 파일을 해당 카테고리 폴더에 복사:

```bash
# 예시
cp my_ski_model.glb assets/models/skis/ski_racing.glb
```

### 3단계: ItemDatabase에 등록

`scripts/items/item_database.gd` 파일을 열고 `_load_default_items()` 함수에 추가:

```gdscript
# === Skis (스키) === 섹션에 추가
items["ski_racing"] = _create_item(
	"레이싱 스키",                                    # 표시 이름
	"ski",                                            # 카테고리
	Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
	false,                                            # 기본 아이템 여부
	false,                                            # "착용 안 함" 여부
	"res://assets/models/skis/ski_racing.glb"        # 모델 파일 경로
)
```

### 4단계: 게임 실행

게임을 실행하면 옷장 화면에서 새 아이템을 볼 수 있습니다!

## 모델링 가이드

### 스키 모델

- **크기**: 약 0.15m(폭) × 1.2m(길이)
- **중심점**: 모델 중앙
- **회전**: 기본 자세에서 수평
- **폴리곤**: 500 이하 권장 (게임 성능)

### 재킷 모델

- **주의**: 현재는 색상 변경만 지원
- 메시 교체는 향후 구현 예정

### 헬멧 모델

- **주의**: 현재는 색상 변경만 지원
- 메시 교체는 향후 구현 예정

### 폴 모델

- **주의**: 현재는 색상 변경만 지원
- 메시 교체는 향후 구현 예정

## 현재 지원 상태

| 카테고리 | 색상 변경 | 3D 모델 교체 |
|---------|----------|------------|
| 재킷    | ✅       | ❌ (TODO)  |
| 스키    | ✅       | ✅         |
| 폴      | ✅       | ❌ (TODO)  |
| 헬멧    | ✅       | ❌ (TODO)  |

## 문제 해결

### 모델이 안 보여요
1. 파일 경로가 올바른지 확인 (`res://assets/models/...`)
2. Godot에서 파일을 import했는지 확인 (재시작 필요할 수 있음)
3. 콘솔에 에러 메시지 확인

### 모델 크기가 이상해요
1. Blender에서 Scale 적용 (Ctrl+A → Scale)
2. 내보내기 설정에서 Scale을 1.0으로 설정

### 모델이 회전되어 있어요
1. Blender에서 Rotation 적용 (Ctrl+A → Rotation)
2. 내보내기 설정에서 +Y Up 체크

## 예시 파일

테스트용 예시 파일:

```gdscript
# scripts/items/item_database.gd

# 레이싱 스키 (GLB 모델)
items["ski_racing"] = _create_item(
	"레이싱 스키",
	"ski",
	Color(1.0, 0.0, 0.0),
	false,
	false,
	"res://assets/models/skis/ski_racing.glb"
)

# 프리스타일 스키 (GLB 모델)
items["ski_freestyle"] = _create_item(
	"프리스타일 스키",
	"ski",
	Color(0.0, 0.5, 1.0),
	false,
	false,
	"res://assets/models/skis/ski_freestyle.glb"
)
```

---

**참고**: 3D 모델 교체 시스템은 현재 스키만 지원합니다. 재킷/헬멧/폴은 향후 업데이트 예정입니다.
