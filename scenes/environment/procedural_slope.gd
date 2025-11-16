extends Node3D

## Procedural slope scene that loads terrain data and generates the mountain

## Difficulty: "easy", "medium", or "hard". Leave empty to use JSON data.
@export var difficulty: String = "medium"

## Random seed for procedural generation. Use -1 for random seed each time.
@export var random_seed: int = -1

## Terrain version: 0=V1 (Procedural), 1=V2 (Flat), 2=V3 (Bumpy)
@export_enum("V1 (Procedural)", "V2 (Flat)", "V3 (Bumpy)") var terrain_version: int = 0

## Optional JSON file path. If difficulty is set, this is ignored and terrain is generated procedurally.
@export var slope_data_path: String = "res://resources/slope_data.json"

var _current_terrain_root: Node3D = null


func _ready() -> void:
	_load_and_build_terrain()

	# Initialize ObstacleFactory
	var obstacle_factory = get_node_or_null("ObstacleFactory")
	if obstacle_factory:
		# Set normal density by default
		obstacle_factory.call_deferred("set_obstacle_density", "normal")


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

	# Generate terrain using appropriate generator
	print("=" .repeat(60))
	print("TERRAIN GENERATION START")
	var version_names = ["V1 (Procedural)", "V2 (Flat)", "V3 (Bumpy)"]
	print("  Version: %s" % version_names[terrain_version])
	print("  Difficulty: %s" % (difficulty if not difficulty.is_empty() else "JSON-based"))
	print("  Random Seed: %d" % random_seed)
	print("=" .repeat(60))

	var terrain_root: Node3D
	match terrain_version:
		0:  # V1: Procedural slope terrain
			print("Using TerrainGenerator (procedural terrain)")
			terrain_root = TerrainGenerator.apply_slope_data(data, difficulty, random_seed)
		1:  # V2: Flat terrain
			print("Using TerrainGeneratorV2 (flat terrain)")
			terrain_root = TerrainGeneratorV2.create_flat_terrain()
		2:  # V3: Bumpy terrain
			print("Using TerrainGeneratorV3 (bumpy terrain)")
			terrain_root = TerrainGeneratorV3.create_bumpy_terrain()
		_:
			print("ERROR: Invalid terrain_version: %d" % terrain_version)
			terrain_root = TerrainGenerator.apply_slope_data(data, difficulty, random_seed)

	# Store reference to current terrain
	if _current_terrain_root:
		_current_terrain_root.queue_free()
	_current_terrain_root = terrain_root
	add_child(terrain_root)

	# Auto-position player at start point
	_position_player_at_start(data, difficulty)

	# Create test obstacles for debugging (V2 only)
	_create_test_obstacles()

	# Create player clone for shadow testing
	_create_player_clone_for_testing()

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
	# Move player slightly 	into the slope (negative Z) to ensure they're on terrain
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


## Toggle between V1 (procedural), V2 (flat), and V3 (bumpy) terrain
func toggle_terrain_version() -> void:
	terrain_version = (terrain_version + 1) % 3

	var version_names = ["V1 (Procedural)", "V2 (Flat)", "V3 (Bumpy)"]
	print("\n" + "=".repeat(60))
	print("TOGGLING TERRAIN VERSION")
	print("  New version: %s" % version_names[terrain_version])
	print("=".repeat(60) + "\n")

	_load_and_build_terrain()


