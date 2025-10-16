extends CharacterBody3D

# Player movement constants
const MAX_SPEED = 15.0  # Maximum forward speed
const TURN_SPEED = 1.5  # Turning speed (reduced for more control)
const MIN_TURN_SPEED = 2.0  # Minimum speed required to turn
const ACCELERATION = 5.0  # Base acceleration on flat ground
const SLOPE_ACCELERATION_FACTOR = 0.5  # How much slope angle affects acceleration
const BRAKE_DECELERATION = 10.0  # How fast braking slows down the player
const FRICTION = 2.0  # Natural friction when no input
const SKATING_SPEED_THRESHOLD = 4.0  # Speed below which skating animation plays
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
@onready var torso = $Body/Torso
@onready var head = $Body/Head
@onready var left_arm = $Body/LeftArm
@onready var right_arm = $Body/RightArm
@onready var left_ski = $Body/LeftLeg/Ski
@onready var right_ski = $Body/RightLeg/Ski
@onready var left_eye = $Body/Head/LeftEye
@onready var right_eye = $Body/Head/RightEye

# UI references
@onready var camera_mode_label = $UI/CameraModeLabel
@onready var speed_label = $UI/SpeedLabel

# Camera mode: 0 = 3rd person back, 1 = 3rd person front, 2 = 1st person, 3 = free camera
var camera_mode = 0

# Signal for UI updates
signal camera_mode_changed(mode_name: String)

# Animation state
var current_tilt = 0.0  # Current Z-axis rotation (roll)
var current_lean = 0.0  # Current X-axis rotation (pitch) - for body
var current_upper_lean = 0.0  # Upper body lean (torso, head, arms)
var target_tilt = 0.0
var target_lean = 0.0
var target_upper_lean = 0.0

# Speed and skating state
var current_speed = 0.0  # Current forward speed
var skating_phase = 0.0  # Skating animation phase (0.0 to 1.0)

# Respawn state
var spawn_position: Vector3
var spawn_rotation: float


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

	# Save spawn position and rotation
	spawn_position = global_position
	spawn_rotation = rotation.y


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

	# Get horizontal and vertical input separately
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	# Handle rotation (left/right keys) - only if moving fast enough
	# Rotate body (not entire player) to change direction
	if turn_input != 0 and current_speed >= MIN_TURN_SPEED:
		body.rotate_y(-turn_input * TURN_SPEED * delta)

	# Tilt left/right based on horizontal input - only if turning
	if current_speed >= MIN_TURN_SPEED:
		target_tilt = -turn_input * TILT_AMOUNT
	else:
		target_tilt = 0.0

	# Lean forward/back based on vertical input and speed
	if is_braking:
		# Brake stance: lean back slightly
		target_lean = -15.0
		target_upper_lean = 0.0  # Upper body upright when braking
	elif is_moving_forward:
		# Accelerate: upper body leans forward 45 degrees
		target_lean = 0.0  # Body stays upright
		target_upper_lean = -45.0  # Upper body leans forward
	elif current_speed > SKATING_SPEED_THRESHOLD:
		# High speed: automatically lean forward even without input
		target_lean = 0.0
		target_upper_lean = -45.0  # Keep leaning forward at high speed
	else:
		# Low speed + no input: neutral stance
		target_lean = 0.0
		target_upper_lean = 0.0

	# Smoothly interpolate to target rotations
	current_tilt = lerp(current_tilt, target_tilt, ANIMATION_SPEED * delta)
	current_lean = lerp(current_lean, target_lean, ANIMATION_SPEED * delta)
	current_upper_lean = lerp(current_upper_lean, target_upper_lean, ANIMATION_SPEED * delta)

	# Apply body rotation (only tilt/roll, no forward lean)
	body.rotation_degrees.z = current_tilt
	body.rotation_degrees.x = current_lean

	# Apply upper body lean (torso and arms lean forward)
	torso.rotation_degrees.x = current_upper_lean
	left_arm.rotation_degrees.x = current_upper_lean
	right_arm.rotation_degrees.x = current_upper_lean

	# Move head forward based on torso lean (not rotate)
	# When torso leans forward -45 degrees, head moves forward naturally
	var lean_rad = deg_to_rad(current_upper_lean)
	var head_base_y = 0.65  # Original head Y position
	var torso_to_head = head_base_y - 0.15  # Distance from torso center to head
	var head_offset_z = sin(lean_rad) * torso_to_head  # Forward offset
	var head_offset_y = (cos(lean_rad) - 1.0) * torso_to_head  # Downward offset
	head.position = Vector3(0, head_base_y + head_offset_y, head_offset_z)

	# Handle ski positioning for braking and skating
	_update_ski_stance(is_braking, delta)

	# Update skating animation when moving at low speed
	if is_moving_forward and current_speed <= SKATING_SPEED_THRESHOLD:
		_update_skating_animation(delta)
	else:
		# Reset skating phase when not skating
		skating_phase = 0.0

	# Calculate slope angle for acceleration
	var slope_factor = 0.0
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var slope_angle = acos(floor_normal.dot(Vector3.UP))
		# Convert slope angle to acceleration factor (steeper = faster acceleration)
		slope_factor = sin(slope_angle) * SLOPE_ACCELERATION_FACTOR

	# Handle forward/backward movement with gradual acceleration
	if is_moving_forward:
		# Accelerate gradually based on base acceleration + slope
		var acceleration = ACCELERATION + slope_factor * 20.0  # Slope adds significant acceleration
		current_speed = min(current_speed + acceleration * delta, MAX_SPEED)
	elif is_braking:
		# Brake: slow down to a stop
		current_speed = max(current_speed - BRAKE_DECELERATION * delta, 0.0)
	else:
		# No input: gradually slow down (natural friction)
		current_speed = max(current_speed - FRICTION * delta, 0.0)

	# Gradually align player rotation with body rotation
	# This makes body twist affect actual movement direction
	if current_speed > 0:
		var body_y_rotation = body.rotation.y
		# Smoothly rotate player to match body direction
		rotation.y = lerp_angle(rotation.y, rotation.y + body_y_rotation, 2.0 * delta)
		# Reset body rotation after transferring to player
		body.rotation.y = lerp_angle(body.rotation.y, 0, 2.0 * delta)

	# Apply speed in player's forward direction
	var forward_dir = -transform.basis.z
	velocity.x = forward_dir.x * current_speed
	velocity.z = forward_dir.z * current_speed

	# Apply physics
	move_and_slide()

	# Update speed UI
	_update_speed_ui()

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

	# Respawn at spawn position with R key
	if event.is_action_pressed("respawn"):
		respawn()


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
	# Hide eyes only in first-person view
	# Show eyes in third-person and free camera views
	if left_eye and right_eye:
		var hide_eyes = (camera_mode == 2)
		left_eye.visible = !hide_eyes
		right_eye.visible = !hide_eyes


