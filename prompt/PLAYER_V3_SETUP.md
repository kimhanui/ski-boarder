# Player V3 설정 가이드

player_v3.gd를 적용하기 위한 Godot 씬 설정 방법입니다.

---

## 1. Player 씬 스크립트 교체

### Godot 에디터에서:

1. **scenes/player/player.tscn** 열기
2. 루트 노드 (CharacterBody3D) 선택
3. Inspector → Script → `scripts/player/player_v3.gd`로 변경
4. 저장

---

## 2. AnimationPlayer 노드 추가

### 씬 트리 구조:

```
Player (CharacterBody3D) [player_v3.gd]
├─ AnimationPlayer          ← 추가 필요
├─ Body (Node3D)
├─ Camera3D_ThirdPerson
├─ ...
└─ UI (Control)
    └─ StateLabel (Label)   ← 추가 필요
```

### 추가 방법:

1. **Player** 노드 우클릭 → Add Child Node
2. **AnimationPlayer** 선택 → Create
3. 노드 이름: `AnimationPlayer` (정확히 이 이름)

---

## 3. UI StateLabel 추가

### Main 씬에서 (또는 Player의 부모 씬):

1. **UI** Control 노드 찾기 (없으면 생성)
2. **UI** 우클릭 → Add Child Node
3. **Label** 선택 → Create
4. 노드 이름: `StateLabel`

### StateLabel 설정:

- **Text**: "State: IDLE" (초기값, 자동으로 업데이트됨)
- **Position**: 화면 좌상단 (예: x=10, y=80)
- **Font Size**: 16-20
- **Modulate**: 밝은 색상 (예: White 또는 Yellow)

---

## 4. 애니메이션 트랙 생성 (선택사항)

현재는 빈 애니메이션이어도 작동합니다. 나중에 키프레임을 추가할 수 있습니다.

### 애니메이션 생성 방법:

1. **AnimationPlayer** 노드 선택
2. Animation 패널 → Animation → New
3. 아래 애니메이션 이름으로 생성:
   - `idle`
   - `ride`
   - `jump`
   - `flip`
   - `landing`
   - `fall`
   - `recover`

### 빈 애니메이션 설정:

- Duration: 1.0초 (기본값)
- Loop: `idle`, `ride`만 켜기
- 나머지는 루프 끄기

---

## 5. 테스트 실행

### 확인 사항:

1. ✅ 게임 실행 시 콘솔에 `[FSM] GROUNDED → IDLE` 로그 출력
2. ✅ 화면에 `State: IDLE` 표시
3. ✅ W 키 눌러서 이동 시 → `State: RIDING`으로 변경
4. ✅ 스페이스바로 점프 → `State: JUMP` → (트릭 중) `State: FLIP` → `State: LANDING`
5. ✅ 착지 실패 시 → `State: FALLEN` → (1.5초 후) `State: RECOVER` → `State: RIDING`

### 착지 실패 테스트:

1. Trick Mode ON (UI 버튼)
2. 점프 후 Backflip (S 키)
3. 180° 이상 회전 후 착지
4. 콘솔에 `[LANDING] FAILED - ...` 출력 확인
5. 자동으로 일어나는지 확인

---

## 6. 디버그 로그

### 콘솔에 출력되는 주요 로그:

```
[FSM] IDLE → RIDING                    # 상태 전환
[RIDING] Entered - Ready to ride       # 상태 진입
[JUMP] Entered - Jumping               # 점프 시작
[FLIP] Entered - Performing trick      # 트릭 시작
[Trick] Starting Backflip!             # 트릭 감지
[LANDING] SUCCESS - All conditions passed  # 착지 성공
[LANDING] FAILED - Pitch=120.0°        # 착지 실패 (예시)
[FALLEN] Entered - Player fell down    # 넘어짐
[RECOVER] Entered - Getting back up    # 일어남
[FSM] Resetting body pose to default   # 자세 리셋
```

---

## 7. 애니메이션 키프레임 추가 (나중 작업)

### 추천 작업 순서:

1. **ride** 애니메이션: 기본 스키 타는 자세
   - Torso: rotation_degrees.x = -45° (앞으로 숙임)
   - Legs: 약간 구부림

2. **jump** 애니메이션: 점프 준비 자세
   - Body: position.y = -0.15 (쪼그림)
   - Legs: rotation_degrees.x = 25° (구부림)

3. **fall** 애니메이션: 넘어지는 동작
   - Body: rotation.x/z 랜덤 회전
   - Duration: 1.5초

4. **recover** 애니메이션: 일어나는 동작
   - Body: rotation → 0 (정상 복귀)
   - Duration: 1.0초

---

## 8. 문제 해결

### "StateLabel not found" 에러:

- Main 씬 (player.tscn의 부모)에 `UI/StateLabel` 노드 추가 필요

### 애니메이션이 재생되지 않음:

- AnimationPlayer 노드가 정확히 `AnimationPlayer` 이름인지 확인
- 애니메이션 이름이 정확한지 확인 (소문자)

### 착지 후 자세가 리셋되지 않음:

- 콘솔에 `[FSM] Resetting body pose to default` 로그가 출력되는지 확인
- `_enter_riding()` 함수에서 `_reset_body_pose()` 호출 확인

---

## 9. V2와의 차이점

| 기능 | V2 | V3 |
|------|----|----|
| 상태 관리 | JumpState (5개) | PlayerState FSM (7개) |
| 착지 실패 | 없음 | 3가지 조건 체크 |
| 자동 회복 | 없음 | FALLEN → RECOVER → RIDING |
| UI 상태 표시 | 없음 | StateLabel로 실시간 표시 |
| 애니메이션 | Procedural만 | AnimationPlayer + Procedural |
| 디버깅 | 제한적 | 상태 전환 로그 상세 |

---

## 10. 다음 단계

1. ✅ player_v3.gd 적용
2. ✅ 기본 테스트 (상태 전환 확인)
3. ⏳ 애니메이션 키프레임 추가 (선택)
4. ⏳ 착지 실패 조건 튜닝 (LANDING_DOT_THRESHOLD 등)
5. ⏳ FALLEN/RECOVER 애니메이션 제작

---

## 참고

- 원본 설계: `player_state_prompt.md`
- 기존 코드: `scripts/player/player_v2.gd`
- 프로젝트 가이드: `CLAUDE.md`
