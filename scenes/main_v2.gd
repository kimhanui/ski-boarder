extends Node3D

## Main scene controller V2 - Enhanced shadow rendering + Trick System
## Manages terrain regeneration with optimized shadow settings

@onready var player: CharacterBody3D = $Player
@onready var procedural_slope: Node3D = $ProceduralSlope
@onready var difficulty_selector: Control = $UI/DifficultySelector
@onready var minimap: Control = $UI/Minimap
@onready var density_controls: VBoxContainer = $UI/DensityControls
@onready var trick_score_display: Control = $UI/TrickScoreDisplay
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	# Force DirectionalLight3D shadow settings with enhanced configuration
	_enforce_shadow_settings_v2()

	# Enable player mesh shadows
	_enable_player_shadows()

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
		print("[MainV2] Trick score display connected to player")

	print("[MainV2] Scene initialized with enhanced shadow rendering and trick system")
	print("Press F1 to cycle camera modes")


## V2: Enhanced shadow settings with optimal configuration
func _enforce_shadow_settings_v2() -> void:
	if directional_light:
		# Enable shadows with maximum quality
		directional_light.shadow_enabled = true
		directional_light.shadow_opacity = 1.0  # Full shadow opacity
		directional_light.shadow_bias = 0.08  # Reduced for sharper shadows
		directional_light.shadow_normal_bias = 1.2  # Prevent shadow acne

		# PSSM (Parallel Split Shadow Map) for better distance shadows
		directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		directional_light.directional_shadow_split_1 = 0.1
		directional_light.directional_shadow_blend_splits = true

		# Extended shadow distance
		directional_light.directional_shadow_max_distance = 3000.0
		directional_light.directional_shadow_fade_start = 0.75

		# Increase light energy for better contrast
		directional_light.light_energy = 1.8

		print("[MainV2] Enhanced shadow settings applied:")
		print("  - Shadow enabled: %s" % directional_light.shadow_enabled)
		print("  - Shadow opacity: %.1f" % directional_light.shadow_opacity)
		print("  - Shadow bias: %.2f" % directional_light.shadow_bias)
		print("  - Light energy: %.1f" % directional_light.light_energy)
		print("  - Shadow mode: PARALLEL_4_SPLITS")


## Enable shadows for player meshes (runtime configuration)
func _enable_player_shadows() -> void:
	if not player:
		return

	# Call player's shadow enable function if it exists
	if player.has_method("_enable_player_shadows"):
		player._enable_player_shadows()
		print("[MainV2] Player shadows enabled via player method")
	else:
		# Fallback: manually enable shadows for all MeshInstance3D children
		var mesh_count = 0
		for child in _get_all_children(player):
			if child is MeshInstance3D:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mesh_count += 1

		print("[MainV2] Player shadows enabled manually: %d meshes" % mesh_count)


## Recursively get all children of a node
func _get_all_children(node: Node) -> Array[Node]:
	var children: Array[Node] = []
	for child in node.get_children():
		children.append(child)
		children.append_array(_get_all_children(child))
	return children


func _on_difficulty_changed(new_difficulty: String) -> void:
	print("[MainV2] Difficulty changed to: %s" % new_difficulty)


func _on_regenerate_requested() -> void:
	print("[MainV2] Regenerating terrain with enhanced shadow settings...")

	# Get current difficulty from UI
	var current_difficulty = difficulty_selector.get_current_difficulty()

	# Regenerate terrain
	procedural_slope.regenerate_terrain(current_difficulty)

	# Re-enforce shadow settings after terrain regeneration
	_enforce_shadow_settings_v2()

	print("[MainV2] Terrain regeneration complete!")
