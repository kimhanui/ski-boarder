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

# Jump animation constants
const JUMP_CROUCH_DURATION = 0.3  # Crouch before jump (seconds)
const JUMP_LAUNCH_DURATION = 0.4  # Launch animation (seconds)
const JUMP_CROUCH_AMOUNT = 0.15  # How much to lower body when crouching
const JUMP_ARM_RAISE_ANGLE = 45.0  # Arms raised angle during launch

# Air trick physics constants (ADD.md spec)
const AIR_YAW_SPEED_MAX = 240.0  # deg/s - spin speed
const AIR_ROLL_RATE = 120.0  # deg/s - roll rate
const AIR_ROLL_MAX = 40.0  # deg - maximum roll angle
const AIR_PITCH_TARGET = 30.0  # deg - pitch forward/back target
const GRAB_MIN_FRAMES = 6  # Minimum frames to hold grab
const LAND_ROLL_THRESHOLD = 12.0  # deg - max roll for safe landing
const LAND_PITCH_THRESHOLD = 18.0  # deg - max pitch for safe landing

# Carving/steering constants (new physics-based turning)
const STEER_YAW_RATE = 90.0  # deg/s - how fast ski yaw changes with A/D input
const SKI_YAW_MAX = 18.0  # deg - maximum ski yaw angle (normal)
const SKI_YAW_MAX_BOOST = 22.0  # deg - maximum ski yaw when accelerating
const SKI_ROLL_MAX = 6.0  # deg - maximum ski roll (carving edge)
const TORSO_ROLL_COEFFICIENT = 0.6  # Torso roll is 60% of ski yaw (reduced from 100%)
const BODY_YAW_FOLLOW = 0.7  # Body yaw follows ski yaw at 70%
const VELOCITY_HEADING_LERP = 0.1  # How fast velocity heading follows ski yaw
const STEER_YAW_DAMPING = 0.92  # Damping factor when no input (0.92 = 8% decay per frame)

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

# Ski raycasts for ground contact
@onready var left_ski_raycast = $Body/LeftLeg/Ski/SkiRayCast
@onready var right_ski_raycast = $Body/RightLeg/Ski/SkiRayCast

# UI references
@onready var camera_mode_label = $UI/CameraModeLabel
@onready var speed_label = $UI/SpeedLabel
@onready var trick_guide_label = $UI/TrickGuideLabel
@onready var trick_display_label = $UI/TrickDisplayLabel
@onready var trick_mode_button = $UI/TrickModeButton

# Systems
@onready var ski_tracks = $SkiTracks

# Camera mode
var camera_mode = 0

# Trick mode toggle
var trick_mode_enabled: bool = false  # Default: OFF

# Signals
signal camera_mode_changed(mode_name: String)
signal trick_performed(trick_name: String)
signal trick_mode_changed(enabled: bool)

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

# Jump animation state
enum JumpState { GROUNDED, CROUCHING, LAUNCHING, AIRBORNE, LANDING }
var jump_state = JumpState.GROUNDED
var jump_timer = 0.0
var jump_crouch_progress = 0.0  # 0 to 1
var jump_launch_progress = 0.0  # 0 to 1
var was_in_air = false

# Speed and skating state
var current_speed = 0.0
var skating_phase = 0.0

# Respawn state
var spawn_position: Vector3
var spawn_rotation: float

# Trick system state
var current_trick: String = ""
var trick_display_timer: float = 0.0
const TRICK_DISPLAY_DURATION = 2.0  # Display trick name for 2 seconds
var air_input_detected: Dictionary = {
	"forward": false,
	"back": false,
	"left": false,
	"right": false,
	"grab": false
}

# Air trick physics (ADD.md spec)
var air_yaw: float = 0.0  # Accumulated yaw rotation (Y-axis spin)
var air_roll: float = 0.0  # Body roll (Z-axis tilt)
var air_pitch: float = 0.0  # Body pitch (X-axis front/back)
var grab_frames: int = 0  # Frames grab is held
var can_land_safely: bool = true  # Landing safety flag

# Carving/steering state (new physics-based turning)
var steer_yaw: float = 0.0  # Current ski yaw angle in degrees (-SKI_YAW_MAX to +SKI_YAW_MAX)
var velocity_heading: float = 0.0  # Current velocity heading in radians


