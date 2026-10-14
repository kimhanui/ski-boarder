class_name ChunkType
extends RefCounted
## 청크 타입 베이스. v = 진행 방향 0..1, 모든 함수는 "표준 대비 변형"을 반환.
## 규칙: 가장자리(v=0,1)에서 변형 값·기울기(가능하면 곡률까지)가 0이 되도록 설계할 것.
## (center_offset 은 마스크 없이 그대로 쓰이므로 특히 엄격히 지킬 것)

var type_name: String = "Base"
var weight: float = 1.0      ## 랜덤 선택 가중치 (0이면 규칙으로만 등장)
var cooldown: int = 0        ## 같은 타입이 다시 나오기까지 최소 청크 수
var color: Color = Color.WHITE  ## 디버그 표시 색


## 청크마다 파라미터를 랜덤으로 정함.
func randomize_params(_rng: RandomNumberGenerator) -> void:
	pass


## 정규화된 하강량 s(v): s(0)=0, s(1)=1, 단조 증가. 기본은 직선 경사.
func slope(v: float) -> float:
	return v


## 코스 중심의 좌우 이동(m).
func center_offset(_v: float) -> float:
	return 0.0


func half_width(_v: float) -> float:
	return ChunkSpec.HALF_WIDTH


func wall_height(_v: float) -> float:
	return ChunkSpec.WALL_HEIGHT


## 픽셀 단위 디테일을 쓰는지 (성능용 플래그).
func has_detail() -> bool:
	return false


## 코스 안 디테일 높이(m). d = 중심에서의 좌우 거리, z = 청크 로컬 z(m), hw = 현재 반폭.
func detail(_d: float, _z: float, _hw: float) -> float:
	return 0.0


func describe() -> String:
	return type_name
