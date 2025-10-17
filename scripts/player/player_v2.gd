extends CharacterBody3D

# V2: Enhanced animation system based on PLAYER_MOVEMENT.md
# Includes breathing cycles, arm swings, weight shifting, and ski edge effects

# Player movement constants
const MAX_SPEED = 15.0
const TURN_SPEED = 1.5
const MIN_TURN_SPEED = 2.0
const ACCELERATION = 5.0
const SLOPE_ACCELERATION_FACTOR = 0.5
const BRAKE_DECELERATION = 10.0
const FRICTION = 2.0
const SKATING_SPEED_THRESHOLD = 4.0
const JUMP_VELOCITY = 6.0
const GRAVITY = 9.8

# V2 Animation constants (based on PLAYER_MOVEMENT.md)
const TILT_AMOUNT = 30.0
const LEAN_AMOUNT = 20.0
const ANIMATION_SPEED = 10.0
const BREATHING_CYCLE_SPEED = 0.5  # 2 second cycle
const ARM_SWING_SPEED = 1.25  # 0.8 second cycle (24f at 30fps)
const EDGE_CHATTER_SPEED = 8.0  # Fast micro vibrations

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
@onready var left_leg = $Body/LeftLeg
@onready var right_leg = $Body/RightLeg
@onready var left_ski = $Body/LeftLeg/Ski
@onready var right_ski = $Body/RightLeg/Ski
@onready var left_eye = $Body/Head/LeftEye
@onready var right_eye = $Body/Head/RightEye

# UI references
@onready var camera_mode_label = $UI/CameraModeLabel
@onready var speed_label = $UI/SpeedLabel

# Camera mode
var camera_mode = 0

# Signal
signal camera_mode_changed(mode_name: String)

# Animation state
var current_tilt = 0.0
var current_lean = 0.0
var current_upper_lean = 0.0
var target_tilt = 0.0
var target_lean = 0.0
var target_upper_lean = 0.0

# V2: New animation phases
var breathing_phase = 0.0  # For idle breathing cycle
var arm_swing_phase = 0.0  # For forward arm swing
var edge_chatter_phase = 0.0  # For ski edge micro-vibrations

# Speed and skating state
var current_speed = 0.0
var skating_phase = 0.0

# Respawn state
var spawn_position: Vector3
var spawn_rotation: float


func _ready() -> void:
	add_to_group("player")
	camera_mode_changed.connect(_on_camera_mode_changed)
	camera_mode = 0
	_apply_camera_mode()
	_on_camera_mode_changed(_get_camera_mode_name())
	spawn_position = global_position
	spawn_rotation = rotation.y


