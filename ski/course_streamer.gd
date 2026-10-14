class_name CourseStreamer
extends Node
## P2: focus 노드 위치를 기준으로 청크를 앞에 추가 / 뒤에서 삭제하고,
## Terrain3D 월드 한계(±16 region)에 가까워지면 전체를 뒤로 옮기는 리센터를 수행.
##
## 인덱스 두 가지:
##   global: 코스 처음부터 센 청크 번호 (0,1,2,... 영원히 증가). 시퀀서/표시용.
##   local : Terrain3D 월드 안의 region z 위치 (-16..15). local = global - shift.
## 월드 좌표는 local 로만 결정됨 → 리센터 = shift 를 바꾸고 다시 import 하는 것.

signal chunk_spawned(global_index: int, type: ChunkType)
signal chunk_removed(global_index: int)
## 리센터 직후. offset 만큼 모든 월드 오브젝트를 옮겨야 함 (focus 는 streamer 가 직접 옮김).
signal recentered(offset: Vector3)

const LOCAL_MIN: int = -16          ## Terrain3DData.REGION_MAP_SIZE / 2
const START_LOCAL: int = -12        ## global 0 이 놓이는 local 위치
const RECENTER_AT_LOCAL: int = 8    ## focus 가 이 local 청크에 들어가면 리센터
const RECENTER_STEP: int = 16       ## 리센터 한 번에 뒤로 옮기는 청크 수

@export var terrain: Terrain3D
@export var focus: Node3D
@export var course_seed: int = 1
@export_range(1, 8) var chunks_ahead: int = 4
@export_range(1, 4) var chunks_behind: int = 2
@export var show_debug: bool = true      ## 코스 중심선(타입 색)
@export var show_labels: bool = false:   ## 3D 라벨 (기본 끔: HUD 목록으로 대체)
	set(value):
		show_labels = value
		for e in _chunks.values():
			if is_instance_valid(e["debug"]):
				ChunkDebug.set_label_visible(e["debug"], value)
@export var max_spawns_per_frame: int = 1

var shift: int = -START_LOCAL       ## local = global - shift
var recenter_count: int = 0
var last_build_ms: float = 0.0
var last_recenter_ms: float = 0.0

var _seq: CourseSequencer
var _next_global: int = 0           ## 다음에 생성할 global
var _chunks: Dictionary = {}        ## global -> {"type": ChunkType, "img": Image, "debug": Node3D}
var _debug_root: Node3D


func _ready() -> void:
	SkiAssets.setup_terrain(terrain)
	reset()


func reset() -> void:
	for g in _chunks.keys():
		_remove_chunk(g, false)
	for loc in terrain.data.get_region_locations():
		terrain.data.remove_regionl(loc, false)
	terrain.data.update_maps()
	if is_instance_valid(_debug_root):
		_debug_root.queue_free()
	_debug_root = Node3D.new()
	_debug_root.name = "_StreamDebug"
	_debug_root.visible = show_debug
	add_child(_debug_root)
	_seq = CourseSequencer.new(course_seed)
	_next_global = 0
	shift = -START_LOCAL
	recenter_count = 0
	# 시작 시 앞쪽 청크를 미리 다 만들어 둠
	for i in chunks_ahead + 1:
		_spawn_next()


func _process(_delta: float) -> void:
	if not is_instance_valid(focus):
		return
	var g: int = focus_global_index()
	# focus 가 살아있는 청크보다 뒤에 있으면(Free 카메라로 역주행 등) 무시: 지운 청크는 되살리지 않음
	if not _chunks.is_empty():
		g = maxi(g, alive_range().x)
	# 리센터
	if g - shift >= RECENTER_AT_LOCAL:
		_recenter()
		g = maxi(focus_global_index(), alive_range().x)
	# 앞쪽 생성
	var spawned: int = 0
	while _next_global <= g + chunks_ahead and spawned < max_spawns_per_frame:
		_spawn_next()
		spawned += 1
	# 뒤쪽 삭제
	for key in _chunks.keys():
		if int(key) < g - chunks_behind:
			_remove_chunk(int(key), true)


# ---------- 조회 API ----------

func has_chunk(global_index: int) -> bool:
	return _chunks.has(global_index)


func get_chunk_type(global_index: int) -> ChunkType:
	return _chunks[global_index]["type"] if _chunks.has(global_index) else null


func chunk_origin_global(global_index: int) -> Vector3:
	return ChunkSpec.chunk_origin(global_index - shift)


## 코스 중심선 위의 월드 좌표.
func center_point(global_index: int, v: float) -> Vector3:
	return chunk_origin_global(global_index) + ChunkBuilder.center_point(_chunks[global_index]["type"], v)


func global_index_at(world_z: float) -> int:
	return floori(world_z / ChunkSpec.SIZE) + shift


func focus_global_index() -> int:
	return global_index_at(focus.global_position.z)


## 살아있는 청크 global 번호 목록 (오름차순).
func alive_indices() -> Array:
	var keys: Array = _chunks.keys()
	keys.sort()
	return keys


func alive_range() -> Vector2i:
	if _chunks.is_empty():
		return Vector2i(-1, -1)
	var keys: Array = _chunks.keys()
	return Vector2i(keys.min(), keys.max())


# ---------- 내부 ----------

func _spawn_next() -> void:
	var g: int = _next_global
	var t: ChunkType = _seq.next()
	var t0: int = Time.get_ticks_usec()
	var img: Image = ChunkBuilder.build(t)
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	var entry := {"type": t, "img": img, "debug": null}
	_chunks[g] = entry
	_import(g)
	terrain.data.update_maps()
	if show_debug:
		var dbg: Node3D = ChunkDebug.make(t, g)
		ChunkDebug.set_label_visible(dbg, show_labels)
		dbg.position = chunk_origin_global(g)
		_debug_root.add_child(dbg)
		entry["debug"] = dbg
	_next_global += 1
	chunk_spawned.emit(g, t)


func _import(g: int) -> void:
	var o: Vector3 = chunk_origin_global(g)
	terrain.data.import_images([_chunks[g]["img"], null, null], Vector3(o.x, 0.0, o.z), o.y, 1.0)


func _remove_chunk(g: int, update: bool) -> void:
	var local: int = g - shift
	if local >= LOCAL_MIN and local < -LOCAL_MIN:
		terrain.data.remove_regionl(Vector2i(0, local), false)
	var dbg = _chunks[g]["debug"]
	if is_instance_valid(dbg):
		dbg.queue_free()
	_chunks.erase(g)
	if update:
		terrain.data.update_maps()
	chunk_removed.emit(g)


func _recenter() -> void:
	var t0: int = Time.get_ticks_usec()
	# 1) 현재 region 전부 제거
	for g in _chunks.keys():
		terrain.data.remove_regionl(Vector2i(0, int(g) - shift), false)
	# 2) shift 변경 → 같은 global 청크가 RECENTER_STEP 만큼 뒤(-Z), 위(+Y)로
	shift += RECENTER_STEP
	var offset := Vector3(0.0, ChunkSpec.DROP * RECENTER_STEP, -float(ChunkSpec.SIZE * RECENTER_STEP))
	# 3) 캐시된 이미지로 다시 import (재생성 없음 → 동일 지형)
	for g in _chunks.keys():
		_import(int(g))
		var dbg = _chunks[g]["debug"]
		if is_instance_valid(dbg):
			dbg.position += offset
	terrain.data.update_maps()
	# 4) focus 이동 + 다른 오브젝트에 알림
	focus.global_position += offset
	recenter_count += 1
	last_recenter_ms = (Time.get_ticks_usec() - t0) / 1000.0
	recentered.emit(offset)