func _ready() -> void:
	add_to_group("player")
	camera_mode_changed.connect(_on_camera_mode_changed)
	camera_mode = 0
	_apply_camera_mode()
	_on_camera_mode_changed(_get_camera_mode_name())
	spawn_position = global_position
	spawn_rotation = rotation.y

	# Initialize velocity heading to match current rotation
	velocity_heading = rotation.y

	# Connect ski tracks to player
	if ski_tracks:
		ski_tracks.player = self

	# Initialize trick UI
	_initialize_trick_ui()

	# Connect trick mode button with forced initialization
	if trick_mode_button:
		# Force button properties (prevent scene file issues)
		trick_mode_button.disabled = false
		trick_mode_button.mouse_filter = Control.MOUSE_FILTER_STOP
		trick_mode_button.button_pressed = trick_mode_enabled

		# Connect signal
		trick_mode_button.toggled.connect(_on_trick_mode_toggled)

		# Update UI to match initial state
		_update_trick_mode_ui()

		print("[BUTTON INIT] Trick mode button initialized:")
		print("  - Disabled: ", trick_mode_button.disabled)
		print("  - Mouse Filter: ", trick_mode_button.mouse_filter)
		print("  - Button Pressed: ", trick_mode_button.button_pressed)
		print("  - Trick Mode Enabled: ", trick_mode_enabled)

	# Ensure mouse is visible for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Enable shadows for all player meshes
	_enable_player_shadows()


