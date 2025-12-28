extends CharacterBody3D

# V3: FSM-based state management with auto-recovery and landing failure detection
# Based on player_state_prompt.md requirements

# Player State Machine (FSM)
enum PlayerState { IDLE, RIDING, JUMP, FLIP, LANDING, FALLEN, RECOVER }
var state: PlayerState = PlayerState.IDLE

# Player movement constants (from v2)
const MAX_SPEED = 15.0
const TURN_SPEED = 1.5
const MIN_TURN_SPEED = 2.0
const ACCELERATION = 5.0
const SLOPE_ACCELERATION_FACTOR = 0.5
const BRAKE_DECELERATION = 10.0
const FRICTION = 2.0
const SKATING_SPEED_THRESHOLD = 4.0
const JUMP_VELOCITY = 12.0
const JUMP_SPEED_BOOST_MAX = 3.0
const JUMP_RAMP_BOOST = 1.3
const GRAVITY = 9.8

# Landing failure detection constants
const LANDING_TILT_THRESHOLD = 0.5  # Body tilt threshold: 60° (dot product with ground normal)

# Animation constants
const TILT_AMOUNT = 30.0
const LEAN_AMOUNT = 20.0
const ANIMATION_SPEED = 10.0
const BREATHING_CYCLE_SPEED = 0.5
const ARM_SWING_SPEED = 1.25

# Trick constants
const AIR_YAW_SPEED_MAX = 240.0
const AIR_ROLL_RATE = 120.0
const AIR_ROLL_MAX = 40.0
const AIR_PITCH_TARGET = 30.0
const FLIP_ROTATION_SPEED = 360.0
const MIN_TRICK_HEIGHT = 1.5

# Carving constants
const STEER_YAW_RATE = 60.0
const SKI_YAW_MAX = 18.0
const SKI_YAW_MAX_BOOST = 22.0
const SKI_ROLL_MAX = 6.0
const TORSO_ROLL_COEFFICIENT = 0.6
const BODY_YAW_FOLLOW = 0.5
const VELOCITY_HEADING_LERP = 0.1
const STEER_YAW_DAMPING = 0.92

# Camera references
@onready var camera_third_person = $Camera3D_ThirdPerson
@onready var camera_third_person_front = $Camera3D_ThirdPersonFront
@onready var camera_first_person = $Body/Camera3D_FirstPerson
@onready var camera_free = $Camera3D_Free

# Body parts references
@onready var body = $Body
@onready var torso = $Body/Torso
@onready var head = $Body/Head
@onready var left_arm = $Body/LeftArm
@onready var right_arm = $Body/RightArm
@onready var left_leg = $Body/LeftLeg
@onready var right_leg = $Body/RightLeg
@onready var left_upper_leg = $Body/LeftLeg/UpperLeg
@onready var left_lower_leg = $Body/LeftLeg/LowerLeg
@onready var right_upper_leg = $Body/RightLeg/UpperLeg
@onready var right_lower_leg = $Body/RightLeg/LowerLeg
@onready var left_ski = $Body/LeftLeg/Ski
@onready var right_ski = $Body/RightLeg/Ski
@onready var left_eye = $Body/Head/LeftEye
@onready var right_eye = $Body/Head/RightEye

# UI references
@onready var camera_mode_label = $UI/CameraModeLabel
@onready var speed_label = $UI/SpeedLabel
@onready var state_label = $UI/StateLabel  # FSM state display
@onready var air_rotation_label = $UI/AirRotationLabel

# Systems
@onready var ski_tracks = $SkiTracks
@onready var animation_player: AnimationPlayer = $AnimationPlayer  # For FSM animations
@onready var player_customization = $PlayerCustomization

# Camera mode
var camera_mode = 0
var hide_body_in_first_person: bool = false

# Trick mode toggle
var trick_mode_enabled: bool = true  # 항상 활성화

# Signals
signal camera_mode_changed(mode_name: String)
signal trick_performed(trick_name: String)
signal trick_mode_changed(enabled: bool)
signal state_changed(new_state: PlayerState)

# Animation state (procedural)
var current_tilt = 0.0
var current_lean = 0.0
var current_upper_lean = 0.0
var target_tilt = 0.0
var target_lean = 0.0
var target_upper_lean = 0.0
var breathing_phase = 0.0
var arm_swing_phase = 0.0
var edge_chatter_phase = 0.0

# Movement state
var current_speed = 0.0
var skating_phase = 0.0
var spawn_position: Vector3
var spawn_rotation: float

# Trick system
var current_trick: String = ""
var air_pitch: float = 0.0
var trick_rotation_x_total: float = 0.0
var trick_flip_speed: float = 0.0
var trick_in_progress: bool = false
var trick_score: int = 0
var total_score: int = 0

# Tail Grab system
var tail_grab_intensity: float = 0.0  # 0.0~1.0 (pose strength)

# Carving state
var steer_yaw: float = 0.0
var velocity_heading: float = 0.0

# FSM timers
var fallen_timer: float = 0.0
var recover_timer: float = 0.0
const FALLEN_DURATION = 1.5  # Duration of fall animation
const RECOVER_DURATION = 1.0  # Duration of recover animation

# Ski track collision detection
@export var track_creation_interval := 0.03  # Seconds between track creation
var track_timer := 0.0
var touching_parts := {}  # Dictionary of body parts currently touching terrain


func _ready() -> void:
	add_to_group("player")
	camera_mode_changed.connect(_on_camera_mode_changed)
	camera_mode = 0
	_apply_camera_mode()
	_on_camera_mode_changed(_get_camera_mode_name())
	spawn_position = global_position
	spawn_rotation = rotation.y
	velocity_heading = rotation.y

	# Connect ski tracks
	if ski_tracks:
		ski_tracks.player = self

	# Setup collision detection for body parts
	_setup_body_part_collision_detection()

	# Initialize UI
	_update_state_ui()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Enable shadows
	_enable_player_shadows()

	# Connect AnimationPlayer signals
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

	# Start in IDLE state
	set_state(PlayerState.IDLE)


## State management functions

func set_state(new_state: PlayerState) -> void:
	if state == new_state:
		return

	var old_state_name = PlayerState.keys()[state]
	var new_state_name = PlayerState.keys()[new_state]

	print("[FSM] %s → %s" % [old_state_name, new_state_name])

	state = new_state
	_update_state_ui()
	_enter_state(new_state)
	state_changed.emit(new_state)


func _enter_state(new_state: PlayerState) -> void:
	match new_state:
		PlayerState.IDLE:
			_enter_idle()
		PlayerState.RIDING:
			_enter_riding()
		PlayerState.JUMP:
			_enter_jump()
		PlayerState.FLIP:
			_enter_flip()
		PlayerState.LANDING:
			_enter_landing()
		PlayerState.FALLEN:
			_enter_fallen()
		PlayerState.RECOVER:
			_enter_recover()


func _enter_idle() -> void:
	print("[IDLE] Entered")
	_reset_body_pose()
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


