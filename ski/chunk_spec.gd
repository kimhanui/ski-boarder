class_name ChunkSpec
extends RefCounted
## 모든 청크가 지키는 공통 규칙. 값 조정은 이 파일에서만.

const SIZE: int = 256              ## 청크 한 변 길이(m) = Terrain3D region_size, vertex_spacing 1
const DROP: float = 50.0           ## 청크당 하강량(m). 50/256 ≈ 평균 11°
const CENTER_X: float = 128.0      ## 입구/출구에서 코스 중심의 x (청크 로컬)
const HALF_WIDTH: float = 30.0     ## 표준 코스 반폭(m)
const WALL_HEIGHT: float = 15.0    ## 표준 벽 높이(m)
const WALL_RAMP: float = 20.0      ## 코스 가장자리 → 벽 꼭대기까지 수평 거리(m)
const OUTER_RISE: float = 0.35     ## 벽 바깥 산비탈 기울기
const EDGE_BLEND: float = 24.0     ## 입구/출구에서 표준 모양으로 강제되는 길이(m)
const MIN_TURN_RADIUS: float = 40.0 ## 커브 최소 반경(m)


## 입구/출구에서 0, 안쪽에서 1. 값·기울기·곡률 모두 가장자리에서 0 → 이음매 매끄러움.
static func edge_mask(v: float) -> float:
	var e: float = EDGE_BLEND / SIZE
	return smootherstep(clampf(v / e, 0.0, 1.0)) * smootherstep(clampf((1.0 - v) / e, 0.0, 1.0))


## 6t⁵ − 15t⁴ + 10t³ : 양 끝에서 1·2차 미분이 0.
static func smootherstep(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## 청크 index 의 월드 원점(x=0 모서리, 입구 높이).
static func chunk_origin(index: int) -> Vector3:
	return Vector3(0.0, -DROP * index, float(index * SIZE))
