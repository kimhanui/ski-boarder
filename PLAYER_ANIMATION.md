너는 Godot 4 3D 게임과 GDScript에 매우 익숙한 시니어 게임 프로그래머이자 애니메이션 TD다.  
목표: 스키 플레이어 캐릭터가 점프 중에 수행하는 **스키 테일 그랩(Tail Grab) 공중 트릭 애니메이션**을, Godot 4에서 실제로 동작하는 GDScript 코드로 직접 만들어줘.

## 전제 / 환경

- 엔진: Godot 4.x
- 언어: GDScript
- 코드는 모두 **탭(tab)으로만 들여쓰기** 해줘. (space 들여쓰기 금지)
- 캐릭터는 3D 스키어이고, 씬 구조는 다음과 같이 가정해줘 (필요하면 이름은 변수로 빼도 됨):

	Player (CharacterBody3D)
	└── Skeleton3D (이름: "Skeleton3D")
	└── AnimationPlayer (이름: "AnimationPlayer")
	└── LeftSki (MeshInstance3D, 왼쪽 스키)
	└── RightSki (MeshInstance3D, 오른쪽 스키)

- Skeleton3D에는 대략 아래와 같은 본 이름이 있다고 가정하고 애니메이션을 만들어줘 (실제 본 이름은 나중에 내가 바꿀 수 있으니, 스크립트 상단에 상수로 정리해줘):

	- "spine"
	- "head"
	- "left_thigh"
	- "right_thigh"
	- "left_calf"
	- "right_calf"
	- "left_foot"
	- "right_foot"
	- "left_upper_arm"
	- "left_lower_arm"
	- "right_upper_arm"
	- "right_lower_arm"

## 해야 할 작업

1. **GDScript 스크립트 파일 하나**를 만들어줘. (예: `SkiTrickAnimator.gd`)
2. 이 스크립트는 Player 노드(또는 별도 Node3D)에 붙일 수 있고, 아래 기능을 가져야 한다:

	- `_ready()`에서:
		- `Skeleton3D`와 `AnimationPlayer`를 찾아서 멤버 변수에 캐싱.
		- `AnimationPlayer`에 **"trick_tail_grab"**라는 이름의 애니메이션을 **코드로 생성**하고, 키프레임을 추가해서 애니메이션을 완성.
	- `play_tail_grab()` 같은 메서드를 제공해서:
		- 호출 시 `AnimationPlayer.play("trick_tail_grab")`로 재생하게 할 것.

3. 애니메이션 생성 방식:

	- `Animation.new()`로 새 애니메이션 리소스를 만들고,
	- 길이는 약 **1.0초** 정도로 해줘. (원하면 0.8~1.2 사이에서 자연스러운 값으로 잡아도 됨)
	- `AnimationPlayer.add_animation("trick_tail_grab", animation)` 형태로 등록.
	- 본 애니메이션은 **Animation의 bone track**을 사용해서, Skeleton3D의 각 본 transform을 직접 키프레임으로 조정해줘.
	  - 예: `var track_idx = animation.add_track(Animation.TYPE_BONE)`  
	    `animation.track_set_path(track_idx, "Skeleton3D:spine")` 와 같이 세팅하고,  
	    `animation.track_insert_key(track_idx, time, bone_pose_transform)` 형태로 키 추가.
	  - Godot 4 API에 맞춰 정확한 메서드 이름과 path 형식을 사용해줘. (문법/타입 오류 없게)