func _enter_riding() -> void:
	print("[RIDING] Entered - Ready to ride")
	_reset_body_pose()
	if animation_player and animation_player.has_animation("ride"):
		animation_player.play("ride")


func _enter_jump() -> void:
	print("[JUMP] Entered - Jumping")
	if animation_player and animation_player.has_animation("jump"):
		animation_player.play("jump")


func _enter_flip() -> void:
	print("[FLIP] Entered - Performing trick")
	if animation_player and animation_player.has_animation("flip"):
		animation_player.play("flip")


func _enter_landing() -> void:
	print("[LANDING] Entered - Checking landing conditions")
	if animation_player and animation_player.has_animation("landing"):
		animation_player.play("landing")


func _enter_fallen() -> void:
	print("[FALLEN] Entered - Player fell down")
	velocity = Vector3.ZERO
	# Reduce gravity for fallen state
	# (Note: CharacterBody3D doesn't have gravity_scale, we'll handle in _physics_process)
	fallen_timer = 0.0

	if animation_player and animation_player.has_animation("fall"):
		animation_player.play("fall")


func _enter_recover() -> void:
	print("[RECOVER] Entered - Getting back up")
	recover_timer = 0.0

	# Correct rotation
	if body:
		body.rotation_degrees.x = 0.0
		body.rotation.y = 0.0
		body.rotation_degrees.z = 0.0

	# Realign forward direction
	rotation.y = velocity_heading

	if animation_player and animation_player.has_animation("recover"):
		animation_player.play("recover")


## Reset body pose to default standing position
func _reset_body_pose() -> void:
	print("[FSM] Resetting body pose to default")

	# Body reset
	if body:
		body.rotation_degrees.x = 0.0
		body.rotation.y = 0.0
		body.rotation_degrees.z = 0.0
		body.position.y = 0.0

	# Head reset
	if head:
		head.rotation = Vector3.ZERO
		head.position.z = 0.0

	# Legs reset
	if left_leg and right_leg:
		left_leg.rotation_degrees.x = 0.0
		right_leg.rotation_degrees.x = 0.0
		left_leg.rotation_degrees.z = 0.0
		right_leg.rotation_degrees.z = 0.0
		left_leg.position.x = -0.15
		right_leg.position.x = 0.15
		left_leg.position.z = 0.0  # Tail Grab Z offset reset
		right_leg.position.z = 0.0  # Tail Grab Z offset reset

	# Upper/Lower leg reset (knee joints)
	if left_upper_leg and left_lower_leg and right_upper_leg and right_lower_leg:
		left_upper_leg.rotation_degrees.x = 0.0
		right_upper_leg.rotation_degrees.x = 0.0
		left_lower_leg.rotation_degrees.x = 0.0
		right_lower_leg.rotation_degrees.x = 0.0
		left_lower_leg.position.y = -0.67  # Original Y position
		right_lower_leg.position.y = -0.67
		left_lower_leg.position.z = 0.0  # Tail Grab Z offset reset
		right_lower_leg.position.z = 0.0  # Tail Grab Z offset reset

	# Skis reset
	if left_ski and right_ski:
		left_ski.rotation_degrees.x = 0.0  # Tail Grab rotation reset
		right_ski.rotation_degrees.x = 0.0
		left_ski.rotation_degrees.y = 0.0
		right_ski.rotation_degrees.y = 0.0
		left_ski.rotation_degrees.z = 0.0
		right_ski.rotation_degrees.z = 0.0
		left_ski.position.y = -0.965  # Original Y position
		right_ski.position.y = -0.965
		left_ski.position.z = -0.3  # Original Z position
		right_ski.position.z = -0.3

	# Torso reset
	if torso:
		torso.position.x = 0.0
		torso.position.z = 0.0
		torso.rotation_degrees.y = 0.0

	# Reset trick variables
	air_pitch = 0.0
	trick_rotation_x_total = 0.0
	trick_flip_speed = 0.0
	trick_in_progress = false
	tail_grab_intensity = 0.0  # Reset Tail Grab

	# Reset animation variables
	current_tilt = 0.0
	current_lean = 0.0
	current_upper_lean = 0.0

	# Reset arms (Tail Grab 포즈 해제)
	if left_arm and right_arm:
		left_arm.rotation = Vector3.ZERO
		right_arm.rotation = Vector3.ZERO


## Update UI state label
func _update_state_ui() -> void:
	if state_label:
		var state_name = PlayerState.keys()[state]
		state_label.text = "State: %s" % state_name


## Animation finished callback
func _on_animation_finished(anim_name: String) -> void:
	print("[AnimationPlayer] Animation finished: %s" % anim_name)

	match anim_name:
		"fall":
			# Auto-transition to RECOVER after fall animation
			set_state(PlayerState.RECOVER)
		"recover":
			# Auto-transition to RIDING after recover animation
			set_state(PlayerState.RIDING)


func _physics_process(delta: float) -> void:
	if camera_mode == 3:  # Free camera mode
		return

	# State-based physics
	match state:
		PlayerState.IDLE:
			_process_idle(delta)
		PlayerState.RIDING:
			_process_riding(delta)
		PlayerState.JUMP:
			_process_jump(delta)
		PlayerState.FLIP:
			_process_flip(delta)
		PlayerState.LANDING:
			_process_landing(delta)
		PlayerState.FALLEN:
			_process_fallen(delta)
		PlayerState.RECOVER:
			_process_recover(delta)

	# Apply physics movement
	move_and_slide()

	# Ski track creation timer
	track_timer += delta
	if track_timer >= track_creation_interval:
		track_timer = 0.0
		_create_tracks_for_touching_parts()

	# Update UI
	_update_speed_ui()
	_update_air_rotation_ui()

	# Debug fall detection
	if global_position.y < -50:
		print("Player fell through terrain! Respawning...")
		respawn()


## State processing functions

