extends Node3D

## Main scene controller
## Manages terrain regeneration

@onready var player: CharacterBody3D = $Player
@onready var procedural_slope: Node3D = $ProceduralSlope
@onready var difficulty_selector: Control = $UI/DifficultySelector
@onready var minimap: Control = $UI/Minimap
@onready var density_controls: VBoxContainer = $UI/DensityControls
@onready var trick_score_display: Control = $UI/TrickScoreDisplay
@onready var trick_mode_button: Button = $UI/TrickModeButton
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var light_control: VBoxContainer = $UI/LightControl
@onready var free_camera: Camera3D = $FreeCamera


func _ready() -> void:
	# Force DirectionalLight3D shadow settings (prevent Godot editor from removing them)
	_enforce_shadow_settings()

	# Connect UI signals
	if difficulty_selector:
		difficulty_selector.difficulty_changed.connect(_on_difficulty_changed)
		difficulty_selector.regenerate_requested.connect(_on_regenerate_requested)

	# Get ObstacleFactory reference
	var obstacle_factory = null
	if procedural_slope:
		obstacle_factory = procedural_slope.get_node_or_null("ObstacleFactory")

	# Connect Minimap to Player and ObstacleFactory
	if minimap and player:
		minimap.player = player
		if obstacle_factory:
			minimap.obstacle_factory = obstacle_factory

	# Connect DensityControls to ObstacleFactory
	if density_controls and obstacle_factory:
		density_controls.obstacle_factory = obstacle_factory

	# Connect TrickScoreDisplay to Player
	if trick_score_display and player:
		trick_score_display.connect_to_player(player)
		print("[Main] Trick score display connected to player")

	# Connect TrickModeButton to Player
	if trick_mode_button and player:
		trick_mode_button.toggled.connect(_on_trick_mode_toggled)
		_update_trick_mode_button_text()
		print("[Main] Trick mode button connected to player")

	# Connect LightControl to DirectionalLight3D and ProceduralSlope
	if light_control and directional_light:
		light_control.set_light(directional_light)
		light_control.set_procedural_slope(procedural_slope)
		print("[Main] Light control connected to directional light and terrain")

	# Player is active by default (normal mode)
	if player:
		player.visible = true
		player.set_physics_process(true)
		player.set_process(true)
		print("[Main] Normal mode: Real player active")

	print("Main scene initialized")
	print("Press F1 to cycle camera modes")
	print("Press L to cycle terrain version (V2/V3 in test mode only)")
	print("Use '지형그림자테스트' button to toggle test mode")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_terrain"):
		_toggle_terrain_version()


func _toggle_terrain_version() -> void:
	if procedural_slope and procedural_slope.has_method("toggle_terrain_version"):
		procedural_slope.toggle_terrain_version()

		# 테스트 모드에서만 카메라 업데이트
		if procedural_slope and procedural_slope.get("shadow_test_mode"):
			var version_names = ["V1 (Procedural)", "V2 (Flat)", "V3 (Bumpy)"]
			print("[Main] Terrain toggled to: %s" % version_names[procedural_slope.terrain_version])
			_update_camera_target()


## Enforce shadow settings at runtime (prevent Godot editor auto-removal)
func _enforce_shadow_settings() -> void:
	if directional_light:
		directional_light.shadow_enabled = true
		directional_light.shadow_opacity = 0.75
		directional_light.shadow_bias = 0.1
		directional_light.shadow_normal_bias = 1.0

		# IMPORTANT: Max distance must be 500m for shadows to render properly
		directional_light.directional_shadow_max_distance = 500.0
		directional_light.directional_shadow_fade_start = 0.8

		# WARNING: DO NOT set light_angular_distance - it causes shadows to disappear!
		# directional_light.light_angular_distance = 0.5  # ← NEVER USE THIS

		print("[Main] Shadow settings enforced: enabled=%s, opacity=%.2f, max_distance=%.0fm" % [
			directional_light.shadow_enabled,
			directional_light.shadow_opacity,
			directional_light.directional_shadow_max_distance
		])


func _on_difficulty_changed(new_difficulty: String) -> void:
	print("[Main] Difficulty changed to: %s" % new_difficulty)
	# Difficulty is set, will be used on next regeneration


func _on_regenerate_requested() -> void:
	print("[Main] Regenerating terrain...")

	# Get current difficulty from UI
	var current_difficulty = difficulty_selector.get_current_difficulty()

	# Regenerate terrain
	procedural_slope.regenerate_terrain(current_difficulty)

	print("[Main] Terrain regeneration complete!")


## Handle trick mode button toggle
func _on_trick_mode_toggled(button_pressed: bool) -> void:
	if player and player.has_method("set_trick_mode"):
		player.set_trick_mode(button_pressed)
		_update_trick_mode_button_text()
		print("[Main] Trick mode toggled: %s" % ("ON" if button_pressed else "OFF"))


## Update trick mode button text
func _update_trick_mode_button_text() -> void:
	if trick_mode_button and player:
		var mode_text = "ON" if player.trick_mode_enabled else "OFF"
		trick_mode_button.text = "트릭 모드: " + mode_text
		trick_mode_button.button_pressed = player.trick_mode_enabled


## Called when shadow test mode is toggled
func _on_shadow_test_mode_changed(enabled: bool) -> void:
	if enabled:
		# 테스트 모드 진입
		print("[Main] Shadow test mode ENABLED")

		# Real player 비활성화
		if player:
			player.visible = false
			player.set_physics_process(false)
			player.set_process(false)

		# 카메라를 dummy로 전환
		_update_camera_target()
	else:
		# 정상 모드 복귀
		print("[Main] Shadow test mode DISABLED")

		# Real player 활성화
		if player:
			player.visible = true
			player.set_physics_process(true)
			player.set_process(true)

		# 카메라를 real player로 복귀
		if free_camera and free_camera.has_method("set_target"):
			free_camera.set_target(null)  # null = fallback to group lookup
			print("[Main] Camera target reset to real player")


## Update camera target to match active terrain's dummy player
func _update_camera_target() -> void:
	if not free_camera or not procedural_slope:
		return

	# 테스트 모드에서만 dummy로 전환
	if procedural_slope and procedural_slope.get("shadow_test_mode"):
		var active_dummy = procedural_slope.get_active_dummy_player()
		if active_dummy and free_camera.has_method("set_target"):
			free_camera.set_target(active_dummy)
			print("[Main] Camera target updated to: %s" % active_dummy.name)
		else:
			push_warning("[Main] Failed to update camera target")
	else:
		# 정상 모드: real player
		if free_camera.has_method("set_target"):
			free_camera.set_target(null)  # Fallback to group lookup
			print("[Main] Camera following real player")