## Create test obstacles for shadow testing (near player spawn, all terrains)
func _create_test_obstacles() -> void:
	print("\n[ProceduralSlope] Creating test obstacles...")

	var obstacle_factory = get_node_or_null("ObstacleFactory")
	if not obstacle_factory:
		print("[ProceduralSlope] ObstacleFactory not found")
		return

	var player = get_parent().get_node_or_null("Player")
	if not player:
		print("[ProceduralSlope] Player not found")
		return

	var player_pos = player.global_position
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Obstacle height offsets (from center to bottom)
	const TREE_OFFSET = 2.5
	const ROCK_OFFSET = 0.7

	# Helper function to get ground Y at position
	var get_ground_y = func(x: float, z: float) -> float:
		if terrain_version == 1:
			return 0.0  # V2: Flat terrain
		else:
			# V1 and V3: Raycast to find ground
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
				Vector3(x, player_pos.y + 10, z),
				Vector3(x, player_pos.y - 500, z)
			)
			query.collision_mask = 2  # Terrain layer
			var result = space_state.intersect_ray(query)
			return result.position.y if result else 0.0

	# Tree: 5m right, 10m forward, bottom at 100cm above terrain
	var tree_pos = Vector3(player_pos.x + 5.0, 0, player_pos.z - 10.0)
	var tree_ground_y = get_ground_y.call(tree_pos.x, tree_pos.z)
	var tree = obstacle_factory._create_obstacle_scene("tree", rng)
	tree.name = "TestTree"
	tree.global_position = Vector3(tree_pos.x, tree_ground_y + 1.0 + TREE_OFFSET, tree_pos.z)
	tree.rotate_y(rng.randf() * TAU)
	obstacle_factory.add_child(tree)

	# Add label to tree
	_add_test_label(tree, "TEST", tree_ground_y + 1.0 + TREE_OFFSET + 3.0)

	# Rock: 5m left, 10m forward, bottom at 100cm above terrain
	var rock_pos = Vector3(player_pos.x - 5.0, 0, player_pos.z - 10.0)
	var rock_ground_y = get_ground_y.call(rock_pos.x, rock_pos.z)
	var rock = obstacle_factory._create_obstacle_scene("rock", rng)
	rock.name = "TestRock"
	rock.global_position = Vector3(rock_pos.x, rock_ground_y + 1.0 + ROCK_OFFSET, rock_pos.z)
	rock.rotate_y(rng.randf() * TAU)
	obstacle_factory.add_child(rock)

	# Add label to rock
	_add_test_label(rock, "TEST", rock_ground_y + 1.0 + ROCK_OFFSET + 1.5)

	print("[ProceduralSlope] Test obstacles created:")
	print("  Tree: ", tree.global_position)
	print("  Rock: ", rock.global_position)


## Create a static clone of the player model at spawn position for shadow testing
func _create_player_clone_for_testing() -> void:
	print("\n[ProceduralSlope] Creating player clone for shadow testing...")

	var player = get_parent().get_node_or_null("Player")
	if not player:
		print("[ProceduralSlope] Player not found")
		return

	var player_pos = player.global_position

	# Load player scene to get mesh structure
	var player_scene = load("res://scenes/player/player.tscn")
	if not player_scene:
		print("[ProceduralSlope] Could not load player.tscn")
		return

	# Instantiate a copy of the player
	var player_clone = player_scene.instantiate()
	player_clone.name = "PlayerCloneForTesting"

	# Calculate ground position (skis at 100cm above terrain)
	# Player skis are at origin - 0.965m, so origin must be higher
	const PLAYER_BOTTOM_OFFSET = 0.965  # Distance from origin to skis
	var clone_y_position: float
	var ground_y: float
	if terrain_version == 1:
		# V2: Flat terrain at Y=0
		# To place skis at 100cm: origin_y = 1.0 + 0.965 = 1.965m
		ground_y = 0.0
		clone_y_position = 1.0 + PLAYER_BOTTOM_OFFSET
	else:
		# V1 and V3: Use raycast to find ground, then add 100cm + player offset
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			Vector3(player_pos.x, player_pos.y + 10, player_pos.z),
			Vector3(player_pos.x, player_pos.y - 500, player_pos.z)
		)
		query.collision_mask = 2  # Terrain layer
		var result = space_state.intersect_ray(query)

		if result:
			ground_y = result.position.y
			clone_y_position = ground_y + 1.0 + PLAYER_BOTTOM_OFFSET
		else:
			ground_y = player_pos.y - 5.0
			clone_y_position = ground_y + 1.0 + PLAYER_BOTTOM_OFFSET  # Fallback

	# Position the clone
	player_clone.global_position = Vector3(player_pos.x, clone_y_position, player_pos.z)

	# Add label to player clone
	_add_test_label(player_clone, "TEST", clone_y_position + 1.5)

	# Disable physics and scripts on clone (make it static)
	if player_clone.has_method("set_physics_process"):
		player_clone.set_physics_process(false)
	if player_clone.has_method("set_process"):
		player_clone.set_process(false)

	# Remove script to prevent any behavior
	player_clone.set_script(null)

	# Add to scene
	add_child(player_clone)

	print("[ProceduralSlope] Player clone created at: ", player_clone.global_position)
	print("  Ground level clone for shadow comparison")


## Add a 3D text label to a test object
func _add_test_label(parent: Node3D, text: String, y_position: float) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 8
	label.modulate = Color(1.0, 1.0, 0.0)  # Yellow
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.global_position = Vector3(parent.global_position.x, y_position, parent.global_position.z)
	add_child(label)