func _process_idle(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Get input to transition to RIDING
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	# Handle speed in IDLE (to start moving)
	_handle_speed(is_moving_forward, is_braking, delta)

	# Apply velocity BEFORE state transition
	_apply_velocity(delta)

	# Breathing animation
	_update_breathing_cycle(delta)

	# Transition to RIDING when speed > 0 (moved to end)
	if current_speed > 0:
		set_state(PlayerState.RIDING)


func _process_riding(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump input
	var wants_to_jump = Input.is_action_just_pressed("jump")
	if wants_to_jump:
		velocity.y = _calculate_jump_boost()

	# Get input
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	# Movement logic (same as v2)
	_handle_turning(turn_input, is_moving_forward, is_braking, delta)
	_handle_speed(is_moving_forward, is_braking, delta)
	_apply_velocity(delta)

	# Animations
	_update_riding_animations(is_moving_forward, is_braking, turn_input, delta)

	# State transitions at the END
	if not is_on_floor() or wants_to_jump:
		set_state(PlayerState.JUMP)
	elif current_speed <= 0:
		set_state(PlayerState.IDLE)


func _process_jump(delta: float) -> void:
	# Apply gravity
	velocity.y -= GRAVITY * delta

	# Continue horizontal movement
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	_handle_turning(turn_input, is_moving_forward, is_braking, delta)
	_apply_velocity(delta)

	# Detect trick inputs (only if trick mode enabled)
	if trick_mode_enabled and _get_height_above_ground() >= MIN_TRICK_HEIGHT:
		# Backflip/Frontflip - transition to FLIP
		if Input.is_action_pressed("move_back") or Input.is_action_pressed("move_forward"):
			set_state(PlayerState.FLIP)
			return

		# Tail Grab 감지 (JUMP 상태 유지)
		_detect_trick_inputs()

	# Apply Tail Grab pose if active (JUMP 상태에서도)
	if tail_grab_intensity > 0.01:
		_apply_tail_grab_pose(tail_grab_intensity)

	# Check for landing
	if is_on_floor() and velocity.y <= 0:
		set_state(PlayerState.LANDING)


func _process_flip(delta: float) -> void:
	# Apply gravity
	velocity.y -= GRAVITY * delta

	# Continue horizontal movement
	var turn_input = Input.get_axis("move_left", "move_right")
	var is_moving_forward = Input.is_action_pressed("move_forward")
	var is_braking = Input.is_action_pressed("move_back")

	_handle_turning(turn_input, is_moving_forward, is_braking, delta)
	_apply_velocity(delta)

	# Detect trick inputs
	_detect_trick_inputs()

	# Check for landing
	if is_on_floor() and velocity.y <= 0:
		set_state(PlayerState.LANDING)


func _process_landing(delta: float) -> void:
	# Check landing failure conditions
	if _check_landing_failed():
		set_state(PlayerState.FALLEN)
		return

	# Landing successful - calculate trick score if applicable
	if trick_in_progress:
		_calculate_trick_score()

	# Smooth transition back to riding
	_reset_body_pose()
	set_state(PlayerState.RIDING)


func _process_fallen(delta: float) -> void:
	# Reduced gravity in fallen state
	velocity.y -= GRAVITY * 0.5 * delta

	# Stay on ground
	if is_on_floor():
		velocity = Vector3.ZERO

	# Timer-based transition (fallback if animation doesn't finish)
	fallen_timer += delta
	if fallen_timer >= FALLEN_DURATION:
		if not animation_player or not animation_player.is_playing():
			set_state(PlayerState.RECOVER)


func _process_recover(delta: float) -> void:
	# Stay still during recovery
	velocity = Vector3.ZERO

	# Timer-based transition (fallback)
	recover_timer += delta
	if recover_timer >= RECOVER_DURATION:
		if not animation_player or not animation_player.is_playing():
			set_state(PlayerState.RIDING)


## Landing failure detection - Tilt-only check
func _check_landing_failed() -> bool:
	# Check body tilt against ground normal (60° threshold)
	# Use body.transform to track the rotating Body node, not the static CharacterBody3D
	var player_up = body.transform.basis.y
	var ground_normal = get_floor_normal()
	var dot = player_up.dot(ground_normal)

	if dot < LANDING_TILT_THRESHOLD:
		var tilt_angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))
		print("[LANDING] FAILED - Body tilt=%.1f° (threshold=60°)" % tilt_angle)
		return true

	print("[LANDING] SUCCESS - Body tilt OK")
	return false


## Movement helper functions (from v2)

func _handle_turning(turn_input: float, is_moving_forward: bool, is_braking: bool, delta: float) -> void:
	if current_speed >= MIN_TURN_SPEED and not is_braking:
		if trick_mode_enabled:
			# Carving system
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
			# Simple rotation
			if turn_input != 0:
				rotation.y += -turn_input * TURN_SPEED * delta

			target_tilt = -turn_input * TILT_AMOUNT
			_apply_weight_shift(turn_input, delta)
	else:
		if trick_mode_enabled:
			steer_yaw = 0.0
			_reset_ski_carving(delta)

		target_tilt = 0.0
		_reset_weight_shift(delta)


func _handle_speed(is_moving_forward: bool, is_braking: bool, delta: float) -> void:
	# Calculate slope factor
	var slope_factor = 0.0
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var slope_angle = acos(floor_normal.dot(Vector3.UP))
		slope_factor = sin(slope_angle) * SLOPE_ACCELERATION_FACTOR

	# Handle speed
	if is_moving_forward:
		var acceleration = ACCELERATION + slope_factor * 20.0
		current_speed = min(current_speed + acceleration * delta, MAX_SPEED)
	elif is_braking:
		current_speed = max(current_speed - BRAKE_DECELERATION * delta, 0.0)
	else:
		current_speed = max(current_speed - FRICTION * delta, 0.0)


