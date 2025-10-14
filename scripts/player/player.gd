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
@onready var camera_third_person_front = $Camera3D_ThirdPersonFront
@onready var camera_first_person = $Camera3D_FirstPerson
@onready var camera_free = $Camera3D_Free

# Body parts references
@onready var body = $Body
@onready var left_ski = $Body/LeftLeg/Ski
@onready var right_ski = $Body/RightLeg/Ski
@onready var left_eye = $Body/Head/LeftEye
@onready var right_eye = $Body/Head/RightEye

# UI references
@onready var camera_mode_label = $UI/CameraModeLabel

# Camera mode: 0 = 3rd person back, 1 = 3rd person front, 2 = 1st person, 3 = free camera
var camera_mode = 0

# Signal for UI updates
signal camera_mode_changed(mode_name: String)

# Animation state
var current_tilt = 0.0  # Current Z-axis rotation (roll)
var current_lean = 0.0  # Current X-axis rotation (pitch)
var target_tilt = 0.0
var target_lean = 0.0


func _ready() -> void:
	# Add to player group for free camera to find
	add_to_group("player")

	# Connect camera mode signal to UI update
	camera_mode_changed.connect(_on_camera_mode_changed)

	# Set initial camera mode
	camera_mode = 0
	_apply_camera_mode()

	# Update UI with initial camera mode
	_on_camera_mode_changed(_get_camera_mode_name())


func _physics_process(delta: float) -> void:
	# Only disable player control in free camera mode
	if camera_mode == 3:
		return

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
	# Cycle through camera modes with F1 key
	# Order: 3rd person back → 3rd person front → 1st person → free camera
	if event.is_action_pressed("toggle_camera"):
		camera_mode = (camera_mode + 1) % 4
		_apply_camera_mode()
		camera_mode_changed.emit(_get_camera_mode_name())


## Apply camera mode (0: 3rd back, 1: 3rd front, 2: 1st person, 3: free camera)
func _apply_camera_mode() -> void:
	match camera_mode:
		0:  # Third person back
			camera_third_person.current = true
			camera_third_person_front.current = false
			camera_first_person.current = false
			camera_free.deactivate()
		1:  # Third person front
			camera_third_person.current = false
			camera_third_person_front.current = true
			camera_first_person.current = false
			camera_free.deactivate()
		2:  # First person
			camera_third_person.current = false
			camera_third_person_front.current = false
			camera_first_person.current = true
			camera_free.deactivate()
		3:  # Free camera
			camera_third_person.current = false
			camera_third_person_front.current = false
			camera_first_person.current = false
			camera_free.activate()

	_update_eye_visibility()


## Get camera mode name for UI display
func _get_camera_mode_name() -> String:
	match camera_mode:
		0:
			return "3인칭 (뒤)"
		1:
			return "3인칭 (앞)"
		2:
			return "1인칭"
		3:
			return "프리 카메라"
		_:
			return "알 수 없음"


## Update eye visibility based on camera mode
func _update_eye_visibility() -> void:
	# Hide eyes in first-person and free camera views
	# Show eyes in third-person views
	if left_eye and right_eye:
		var hide_eyes = (camera_mode in [2, 3])
		left_eye.visible = !hide_eyes
		right_eye.visible = !hide_eyes


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
	# This creates a reverse wedge shape with ski tails pointing inward
	left_ski.rotation_degrees.y = new_ski_rot
	right_ski.rotation_degrees.y = -new_ski_rot


## Update camera mode label when camera changes
func _on_camera_mode_changed(mode_name: String) -> void:
	if camera_mode_label:
		camera_mode_label.text = "카메라: " + mode_name
