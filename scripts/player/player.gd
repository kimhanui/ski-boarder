extends CharacterBody3D

# Player movement constants
const SPEED = 8.0
const TURN_SPEED = 3.0
const JUMP_VELOCITY = 6.0
const GRAVITY = 9.8

# Camera references
@onready var camera_third_person = $Camera3D_ThirdPerson
@onready var camera_first_person = $Camera3D_FirstPerson

var is_first_person = false


func _ready() -> void:
	# Set initial camera
	camera_third_person.current = true
	camera_first_person.current = false


func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

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
	# Toggle camera
	if event.is_action_pressed("toggle_camera"):
		is_first_person = !is_first_person
		camera_third_person.current = !is_first_person
		camera_first_person.current = is_first_person