func _physics_process(delta: float) -> void:
	if camera_mode == 3:
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump state machine
	_update_jump_state(delta)

	# Handle jump input
	if Input.is_action_just_pressed("jump") and is_on_floor() and jump_state == JumpState.GROUNDED:
		if trick_mode_enabled:
			# Trick mode ON: use full jump animation (crouch → launch → air)
			jump_state = JumpState.CROUCHING
			jump_timer = 0.0
		else:
			# Trick mode OFF: simple jump (direct to airborne)
			velocity.y = JUMP_VELOCITY
			jump_state = JumpState.AIRBORNE
			was_in_air = true

	# Detect trick inputs in the air (only if trick mode enabled)
	if jump_state == JumpState.AIRBORNE and trick_mode_enabled:
		_detect_trick_inputs()
	else:
		# Reset air inputs when grounded or trick mode disabled
		_reset_air_inputs()

	# Force reset body rotations when trick mode is OFF (only in air, only Z rotation)
	if not trick_mode_enabled and jump_state == JumpState.AIRBORNE:
		if body:
			# Keep Y rotation for turning, only reset Z (roll from tricks)
			body.rotation_degrees.z = 0.0
		# Reset all body part rotations
		if torso:
			torso.rotation_degrees.x = 0.0
		if left_arm and right_arm:
			left_arm.rotation_degrees.x = 0.0
			right_arm.rotation_degrees.x = 0.0
			left_arm.position.x = -0.35
			right_arm.position.x = 0.35
		if left_leg and right_leg:
			left_leg.rotation_degrees.x = 0.0
			right_leg.rotation_degrees.x = 0.0

	# Update trick display timer
	_update_trick_display(delta)

	# Get input
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	# A/D CONTROL: Trick mode ON = carving, OFF = simple rotation (PLAYER.MD)
	if current_speed >= MIN_TURN_SPEED and not is_braking:
		if trick_mode_enabled:
			# TRICK MODE ON: Carving system (current behavior)
			var target_ski_yaw_max = SKI_YAW_MAX
			if is_moving_forward:
				target_ski_yaw_max = SKI_YAW_MAX_BOOST

			if turn_input != 0:
				steer_yaw += turn_input * STEER_YAW_RATE * delta
				steer_yaw = clamp(steer_yaw, -target_ski_yaw_max, target_ski_yaw_max)
			else:
				steer_yaw *= STEER_YAW_DAMPING
				if abs(steer_yaw) < 0.5:
					steer_yaw = 0.0

			_apply_ski_carving(steer_yaw, delta)
			_update_velocity_heading(delta)
			_update_body_yaw_follow(delta)
			target_tilt = -steer_yaw * TORSO_ROLL_COEFFICIENT
			_apply_weight_shift(turn_input, delta)
		else:
			# TRICK MODE OFF: Simple Y-axis rotation (PLAYER.MD spec)
			if turn_input != 0:
				rotation.y += -turn_input * TURN_SPEED * delta

			target_tilt = -turn_input * TILT_AMOUNT
			_apply_weight_shift(turn_input, delta)
	else:
		# Below min speed or braking: reset
		if trick_mode_enabled:
			steer_yaw = 0.0
			_reset_ski_carving(delta)

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
	if is_moving_forward and current_speed < SKATING_SPEED_THRESHOLD:
		_update_skating_animation(delta)
	elif skating_phase > 0.0:
		# When speed crosses threshold, immediately reset skis to parallel
		if current_speed >= SKATING_SPEED_THRESHOLD:
			_reset_skating_stance(delta, true)  # Force immediate reset
			skating_phase = 0.0
		else:
			# Smoothly return skis to parallel when exiting skating
			_reset_skating_stance(delta, false)
			skating_phase = 0.0
	else:
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

	# VELOCITY: Trick mode ON = velocity_heading, OFF = transform.basis (PLAYER.MD)
	if current_speed > 0:
		if trick_mode_enabled:
			# TRICK MODE ON: Use velocity_heading (carving system)
			var velocity_dir = Vector3(-sin(velocity_heading), 0, -cos(velocity_heading))
			velocity.x = velocity_dir.x * current_speed
			velocity.z = velocity_dir.z * current_speed
			rotation.y = velocity_heading
		else:
			# TRICK MODE OFF: Use transform.basis (PLAYER.MD spec)
			var forward_dir = -transform.basis.z
			velocity.x = forward_dir.x * current_speed
			velocity.z = forward_dir.z * current_speed

			# Gradually align player rotation with body rotation (PLAYER.MD spec)
			var body_y_rotation = body.rotation.y
			rotation.y = lerp_angle(rotation.y, rotation.y + body_y_rotation, 2.0 * delta)
			body.rotation.y = lerp_angle(body.rotation.y, 0, 2.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Apply physics
	move_and_slide()

	# Update speed UI
	_update_speed_ui()

	# Debug
	if global_position.y < -50:
		print("Player fell through terrain! Position: ", global_position)


## Update jump animation state machine
func _update_jump_state(delta: float) -> void:
	match jump_state:
		JumpState.GROUNDED:
			jump_crouch_progress = 0.0
			jump_launch_progress = 0.0
			# Detect if we left the ground (for falling)
			if not is_on_floor() and was_in_air == false:
				jump_state = JumpState.AIRBORNE
				was_in_air = true

		JumpState.CROUCHING:
			jump_timer += delta
			jump_crouch_progress = min(jump_timer / JUMP_CROUCH_DURATION, 1.0)

			# After crouch animation, launch!
			if jump_timer >= JUMP_CROUCH_DURATION:
				jump_state = JumpState.LAUNCHING
				jump_timer = 0.0
				velocity.y = JUMP_VELOCITY  # Actually jump

		JumpState.LAUNCHING:
			jump_timer += delta
			jump_launch_progress = min(jump_timer / JUMP_LAUNCH_DURATION, 1.0)

			# Transition to airborne when launch animation completes or we're clearly in air
			if jump_timer >= JUMP_LAUNCH_DURATION or not is_on_floor():
				jump_state = JumpState.AIRBORNE
				was_in_air = true

		JumpState.AIRBORNE:
			# Maintain airborne pose
			jump_crouch_progress = 0.0
			jump_launch_progress = 1.0

			# Check landing conditions (ADD.md spec)
			if _can_land_safely():
				jump_state = JumpState.LANDING
				jump_timer = 0.0
				print("[LANDING] Safe landing! Roll: %.1f°, Pitch: %.1f°" % [air_roll, air_pitch])

		JumpState.LANDING:
			jump_timer += delta
			# Quick landing recovery (use same duration as crouch)
			var landing_progress = min(jump_timer / JUMP_CROUCH_DURATION, 1.0)
			jump_launch_progress = 1.0 - landing_progress

			if jump_timer >= JUMP_CROUCH_DURATION:
				jump_state = JumpState.GROUNDED
				was_in_air = false

	# Apply jump animations to body
	_apply_jump_animation()


## Apply jump animation to body parts
func _apply_jump_animation() -> void:
	if jump_state == JumpState.GROUNDED:
		return  # No jump animation needed

	# Skip jump animations when trick mode is OFF
	if not trick_mode_enabled:
		return

	# Calculate body height offset (crouch down, then neutral)
	var body_offset_y = 0.0
	if jump_state == JumpState.CROUCHING:
		# Crouch down progressively
		body_offset_y = -JUMP_CROUCH_AMOUNT * jump_crouch_progress
	elif jump_state == JumpState.LAUNCHING:
		# Rise back up during launch
		body_offset_y = -JUMP_CROUCH_AMOUNT * (1.0 - jump_launch_progress)

	# Apply body offset
	body.position.y = body_offset_y

	# Arm animation during jump
	var arm_angle_offset = 0.0
	if jump_state == JumpState.CROUCHING:
		# Arms stay down during crouch
		arm_angle_offset = 0.0
	elif jump_state == JumpState.LAUNCHING or jump_state == JumpState.AIRBORNE:
		# Arms raise up during launch and stay up in air
		arm_angle_offset = -JUMP_ARM_RAISE_ANGLE * jump_launch_progress
	elif jump_state == JumpState.LANDING:
		# Arms come back down during landing
		arm_angle_offset = -JUMP_ARM_RAISE_ANGLE * jump_launch_progress

	# Apply arm offset (additive to current arm rotation)
	if jump_state != JumpState.GROUNDED:
		left_arm.rotation_degrees.x += arm_angle_offset
		right_arm.rotation_degrees.x += arm_angle_offset

	# Leg bend during crouch
	if jump_state == JumpState.CROUCHING:
		# Bend legs during crouch
		var leg_bend = 25.0 * jump_crouch_progress
		left_leg.rotation_degrees.x = leg_bend
		right_leg.rotation_degrees.x = leg_bend
	elif jump_state == JumpState.LAUNCHING:
		# Straighten legs during launch
		var leg_bend = 25.0 * (1.0 - jump_launch_progress)
		left_leg.rotation_degrees.x = leg_bend
		right_leg.rotation_degrees.x = leg_bend
	elif jump_state == JumpState.AIRBORNE:
		# Slightly bent legs in air for natural pose
		left_leg.rotation_degrees.x = 10.0
		right_leg.rotation_degrees.x = 10.0
	elif jump_state == JumpState.LANDING:
		# Bend legs slightly on landing for absorption
		var leg_bend = 10.0 + 15.0 * (1.0 - jump_launch_progress)
		left_leg.rotation_degrees.x = leg_bend
		right_leg.rotation_degrees.x = leg_bend
	else:
		# Reset leg rotation when grounded
		left_leg.rotation_degrees.x = 0.0
		right_leg.rotation_degrees.x = 0.0


## V2: Breathing cycle for IDLE animation (PLAYER_MOVEMENT.md spec)
func _update_breathing_cycle(delta: float) -> void:
	# Use fmod for smooth continuous phase wrapping
	breathing_phase = fmod(breathing_phase + delta * BREATHING_CYCLE_SPEED * TAU, TAU)

	# Torso: -15° ± 3° breathing
	var breathing_amplitude = 3.0
	var breathing_torso = sin(breathing_phase) * breathing_amplitude
	torso.rotation_degrees.x = current_upper_lean + breathing_torso

	# Arms: idle swing ±5° - use same breathing phase with offset for continuity
	var arm_phase_offset = breathing_phase + PI * 0.5  # 90° phase offset
	var arm_idle_swing = sin(arm_phase_offset) * 5.0
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
func _reset_skating_stance(delta: float, immediate: bool = false) -> void:
	if immediate:
		# Immediate reset when crossing speed threshold
		left_leg.position.x = -0.15
		right_leg.position.x = 0.15
		left_ski.rotation_degrees.y = 0.0
		right_ski.rotation_degrees.y = 0.0
	else:
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

	# Reset jump state
	jump_state = JumpState.GROUNDED
	jump_timer = 0.0
	jump_crouch_progress = 0.0
	jump_launch_progress = 0.0
	was_in_air = false

	# Reset body position
	body.position.y = 0.0

	# Reset trick system
	current_trick = ""
	trick_display_timer = 0.0
	_reset_air_inputs()

	# Reset carving system
	steer_yaw = 0.0
	velocity_heading = rotation.y

	print("Player (V2) respawned at: ", spawn_position)


## Detect trick inputs during airborne state (ADD.md spec)
func _detect_trick_inputs() -> void:
	# Early exit if trick mode disabled
	if not trick_mode_enabled:
		return

	var delta = get_physics_process_delta_time()

	# A/D → Yaw (spin) + Roll (bank)
	if Input.is_action_pressed("move_left"):
		air_yaw += AIR_YAW_SPEED_MAX * delta  # Spin left (positive Y rotation)
		air_roll = clamp(air_roll + AIR_ROLL_RATE * 0.25 * delta, -AIR_ROLL_MAX, AIR_ROLL_MAX)
	if Input.is_action_pressed("move_right"):
		air_yaw -= AIR_YAW_SPEED_MAX * delta  # Spin right (negative Y rotation)
		air_roll = clamp(air_roll - AIR_ROLL_RATE * 0.25 * delta, -AIR_ROLL_MAX, AIR_ROLL_MAX)

	# W/S → Pitch (forward/back flip)
	if Input.is_action_pressed("move_forward"):
		air_pitch = lerp(air_pitch, AIR_PITCH_TARGET, 0.1)  # Pitch forward
	elif Input.is_action_pressed("move_back"):
		air_pitch = lerp(air_pitch, -AIR_PITCH_TARGET, 0.1)  # Pitch back
	else:
		air_pitch = lerp(air_pitch, 0.0, 0.12)  # Return to neutral

	# Space → Grab
	if Input.is_action_pressed("jump"):
		grab_frames += 1
	else:
		grab_frames = max(grab_frames - 2, 0)

	# Apply physical rotations to body
	_apply_air_trick_rotations()

	# Determine current trick name for UI
	var trick_name = _determine_trick_from_physics()
	if trick_name != "" and trick_name != current_trick:
		_trigger_trick(trick_name)


## Apply air trick rotations to body (ADD.md spec)
func _apply_air_trick_rotations() -> void:
	# Apply additive rotations to Body node
	# Note: Body.rotation is LOCAL to Player node

	# Yaw (Y-axis spin) - rotate entire body
	body.rotation.y = deg_to_rad(air_yaw)

	# Roll (Z-axis bank) - body tilt left/right
	body.rotation_degrees.z = air_roll

	# Pitch (X-axis flip) - forward/back rotation
	# ADD.md: Apply to Torso, Arms, Legs (not Head!)
	torso.rotation_degrees.x = air_pitch

	# Grab animation (ADD.md spec) - arms reach toward skis
	var grab_weight = clamp(grab_frames / float(GRAB_MIN_FRAMES), 0.0, 1.0)
	if grab_weight > 0.0:
		# Arms reach down toward skis (additive to pitch)
		var grab_arm_angle = 60.0 * grab_weight  # Reach down 60°
		left_arm.rotation_degrees.x = air_pitch + grab_arm_angle
		right_arm.rotation_degrees.x = air_pitch + grab_arm_angle

		# Arms move slightly inward (toward skis)
		var grab_arm_inward = 0.1 * grab_weight
		left_arm.position.x = -0.35 + grab_arm_inward  # Original: -0.35
		right_arm.position.x = 0.35 - grab_arm_inward  # Original: 0.35
	else:
		# Normal arm rotation (no grab)
		left_arm.rotation_degrees.x = air_pitch
		right_arm.rotation_degrees.x = air_pitch
		# Reset arm positions
		left_arm.position.x = -0.35
		right_arm.position.x = 0.35

	# Legs pitch slightly less for natural look
	left_leg.rotation_degrees.x = air_pitch * 0.5
	right_leg.rotation_degrees.x = air_pitch * 0.5

	# Head NEVER rotates - only small translation (ADD.md constraint)
	head.rotation = Vector3.ZERO
	# Small forward translation based on pitch
	var head_forward_offset = -air_pitch * 0.01  # Subtle forward lean
	head.position.z = head_forward_offset


## Determine trick name from physics state (ADD.md spec)
func _determine_trick_from_physics() -> String:
	var is_spinning = abs(air_yaw) > 45.0  # Spinning if > 45° total
	var is_rolling = abs(air_roll) > 10.0  # Rolling if > 10°
	var is_pitching_fwd = air_pitch > 10.0
	var is_pitching_back = air_pitch < -10.0
	var is_grabbing = grab_frames >= GRAB_MIN_FRAMES

	# Combination tricks
	if is_grabbing and is_pitching_fwd:
		return "NOSE GRAB"
	if is_grabbing and is_pitching_back:
		return "TAIL GRAB"
	if is_grabbing and (is_spinning or is_rolling):
		return "GRAB + TWIST"

	if is_pitching_fwd and is_spinning and air_yaw > 0:
		return "CORKSCREW LEFT"
	if is_pitching_fwd and is_spinning and air_yaw < 0:
		return "CORKSCREW RIGHT"
	if is_pitching_back and is_spinning and air_yaw > 0:
		return "BACKROLL LEFT"
	if is_pitching_back and is_spinning and air_yaw < 0:
		return "BACKROLL RIGHT"

	# Single tricks
	if is_spinning and air_yaw > 0:
		var spins = int(abs(air_yaw) / 180.0)
		return "SPIN LEFT " + str(spins * 180) + "°"
	if is_spinning and air_yaw < 0:
		var spins = int(abs(air_yaw) / 180.0)
		return "SPIN RIGHT " + str(spins * 180) + "°"
	if is_pitching_fwd:
		return "PITCH FORWARD"
	if is_pitching_back:
		return "PITCH BACK"
	if is_grabbing:
		return "GRAB"

	return ""


## Trigger a trick (display and emit signal)
func _trigger_trick(trick_name: String) -> void:
	current_trick = trick_name
	trick_display_timer = TRICK_DISPLAY_DURATION
	trick_performed.emit(trick_name)

	# Update display immediately
	if trick_display_label:
		trick_display_label.text = trick_name
		trick_display_label.visible = true


## Update trick display timer and fade out
func _update_trick_display(delta: float) -> void:
	if trick_display_timer > 0.0:
		trick_display_timer -= delta

		if trick_display_timer <= 0.0:
			# Hide trick display
			if trick_display_label:
				trick_display_label.visible = false
			current_trick = ""


## Reset air input tracking and physics
func _reset_air_inputs() -> void:
	air_input_detected["forward"] = false
	air_input_detected["back"] = false
	air_input_detected["left"] = false
	air_input_detected["right"] = false
	air_input_detected["grab"] = false

	# Reset air physics
	air_yaw = 0.0
	air_roll = 0.0
	air_pitch = 0.0
	grab_frames = 0

	# Reset body rotations (when trick mode disabled or landed)
	if body:
		body.rotation.y = 0.0
		body.rotation_degrees.z = 0.0

	# Reset arm positions from grab
	if left_arm and right_arm:
		left_arm.position.x = -0.35
		right_arm.position.x = 0.35


## Check if safe landing is possible (ADD.md spec for trick mode, instant for original)
func _can_land_safely() -> bool:
	# 트릭 모드 OFF: 원본처럼 바로 착지 (is_on_floor()만 체크)
	if not trick_mode_enabled:
		return is_on_floor() and velocity.y <= 0.0

	# 트릭 모드 ON: ADD.md spec 적용
	# Must be descending
	if velocity.y > 0.0:
		return false

	# Check ground contact using raycasts
	var left_grounded = left_ski_raycast and left_ski_raycast.is_colliding()
	var right_grounded = right_ski_raycast and right_ski_raycast.is_colliding()

	if not (left_grounded or right_grounded):
		return false

	# Check angle limits (ADD.md spec)
	var roll_ok = abs(air_roll) <= LAND_ROLL_THRESHOLD  # ±12°
	var pitch_ok = abs(air_pitch) <= LAND_PITCH_THRESHOLD  # ±18°

	can_land_safely = roll_ok and pitch_ok

	# Unsafe landing warning
	if not can_land_safely:
		print("[WARNING] Unsafe landing! Roll: %.1f° (max %.1f°), Pitch: %.1f° (max %.1f°)" % [
			air_roll, LAND_ROLL_THRESHOLD,
			air_pitch, LAND_PITCH_THRESHOLD
		])

	return (left_grounded or right_grounded) and can_land_safely


## Initialize trick UI with guide text
func _initialize_trick_ui() -> void:
	# Set up trick guide (always visible)
	if trick_guide_label:
		var guide_text = "공중 트릭: W=전방기울임 | S=후방기울임 | A=좌회전 | D=우회전 | Space=그랩\n"
		guide_text += "조합 트릭: W+A/D=코크스크류 | S+A/D=백롤 | Space+W=노즈그랩 | Space+S=테일그랩"
		trick_guide_label.text = guide_text
		trick_guide_label.visible = trick_mode_enabled

	# Set up trick display (hidden by default)
	if trick_display_label:
		trick_display_label.text = ""
		trick_display_label.visible = false


## Update trick mode UI elements
func _update_trick_mode_ui() -> void:
	if trick_mode_button:
		trick_mode_button.text = "트릭 모드: ON" if trick_mode_enabled else "트릭 모드: OFF"
	if trick_guide_label:
		trick_guide_label.visible = trick_mode_enabled


## Handle trick mode toggle button
func _on_trick_mode_toggled(button_pressed: bool) -> void:
	print("========================================")
	print("[TRICK MODE TOGGLE] Button clicked!")
	print("  Previous state: ", "ON" if trick_mode_enabled else "OFF")
	print("  New state: ", "ON" if button_pressed else "OFF")
	print("========================================")

	trick_mode_enabled = button_pressed

	# Synchronize velocity_heading when switching modes
	if trick_mode_enabled:
		# Switching to TRICK MODE ON: sync velocity_heading to current rotation
		velocity_heading = rotation.y
		print("[TRICK MODE] → ON")
		print("  - Carving system: ENABLED")
		print("  - Air tricks: ENABLED")
		print("  - Jump animation: ENABLED (crouch → launch)")
	else:
		# Switching to TRICK MODE OFF: reset carving state
		steer_yaw = 0.0
		velocity_heading = rotation.y
		print("[TRICK MODE] → OFF")
		print("  - Simple rotation: ENABLED")
		print("  - Air tricks: DISABLED")
		print("  - Jump animation: DISABLED (instant jump)")

	# Update UI elements
	_update_trick_mode_ui()
	print("  - Button text updated: ", trick_mode_button.text if trick_mode_button else "N/A")
	print("  - Trick guide visible: ", trick_guide_label.visible if trick_guide_label else false)

	# Hide trick display when disabled
	if not trick_mode_enabled and trick_display_label:
		trick_display_label.visible = false

	# Reset air physics when disabling
	if not trick_mode_enabled:
		_reset_air_inputs()
		print("  - Air physics reset")

	# Emit signal
	trick_mode_changed.emit(trick_mode_enabled)

	print("========================================")

## NEW CARVING SYSTEM: Apply ski yaw rotation and roll (edge carving)
func _apply_ski_carving(ski_yaw_deg: float, delta: float) -> void:
	# Ski yaw: both skis rotate together in Y-axis (steering direction)
	left_ski.rotation_degrees.y = ski_yaw_deg
	right_ski.rotation_degrees.y = ski_yaw_deg
	
	# Ski roll (Z-axis): carving edge effect
	# Left turn (negative yaw) → lean left (negative roll)
	# Right turn (positive yaw) → lean right (positive roll)
	var ski_roll_deg = ski_yaw_deg * 0.3  # Roll is 30% of yaw
	ski_roll_deg = clamp(ski_roll_deg, -SKI_ROLL_MAX, SKI_ROLL_MAX)
	
	# Outer ski gets more roll (weighted leg)
	if ski_yaw_deg < 0:  # Left turn
		left_ski.rotation_degrees.z = ski_roll_deg * 1.5  # Inner ski
		right_ski.rotation_degrees.z = ski_roll_deg  # Outer ski
	elif ski_yaw_deg > 0:  # Right turn
		right_ski.rotation_degrees.z = ski_roll_deg * 1.5  # Inner ski
		left_ski.rotation_degrees.z = ski_roll_deg  # Outer ski
	else:
		left_ski.rotation_degrees.z = 0.0
		right_ski.rotation_degrees.z = 0.0


## NEW CARVING SYSTEM: Reset ski carving to neutral
func _reset_ski_carving(delta: float) -> void:
	# Smoothly reset ski rotations
	left_ski.rotation_degrees.y = lerp(left_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	right_ski.rotation_degrees.y = lerp(right_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	left_ski.rotation_degrees.z = lerp(left_ski.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)
	right_ski.rotation_degrees.z = lerp(right_ski.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)


## NEW CARVING SYSTEM: Update velocity heading to follow ski yaw
func _update_velocity_heading(delta: float) -> void:
	# Convert steer_yaw (degrees) to target heading (radians)
	# Note: Godot Y-axis rotation: 0 = forward (-Z), PI/2 = left (+X), -PI/2 = right (-X)
	# steer_yaw: positive = right turn, negative = left turn
	var ski_yaw_rad = deg_to_rad(-steer_yaw)  # Negate to match Godot rotation
	var target_heading = rotation.y + ski_yaw_rad
	
	# Smoothly lerp velocity_heading toward target
	velocity_heading = lerp_angle(velocity_heading, target_heading, VELOCITY_HEADING_LERP)


## NEW CARVING SYSTEM: Update body yaw to partially follow ski direction
func _update_body_yaw_follow(delta: float) -> void:
	# Body yaw follows ski yaw direction (visual feedback)
	var target_body_yaw = deg_to_rad(steer_yaw * BODY_YAW_FOLLOW)
	body.rotation.y = lerp_angle(body.rotation.y, target_body_yaw, ANIMATION_SPEED * delta)


## Enable shadows for all player meshes (runtime configuration)
func _enable_player_shadows() -> void:
	# Collect all MeshInstance3D nodes in player body
	var mesh_nodes = []

	# Add all body part meshes
	if head and head is MeshInstance3D:
		mesh_nodes.append(head)
	if torso and torso is MeshInstance3D:
		mesh_nodes.append(torso)

	# Arms and ski poles
	if left_arm:
		var left_upper_arm = left_arm.get_node_or_null("UpperArm")
		var left_pole = left_arm.get_node_or_null("SkiPole")
		if left_upper_arm and left_upper_arm is MeshInstance3D:
			mesh_nodes.append(left_upper_arm)
		if left_pole and left_pole is MeshInstance3D:
			mesh_nodes.append(left_pole)

	if right_arm:
		var right_upper_arm = right_arm.get_node_or_null("UpperArm")
		var right_pole = right_arm.get_node_or_null("SkiPole")
		if right_upper_arm and right_upper_arm is MeshInstance3D:
			mesh_nodes.append(right_upper_arm)
		if right_pole and right_pole is MeshInstance3D:
			mesh_nodes.append(right_pole)

	# Legs and skis
	if left_leg:
		var left_upper_leg = left_leg.get_node_or_null("UpperLeg")
		var left_lower_leg = left_leg.get_node_or_null("LowerLeg")
		if left_upper_leg and left_upper_leg is MeshInstance3D:
			mesh_nodes.append(left_upper_leg)
		if left_lower_leg and left_lower_leg is MeshInstance3D:
			mesh_nodes.append(left_lower_leg)

	if right_leg:
		var right_upper_leg = right_leg.get_node_or_null("UpperLeg")
		var right_lower_leg = right_leg.get_node_or_null("LowerLeg")
		if right_upper_leg and right_upper_leg is MeshInstance3D:
			mesh_nodes.append(right_upper_leg)
		if right_lower_leg and right_lower_leg is MeshInstance3D:
			mesh_nodes.append(right_lower_leg)

	# Skis
	if left_ski and left_ski is MeshInstance3D:
		mesh_nodes.append(left_ski)
	if right_ski and right_ski is MeshInstance3D:
		mesh_nodes.append(right_ski)

	# Enable shadows for all collected meshes
	for node in mesh_nodes:
		if node:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var all_cast_on := true
	for node in mesh_nodes:
		if node and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			all_cast_on = false
			break
	print("[Player] Shadow casting set for %d meshes (all_on=%s)" % [mesh_nodes.size(), all_cast_on])