func _apply_velocity(delta: float) -> void:
	if current_speed > 0:
		if trick_mode_enabled:
			# Use velocity_heading (carving)
			var velocity_dir = Vector3(-sin(velocity_heading), 0, -cos(velocity_heading))
			velocity.x = velocity_dir.x * current_speed
			velocity.z = velocity_dir.z * current_speed
			rotation.y = velocity_heading
		else:
			# Use transform.basis
			var forward_dir = -transform.basis.z
			velocity.x = forward_dir.x * current_speed
			velocity.z = forward_dir.z * current_speed

			# Align rotation with body
			var body_y_rotation = body.rotation.y
			rotation.y = lerp_angle(rotation.y, rotation.y + body_y_rotation, 2.0 * delta)
			body.rotation.y = lerp_angle(body.rotation.y, 0, 2.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _update_riding_animations(is_moving_forward: bool, is_braking: bool, turn_input: float, delta: float) -> void:
	# Lean system
	var target_leg_bend = 0.0  # Target knee bending angle

	if is_braking:
		target_lean = -20.0
		target_upper_lean = -10.0
		target_leg_bend = -15.0  # Slight knee bend while braking
	elif is_moving_forward and current_speed < SKATING_SPEED_THRESHOLD:
		# 스케이팅 (저속 + 전진)
		target_lean = 0.0
		target_upper_lean = -45.0
		target_leg_bend = 0.0  # 다리 펼침 (스케이팅 자세)
		_update_arm_swing(delta)  # 팔 푸시 애니메이션
	elif is_moving_forward:
		# 일반 전진 (고속)
		target_lean = 0.0
		target_upper_lean = -45.0
		target_leg_bend = -25.0  # Proper ski stance - knees bent
		_update_arm_swing(delta)
	else:
		# 유휴 (정지/활주)
		target_lean = 0.0
		target_upper_lean = -15.0
		target_leg_bend = 0.0  # Straight legs when idle

	# Always update breathing
	_update_breathing_cycle(delta)

	# Smooth interpolation
	current_tilt = lerp(current_tilt, target_tilt, ANIMATION_SPEED * delta)
	current_lean = lerp(current_lean, target_lean, ANIMATION_SPEED * delta)
	current_upper_lean = lerp(current_upper_lean, target_upper_lean, ANIMATION_SPEED * delta)

	# Apply rotations (only when not in air trick)
	if state != PlayerState.FLIP:
		body.rotation_degrees.z = current_tilt
		body.rotation_degrees.x = current_lean

	torso.rotation_degrees.x = current_upper_lean

	# Keep head on top of tilted torso (RIDING and FLIP states)
	# Head rotation stays upright (no rotation), only position follows torso
	if head and (state == PlayerState.RIDING or state == PlayerState.FLIP):
		# Calculate Z offset to keep head on top of tilted torso
		var lean_rad = deg_to_rad(current_upper_lean)
		var torso_half_height = 0.25  # CapsuleMesh height/2
		var neck_height = 0.25  # Gap between torso top and head

		# Head moves forward when torso tilts forward (negative lean)
		# Z offset = sin(rotation) * (torso_top_offset + neck_height)
		var total_height = torso_half_height + neck_height
		var z_offset = sin(lean_rad) * total_height

		head.position.z = z_offset

	# Keep arms attached to body sides when tilting (RIDING and FLIP states)
	if left_arm and right_arm and (state == PlayerState.RIDING or state == PlayerState.FLIP):
		var tilt_rad = deg_to_rad(current_tilt)
		var shoulder_height = 0.3  # Y position of arms (shoulder level)

		# When body tilts left (positive Z rotation):
		# - Left shoulder moves left and down
		# - Right shoulder moves right and up

		# X offset: horizontal displacement (always positive to move toward center)
		var x_offset = abs(sin(tilt_rad)) * shoulder_height

		# Original arm X positions
		var left_arm_base_x = -0.35
		var right_arm_base_x = 0.35

		left_arm.position.x = left_arm_base_x + x_offset
		right_arm.position.x = right_arm_base_x - x_offset

		# 팔 상단 Y위치: 몸통 기울기에 따라 어깨 위치 조정
		# 몸통이 앞으로 기울면 어깨가 아래로 이동
		var torso_lean_rad = deg_to_rad(current_upper_lean)
		var shoulder_y_offset = sin(torso_lean_rad) * 0.25  # 몸통 절반 높이만큼 이동
		var arm_base_y = 0.4  # 몸통 상단 (Torso 0.15 + 높이 절반 0.25)
		left_arm.position.y = arm_base_y + shoulder_y_offset
		right_arm.position.y = arm_base_y + shoulder_y_offset

		# Z offset: 상체 기울기에 따라 어깨가 앞으로
		var shoulder_z_offset = sin(torso_lean_rad) * 0.25
		left_arm.position.z = shoulder_z_offset
		right_arm.position.z = shoulder_z_offset


	# Apply leg bending (knee bend for ski stance)
	# Split knee joint: upper leg (thigh) + lower leg (calf) for realistic bending
	if left_upper_leg and left_lower_leg and right_upper_leg and right_lower_leg:
		# Upper leg (thigh): hip joint bending (OPPOSITE direction)
		var target_upper_leg = target_leg_bend * -0.6  # Negative sign = opposite rotation
		left_upper_leg.rotation_degrees.x = lerp(left_upper_leg.rotation_degrees.x, target_upper_leg, ANIMATION_SPEED * delta)
		right_upper_leg.rotation_degrees.x = lerp(right_upper_leg.rotation_degrees.x, target_upper_leg, ANIMATION_SPEED * delta)

		# Lower leg (calf): knee joint bending (forward bend)
		var target_lower_leg = target_leg_bend * 1.0  # 100% at knee for sharper bend
		left_lower_leg.rotation_degrees.x = lerp(left_lower_leg.rotation_degrees.x, target_lower_leg, ANIMATION_SPEED * delta)
		right_lower_leg.rotation_degrees.x = lerp(right_lower_leg.rotation_degrees.x, target_lower_leg, ANIMATION_SPEED * delta)


	# Ski stance
	_update_ski_stance(is_braking, delta)


## Trick detection (from v2)
func _detect_trick_inputs() -> void:
	if not trick_mode_enabled:
		return

	var height_above_ground = _get_height_above_ground()
	if height_above_ground < MIN_TRICK_HEIGHT:
		trick_flip_speed = lerp(trick_flip_speed, 0.0, 0.2)
		return

	var delta = get_physics_process_delta_time()

	# Shift → Tail Grab (레이어로 작동 - 어떤 트릭 위에도 얹을 수 있음)
	if Input.is_key_pressed(KEY_SHIFT):
		tail_grab_intensity = lerp(tail_grab_intensity, 1.0, 0.15)
		if not trick_in_progress:
			# Tail Grab만 단독 실행
			trick_in_progress = true
			current_trick = "Tail Grab"
			print("[Trick] Starting Tail Grab!")
		elif not current_trick.contains("Tail Grab"):
			# 이미 다른 트릭 중 + Shift 누름 = 콤보
			current_trick = current_trick + " + Tail Grab"
			print("[Trick] Combo: %s!" % current_trick)
	else:
		tail_grab_intensity = lerp(tail_grab_intensity, 0.0, 0.15)

	# W/S → Flip tricks (간소화: 콤보 로직 제거, 위에서 통합 처리)
	if Input.is_action_pressed("move_back"):
		# Backflip
		trick_flip_speed = -FLIP_ROTATION_SPEED
		if not trick_in_progress:
			trick_in_progress = true
			current_trick = "Backflip"
			print("[Trick] Starting Backflip!")
	elif Input.is_action_pressed("move_forward"):
		# Frontflip
		trick_flip_speed = FLIP_ROTATION_SPEED
		if not trick_in_progress:
			trick_in_progress = true
			current_trick = "Frontflip"
			print("[Trick] Starting Frontflip!")
	else:
		trick_flip_speed = lerp(trick_flip_speed, 0.0, 0.15)

	# Apply flip rotation
	if abs(trick_flip_speed) > 1.0:
		var flip_delta = trick_flip_speed * delta
		trick_rotation_x_total += flip_delta
		air_pitch += flip_delta

	# Apply to body
	_apply_air_trick_rotations()

	# Apply Tail Grab pose (독립적으로 적용)
	if tail_grab_intensity > 0.01:
		_apply_tail_grab_pose(tail_grab_intensity)


## Apply air trick rotations to body
## Note: Head는 Body의 자식이므로 자동으로 회전을 상속받음
## 따라서 head.position이나 head.rotation을 별도로 수정하지 않음
## (부모 회전 시 자식의 로컬 축도 회전되므로 position 수정은 버그 발생)
func _apply_air_trick_rotations() -> void:
	body.rotation_degrees.x = air_pitch
	body.rotation.y = 0.0
	body.rotation_degrees.z = 0.0

	# Head는 Body의 자식이므로 자동으로 body 회전을 따라감
	# head.position.z를 수정하지 않음 (이전 버그: flip 시 머리가 떨어져 나감)
	if head:
		head.rotation = Vector3.ZERO  # 착지 후 리셋용


## Apply Tail Grab pose to body parts
## intensity: 0.0~1.0 (pose strength, lerped for smooth transitions)
## Note: 이 함수는 Body 회전과 독립적으로 작동 (Torso, Arms, Legs만 조작)
## Body 회전(Backflip/Frontflip)과 동시 사용 가능
func _apply_tail_grab_pose(intensity: float) -> void:
	if not right_arm or not left_arm or not right_leg or not left_leg or not torso:
		return

	# Smooth interpolation factor (부드러운 전환)
	var lerp_factor = 0.2

	# === 오른팔: 뒤로 뻗어 오른쪽 스키 테일 잡기 ===
	# X축: 팔을 뒤로 -140도 (스키 테일에 닿을 정도)
	# Y축: 약간 안쪽으로 -30도 (몸 쪽으로)
	# Tail grab targets
	var tail_grab_right_x = -40.0 * intensity
	var tail_grab_right_y = -40.0 * intensity

	# RIDING targets (from line 1078-1079: breathing animation)
	# Use current_upper_lean as base (like RIDING does)
	var riding_right_x = current_upper_lean - 5.0  # Default breathing offset

	# Blend: intensity=1 → tail_grab, intensity=0 → riding
	var target_right_arm_x = lerp(riding_right_x, tail_grab_right_x, intensity)
	var target_right_arm_y = lerp(0.0, tail_grab_right_y, intensity)  # Y returns to 0

	right_arm.rotation_degrees.x = lerp(right_arm.rotation_degrees.x, target_right_arm_x, lerp_factor)
	right_arm.rotation_degrees.y = lerp(right_arm.rotation_degrees.y, target_right_arm_y, lerp_factor)

	# === 왼팔: 균형 잡기 위해 위/옆으로 ===
	# X축: 위로 45도
	# Z축: 옆으로 30도
	# Tail grab targets
	var tail_grab_left_x = 45.0 * intensity
	var tail_grab_left_z = 30.0 * intensity

	# RIDING targets
	var riding_left_x = current_upper_lean + 5.0  # Default breathing offset

	# Blend
	var target_left_arm_x = lerp(riding_left_x, tail_grab_left_x, intensity)
	var target_left_arm_z = lerp(0.0, tail_grab_left_z, intensity)  # Z returns to 0

	left_arm.rotation_degrees.x = lerp(left_arm.rotation_degrees.x, target_left_arm_x, lerp_factor)
	left_arm.rotation_degrees.z = lerp(left_arm.rotation_degrees.z, target_left_arm_z, lerp_factor)

	# === 다리: Torso와 평행하게 회전 ===
	# 허벅지 (UpperLeg): -30도 (Torso와 평행)
	var tail_grab_upper_x = -30.0 * intensity
	var riding_upper_x = 15.0  # Default RIDING knee bend (from line 723)
	var target_upper_leg_x = lerp(riding_upper_x, tail_grab_upper_x, intensity)
	right_upper_leg.rotation_degrees.x = lerp(right_upper_leg.rotation_degrees.x, target_upper_leg_x, lerp_factor)
	left_upper_leg.rotation_degrees.x = lerp(left_upper_leg.rotation_degrees.x, target_upper_leg_x, lerp_factor)

	# 종아리 (LowerLeg): -100도 (더 강하게 뒤로 굽힘)
	var tail_grab_lower_x = -100.0 * intensity
	var riding_lower_x = -25.0  # Default RIDING calf bend (from line 728)
	var target_lower_leg_x = lerp(riding_lower_x, tail_grab_lower_x, intensity)
	right_lower_leg.rotation_degrees.x = lerp(right_lower_leg.rotation_degrees.x, target_lower_leg_x, lerp_factor)
	left_lower_leg.rotation_degrees.x = lerp(left_lower_leg.rotation_degrees.x, target_lower_leg_x, lerp_factor)

	# === 상체: 뒤로 아치형 벤딩 ===
	# X축: 뒤로 -30도 (적당한 아치, 스키 테일 방향으로 휨)
	# Tail grab target
	var tail_grab_torso_x = 30.0 * intensity

	# RIDING target (from line 682: current_upper_lean)
	var riding_torso_x = current_upper_lean

	# Blend: intensity=1 → tail_grab, intensity=0 → riding
	var target_torso_x = lerp(riding_torso_x, tail_grab_torso_x, intensity)

	torso.rotation_degrees.x = lerp(torso.rotation_degrees.x, target_torso_x, lerp_factor)

	# Position.z should return to 0 (RIDING default)
	var target_torso_z = lerp(0.0, torso.rotation_degrees.z - 0.2, intensity)
	torso.position.z = lerp(torso.position.z, target_torso_z, lerp_factor)

	# === 머리: 몸통 상단에 붙이기 ===
	# Torso가 뒤로 회전할 때 head가 몸통 상단에 붙어있도록 위치 조정
	if head:
		var torso_rotation_rad = deg_to_rad(target_torso_x)  # 30° * intensity
		var torso_half_height = 0.25
		var neck_height = 0.25
		var total_height = torso_half_height + neck_height

		# Torso가 뒤로 기울면 head는 앞으로 이동 (sin 사용)
		# intensity=0 → target_head_z=0 (원래 위치)
		# intensity=1 → target_head_z≈0.25 (앞으로 이동)
		var target_head_z = sin(torso_rotation_rad) * total_height
		head.position.z = lerp(head.position.z, target_head_z, lerp_factor)

	# === 다리 위치: Torso 회전을 따라 뒤로 이동 ===
	# Torso가 뒤로 기울 때 고관절(다리 시작점)도 뒤로 이동
	if left_leg and right_leg:
		# Torso 회전 각도를 라디안으로 변환
		var torso_rotation_rad = deg_to_rad(target_torso_x)

		# Torso 높이(Y=0.15)에서 회전 시 Z축 오프셋 계산
		# sin(rotation) * height = Z방향 이동량
		var torso_height = 0.15  # Torso의 Y 위치
		var leg_attach_height = -0.3  # LeftLeg의 원래 Y 위치
		var height_diff = torso_height - leg_attach_height  # 0.45m

		# 뒤로 기울 때 고관절이 뒤로 이동하는 양
		# -50도 회전 시 약 0.35m 뒤로 이동
		# 부호 반전: 상체가 뒤로 기울면 다리도 뒤로
		var z_offset = -sin(torso_rotation_rad) * height_diff * intensity

		# 다리를 뒤로 이동 (부드럽게 lerp)
		left_leg.position.z = lerp(left_leg.position.z, z_offset, lerp_factor)
		right_leg.position.z = lerp(right_leg.position.z, z_offset, lerp_factor)

	# === LowerLeg 위치: UpperLeg 끝에 붙이기 ===
	# UpperLeg이 -30° 회전하면 끝점이 이동 → LowerLeg를 그 끝점에 배치
	if left_upper_leg and left_lower_leg and right_upper_leg and right_lower_leg:
		# UpperLeg 회전 각도 (-30°)
		var upper_leg_rotation_rad = deg_to_rad(-30.0 * intensity)
		var upper_leg_half_length = 0.25  # CapsuleMesh height 0.5m / 2

		# UpperLeg 끝점 위치 (UpperLeg 중심 기준)
		# 원래 UpperLeg 중심: Y=-0.15
		var upper_leg_end_y = -upper_leg_half_length - cos(upper_leg_rotation_rad) * upper_leg_half_length
		var upper_leg_end_z = -sin(upper_leg_rotation_rad) * upper_leg_half_length

		# LowerLeg을 UpperLeg 끝점에 배치 (LowerLeg 중심을 끝점 아래로)
		var lower_leg_half_length = 0.25
		var calculated_lower_y = upper_leg_end_y + lower_leg_half_length
		var calculated_lower_z = upper_leg_end_z + lower_leg_half_length

		# Original positions (from player.tscn)
		var original_lower_y = -0.67
		var original_lower_z = 0.0

		# Interpolate between calculated position and original position based on intensity
		# intensity=1.0 → calculated position (tail grab)
		# intensity=0.0 → original position (normal)
		var target_lower_y = lerp(original_lower_y, calculated_lower_y, intensity)
		var target_lower_z = lerp(original_lower_z, calculated_lower_z, intensity)

		left_lower_leg.position.y = lerp(left_lower_leg.position.y, target_lower_y, lerp_factor)
		left_lower_leg.position.z = lerp(left_lower_leg.position.z, target_lower_z, lerp_factor)
		right_lower_leg.position.y = lerp(right_lower_leg.position.y, target_lower_y, lerp_factor)
		right_lower_leg.position.z = lerp(right_lower_leg.position.z, target_lower_z, lerp_factor)

	# === Ski 위치: LowerLeg 끝에 붙이기 ===
	# LowerLeg이 -100° 회전하면 끝점이 이동 → Ski를 그 끝점에 배치
	if left_ski and right_ski and left_lower_leg and right_lower_leg:
		# LowerLeg 회전 각도 (-100°)
		var lower_leg_rotation_rad = deg_to_rad(-100.0 * intensity)
		var lower_leg_half_length = 0.25

		# LowerLeg의 LeftLeg 기준 position 가져오기
		var lower_leg_pos_y = left_lower_leg.position.y  # UpperLeg 끝에 배치된 Y
		var lower_leg_pos_z = left_lower_leg.position.z  # UpperLeg 끝에 배치된 Z

		# LowerLeg 끝점 오프셋 (LowerLeg 중심에서 끝까지)
		# LowerLeg이 -100° 회전했을 때의 끝점 방향
		var lower_leg_end_offset_y = -cos(lower_leg_rotation_rad) * lower_leg_half_length
		var lower_leg_end_offset_z = -sin(lower_leg_rotation_rad) * lower_leg_half_length

		# 최종 Ski 위치 = LowerLeg position + 끝점 오프셋
		var target_ski_y = lower_leg_pos_y + lower_leg_end_offset_y
		var target_ski_z = lower_leg_pos_z + lower_leg_end_offset_z + 0.1  # 원래 Z 오프셋 유지

		left_ski.position.y = lerp(left_ski.position.y, target_ski_y, lerp_factor)
		left_ski.position.z = lerp(left_ski.position.z, target_ski_z, lerp_factor)
		right_ski.position.y = lerp(right_ski.position.y, target_ski_y, lerp_factor)
		right_ski.position.z = lerp(right_ski.position.z, target_ski_z, lerp_factor)

		# Ski를 LowerLeg와 수직으로 회전
		# LowerLeg -100° + 90° (수직) = -10°
		var target_ski_rotation_x = -140.0 * intensity

		left_ski.rotation_degrees.x = lerp(left_ski.rotation_degrees.x, target_ski_rotation_x, lerp_factor)
		right_ski.rotation_degrees.x = lerp(right_ski.rotation_degrees.x, target_ski_rotation_x, lerp_factor)

	# 디버그 출력 (intensity가 변할 때만)
	if abs(intensity - tail_grab_intensity) > 0.05:
		print("[Tail Grab] Pose intensity: %.2f" % intensity)


## Helper functions (from v2)

func _calculate_jump_boost() -> float:
	var jump_vel = JUMP_VELOCITY
	var speed_ratio = current_speed / MAX_SPEED
	jump_vel += speed_ratio * JUMP_SPEED_BOOST_MAX

	var on_ramp = _detect_ramp_peak()
	if on_ramp:
		jump_vel *= JUMP_RAMP_BOOST
		print("[Player] Jump ramp boost! velocity: %.1f m/s" % jump_vel)

	return jump_vel


func _detect_ramp_peak() -> bool:
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = global_position + Vector3.DOWN * 2.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var ground_normal = result.get("normal", Vector3.UP)
	var forward_dir = -transform.basis.z
	var slope_dot = ground_normal.dot(forward_dir)

	if slope_dot < -0.3:
		return true

	return false


func _get_height_above_ground() -> float:
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = global_position + Vector3.DOWN * 50.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return 999.0

	var ground_point = result.get("position", global_position)
	var height = global_position.y - ground_point.y

	return height


func _calculate_trick_score() -> void:
	if not trick_in_progress:
		return

	var total_rotation_abs = abs(trick_rotation_x_total)
	var num_rotations = floor(total_rotation_abs / 360.0)

	if num_rotations == 0:
		print("[Trick] Incomplete rotation (%.1f°), no score" % total_rotation_abs)
		return

	var rotation_remainder = fmod(total_rotation_abs, 360.0)
	var landing_error = min(rotation_remainder, 360.0 - rotation_remainder)

	const LANDING_TOLERANCE = 30.0
	const PERFECT_LANDING_TOLERANCE = 10.0

	if landing_error > LANDING_TOLERANCE:
		print("[Trick] FAILED! Rotation error: %.1f° (need ±%.0f°)" % [landing_error, LANDING_TOLERANCE])
		return

	var base_score = 0
	match num_rotations:
		1: base_score = 100
		2: base_score = 250
		3: base_score = 450
		_: base_score = 450 + (num_rotations - 3) * 250

	var bonus = 0
	if landing_error <= PERFECT_LANDING_TOLERANCE:
		bonus = 50
		print("[Trick] ✨ PERFECT LANDING! ✨")

	trick_score = base_score + bonus
	total_score += trick_score

	var trick_full_name = ""
	if num_rotations == 1:
		trick_full_name = current_trick
	elif num_rotations == 2:
		trick_full_name = "Double " + current_trick
	elif num_rotations == 3:
		trick_full_name = "Triple " + current_trick
	else:
		trick_full_name = str(num_rotations) + "x " + current_trick

	print("[Trick] SUCCESS! %s (%.1f°)" % [trick_full_name, total_rotation_abs])
	print("  → Score: +%d pts (base: %d, bonus: %d)" % [trick_score, base_score, bonus])
	print("  → Total Score: %d pts" % total_score)

	trick_performed.emit(trick_full_name)


## Animation helper functions (from v2)

func _update_breathing_cycle(delta: float) -> void:
	breathing_phase = fmod(breathing_phase + delta * BREATHING_CYCLE_SPEED * TAU, TAU)

	var breathing_amplitude = 3.0
	var breathing_torso = sin(breathing_phase) * breathing_amplitude
	torso.rotation_degrees.x = current_upper_lean + breathing_torso

	var arm_phase_offset = breathing_phase + PI * 0.5
	var arm_idle_swing = sin(arm_phase_offset) * 5.0
	# Arms horizontal at sides (0°), not following torso lean
	left_arm.rotation_degrees.x = 0.0 + arm_idle_swing
	right_arm.rotation_degrees.x = 0.0 - arm_idle_swing


func _update_arm_swing(delta: float) -> void:
	arm_swing_phase += delta * ARM_SWING_SPEED * TAU
	if arm_swing_phase >= TAU:
		arm_swing_phase -= TAU

	var push_intensity = (sin(arm_swing_phase) + 1.0) * 0.5

	var left_arm_angle = lerp(-30.0, -45.0, push_intensity)
	left_arm.rotation_degrees.x = left_arm_angle

	var right_arm_angle = lerp(-30.0, -45.0, 1.0 - push_intensity)
	right_arm.rotation_degrees.x = right_arm_angle


func _apply_weight_shift(turn_direction: float, delta: float) -> void:
	var target_torso_x = turn_direction * 0.03
	var target_torso_y_rot = -turn_direction * 10.0

	torso.position.x = lerp(torso.position.x, target_torso_x, ANIMATION_SPEED * delta)
	torso.rotation_degrees.y = lerp(torso.rotation_degrees.y, target_torso_y_rot, ANIMATION_SPEED * delta)

	if turn_direction < 0:
		right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, -6.0, ANIMATION_SPEED * delta)
		left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, -3.0, ANIMATION_SPEED * delta)
	elif turn_direction > 0:
		left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, 6.0, ANIMATION_SPEED * delta)
		right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, 3.0, ANIMATION_SPEED * delta)


