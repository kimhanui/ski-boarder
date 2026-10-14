@tool
class_name CoursePreview
extends Node3D
## P1: 실행하지 않고 에디터에서 청크 N개를 생성해 확인하는 도구.
## 인스펙터 버튼: Generate / New Seed / Clear
## 생성된 지형은 저장되지 않음(Terrain3D data_directory 비움) → 언제든 다시 생성.

@export var terrain: Terrain3D
@export var course_seed: int = 1
## 원점(z=0)부터 +Z 로 배치. Terrain3D 월드 한계(±16 region) 때문에 최대 16개.
@export_range(1, 16) var chunk_count: int = 8
@export var show_debug: bool = true:
	set(value):
		show_debug = value
		if is_instance_valid(_debug_root):
			_debug_root.visible = value

@export_tool_button("Generate", "Play") var _btn_generate: Callable = generate
@export_tool_button("New Seed", "RandomNumberGenerator") var _btn_reseed: Callable = reseed
@export_tool_button("Clear", "Remove") var _btn_clear: Callable = clear

var chunks: Array[ChunkType] = []
var _debug_root: Node3D


func _ready() -> void:
	# 씬을 열거나 실행하면 자동 생성
	generate.call_deferred()


func reseed() -> void:
	course_seed = randi() % 100000
	notify_property_list_changed()
	generate()


func generate() -> void:
	if not _check_terrain():
		return
	var t0: int = Time.get_ticks_msec()
	clear()
	_setup_terrain()

	var seq := CourseSequencer.new(course_seed)
	var count: int = mini(chunk_count, Terrain3DData.REGION_MAP_SIZE / 2)
	for i in count:
		var t: ChunkType = seq.next()
		chunks.append(t)
		var img: Image = ChunkBuilder.build(t)
		var origin: Vector3 = ChunkSpec.chunk_origin(i)
		terrain.data.import_images([img, null, null], Vector3(origin.x, 0.0, origin.z), origin.y, 1.0)

	_build_debug()
	var report: String = check_seams()
	print("[CoursePreview] seed=%d, %d chunks, %d ms" % [course_seed, chunk_count, Time.get_ticks_msec() - t0])
	for i in chunks.size():
		print("  #%d  %s" % [i, chunks[i].describe()])
	print(report)


func clear() -> void:
	chunks.clear()
	if is_instance_valid(_debug_root):
		_debug_root.queue_free()
		_debug_root = null
	if not _check_terrain():
		return
	for loc in terrain.data.get_region_locations():
		terrain.data.remove_regionl(loc, false)
	terrain.data.update_maps()


## 인접 청크 경계에서 높이 기울기가 끊기는지 검사. (기울기 변화량 = 2차 차분)
func check_seams(tolerance: float = 0.01) -> String:
	var S: int = ChunkSpec.SIZE
	var lines: PackedStringArray = ["[SeamCheck] tolerance %.3fm" % tolerance]
	var all_ok: bool = true
	for i in range(1, chunks.size()):
		var zb: float = float(i * S)
		var worst: float = 0.0
		var worst_x: int = 0
		for x in S:
			var h0: float = terrain.data.get_height(Vector3(x, 0, zb - 2.0))
			var h1: float = terrain.data.get_height(Vector3(x, 0, zb - 1.0))
			var h2: float = terrain.data.get_height(Vector3(x, 0, zb))
			var h3: float = terrain.data.get_height(Vector3(x, 0, zb + 1.0))
			# 경계 양쪽의 2차 차분 중 큰 값
			var e: float = maxf(absf(h2 - 2.0 * h1 + h0), absf(h3 - 2.0 * h2 + h1))
			if is_nan(e):
				e = INF
			if e > worst:
				worst = e
				worst_x = x
		var ok: bool = worst < tolerance
		all_ok = all_ok and ok
		lines.append("  #%d|#%d  max=%.4fm at x=%d  %s" % [i - 1, i, worst, worst_x, "OK" if ok else "FAIL"])
	lines.append("  => %s" % ("ALL OK" if all_ok else "SEAM PROBLEM"))
	return "\n".join(lines)


## 월드 좌표의 코스 중심선 (P2 Rail Follower 에서도 사용 예정).
func center_point_world(index: int, v: float) -> Vector3:
	return ChunkSpec.chunk_origin(index) + ChunkBuilder.center_point(chunks[index], v)


func _check_terrain() -> bool:
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("CoursePreview: terrain 이 지정되지 않았거나 준비되지 않음")
		return false
	return true


func _setup_terrain() -> void:
	SkiAssets.setup_terrain(terrain)


func _build_debug() -> void:
	_debug_root = Node3D.new()
	_debug_root.name = "_Debug"
	_debug_root.visible = show_debug
	add_child(_debug_root)  # owner 미지정 → 씬에 저장되지 않음

	# 코스 중심선 (타입별 색)
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var steps: int = ChunkSpec.SIZE / 4
	for i in chunks.size():
		im.surface_set_color(chunks[i].color)
		for s in steps:
			var p: Vector3 = center_point_world(i, float(s) / steps)
			p.y = terrain.data.get_height(p) + 1.0
			im.surface_add_vertex(p)
	im.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = im
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_root.add_child(line)

	# 청크 번호 + 타입 라벨
	for i in chunks.size():
		var lbl := Label3D.new()
		lbl.text = "#%d %s" % [i, chunks[i].describe()]
		lbl.modulate = chunks[i].color
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.fixed_size = true
		lbl.pixel_size = 0.002
		lbl.font_size = 40
		lbl.outline_size = 12
		var p: Vector3 = center_point_world(i, 0.08)
		p.y = terrain.data.get_height(p) + 12.0
		lbl.position = p
		_debug_root.add_child(lbl)