func _physics_process(delta: float) -> void:
	if camera_mode == 3:
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	# Handle rotation
	if turn_input != 0 and current_speed >= MIN_TURN_SPEED:
		body.rotate_y(-turn_input * TURN_SPEED * delta)

	# V2: Enhanced turn animation with weight shift
	if current_speed >= MIN_TURN_SPEED:
		target_tilt = -turn_input * TILT_AMOUNT
		# V2: Add weight shift (COM shift) during turns
		_apply_weight_shift(turn_input, delta)
		# V2: Add ski edge effect during turns
		_apply_ski_edge_effect(turn_input, delta)
	else:
		target_tilt = 0.0
		_reset_weight_shift(delta)

	# V2: Enhanced lean system
	if is_braking:
		# V2: Improved brake stance - lean back more
		target_lean = -20.0  # Was -15.0 in V1
		target_upper_lean = -10.0  # Slight forward torso for balance
	elif is_moving_forward:
		target_lean = 0.0
		target_upper_lean = -45.0
		# V2: Add arm swing during forward movement
		_update_arm_swing(delta)
	elif current_speed > SKATING_SPEED_THRESHOLD:
		target_lean = 0.0
		target_upper_lean = -45.0
	else:
		# V2: IDLE with breathing cycle
		target_lean = 0.0
		target_upper_lean = -15.0  # Slight athletic stance (was 0 in V1)

	# Always update breathing cycle for smooth transitions
	_update_breathing_cycle(delta)

	# Smoothly interpolate to target rotations
	current_tilt = lerp(current_tilt, target_tilt, ANIMATION_SPEED * delta)
	current_lean = lerp(current_lean, target_lean, ANIMATION_SPEED * delta)
	current_upper_lean = lerp(current_upper_lean, target_upper_lean, ANIMATION_SPEED * delta)

	# Apply body rotation
	body.rotation_degrees.z = current_tilt
	body.rotation_degrees.x = current_lean

	# Apply upper body lean
	torso.rotation_degrees.x = current_upper_lean

	# V2: Arms follow torso but can have independent swing
	# (arm swing is applied in _update_arm_swing)

	# Move head forward based on torso lean (not rotate)
	var lean_rad = deg_to_rad(current_upper_lean)
	var head_base_y = 0.65
	var torso_to_head = head_base_y - 0.15
	var head_offset_z = sin(lean_rad) * torso_to_head
	var head_offset_y = (cos(lean_rad) - 1.0) * torso_to_head

	# V2: Add breathing cycle to head position
	var breathing_offset = sin(breathing_phase) * 0.02  # Breathe in: forward -0.02
	head.position = Vector3(0, head_base_y + head_offset_y, head_offset_z + breathing_offset)

	# Handle ski positioning for braking and skating
	_update_ski_stance(is_braking, delta)

	# Update skating animation
	if is_moving_forward and current_speed <= SKATING_SPEED_THRESHOLD:
		_update_skating_animation(delta)
	else:
		# Smoothly return skis to parallel when exiting skating
		if skating_phase > 0.0:
			_reset_skating_stance(delta)
		skating_phase = 0.0

	# Calculate slope angle for acceleration
	var slope_factor = 0.0
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var slope_angle = acos(floor_normal.dot(Vector3.UP))
		slope_factor = sin(slope_angle) * SLOPE_ACCELERATION_FACTOR

	# Handle forward/backward movement
	if is_moving_forward:
		var acceleration = ACCELERATION + slope_factor * 20.0
		current_speed = min(current_speed + acceleration * delta, MAX_SPEED)
	elif is_braking:
		current_speed = max(current_speed - BRAKE_DECELERATION * delta, 0.0)
	else:
		current_speed = max(current_speed - FRICTION * delta, 0.0)

	# Gradually align player rotation with body rotation
	if current_speed > 0:
		var body_y_rotation = body.rotation.y
		rotation.y = lerp_angle(rotation.y, rotation.y + body_y_rotation, 2.0 * delta)
		body.rotation.y = lerp_angle(body.rotation.y, 0, 2.0 * delta)

	# Apply speed in player's forward direction
	var forward_dir = -transform.basis.z
	velocity.x = forward_dir.x * current_speed
	velocity.z = forward_dir.z * current_speed

	# Apply physics
	move_and_slide()

	# Update speed UI
	_update_speed_ui()

	# Debug
	if global_position.y < -50:
		print("Player fell through terrain! Position: ", global_position)


## V2: Breathing cycle for IDLE animation (PLAYER_MOVEMENT.md spec)
func _update_breathing_cycle(delta: float) -> void:
	breathing_phase += delta * BREATHING_CYCLE_SPEED * TAU  # 2 second cycle
	if breathing_phase >= TAU:
		breathing_phase -= TAU

	# Torso: -15° ± 3° breathing
	var breathing_amplitude = 3.0
	var breathing_torso = sin(breathing_phase) * breathing_amplitude
	torso.rotation_degrees.x = current_upper_lean + breathing_torso

	# Arms: idle swing ±5°
	var arm_idle_swing = sin(breathing_phase * 0.8) * 5.0  # Slightly different phase
	left_arm.rotation_degrees.x = current_upper_lean + arm_idle_swing
	right_arm.rotation_degrees.x = current_upper_lean - arm_idle_swing  # Opposite phase


