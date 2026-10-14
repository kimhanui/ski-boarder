class_name FreeCamera
extends Camera3D
## 자유 비행 카메라 (지형 통과 가능). active 일 때만 입력을 받음.
## 우클릭 드래그: 시점   WASD: 이동   Q/E: 하강/상승   Shift: 3배   휠: 기본 속도 조절

@export var active: bool = false
@export var base_speed: float = 40.0
@export var mouse_sensitivity: float = 0.003

var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	_yaw = rotation.y
	_pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			base_speed = minf(base_speed * 1.25, 1000.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			base_speed = maxf(base_speed / 1.25, 2.0)
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= mm.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if not active:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= basis.z
	if Input.is_key_pressed(KEY_S): dir += basis.z
	if Input.is_key_pressed(KEY_A): dir -= basis.x
	if Input.is_key_pressed(KEY_D): dir += basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir == Vector3.ZERO:
		return
	var spd: float = base_speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += dir.normalized() * spd * delta


## 다른 카메라 시점에서 이어받기.
func take_over_from(cam: Camera3D) -> void:
	global_transform = cam.global_transform
	_yaw = rotation.y
	_pitch = rotation.x
	rotation = Vector3(_pitch, _yaw, 0.0)
