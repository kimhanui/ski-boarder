class_name RailFollower
extends Node3D
## 물리 없이 코스 중심선을 따라 이동하는 관찰자. 절대 떨어지지 않음.
## 위치는 매 프레임 (global_index, v) 로부터 다시 계산 → 리센터에도 자동으로 맞춰짐.
##
## 조작:  + / -  속도 ±5 m/s   Space 일시정지   N 다음 청크로 점프

@export var streamer: CourseStreamer
@export var speed: float = 20.0          ## m/s
@export var height_above: float = 2.0    ## 중심선 위 높이(m)
@export var look_ahead: float = 12.0     ## 바라보는 앞쪽 거리(m)
@export var paused: bool = false

var global_index: int = 0
var v: float = 0.05
var waiting: bool = false   ## 다음 청크가 아직 없어서 대기 중


func _ready() -> void:
	restart()


## 코스 시작점(0번 청크)으로 이동.
func restart() -> void:
	global_index = 0
	v = 0.05
	waiting = false
	if is_instance_valid(streamer):
		_place()


func _process(delta: float) -> void:
	if not is_instance_valid(streamer):
		return
	if not paused:
		_advance(speed * delta)
	_place()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			speed = minf(speed + 5.0, 200.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			speed = maxf(speed - 5.0, 0.0)
		KEY_SPACE:
			paused = not paused
		KEY_N:
			if streamer.has_chunk(global_index + 1):
				global_index += 1
				v = 0.0


## 중심선의 z 방향 거리로 근사해서 전진 (커브에서 약간 빠르게 느껴질 수 있음).
func _advance(dist: float) -> void:
	var nv: float = v + dist / ChunkSpec.SIZE
	while nv >= 1.0:
		if not streamer.has_chunk(global_index + 1):
			nv = 0.999
			waiting = true
			break
		nv -= 1.0
		global_index += 1
	if nv < 0.999:
		waiting = false
	v = nv


func _place() -> void:
	if not streamer.has_chunk(global_index):
		return
	var p: Vector3 = streamer.center_point(global_index, v) + Vector3.UP * height_above
	global_position = p
	var ahead: Vector3 = _point_ahead(look_ahead) + Vector3.UP * height_above
	if not ahead.is_equal_approx(p):
		look_at(ahead, Vector3.UP)


func _point_ahead(dist: float) -> Vector3:
	var g: int = global_index
	var nv: float = v + dist / ChunkSpec.SIZE
	if nv >= 1.0 and streamer.has_chunk(g + 1):
		g += 1
		nv -= 1.0
	nv = minf(nv, 1.0)
	return streamer.center_point(g, nv)
