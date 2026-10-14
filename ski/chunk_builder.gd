class_name ChunkBuilder
extends RefCounted
## ChunkType → 256×256 높이맵(FORMAT_RF, 청크 입구 기준 상대 높이).
## h = 기본경사(v) + 단면(|x − 중심(v)|) + 디테일 × edge_mask(v)


static func build(t: ChunkType) -> Image:
	var S: int = ChunkSpec.SIZE
	var data := PackedFloat32Array()
	data.resize(S * S)
	for z in S:
		var v: float = float(z) / S
		var m: float = ChunkSpec.edge_mask(v)
		var base: float = base_height(t, v, m)
		var cx: float = center_x(t, v, m)
		var hw: float = lerpf(ChunkSpec.HALF_WIDTH, t.half_width(v), m)
		var wh: float = lerpf(ChunkSpec.WALL_HEIGHT, t.wall_height(v), m)
		var use_detail: bool = t.has_detail() and m > 0.0
		var row: int = z * S
		for x in S:
			var d: float = float(x) - cx
			var h: float = base + section(absf(d), hw, wh)
			if use_detail:
				h += t.detail(d, float(z), hw) * m
			data[row + x] = h
	return Image.create_from_data(S, S, false, Image.FORMAT_RF, data.to_byte_array())


static func base_height(t: ChunkType, v: float, m: float) -> float:
	return -ChunkSpec.DROP * lerpf(v, t.slope(v), m)


## 중심 이동에는 마스크를 곱하지 않음: 마스크가 커브 시작부를 압축해 반경이 작아지기 때문.
## 대신 타입이 center_offset 의 값·기울기·곡률을 v=0,1 에서 0 으로 직접 보장해야 함.
static func center_x(t: ChunkType, v: float, _m: float) -> float:
	return ChunkSpec.CENTER_X + t.center_offset(v)


## 코스 단면: 반폭 안은 평평, 바깥은 벽 → 완만한 산비탈.
static func section(ad: float, hw: float, wh: float) -> float:
	if ad <= hw:
		return 0.0
	var k: float = ad - hw
	return wh * smoothstep(0.0, ChunkSpec.WALL_RAMP, k) + maxf(k - ChunkSpec.WALL_RAMP, 0.0) * ChunkSpec.OUTER_RISE


## 코스 중심선 위의 점(청크 로컬, 입구 높이 기준). Rail Follower / 디버그 라인용.
static func center_point(t: ChunkType, v: float) -> Vector3:
	var m: float = ChunkSpec.edge_mask(v)
	return Vector3(center_x(t, v, m), base_height(t, v, m), v * ChunkSpec.SIZE)
