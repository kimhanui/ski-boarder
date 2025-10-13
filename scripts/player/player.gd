extends CharacterBody3D

# Player movement constants
const SPEED = 8.0
const TURN_SPEED = 3.0
const JUMP_VELOCITY = 6.0
const GRAVITY = 9.8

# Animation constants
const TILT_AMOUNT = 30.0  # degrees
const LEAN_AMOUNT = 20.0  # degrees
const ANIMATION_SPEED = 10.0  # how fast animations interpolate

# Camera references
@onready var camera_third_person = $Camera3D_ThirdPerson
@onready var camera_first_person = $Camera3D_FirstPerson

# Body parts references
@onready var body = $Body
@onready var left_ski = $Body/LeftLeg/Ski
@onready var right_ski = $Body/RightLeg/Ski
@onready var left_eye = $Body/Head/LeftEye
@onready var right_eye = $Body/Head/RightEye

var is_first_person = false
var _player_cameras_active = true  # Track if player cameras are in control

# Animation state
var current_tilt = 0.0  # Current Z-axis rotation (roll)
var current_lean = 0.0  # Current X-axis rotation (pitch)
var target_tilt = 0.0
var target_lean = 0.0


func _ready() -> void:
	# Add to player group for free camera to find
	add_to_group("player")

	# Set initial camera
	camera_third_person.current = true
	camera_first_person.current = false

	# Hide eyes in first person initially (they're visible in 3rd person)
	_update_eye_visibility()


func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Calculate target animations based on input
	var is_braking = Input.is_action_pressed("move_back")

	# Tilt left/right based on horizontal input
	target_tilt = -input_dir.x * TILT_AMOUNT

	# Lean forward/back based on vertical input
	if is_braking:
		# Brake stance: lean back
		target_lean = -15.0
	elif Input.is_action_pressed("move_forward"):
		# Accelerate: lean forward
		target_lean = LEAN_AMOUNT
	else:
		# Neutral stance
		target_lean = 0.0

	# Smoothly interpolate to target rotations
	current_tilt = lerp(current_tilt, target_tilt, ANIMATION_SPEED * delta)
	current_lean = lerp(current_lean, target_lean, ANIMATION_SPEED * delta)

	# Apply body rotation
	body.rotation_degrees.z = current_tilt
	body.rotation_degrees.x = current_lean

	# Handle ski positioning for braking
	_update_ski_stance(is_braking, delta)

	# Apply movement
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)

	# Apply physics
	move_and_slide()

	# Debug: log position when falling
	if global_position.y < -50:
		print("Player fell through terrain! Position: ", global_position)


func _input(event: InputEvent) -> void:
	# Toggle camera (only when player cameras are active)
	if event.is_action_pressed("toggle_camera") and _player_cameras_active:
		is_first_person = !is_first_person
		camera_third_person.current = !is_first_person
		camera_first_person.current = is_first_person
		_update_eye_visibility()


## Update eye visibility based on camera mode
func _update_eye_visibility() -> void:
	# Hide eyes in first-person view (they're too close to camera)
	# Show eyes in third-person view
	if left_eye and right_eye:
		left_eye.visible = !is_first_person
		right_eye.visible = !is_first_person


## Update ski stance for braking (pizza/wedge position)
func _update_ski_stance(is_braking: bool, delta: float) -> void:
	# Target rotation for skis
	var target_ski_rotation_x = 0.0  # Normal parallel position
	var target_ski_spacing = 0.15  # Normal leg width

	if is_braking:
		# Brake stance: rotate skis inward (pizza/wedge)
		target_ski_rotation_x = 15.0  # Tilt skis inward
		target_ski_spacing = 0.25  # Widen legs slightly

	# Smoothly interpolate ski positions
	var current_leg_spacing = $Body/LeftLeg.position.x
	var new_spacing = lerp(abs(current_leg_spacing), target_ski_spacing, ANIMATION_SPEED * delta)

	$Body/LeftLeg.position.x = -new_spacing
	$Body/RightLeg.position.x = new_spacing

	# Rotate skis for braking
	var current_ski_rot = left_ski.rotation_degrees.y
	var new_ski_rot = lerp(current_ski_rot, target_ski_rotation_x, ANIMATION_SPEED * delta)

	# Left ski rotates right (positive), right ski rotates left (negative)
	left_ski.rotation_degrees.y = new_ski_rot
	right_ski.rotation_degrees.y = -new_ski_rot


## Called when switching to/from free camera
func set_cameras_active(active: bool) -> void:
	_player_cameras_active = active
	if not active:
		# Deactivate both player cameras
		camera_third_person.current = false
		camera_first_person.current = false
	else:
		# Restore the camera that was active
		camera_third_person.current = not is_first_person
		camera_first_person.current = is_first_person
