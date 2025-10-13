# 캐릭터 모델링 계획

**브랜치**: `feat/character-modeling`. 

---

## 목표

1. MVP용 치비 스타일 스키 플레이어 캐릭터 구현

---

## 1단계: MVP 플레이어 캐릭터 모델링

### 요구사항 분석

**참조 문서**: `CREATE_PLAYER.json`

- **스타일**: 로우폴리, 치비, 캐주얼 게임 느낌
- **비율**: 머리가 전체 높이의 약 1/3
- **모듈성**: 향후 전문 3D 모델로 교체 가능한 구조
- **포즈**: 스키 자세 (무릎 약간 구부림, 폴 양손에 들기)

### 구현 방식

**Godot 내장 프리미티브 활용** (외부 3D 소프트웨어 불필요)

#### 캐릭터 파트

1. **Body 그룹**
   - `Head`: SphereMesh (반지름 0.3) - 살구색 피부
   - `UpperBody`: BoxMesh (0.4×0.4×0.25) - 파란색 재킷
   - `LeftLeg`, `RightLeg`: CylinderMesh (높이 0.4) - 검은 바지
     - 무릎 구부린 자세를 위해 30° 기울임

2. **Equipment 그룹**
   - `SkiLeft`, `SkiRight`: BoxMesh (0.15×0.05×1.0) - 빨간 스키
   - `PoleLeft`, `PoleRight`: CylinderMesh (반지름 0.015, 높이 0.8) - 회색 폴
     - 스키 자세에 맞게 각도 조정

3. **Face 그룹** (Head의 자식)
   - `LeftEye`, `RightEye`: SphereMesh (반지름 0.1) - 큰 검은 눈
   - `Mouth`: SphereMesh (반지름 0.06, 납작) - 작은 입

### 파일 변경사항

- `scenes/player/player.tscn`:
  - 기존 CapsuleMesh 제거
  - 모듈러 메시 노드들 추가
  - SubResource로 각 메시 및 머티리얼 정의

---

## 구현 결과

### 파일 트리

```
ski-boarder/
├── CREATE_PLAYER.json           # 캐릭터 명세 (향후 전문 모델링 참고용)
├── scenes/
│   └── player/
│       └── player.tscn          # ✏️ 수정: 치비 캐릭터 + 
```

---

## 테스트 방법

### 캐릭터 모델 확인

1. Godot 에디터에서 `scenes/player/player.tscn` 열기
2. 3D 뷰에서 캐릭터 외형 확인
   - 치비 비율 (큰 머리)
   - 스키와 폴이 적절히 배치됨
   - 무릎이 약간 구부러진 자세

---

## 향후 개선 사항

#### 캐릭터 모델

- [ ] Blender에서 전문 3D 모델 제작
  - CREATE_PLAYER.json 명세 따라 모델링
  - FBX/GLB로 익스포트
  - `Body`, `Equipment` 노드에 임포트된 메시로 교체

- [ ] 애니메이션 추가
  - 스키 타는 동작 (idle)
  - 점프 애니메이션
  - 착지 애니메이션

---

## 참고 자료

- **CREATE_PLAYER.json**: 캐릭터 모델링 상세 명세
- **커밋 해시**: `4fe80ca` (이 계획서 기준)

---