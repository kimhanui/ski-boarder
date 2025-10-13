extends CharacterBody3D

# Player movement constants
const SPEED = 8.0
const TURN_SPEED = 3.0
const JUMP_VELOCITY = 6.0
const GRAVITY = 9.8

# Camera references
@onready var camera_third_person = $Camera3D_ThirdPerson
@onready var camera_first_person = $Camera3D_FirstPerson
@onready var camera_free = $Camera3D_Free

var is_first_person = false
var is_free_camera = false


func _ready() -> void:
	# Set initial camera
	camera_third_person.current = true
	camera_first_person.current = false
	camera_free.current = false


func _physics_process(delta: float) -> void:
	# Skip player physics when in free camera mode
	if is_free_camera:
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction
	# Input.get_vector(negative_x, positive_x, negative_y, positive_y)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Log input for debugging
	if input_dir != Vector2.ZERO:
		var keys_pressed = []
		if Input.is_action_pressed("move_forward"):
			keys_pressed.append("W (Forward)")
		if Input.is_action_pressed("move_back"):
			keys_pressed.append("S (Back)")
		if Input.is_action_pressed("move_left"):
			keys_pressed.append("A (Left)")
		if Input.is_action_pressed("move_right"):
			keys_pressed.append("D (Right)")
		print("Keys pressed: ", keys_pressed, " | Input direction: ", input_dir)

	# Apply movement
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)

	# Apply physics
	move_and_slide()


func _input(event: InputEvent) -> void:
	# Toggle free camera with Tab
	if event.is_action_pressed("ui_focus_next"):  # Tab key
		is_free_camera = !is_free_camera

		if is_free_camera:
			camera_free.activate()
			camera_third_person.current = false
			camera_first_person.current = false
		else:
			camera_free.deactivate()
			# Restore previous camera state
			camera_third_person.current = !is_first_person
			camera_first_person.current = is_first_person

	# Toggle between 1st and 3rd person (F1 key) - only when not in free camera
	if event.is_action_pressed("toggle_camera") and not is_free_camera:
		is_first_person = !is_first_person
		camera_third_person.current = !is_first_person
		camera_first_person.current = is_first_person