## V2: Arm swing for forward movement (PLAYER_MOVEMENT.md spec)
func _update_arm_swing(delta: float) -> void:
	arm_swing_phase += delta * ARM_SWING_SPEED * TAU  # 0.8 second cycle
	if arm_swing_phase >= TAU:
		arm_swing_phase -= TAU

	# Push-glide cycle: f0→f8 push, f8→f24 glide
	# Left and right arms in opposite phase
	var push_intensity = (sin(arm_swing_phase) + 1.0) * 0.5  # 0 to 1

	# Left arm: -45° (push) to -30° (recover)
	var left_arm_angle = lerp(-30.0, -45.0, push_intensity)
	left_arm.rotation_degrees.x = left_arm_angle

	# Right arm: opposite phase
	var right_arm_angle = lerp(-30.0, -45.0, 1.0 - push_intensity)
	right_arm.rotation_degrees.x = right_arm_angle


## V2: Weight shift during turns (PLAYER_MOVEMENT.md spec)
func _apply_weight_shift(turn_direction: float, delta: float) -> void:
	# Left turn (negative): shift weight to RIGHT leg (positive X)
	# Right turn (positive): shift weight to LEFT leg (negative X)
	var target_torso_x = turn_direction * 0.03  # ±0.03 lateral shift
	var target_torso_y_rot = -turn_direction * 10.0  # Face into turn ±10°

	# Smoothly shift torso position
	torso.position.x = lerp(torso.position.x, target_torso_x, ANIMATION_SPEED * delta)

	# Torso yaw rotation (facing turn direction)
	torso.rotation_degrees.y = lerp(torso.rotation_degrees.y, target_torso_y_rot, ANIMATION_SPEED * delta)

	# Leg angles: weighted leg edges more
	if turn_direction < 0:  # Left turn - weight on right leg
		right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, -6.0, ANIMATION_SPEED * delta)
		left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, -3.0, ANIMATION_SPEED * delta)
	elif turn_direction > 0:  # Right turn - weight on left leg
		left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, 6.0, ANIMATION_SPEED * delta)
		right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, 3.0, ANIMATION_SPEED * delta)


## V2: Reset weight shift when not turning
func _reset_weight_shift(delta: float) -> void:
	torso.position.x = lerp(torso.position.x, 0.0, ANIMATION_SPEED * delta)
	torso.rotation_degrees.y = lerp(torso.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)
	right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)


## V2: Ski edge effect during turns (PLAYER_MOVEMENT.md spec)
func _apply_ski_edge_effect(turn_direction: float, delta: float) -> void:
	# Advance edge chatter phase
	edge_chatter_phase += delta * EDGE_CHATTER_SPEED * TAU
	if edge_chatter_phase >= TAU:
		edge_chatter_phase -= TAU

	# Micro vibration for "edge chatter" effect
	var chatter = sin(edge_chatter_phase) * 2.0  # ±2° chatter

	# Ski yaw during turns
	var base_ski_yaw = -turn_direction * 12.0  # ±12° at apex

	# Inner ski trails by additional 2°
	if turn_direction < 0:  # Left turn
		left_ski.rotation_degrees.y = base_ski_yaw - 2.0 + chatter  # Inner ski
		right_ski.rotation_degrees.y = base_ski_yaw + chatter  # Outer ski
	elif turn_direction > 0:  # Right turn
		right_ski.rotation_degrees.y = base_ski_yaw + 2.0 + chatter  # Inner ski
		left_ski.rotation_degrees.y = base_ski_yaw + chatter  # Outer ski


## Update ski stance for braking
func _update_ski_stance(is_braking: bool, delta: float) -> void:
	if current_speed < SKATING_SPEED_THRESHOLD and not is_braking:
		return

	var target_ski_rotation_x = 0.0
	var target_ski_spacing = 0.15

	if is_braking:
		# V2: Enhanced brake stance (pizza/wedge)
		target_ski_rotation_x = 15.0
		target_ski_spacing = 0.25

	# Smoothly interpolate ski positions
	var current_leg_spacing = left_leg.position.x
	var new_spacing = lerp(abs(current_leg_spacing), target_ski_spacing, ANIMATION_SPEED * delta)

	left_leg.position.x = -new_spacing
	right_leg.position.x = new_spacing

	# Rotate skis for braking (only when not turning)
	if is_braking:
		var current_ski_rot = left_ski.rotation_degrees.y
		var new_ski_rot = lerp(abs(current_ski_rot), target_ski_rotation_x, ANIMATION_SPEED * delta)
		left_ski.rotation_degrees.y = -new_ski_rot
		right_ski.rotation_degrees.y = new_ski_rot