4. 애니메이션 포즈 흐름 (테일 그랩):

	애니메이션은 약 1초짜리로, 대략 8~10개의 중요한 타임 포인트로 나눠줘.  
	**정규화된 타임 예시**: 0.0, 0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0

	각 구간에서 Skeleton 본들을 어떻게 움직일지 코드 안에서 직접 세팅해줘:

	1) 0.0초 – 프리 점프 준비
		- 무게중심을 낮추고 상체를 약간 앞으로 숙인 기본 라이딩 자세.
		- 무릎(양쪽 thigh/calf)은 살짝 굽힌 상태.
		- 팔은 옆으로 자연스럽게, 폴을 쥔 상태를 가정 (폴은 실제 Mesh가 없다고 가정하고, 팔 각도만 조절).

	2) 0.1초 – 테이크오프
		- 상체가 약간 더 위로 올라오고, 다리가 힘을 써서 점프하는 느낌 (무릎이 펴지는 방향).
		- 스키(foot/스키 본)는 설면에서 막 떼어지는 느낌으로 약간 위로 향하게.

	3) 0.25초 – 공중에서 수축 시작
		- 상체는 살짝 뒤로 젖혀지거나 위를 보며, 무릎을 굽혀 스키를 몸 쪽으로 끌어오는 느낌.
		- 허벅지(thigh)와 종아리(calf)를 굽혀서, 발이 몸 가까이로 이동.

	4) 0.4초 – **테일 그랩 최대 포즈 (클라이맥스)**
		- 한쪽 손(예: 오른팔)으로 **오른쪽 스키 테일**을 잡는 동작을 표현:
			- right_upper_arm, right_lower_arm 본을 회전시켜 뒤로/아래로 뻗어 스키 테일 위치로 이동.
		- 무릎은 강하게 굽혀 콤팩트한 포즈 (양쪽 thigh/calf/foot 본 각도 조정).
		- 반대쪽 팔은 균형을 잡기 위해 위나 옆으로 뻗어줌.
		- 상체는 스키 쪽으로 약간 숙여져 있고, 머리(시선)는 진행 방향 또는 스키 쪽을 보는 느낌.

	5) 0.55초 – 그랩 유지
		- 0.4초의 포즈에서 크게 변하지 않고, 테일을 계속 잡는 상태를 약간만 움직여 자연스럽게 유지.
		- 상체/팔/다리의 각도를 미묘하게 조정해서 살아있는 느낌을 줄 것.

	6) 0.7초 – 그랩 해제
		- 손을 테일에서 떼고, 상체를 점차 세워서 착지 방향을 바라보게.
		- 무릎은 아직 굽혀진 상태지만 점점 펴질 준비.

	7) 0.85초 – 착지 직전
		- 스키가 설면과 거의 평행하게 돌아오고, 무릎을 다시 깊게 굽혀 충격을 받을 준비.
		- 상체는 약간 앞으로, 팔은 균형을 잡는 포즈.

	8) 1.0초 – 착지 후 리커버리
		- 충격을 흡수한 직후 자세: 상체가 잠깐 더 숙여졌다가,
		- 이후 다시 기본 라이딩 자세로 되돌아갈 수 있도록 마무리 포즈.

5. 코드 작성 스타일

	- GDScript 코드는 **실제로 붙여서 실행 가능한 상태**로 작성해줘. 문법 오류/타입 오류 없이.
	- 본 transform을 다룰 때는:
		- Godot 4용 Skeleton3D와 Animation의 bone track 조합을 정확히 사용해줘.
		- 각 본의 `Transform3D`를 만들거나 기존 포즈에서 회전만 가해도 좋다.
	- 스크립트 상단에:
		- 본 이름 상수를 묶어두고,
		- 애니메이션 이름, 길이, 타임 포인트를 상수/배열로 선언해두면 좋다.
	- 들여쓰기: 반드시 **tab 문자만 사용**해줘.

## 최종 출력

- 하나의 GDScript 파일 전체 코드를 출력해줘.
- 중간에 설명용 주석은 달아도 되지만, 최종적으로 내가 Godot에 그대로 붙여 넣어 테스트할 수 있을 정도로 완성된 코드여야 한다.
- 추가로, 코드 마지막에 `play_tail_grab()`을 테스트하는 간단한 사용 예시(예: `_input(event)`에서 특정 키 누르면 재생)를 넣어줘도 좋다.
