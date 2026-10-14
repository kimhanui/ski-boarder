class_name CourseSequencer
extends RefCounted
## 다음 청크 타입을 결정. 같은 seed → 같은 코스.
## 규칙:
##   - 0번 청크는 항상 Straight (출발 구간)
##   - REST_EVERY 번째마다 Rest
##   - 각 타입의 cooldown 동안 같은 타입 금지
##   - 나머지는 weight 기반 랜덤

const REST_EVERY: int = 6

var rng := RandomNumberGenerator.new()
var index: int = 0
var _protos: Array[ChunkType] = []
var _last_used: Dictionary = {}  # type_name -> index


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value
	_protos = [StraightChunk.new(), SCurveChunk.new(), MogulsChunk.new(), SteepChunk.new(), RestChunk.new()]


func next() -> ChunkType:
	var proto: ChunkType
	if index == 0:
		proto = _protos[0]
	elif index % REST_EVERY == REST_EVERY - 1:
		proto = _find("Rest")
	else:
		proto = _pick_weighted()
	var t: ChunkType = proto.get_script().new()
	t.randomize_params(rng)
	_last_used[t.type_name] = index
	index += 1
	return t


func _find(type_name: String) -> ChunkType:
	for p in _protos:
		if p.type_name == type_name:
			return p
	return _protos[0]


func _pick_weighted() -> ChunkType:
	var pool: Array[ChunkType] = []
	var total: float = 0.0
	for p in _protos:
		if p.weight <= 0.0:
			continue
		if _last_used.has(p.type_name) and index - int(_last_used[p.type_name]) <= p.cooldown:
			continue
		pool.append(p)
		total += p.weight
	if pool.is_empty():
		return _protos[0]
	var r: float = rng.randf() * total
	for p in pool:
		r -= p.weight
		if r <= 0.0:
			return p
	return pool[-1]