## Update skating animation
func _update_skating_animation(delta: float) -> void:
	skating_phase += delta * 1.5
	if skating_phase >= 1.0:
		skating_phase = 0.0

	var is_left_push = skating_phase < 0.5
	var phase_in_cycle = fmod(skating_phase, 0.5) / 0.5
	var push_intensity = sin(phase_in_cycle * PI)

	if is_left_push:
		var left_offset = 0.15 + push_intensity * 0.15
		var right_offset = 0.15
		left_leg.position.x = -left_offset
		right_leg.position.x = right_offset
		left_ski.rotation_degrees.y = push_intensity * 20.0
		right_ski.rotation_degrees.y = 0.0
	else:
		var left_offset = 0.15
		var right_offset = 0.15 + push_intensity * 0.15
		left_leg.position.x = -left_offset
		right_leg.position.x = right_offset
		left_ski.rotation_degrees.y = 0.0
		right_ski.rotation_degrees.y = -push_intensity * 20.0


## Smoothly reset skiing stance when exiting skating mode
func _reset_skating_stance(delta: float) -> void:
	# Smoothly return legs to parallel position
	left_leg.position.x = lerp(left_leg.position.x, -0.15, ANIMATION_SPEED * delta)
	right_leg.position.x = lerp(right_leg.position.x, 0.15, ANIMATION_SPEED * delta)

	# Smoothly return skis to 0° rotation (parallel)
	left_ski.rotation_degrees.y = lerp(left_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	right_ski.rotation_degrees.y = lerp(right_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		camera_mode = (camera_mode + 1) % 4
		_apply_camera_mode()
		camera_mode_changed.emit(_get_camera_mode_name())

	if event.is_action_pressed("respawn"):
		respawn()


func _apply_camera_mode() -> void:
	match camera_mode:
		0:
			camera_third_person.current = true
			camera_third_person_front.current = false
			camera_first_person.current = false
			camera_free.deactivate()
		1:
			camera_third_person.current = false
			camera_third_person_front.current = true
			camera_first_person.current = false
			camera_free.deactivate()
		2:
			camera_third_person.current = false
			camera_third_person_front.current = false
			camera_first_person.current = true
			camera_free.deactivate()
		3:
			camera_third_person.current = false
			camera_third_person_front.current = false
			camera_first_person.current = false
			camera_free.activate()

	_update_eye_visibility()


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


func _update_eye_visibility() -> void:
	if left_eye and right_eye:
		var hide_eyes = (camera_mode == 2)
		left_eye.visible = !hide_eyes
		right_eye.visible = !hide_eyes


func _on_camera_mode_changed(mode_name: String) -> void:
	if camera_mode_label:
		camera_mode_label.text = "카메라: " + mode_name


func _update_speed_ui() -> void:
	if speed_label:
		var skating_status = "OFF"
		if current_speed < SKATING_SPEED_THRESHOLD and Input.is_action_pressed("move_forward"):
			skating_status = "ON"

		# V2: Show version in UI
		speed_label.text = "V2 | 속도: %.1f m/s | 스케이팅: %s (< %.1f)" % [current_speed, skating_status, SKATING_SPEED_THRESHOLD]


func respawn() -> void:
	global_position = spawn_position
	rotation.y = spawn_rotation
	velocity = Vector3.ZERO
	current_speed = 0.0
	skating_phase = 0.0
	breathing_phase = 0.0
	arm_swing_phase = 0.0
	edge_chatter_phase = 0.0
	current_tilt = 0.0
	current_lean = 0.0
	current_upper_lean = 0.0
	target_tilt = 0.0
	target_lean = 0.0
	target_upper_lean = 0.0
	print("Player (V2) respawned at: ", spawn_position)
