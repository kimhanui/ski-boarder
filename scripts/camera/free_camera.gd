extends Camera3D

## Free camera for spectating and terrain inspection
## Toggle with Tab key, control with mouse and keyboard

@export var move_speed: float = 50.0
@export var fast_speed_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003
@export var initial_position: Vector3 = Vector3(0, 100, 100)
@export var target: Node3D = null  # Target to follow (for dummy player switching)

var _rotation_x: float = -0.5  # Pitch
var _rotation_y: float = 0.0   # Yaw
var _is_active: bool = false
var _mouse_captured: bool = false


func _ready() -> void:
	# Position camera high above terrain
	global_position = initial_position
	_rotation_x = -0.5  # Look down slightly
	_update_camera_rotation()
	# Start inactive
	current = false


## 입력 처리 - 카메라가 활성화되었을 때만 처리
## 중요: `return`으로 조기 종료해도 이벤트는 소비되지 않음!
## 이벤트를 명시적으로 소비하려면 `get_viewport().set_input_as_handled()` 호출 필요
## 현재 구현은 비활성 시 이벤트를 전파하므로 UI 버튼 클릭에 영향 없음
func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Mouse motion for camera rotation
	if event is InputEventMouseMotion and _mouse_captured:
		_rotation_y -= event.relative.x * mouse_sensitivity
		_rotation_x -= event.relative.y * mouse_sensitivity
		_rotation_x = clamp(_rotation_x, -PI/2, PI/2)
		_update_camera_rotation()

	# Right mouse button to capture/release mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_mouse_captured = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_mouse_captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	# Get movement input
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.z += 1  # Fixed: was inverted
	if Input.is_action_pressed("move_back"):
		input_dir.z -= 1  # Fixed: was inverted
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# Up/Down with Q/E or Space/Ctrl
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

		# Apply speed multiplier when Shift is held
		var speed = move_speed
		if Input.is_action_pressed("sprint"):  # Shift key
			speed *= fast_speed_multiplier

		# Transform direction relative to camera orientation
		var forward = -global_transform.basis.z
		var right = global_transform.basis.x
		var up = Vector3.UP

		var movement = (right * input_dir.x + up * input_dir.y + forward * input_dir.z) * speed * delta
		global_position += movement


func activate() -> void:
	_is_active = true
	current = true

	# Position camera to face target (if set) or player (fallback)
	var target_node = target if target else get_tree().get_first_node_in_group("player")

	if target_node:
		var target_pos = target_node.global_position
		# Position camera behind and above target
		global_position = target_pos + Vector3(0, 5, 10)
		# Look at target
		look_at(target_pos, Vector3.UP)
		# Update rotation variables to match
		_rotation_y = rotation.y
		_rotation_x = rotation.x
		print("[FreeCamera] Activated - Following: %s" % target_node.name)
	else:
		print("[FreeCamera] Activated - No target found")

	print("Free camera activated - Right-click and drag to rotate, WASD to move, Space/Ctrl for up/down, Shift for speed")


func deactivate() -> void:
	_is_active = false
	current = false
	if _mouse_captured:
		_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Free camera deactivated")


func _update_camera_rotation() -> void:
	rotation.x = _rotation_x
	rotation.y = _rotation_y
	rotation.z = 0


## Set camera target (for switching between dummy players)
func set_target(new_target: Node3D) -> void:
	target = new_target

	# If camera is active, immediately position relative to new target
	if target and _is_active:
		var target_pos = target.global_position
		global_position = target_pos + Vector3(0, 5, 10)
		look_at(target_pos, Vector3.UP)
		# Update rotation variables to match
		_rotation_y = rotation.y
		_rotation_x = rotation.x
		print("[FreeCamera] Target switched to: %s" % target.name)