## Update ski stance for braking (pizza/wedge position)
func _update_ski_stance(is_braking: bool, delta: float) -> void:
	# Don't apply brake stance when skating (handled separately)
	# But always apply when braking
	if current_speed < SKATING_SPEED_THRESHOLD and not is_braking:
		return

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

	# Left ski rotates left (negative), right ski rotates right (positive)
	# This creates a wedge shape with ski tips pointing inward (pizza/wedge)
	left_ski.rotation_degrees.y = -new_ski_rot
	right_ski.rotation_degrees.y = new_ski_rot


## Update skating animation for low-speed start
func _update_skating_animation(delta: float) -> void:
	# Advance skating phase (cycles from 0.0 to 1.0)
	skating_phase += delta * 1.5  # Speed of skating cycle
	if skating_phase >= 1.0:
		skating_phase = 0.0

	# Left push phase: 0.0 to 0.5
	# Right push phase: 0.5 to 1.0
	var is_left_push = skating_phase < 0.5
	var phase_in_cycle = fmod(skating_phase, 0.5) / 0.5  # 0.0 to 1.0 within each half

	# Calculate push intensity (peaks at middle of each push)
	var push_intensity = sin(phase_in_cycle * PI)  # 0 -> 1 -> 0

	if is_left_push:
		# Left leg pushes out, right leg stays center
		var left_offset = 0.15 + push_intensity * 0.15  # 0.15 to 0.30
		var right_offset = 0.15  # Normal position
		$Body/LeftLeg.position.x = -left_offset
		$Body/RightLeg.position.x = right_offset

		# Angle left ski outward during push
		left_ski.rotation_degrees.y = push_intensity * 20.0
		right_ski.rotation_degrees.y = 0.0
	else:
		# Right leg pushes out, left leg stays center
		var left_offset = 0.15  # Normal position
		var right_offset = 0.15 + push_intensity * 0.15  # 0.15 to 0.30
		$Body/LeftLeg.position.x = -left_offset
		$Body/RightLeg.position.x = right_offset

		# Angle right ski outward during push
		left_ski.rotation_degrees.y = 0.0
		right_ski.rotation_degrees.y = -push_intensity * 20.0


## Update camera mode label when camera changes
func _on_camera_mode_changed(mode_name: String) -> void:
	if camera_mode_label:
		camera_mode_label.text = "카메라: " + mode_name


## Update speed UI label
func _update_speed_ui() -> void:
	if speed_label:
		var skating_status = "OFF"
		if current_speed < SKATING_SPEED_THRESHOLD and Input.is_action_pressed("move_forward"):
			skating_status = "ON"

		speed_label.text = "속도: %.1f m/s | 스케이팅: %s (< %.1f)" % [current_speed, skating_status, SKATING_SPEED_THRESHOLD]


## Respawn player at spawn position
func respawn() -> void:
	# Reset position and rotation
	global_position = spawn_position
	rotation.y = spawn_rotation

	# Reset velocity and speed
	velocity = Vector3.ZERO
	current_speed = 0.0

	# Reset animations
	skating_phase = 0.0
	current_tilt = 0.0
	current_lean = 0.0
	current_upper_lean = 0.0
	target_tilt = 0.0
	target_lean = 0.0
	target_upper_lean = 0.0

	print("Player respawned at: ", spawn_position)
