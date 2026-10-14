extends Node3D
## P2 테스트 씬 컨트롤러.
##   Tab: Rail ↔ Free 카메라 전환   R: 새 시드로 리셋
##   H: HUD 숨김   L: 3D 라벨 표시   [ / ]: HUD 글씨 크기
##   Rail 모드: + / - 속도, Space 일시정지, N 다음 청크
##   Free 모드: 우클릭 드래그 시점, WASD/QE 이동, Shift 3배, 휠 속도

const BASE_FONT := 20

@onready var terrain: Terrain3D = $Terrain3D
@onready var streamer: CourseStreamer = $CourseStreamer
@onready var rail: RailFollower = $RailFollower
@onready var chase_cam: Camera3D = $RailFollower/ChaseCam
@onready var free_cam: FreeCamera = $FreeCamera
@onready var hud_layer: CanvasLayer = $HUD
@onready var status_label: Label = $HUD/Label

var mode_free: bool = false
var font_scale: float = 1.0
var type_counts: Dictionary = {}     ## 시작 후 등장한 타입별 개수
var _chunk_list: RichTextLabel
var _status_panel: PanelContainer
var _list_panel: PanelContainer


func _ready() -> void:
	streamer.recentered.connect(_on_recentered)
	streamer.chunk_spawned.connect(_on_chunk_spawned)
	# 이미 만들어진 시작 청크도 집계
	for g in streamer.alive_indices():
		_on_chunk_spawned(g, streamer.get_chunk_type(g))
	# 레티나 등 고해상도 화면이면 자동으로 크게
	font_scale = maxf(1.0, DisplayServer.screen_get_scale())
	_build_hud()
	_set_mode(false)


# ---------------- 입력 ----------------

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_TAB:
			_set_mode(not mode_free)
		KEY_R:
			streamer.course_seed = randi() % 100000
			type_counts.clear()
			streamer.reset()  # 시작 청크는 chunk_spawned 신호로 집계됨
			rail.restart()
			_set_mode(false)
		KEY_H:
			hud_layer.visible = not hud_layer.visible
		KEY_L:
			streamer.show_labels = not streamer.show_labels
		KEY_BRACKETRIGHT:
			font_scale = minf(font_scale + 0.25, 4.0)
			_apply_font()
		KEY_BRACKETLEFT:
			font_scale = maxf(font_scale - 0.25, 0.5)
			_apply_font()


func _set_mode(free: bool) -> void:
	mode_free = free
	free_cam.active = free
	if free:
		free_cam.take_over_from(chase_cam)
		free_cam.make_current()
		streamer.focus = free_cam
		terrain.set_camera(free_cam)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		chase_cam.make_current()
		streamer.focus = rail
		terrain.set_camera(chase_cam)


## streamer 는 focus 만 옮겨 줌 → 나머지 월드 오브젝트는 여기서 옮김.
## (RailFollower 는 (청크, v) 로 위치를 계산하므로 옮길 필요 없음)
func _on_recentered(offset: Vector3) -> void:
	if streamer.focus != free_cam:
		free_cam.global_position += offset


func _on_chunk_spawned(_g: int, t: ChunkType) -> void:
	type_counts[t.type_name] = int(type_counts.get(t.type_name, 0)) + 1


# ---------------- HUD ----------------

func _build_hud() -> void:
	# 왼쪽 위: 상태 (기존 Label 을 패널로 감쌈)
	_status_panel = _make_panel()
	_status_panel.position = Vector2(10, 10)
	hud_layer.add_child(_status_panel)
	status_label.reparent(_status_panel)
	status_label.label_settings = null

	# 오른쪽 위: 청크 배열
	_list_panel = _make_panel()
	hud_layer.add_child(_list_panel)
	_chunk_list = RichTextLabel.new()
	_chunk_list.bbcode_enabled = true
	_chunk_list.fit_content = true
	_chunk_list.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chunk_list.scroll_active = false
	_list_panel.add_child(_chunk_list)
	_apply_font()


func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _apply_font() -> void:
	var size: int = int(BASE_FONT * font_scale)
	status_label.add_theme_font_size_override("font_size", size)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	for key in ["normal_font_size", "bold_font_size", "mono_font_size"]:
		_chunk_list.add_theme_font_size_override(key, size)
	_chunk_list.custom_minimum_size.x = size * 22
	# 크기 바뀐 뒤 오른쪽 정렬 다시 맞춤
	_list_panel.reset_size()
	_status_panel.reset_size()


func _process(_delta: float) -> void:
	if not hud_layer.visible:
		return
	var g: int = streamer.focus_global_index()
	var progress: float = rail.v if not mode_free else fposmod(streamer.focus.global_position.z, ChunkSpec.SIZE) / ChunkSpec.SIZE
	if not mode_free:
		g = rail.global_index
	_update_status(g)
	_update_chunk_list(g, progress)
	_list_panel.reset_size()
	_status_panel.reset_size()
	var vw: float = get_viewport().get_visible_rect().size.x
	_list_panel.position = Vector2(vw - _list_panel.size.x - 10.0, 10.0)


func _update_status(g: int) -> void:
	var r: Vector2i = streamer.alive_range()
	var lines: PackedStringArray = [
		"[%s]  Tab 전환 · R 새 시드 · L 라벨 · [ ] 글씨" % ("FREE" if mode_free else "RAIL"),
		"seed %d    FPS %d" % [streamer.course_seed, Engine.get_frames_per_second()],
		"local z %d / 리센터 %d   (%d회, %.1f ms)" % [g - streamer.shift, CourseStreamer.RECENTER_AT_LOCAL, streamer.recenter_count, streamer.last_recenter_ms],
		"region %d개   청크 생성 %.1f ms" % [terrain.data.get_region_count(), streamer.last_build_ms],
	]
	if mode_free:
		lines.append("free %.0f m/s (휠)" % free_cam.base_speed)
	else:
		var st: String = "  [일시정지]" if rail.paused else ("  [청크 대기]" if rail.waiting else "")
		lines.append("rail %.0f m/s%s  (+/- · Space · N)" % [rail.speed, st])
	status_label.text = "\n".join(lines)


func _update_chunk_list(g: int, progress: float) -> void:
	var sb: PackedStringArray = ["[b]코스 배열[/b]  (위 = 앞쪽)"]
	var idx: Array = streamer.alive_indices()
	idx.reverse()  # 앞쪽(먼 청크)이 위
	for i in idx:
		var t: ChunkType = streamer.get_chunk_type(i)
		var hex: String = t.color.to_html(false)
		var mark: String
		if i == g:
			var filled: int = clampi(int(progress * 10.0), 0, 10)
			mark = "[b]▶ #%-3d %s[/b]  %s%s" % [i, t.describe(), "■".repeat(filled), "□".repeat(10 - filled)]
		elif i < g:
			mark = "[color=#888888]   #%-3d %s   (지나감)[/color]" % [i, t.describe()]
			sb.append(mark)
			continue
		else:
			mark = "   #%-3d %s   +%d" % [i, t.describe(), i - g]
		sb.append("[color=#%s]%s[/color]" % [hex, mark])
	# 타입별 누적 등장 횟수
	var counts: PackedStringArray = []
	for name in ["Straight", "SCurve", "Moguls", "Steep", "Rest"]:
		counts.append("%s %d" % [name, int(type_counts.get(name, 0))])
	sb.append("")
	sb.append("[color=#aaaaaa]누적: %s[/color]" % " · ".join(counts))
	_chunk_list.text = "\n".join(sb)
