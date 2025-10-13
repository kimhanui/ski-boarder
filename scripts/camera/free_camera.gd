extends Camera3D

# Free flying camera for debugging/spectating
const SPEED = 10.0
const FAST_SPEED = 20.0
const MOUSE_SENSITIVITY = 0.003

var rotation_x = 0.0
var rotation_y = 0.0
var is_active = false


func _ready() -> void:
	# Start inactive
	current = false


func activate() -> void:
	is_active = true
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Set initial rotation based on current transform
	rotation_y = rotation.y
	rotation_x = rotation.x


func deactivate() -> void:
	is_active = false
	current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	# Handle mouse look
	if event is InputEventMouseMotion:
		rotation_y -= event.relative.x * MOUSE_SENSITIVITY
		rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		rotation_x = clamp(rotation_x, -PI / 2, PI / 2)

		transform.basis = Basis()
		rotate_object_local(Vector3.UP, rotation_y)
		rotate_object_local(Vector3.RIGHT, rotation_x)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Get movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Vertical movement
	var vertical = 0.0
	if Input.is_action_pressed("jump"):
		vertical = 1.0
	if Input.is_action_pressed("crouch"):
		vertical = -1.0

	# Speed modifier (Shift for faster)
	var speed = FAST_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED

	# Apply movement
	if direction != Vector3.ZERO or vertical != 0:
		var velocity = direction * speed
		velocity.y = vertical * speed
		global_position += velocity * delta
