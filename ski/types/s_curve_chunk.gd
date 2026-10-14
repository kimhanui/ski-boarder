class_name SCurveChunk
extends ChunkType
## 코스 중심이 좌우로 휘었다가 출구에서 원위치.
## offset(v) = amp * sin³(πnv) → 각 마디(입구/출구 포함)에서 값·기울기·곡률 모두 0.
##   → 직선 청크와 이어질 때 곡률이 갑자기 바뀌지 않음.
## 최대 곡률 = 3·amp·(πn/S)² 이므로 MIN_TURN_RADIUS 로 amp 상한을 계산.

var lobes: int = 1    ## 1 = 한쪽으로 크게, 2 = S자
var amp: float = 0.0  ## 최대 좌우 이동(m), 부호 = 방향


func _init() -> void:
	type_name = "SCurve"
	weight = 1.2
	cooldown = 1
	color = Color(0.3, 0.7, 1.0)


func randomize_params(rng: RandomNumberGenerator) -> void:
	lobes = rng.randi_range(1, 2)
	var k: float = PI * lobes / ChunkSpec.SIZE
	var amp_max: float = 1.0 / (3.0 * k * k * ChunkSpec.MIN_TURN_RADIUS)
	# 코스+벽이 청크 밖으로 나가지 않게
	var lateral_room: float = ChunkSpec.CENTER_X - ChunkSpec.HALF_WIDTH - ChunkSpec.WALL_RAMP - 8.0
	amp_max = minf(amp_max, lateral_room)
	amp = rng.randf_range(0.6, 1.0) * amp_max * (1.0 if rng.randf() < 0.5 else -1.0)


func center_offset(v: float) -> float:
	var s: float = sin(PI * lobes * v)
	return amp * s * s * s


func describe() -> String:
	return "%s n=%d amp=%.0fm" % [type_name, lobes, amp]
