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

# Store all 3 terrain versions (keep them all, just toggle visibility)
var _terrain_v1: Node3D = null
var _terrain_v2: Node3D = null
var _terrain_v3: Node3D = null

# Shadow test mode (V2/V3 with dummies) vs normal mode (V1 with real player)
var shadow_test_mode: bool = false

# Test mode objects (created/destroyed on mode toggle)
var _test_dummy_player: CharacterBody3D = null
var _test_obstacles: Array[Node3D] = []


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

	# Generate all 3 terrains if they don't exist (only once)
	if not _terrain_v1:
		print("=== Generating V1 (Procedural) Terrain ===")
		_terrain_v1 = TerrainGenerator.apply_slope_data(data, difficulty, random_seed)
		_terrain_v1.name = "TerrainV1"
		add_child(_terrain_v1)
		print("V1 terrain created")

	if not _terrain_v2:
		print("=== Generating V2 (Flat) Terrain ===")
		_terrain_v2 = TerrainGeneratorV2.create_flat_terrain()
		_terrain_v2.name = "TerrainV2"
		add_child(_terrain_v2)
		print("V2 terrain created")

	if not _terrain_v3:
		print("=== Generating V3 (Bumpy) Terrain ===")
		_terrain_v3 = TerrainGeneratorV3.create_bumpy_terrain()
		_terrain_v3.name = "TerrainV3"
		add_child(_terrain_v3)
		print("V3 terrain created")

	# Show only the current terrain version
	_show_active_terrain()

	# Position player at start point of active terrain
	_position_player_at_start(data, difficulty)

	print("=" .repeat(60))
	print("TERRAIN SETUP COMPLETE")
	var version_names = ["V1 (Procedural)", "V2 (Flat)", "V3 (Bumpy)"]
	print("  Active version: %s" % version_names[terrain_version])
	print("  Mode: %s" % ("Shadow Test" if shadow_test_mode else "Normal"))
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


## Show only the active terrain, hide others
func _show_active_terrain() -> void:
	if not shadow_test_mode:
		# Normal mode: V1만 표시
		if _terrain_v1:
			_terrain_v1.visible = true
		if _terrain_v2:
			_terrain_v2.visible = false
		if _terrain_v3:
			_terrain_v3.visible = false
		print("[ProceduralSlope] Normal mode: V1 active")
	else:
		# Shadow test mode: V2/V3만 토글
		if _terrain_v1:
			_terrain_v1.visible = false
		if _terrain_v2:
			_terrain_v2.visible = (terrain_version == 1)
		if _terrain_v3:
			_terrain_v3.visible = (terrain_version == 2)

		var version_names = {1: "V2", 2: "V3"}
		print("[ProceduralSlope] Test mode: %s active" % version_names.get(terrain_version, "Unknown"))


## Get terrain start position (consistent across V1/V2/V3)
func _get_terrain_start_position() -> Vector3:
	# All terrains are aligned at origin (0, 0, 0) with same Z range (+50 to -1450)
	# Calculate start position based on difficulty config
	if not difficulty.is_empty():
		var config = DifficultyConfig.get_config(difficulty)
		# Player spawns 5m above terrain, 10m back from front edge
		return Vector3(0.0, config.vertical_drop + 5.0, -20.0 - 10.0)
	else:
		# Fallback for JSON mode (not used currently)
		return Vector3(0.0, 50.0, -20.0)


## Get active dummy player (for camera targeting)
func get_active_dummy_player() -> CharacterBody3D:
	return _test_dummy_player  # 공통 dummy 반환


## Toggle shadow test mode (V2/V3 with dummies vs V1 with real player)
func set_shadow_test_mode(enabled: bool) -> void:
	shadow_test_mode = enabled

	if enabled:
		# 테스트 모드 진입: V2로 전환
		terrain_version = 1

		# 테스트 객체 생성 (10m 위)
		_create_test_objects()

		print("[ProceduralSlope] Shadow test mode ENABLED - Objects created 10m above terrain")
	else:
		# 정상 모드 복귀: V1로 전환
		terrain_version = 0

		# 테스트 객체 제거
		_remove_test_objects()

		print("[ProceduralSlope] Shadow test mode DISABLED - Objects removed")

	_show_active_terrain()


## Get active terrain node
func _get_active_terrain() -> Node3D:
	if terrain_version == 1:
		return _terrain_v2
	elif terrain_version == 2:
		return _terrain_v3
	return _terrain_v1


## Get terrain ground Y position at (x, z)
func _get_terrain_ground_y(x: float, z: float) -> float:
	if terrain_version == 1:
		return 0.0  # V2: Flat terrain at Y=0
	else:
		# V1/V3: Raycast to find ground
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			Vector3(x, 100, z),
			Vector3(x, -500, z)
		)
		query.collision_mask = 2  # Terrain layer
		var result = space_state.intersect_ray(query)
		return result.position.y if result else 0.0