func _reset_weight_shift(delta: float) -> void:
	torso.position.x = lerp(torso.position.x, 0.0, ANIMATION_SPEED * delta)
	torso.rotation_degrees.y = lerp(torso.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	left_leg.rotation_degrees.z = lerp(left_leg.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)
	right_leg.rotation_degrees.z = lerp(right_leg.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)


func _update_ski_stance(is_braking: bool, delta: float) -> void:
	if current_speed < SKATING_SPEED_THRESHOLD and not is_braking:
		return

	var target_ski_rotation_x = 0.0
	var target_ski_spacing = 0.15

	if is_braking:
		target_ski_rotation_x = 15.0
		target_ski_spacing = 0.25

	var current_leg_spacing = left_leg.position.x
	var new_spacing = lerp(abs(current_leg_spacing), target_ski_spacing, ANIMATION_SPEED * delta)

	left_leg.position.x = -new_spacing
	right_leg.position.x = new_spacing

	if is_braking:
		var current_ski_rot = left_ski.rotation_degrees.y
		var new_ski_rot = lerp(abs(current_ski_rot), target_ski_rotation_x, ANIMATION_SPEED * delta)
		left_ski.rotation_degrees.y = -new_ski_rot
		right_ski.rotation_degrees.y = new_ski_rot


func _apply_ski_carving(ski_yaw_deg: float, delta: float) -> void:
	# Negate to match Godot's Y-rotation convention
	# Godot: +Y = left, -Y = right
	# Input: left turn = negative steer_yaw, right turn = positive steer_yaw
	left_ski.rotation_degrees.y = -ski_yaw_deg
	right_ski.rotation_degrees.y = -ski_yaw_deg

	var ski_roll_deg = ski_yaw_deg * 0.3
	ski_roll_deg = clamp(ski_roll_deg, -SKI_ROLL_MAX, SKI_ROLL_MAX)

	if ski_yaw_deg < 0:
		left_ski.rotation_degrees.z = ski_roll_deg * 1.5
		right_ski.rotation_degrees.z = ski_roll_deg
	elif ski_yaw_deg > 0:
		right_ski.rotation_degrees.z = ski_roll_deg * 1.5
		left_ski.rotation_degrees.z = ski_roll_deg
	else:
		left_ski.rotation_degrees.z = 0.0
		right_ski.rotation_degrees.z = 0.0


func _reset_ski_carving(delta: float) -> void:
	left_ski.rotation_degrees.y = lerp(left_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	right_ski.rotation_degrees.y = lerp(right_ski.rotation_degrees.y, 0.0, ANIMATION_SPEED * delta)
	left_ski.rotation_degrees.z = lerp(left_ski.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)
	right_ski.rotation_degrees.z = lerp(right_ski.rotation_degrees.z, 0.0, ANIMATION_SPEED * delta)


func _update_velocity_heading(delta: float) -> void:
	var ski_yaw_rad = deg_to_rad(-steer_yaw)
	var target_heading = rotation.y + ski_yaw_rad
	velocity_heading = lerp_angle(velocity_heading, target_heading, VELOCITY_HEADING_LERP)


func _update_body_yaw_follow(delta: float) -> void:
	var target_body_yaw = deg_to_rad(steer_yaw * BODY_YAW_FOLLOW)
	body.rotation.y = lerp_angle(body.rotation.y, target_body_yaw, ANIMATION_SPEED * delta)


## Camera and UI functions (from v2)

## 플레이어 입력 처리
## Note: _unhandled_input() 사용으로 GUI 입력 우선권 보장
## GUI(버튼, TextEdit 등)가 먼저 처리하고, 처리 안 된 입력만 여기로 옴
## 이렇게 하면 UI 버튼 클릭 시 Player가 입력을 가로채지 않음
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		camera_mode = (camera_mode + 1) % 4
		_apply_camera_mode()
		camera_mode_changed.emit(_get_camera_mode_name())

	if event.is_action_pressed("respawn"):
		respawn()

	if event.is_action_pressed("toggle_body_visibility"):
		hide_body_in_first_person = !hide_body_in_first_person
		_update_visibility()


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

	_update_visibility()


func _get_camera_mode_name() -> String:
	match camera_mode:
		0: return "3인칭 (뒤)"
		1: return "3인칭 (앞)"
		2: return "1인칭"
		3: return "프리 카메라"
		_: return "알 수 없음"


func _update_visibility() -> void:
	var is_first_person = (camera_mode == 2)

	if left_eye and right_eye:
		left_eye.visible = !is_first_person
		right_eye.visible = !is_first_person

	if head:
		head.visible = !is_first_person

	# Hide helmet in first-person
	if player_customization:
		player_customization.update_helmet_visibility(is_first_person)

	if is_first_person and hide_body_in_first_person:
		if torso:
			torso.visible = false
		# Hide arms, legs (implementation same as v2)
	else:
		if torso:
			torso.visible = true
		# Show arms, legs (implementation same as v2)


func _on_camera_mode_changed(mode_name: String) -> void:
	if camera_mode_label:
		camera_mode_label.text = "카메라: " + mode_name


func _update_speed_ui() -> void:
	if speed_label:
		var skating_status = "OFF"
		if current_speed < SKATING_SPEED_THRESHOLD and Input.is_action_pressed("move_forward"):
			skating_status = "ON"

		speed_label.text = "V3 | 속도: %.1f m/s | 스케이팅: %s (< %.1f)" % [current_speed, skating_status, SKATING_SPEED_THRESHOLD]


func _update_air_rotation_ui() -> void:
	if air_rotation_label:
		# Only show when in air (JUMP or FLIP state)
		if state == PlayerState.JUMP or state == PlayerState.FLIP:
			# Calculate body tilt angle (dot product → degrees)
			# Use body.transform to track the rotating Body node, not the static CharacterBody3D
			var player_up = body.transform.basis.y
			var ground_up = Vector3.UP
			var dot = player_up.dot(ground_up)
			var tilt_angle = rad_to_deg(acos(clamp(dot, -1.0, 1.0)))

			# Get pitch and roll from body rotation
			var pitch = body.rotation_degrees.x
			var roll = body.rotation_degrees.z

			# Update label text and make visible
			air_rotation_label.text = "Tilt: %.1f° | Pitch: %.1f° | Roll: %.1f°" % [tilt_angle, pitch, roll]
			air_rotation_label.visible = true
			air_rotation_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
		else:
			# Hide when not in air
			air_rotation_label.visible = false


func set_trick_mode(enabled: bool) -> void:
	trick_mode_enabled = enabled

	if trick_mode_enabled:
		velocity_heading = rotation.y
	else:
		steer_yaw = 0.0
		velocity_heading = rotation.y

	trick_mode_changed.emit(trick_mode_enabled)


func respawn() -> void:
	global_position = spawn_position
	rotation.y = spawn_rotation
	velocity = Vector3.ZERO
	current_speed = 0.0
	skating_phase = 0.0
	breathing_phase = 0.0
	arm_swing_phase = 0.0
	edge_chatter_phase = 0.0

	steer_yaw = 0.0
	velocity_heading = rotation.y

	_reset_body_pose()
	set_state(PlayerState.IDLE)

	print("Player (V3) respawned at: ", spawn_position)


func _enable_player_shadows() -> void:
	var mesh_nodes = []

	if head and head is MeshInstance3D:
		mesh_nodes.append(head)
	if torso and torso is MeshInstance3D:
		mesh_nodes.append(torso)

	# Arms and poles
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

	if left_ski and left_ski is MeshInstance3D:
		mesh_nodes.append(left_ski)
	if right_ski and right_ski is MeshInstance3D:
		mesh_nodes.append(right_ski)

	for node in mesh_nodes:
		if node:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	print("[Player V3] Shadows enabled for %d meshes" % mesh_nodes.size())


## Ski track collision detection setup
func _setup_body_part_collision_detection():
	var body_parts = [
		"Body/Head",
		"Body/Torso",
		"Body/LeftArm/UpperArm",
		"Body/RightArm/UpperArm",
		"Body/LeftLeg/UpperLeg",
		"Body/LeftLeg/LowerLeg",
		"Body/LeftLeg/Ski",
		"Body/RightLeg/UpperLeg",
		"Body/RightLeg/LowerLeg",
		"Body/RightLeg/Ski"
	]

	for part_path in body_parts:
		if has_node(part_path):
			var part_node = get_node(part_path)
			_add_collision_area_to_part(part_node, part_path)

func _add_collision_area_to_part(part: Node3D, part_name: String):
	var area = Area3D.new()
	area.name = "CollisionDetector"
	area.collision_layer = 0
	area.collision_mask = 2  # Terrain layer

	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()

	# Extract mesh size automatically
	var mesh_size = _get_mesh_size(part)
	shape.size = mesh_size

	collision_shape.shape = shape
	area.add_child(collision_shape)

	# DEBUG: Visualize collision box with red mesh (only in test mode)
	if TestModeManager.test_mode_enabled:
		var debug_mesh = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = mesh_size
		debug_mesh.mesh = box_mesh

		var debug_material = StandardMaterial3D.new()
		debug_material.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Red, semi-transparent
		debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
		debug_mesh.material_override = debug_material

		area.add_child(debug_mesh)

	# Connect signals
	area.body_entered.connect(_on_body_part_touched_ground.bind(part, part_name))
	area.body_exited.connect(_on_body_part_left_ground.bind(part_name))

	part.add_child(area)

	print("[Player] Collision area added to: ", part_name, " size: ", mesh_size)

func _get_mesh_size(node: Node3D) -> Vector3:
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh is PrismMesh:  # Skis
			return mesh.size
		elif mesh is SphereMesh:  # Head
			var radius = mesh.radius
			return Vector3(radius * 2, radius * 2, radius * 2)
		elif mesh is CapsuleMesh:  # Torso, Arms, Legs
			var radius = mesh.radius
			var height = mesh.height
			return Vector3(radius * 2, height, radius * 2)

	return Vector3(0.3, 0.3, 0.3)  # Default fallback

func _on_body_part_touched_ground(body: Node, part: Node3D, part_name: String):
	if body.is_in_group("terrain"):
		touching_parts[part_name] = part

func _on_body_part_left_ground(body: Node, part_name: String):
	if body.is_in_group("terrain"):
		touching_parts.erase(part_name)
		print("[충돌종료] part_name: ", part_name, " | Remaining: ", touching_parts.keys())

func _create_tracks_for_touching_parts():
	# Only create tracks when player is moving
	const MIN_TRACK_SPEED = 0.5  # m/s (prevent tracks when stationary)

	if current_speed < MIN_TRACK_SPEED:
		return  # Not moving, don't create tracks

	for part_name in touching_parts:
		var part = touching_parts[part_name]
		var mesh_size = _get_mesh_size(part)

		# Calculate track position (default: center of part)
		var track_position = part.global_position

		# Offset to ski edge AND tail for Ski parts only
		if part_name.contains("Ski"):
			# Get ski's roll angle to determine which edge is touching ground
			var ski_roll_rad = part.rotation.z
			var ski_width = mesh_size.x  # 0.15m

			# Calculate edge offset (left edge or right edge based on roll)
			# Positive roll = right edge down, negative roll = left edge down
			var ski_right_dir = part.global_transform.basis.x
			var edge_offset = ski_right_dir * (ski_width * 0.5) * sign(ski_roll_rad)

			# Calculate tail offset (backward along ski's actual direction)
			var ski_backward_dir = part.global_transform.basis.z
			var ski_length = mesh_size.z  # 1.2m
			var tail_offset = ski_backward_dir * (ski_length * 0.5)

			# Apply both offsets
			track_position = part.global_position + edge_offset + tail_offset

		# DEBUG_TRACK - Remove after testing
		print("[자국생성] part_name: ", part_name)
		print("[자국생성] track_position: ", track_position)
		# END DEBUG_TRACK

		if ski_tracks:
			ski_tracks.create_track_at_position(
				track_position,
				mesh_size,
				part_name
			)
