# 🏔️ **Player State Machine + Auto Recovery + UI Debug Prompt (for Claude)**

## 🎯 목적
Godot 4 스키 게임의 Player에 **상태머신(FSM)** 을 적용하고, **착지 실패 시 자동 회복(자동 일어남)** 기능을 구현하며, **현재 상태를 UI(Label)에 표시하도록** Claude에게 요청하는 프롬프트.

---

# 📌 Claude Prompt — Implement Ski Player FSM + Auto Recovery + UI State Label

너는 Godot 4 기준 스키 게임에서 사용할 Player 상태머신을 설계하고 GDScript 코드를 작성해줘야 한다.

---

## 🎯 목표 요구사항

### 1) Player 상태머신 구성
아래 상태값을 가진 FSM을 Player에 적용한다.

```
IDLE  
RIDING  
JUMP  
FLIP  
LANDING  
FALLEN  
RECOVER
```

---

### 2) 자동 회복(Autorecovery) 기능 필수

- FLIP 후 LANDING에서 착지 실패하면 즉시 `FALLEN` 상태로 전환  
- FALLEN 상태에서 넘어짐(fall) 애니메이션이 끝나면 자동으로 `RECOVER` 전환  
- RECOVER 애니메이션이 끝나면 자동으로 `RIDING`으로 복귀  
- 플레이어 입력 없이 모든 회복 동작이 자동으로 이루어져야 함  

---

### 3) 착지 실패(FALLEN) 조건

착지 순간 아래 조건 중 하나라도 맞으면 FALLEN 판정:

- `dot(player_forward, ground_normal)` < 0.5  
- Player 회전 X/Z 각도가 60° 이상 틀어짐  
- Angular velocity가 threshold 이상  
- 착지 시 속도가 일정 기준 이하

---

### 4) FALLEN 상태 처리 방식

아래 로직을 반드시 포함:

```gdscript
velocity = Vector3.ZERO
gravity_scale = 0.5
play_anim("fall")
```

---

### 5) RECOVER 상태 처리 방식

- `"recover"` 애니메이션 재생  
- 애니메이션 종료 시 rotation.x / rotation.z 보정  
- Forward 방향 재정렬 후 자동으로 `RIDING` 전환  

---

### 6) 상태값을 UI(Label)로 실시간 표시

아래 형식으로 Player가 UI Label을 직접 갱신하도록:

```gdscript
@onready var state_label: Label = $"../UI/StateLabel"

func _update_state_ui():
	state_label.text = str(state)
```

상태가 바뀔 때마다 UI에 반영되도록 해야 한다.

---

### 7) enum 기반 FSM 선언 요구

```gdscript
enum PlayerState { IDLE, RIDING, JUMP, FLIP, LANDING, FALLEN, RECOVER }
var state: PlayerState = PlayerState.IDLE
```

---

### 8) 상태 변경 함수 필수

```gdscript
func set_state(new_state: PlayerState):
	if state == new_state:
		return
	state = new_state
	_update_state_ui()
	_enter_state(new_state)
```

---

### 9) 애니메이션 명칭(고정)

Claude는 반드시 아래 이름을 사용해 코드 작성:

```
ride
jump
flip
landing
fall
recover
```

---

### 10) 전체 흐름(State Flow)

아래 전이 조건을 코드로 반드시 구현할 것:

```
IDLE → RIDING(속도>0)
RIDING → JUMP(점프)
JUMP → FLIP(공중에서 회전 시작)
FLIP → LANDING(바닥 감지)
LANDING → RIDING(착지 성공)
LANDING → FALLEN(착지 실패)
FALLEN → RECOVER(fall anim 종료 후)
RECOVER → RIDING(recover anim 종료 후)
```

---

### 11) 애니메이션 종료 감지

`animation_finished(anim_name)` 방식 활용:

- fall 끝 → 자동 RECOVER  
- recover 끝 → 자동 RIDING  

---

### 12) 최종 코드 구성 요구

Claude에게 **Player.gd 전체 코드(하나의 스크립트)로 완성본**을 작성하도록 지시해야 한다.

- `_physics_process()` 안에서 상태별 이동 로직  
- `_enter_state()` 안에서 상태 입장 처리  
- `_update_state_ui()` 포함  
- 애니메이션/회전 보정 포함  
- 자동 회복 전체 구현  
- Godot 4.2~4.4 문법 준수  

---

# 📢 Claude에게 전달할 마지막 요청

> 위 모든 요구사항을 만족하는 **Player.gd 전체 GDScript 코드**를 작성해줘.  
> FSM 구조, 자동 회복, UI 상태 표시, 회복 애니메이션 로직, 회전 보정 등을 모두 포함한 완성본을 제공해줘.