## Create test objects 10m above terrain
func _create_test_objects() -> void:
	print("\n[ProceduralSlope] Creating test objects 10m above terrain...")

	# 1. Dummy Player 생성
	var player_scene = load("res://scenes/player/player.tscn")
	if not player_scene:
		push_error("[ProceduralSlope] Failed to load player.tscn")
		return

	_test_dummy_player = player_scene.instantiate()
	_test_dummy_player.name = "TestDummyPlayer"

	# 지면 높이 계산
	var ground_y = _get_terrain_ground_y(0.0, -30.0)  # 중앙 위치
	var hover_height = 10.0  # 지면에서 10m 위

	# Dummy 위치: 지면 + 10m
	_test_dummy_player.global_position = Vector3(0.0, ground_y + hover_height, -30.0)
	_test_dummy_player.set_script(null)
	_test_dummy_player.set_physics_process(false)
	_test_dummy_player.set_process(false)

	# 현재 활성 지형의 자식으로 추가
	var active_terrain = _get_active_terrain()
	if active_terrain:
		active_terrain.add_child(_test_dummy_player)

	print("[ProceduralSlope] Dummy player created at: ", _test_dummy_player.global_position)

	# 2. 테스트 Obstacles 생성 (고정 위치)
	_create_test_obstacles_fixed(ground_y, hover_height)

	print("[ProceduralSlope] Test objects created: 1 dummy + %d obstacles" % _test_obstacles.size())


## Create test obstacles at fixed positions
func _create_test_obstacles_fixed(ground_y: float, hover_height: float) -> void:
	var obstacle_factory = get_node_or_null("ObstacleFactory")
	if not obstacle_factory:
		print("[ProceduralSlope] ObstacleFactory not found")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Obstacle 높이 오프셋 (중심에서 바닥까지)
	const TREE_OFFSET = 2.5
	const ROCK_OFFSET = 0.7

	# 고정 위치 배치 (Dummy 주변)
	var positions = [
		{"type": "tree", "pos": Vector3(5.0, 0, -40.0), "offset": TREE_OFFSET},   # 오른쪽 앞
		{"type": "rock", "pos": Vector3(-5.0, 0, -40.0), "offset": ROCK_OFFSET},  # 왼쪽 앞
		{"type": "tree", "pos": Vector3(10.0, 0, -30.0), "offset": TREE_OFFSET},  # 오른쪽
		{"type": "rock", "pos": Vector3(-10.0, 0, -30.0), "offset": ROCK_OFFSET}, # 왼쪽
	]

	for data in positions:
		var obstacle = obstacle_factory._create_obstacle_scene(data["type"], rng)
		obstacle.name = "Test" + data["type"].capitalize()

		# 위치: 지면 + 10m + 장애물 오프셋
		obstacle.global_position = Vector3(
			data["pos"].x,
			ground_y + hover_height + data["offset"],
			data["pos"].z
		)
		obstacle.rotate_y(rng.randf() * TAU)

		# 현재 활성 지형의 자식으로 추가
		var active_terrain = _get_active_terrain()
		if active_terrain:
			active_terrain.add_child(obstacle)

		_test_obstacles.append(obstacle)
		print("[ProceduralSlope] Test obstacle created: %s at %s" % [obstacle.name, obstacle.global_position])


## Remove all test objects
func _remove_test_objects() -> void:
	print("[ProceduralSlope] Removing test objects...")

	# Dummy player 제거
	if _test_dummy_player:
		_test_dummy_player.queue_free()
		_test_dummy_player = null
		print("[ProceduralSlope] Dummy player removed")

	# Obstacles 제거
	for obstacle in _test_obstacles:
		if obstacle:
			obstacle.queue_free()
	_test_obstacles.clear()

	print("[ProceduralSlope] All test objects removed")


## Update test objects position when switching terrain (V2 ↔ V3)
func _update_test_objects_position() -> void:
	if not shadow_test_mode or not _test_dummy_player:
		return

	# 새 지형의 지면 높이 계산
	var ground_y = _get_terrain_ground_y(0.0, -30.0)
	var hover_height = 10.0

	# Dummy 위치 업데이트
	var old_pos = _test_dummy_player.global_position
	_test_dummy_player.global_position.y = ground_y + hover_height

	# Obstacles도 같은 높이 차이만큼 이동
	var y_diff = _test_dummy_player.global_position.y - old_pos.y
	for obstacle in _test_obstacles:
		if obstacle:
			obstacle.global_position.y += y_diff

	print("[ProceduralSlope] Test objects repositioned to Y=%.1f (ground=%.1f + 10m)" % [ground_y + hover_height, ground_y])


## Toggle between V2 (flat) and V3 (bumpy) terrain (shadow test mode only)
func toggle_terrain_version() -> void:
	# 테스트 모드에서만 V2 ↔ V3 토글
	if shadow_test_mode:
		terrain_version = 1 if terrain_version == 2 else 2

		var version_names = {1: "V2 (Flat)", 2: "V3 (Bumpy)"}
		print("\n" + "=".repeat(60))
		print("TOGGLING TERRAIN VERSION (Test Mode)")
		print("  New version: %s" % version_names.get(terrain_version, "Unknown"))
		print("=".repeat(60) + "\n")

		# Toggle visibility
		_show_active_terrain()

		# 테스트 객체들을 새 지형 높이에 맞춰 이동
		_update_test_objects_position()
	else:
		print("[ProceduralSlope] Terrain toggle disabled in normal mode (use shadow test mode button)")


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
