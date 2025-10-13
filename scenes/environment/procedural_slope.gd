extends Node3D

## Procedural slope scene that loads terrain data and generates the mountain

## Difficulty: "easy", "medium", or "hard". Leave empty to use JSON data.
@export var difficulty: String = "medium"

## Random seed for procedural generation. Use -1 for random seed each time.
@export var random_seed: int = -1

## Optional JSON file path. If difficulty is set, this is ignored and terrain is generated procedurally.
@export var slope_data_path: String = "res://resources/slope_data.json"

var _current_terrain_root: Node3D = null


func _ready() -> void:
	_load_and_build_terrain()


func _load_and_build_terrain() -> void:
	var data: Dictionary = {}

	# If using procedural generation (difficulty is set)
	if not difficulty.is_empty():
		print("Using procedural generation with difficulty: %s" % difficulty)
		# Pass empty dictionary - TerrainGenerator will handle everything
		data = {
			"terrain": {"origin": [0, 0, 0]},
			"path_spline": {},
			"obstacles": [],
			"checkpoints": []
		}
	else:
		# Load from JSON file
		var file = FileAccess.open(slope_data_path, FileAccess.READ)
		if not file:
			push_error("Failed to load slope data from: " + slope_data_path)
			return

		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error != OK:
			push_error("Failed to parse slope data JSON: " + json.get_error_message())
			return

		data = json.data
		if not data is Dictionary:
			push_error("Slope data is not a valid dictionary")
			return

	# Generate terrain using TerrainGenerator
	print("=" .repeat(60))
	print("TERRAIN GENERATION START")
	print("  Difficulty: %s" % (difficulty if not difficulty.is_empty() else "JSON-based"))
	print("  Random Seed: %d" % random_seed)
	print("=" .repeat(60))

	var terrain_root = TerrainGenerator.apply_slope_data(data, difficulty, random_seed)

	# Store reference to current terrain
	if _current_terrain_root:
		_current_terrain_root.queue_free()
	_current_terrain_root = terrain_root
	add_child(terrain_root)

	# Auto-position player at start point
	_position_player_at_start(data, difficulty)

	print("=" .repeat(60))
	print("TERRAIN GENERATION COMPLETE")
	print("  Metadata: ", data.get("meta", {}))
	print("=" .repeat(60))


func _position_player_at_start(data: Dictionary, diff: String) -> void:
	# For procedural generation, calculate start position from config
	var start_point: Array

	if not diff.is_empty():
		# Procedural: use config to get start height
		var config = DifficultyConfig.get_config(diff)
		start_point = [0, config.vertical_drop, -20]
		print("Calculated procedural start point: [%.1f, %.1f, %.1f]" % [start_point[0], start_point[1], start_point[2]])
	else:
		# JSON: get from path spline data
		var path_data = data.get("path_spline", {})
		var points = path_data.get("points", [])

		if points.is_empty():
			push_warning("No path points found, cannot position player")
			return

		start_point = points[0]
		print("Using JSON start point: [%.1f, %.1f, %.1f]" % [start_point[0], start_point[1], start_point[2]])

	# Find player node in parent (Main scene)
	var player = get_parent().get_node_or_null("Player")
	if not player:
		push_warning("Player node not found in parent scene")
		return

	# Position player above start point with some clearance
	# Move player slightly into the slope (negative Z) to ensure they're on terrain
	var spawn_position = Vector3(start_point[0], start_point[1] + 5.0, start_point[2] - 10.0)
	player.global_position = spawn_position

	print("Player positioned at start: ", spawn_position)


## Regenerate terrain with new difficulty setting
func regenerate_terrain(new_difficulty: String = "") -> void:
	print("\n" + "!".repeat(60))
	print("REGENERATING TERRAIN")
	print("  Previous difficulty: %s" % difficulty)
	print("  New difficulty: %s" % new_difficulty)
	print("!".repeat(60) + "\n")

	# Update difficulty if provided
	if not new_difficulty.is_empty():
		difficulty = new_difficulty

	# Generate new random seed for different terrain
	random_seed = -1

	# Rebuild terrain
	_load_and_build_terrain()
