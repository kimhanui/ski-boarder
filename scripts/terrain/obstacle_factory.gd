extends Node3D
class_name ObstacleFactory

## Procedural obstacle scatter system for snow mountain terrain
## Supports sparse/normal/dense modes with runtime adjustment

signal density_changed(mode: String)

@export var terrain_size := Vector2(800, 800)  # Terrain dimensions (X, Z)
@export var seed_value := 12345  # Random seed for reproducible placement
@export var terrain_collision_mask: int = 2  # Terrain collision layer
@export var player_radius_m: float = 70.0  # Radius around player for normal mode

# Base counts for "normal" mode (total 10 obstacles)
@export_group("Base Counts (Normal Mode)")
@export var tree_count_base := 4
@export var grass_count_base := 4
@export var rock_count_base := 2

# Density multipliers
const DENSITY_MULTIPLIERS = {
	"sparse": 0.2,
	"normal": 1.0,
	"dense": 2.0
}

# Obstacle type meshes (simple placeholders)
var tree_mesh: Mesh
var grass_mesh: Mesh
var rock_mesh_small: Mesh
var rock_mesh_medium: Mesh
var rock_mesh_large: Mesh

# MultiMesh instances
var trees_multimesh: MultiMeshInstance3D
var grass_multimesh: MultiMeshInstance3D
var rocks_multimesh: MultiMeshInstance3D

# Current density mode
var current_density := "normal"

# Exclusion zones (paths where obstacles shouldn't spawn)
var exclusion_zones: Array[Rect2] = []

# Player reference (for normal mode proximity spawning)
var player: Node3D = null

# Scene-based obstacles for normal mode (instead of MultiMesh)
var normal_mode_obstacles: Array[Node3D] = []


func _ready() -> void:
	_create_placeholder_meshes()
	_create_multimesh_instances()
	_add_default_exclusion_zones()

	# Find player reference
	await get_tree().process_frame
	player = _find_player()

	# Wait for terrain physics to be ready before placing obstacles
	await get_tree().physics_frame
	await get_tree().physics_frame  # Wait 2 frames for terrain collision to be fully initialized

	# Run diagnostics
	debug_diagnose()

	set_obstacle_density("normal")


## Create simple placeholder meshes for obstacles
func _create_placeholder_meshes() -> void:
	# Tree: Cylinder + Cone
	tree_mesh = _create_tree_mesh()

	# Grass: Small scattered quads
	grass_mesh = _create_grass_mesh()

	# Rocks: Different sized boxes/spheres
	rock_mesh_small = _create_rock_mesh(0.3)
	rock_mesh_medium = _create_rock_mesh(0.6)
	rock_mesh_large = _create_rock_mesh(1.2)


func _create_tree_mesh() -> Mesh:
	# Realistic conifer tree - use cone shape for overall tree silhouette
	var cone = CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.5
	cone.height = 5.0
	cone.radial_segments = 8

	# Dark green conifer material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.35, 0.18)  # Dark evergreen
	material.roughness = 0.85
	cone.material = material

	return cone


func _create_grass_mesh() -> Mesh:
	# Realistic dried grass clumps
	var array_mesh = ArrayMesh.new()

	# Create multiple blade clusters
	var grass_blades = []
	for i in range(8):
		var blade = QuadMesh.new()
		blade.size = Vector2(0.15, 0.6)
		grass_blades.append(blade)

	# Use a small box mesh as base with variations
	var base = CylinderMesh.new()
	base.top_radius = 0.2
	base.bottom_radius = 0.25
	base.height = 0.6
	base.radial_segments = 6

	# Dry grass material (yellowish-brown)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.6, 0.35)  # Dry grass color
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Double-sided
	base.material = material

	return base


func _create_rock_mesh(size: float) -> Mesh:
	# Irregular rock (using sphere with low subdivisions for angular look)
	var sphere = SphereMesh.new()
	sphere.radius = size * 0.8
	sphere.height = size * 1.4
	sphere.radial_segments = 5  # Lower segments for more angular/rocky look
	sphere.rings = 3

	# Grey/brown rocky material with variation
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.42, 0.38)  # Grey-brown
	material.roughness = 0.95
	material.metallic = 0.0

	# Add slight normal map variation for texture
	material.normal_enabled = true

	sphere.material = material

	return sphere


## Create MultiMeshInstance3D nodes
func _create_multimesh_instances() -> void:
	# Trees
	trees_multimesh = MultiMeshInstance3D.new()
	trees_multimesh.name = "Trees"
	trees_multimesh.multimesh = MultiMesh.new()
	trees_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trees_multimesh.multimesh.mesh = tree_mesh
	trees_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(trees_multimesh)

	# Grass
	grass_multimesh = MultiMeshInstance3D.new()
	grass_multimesh.name = "Grass"
	grass_multimesh.multimesh = MultiMesh.new()
	grass_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.multimesh.mesh = grass_mesh
	grass_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(grass_multimesh)

	# Rocks (mixed sizes)
	rocks_multimesh = MultiMeshInstance3D.new()
	rocks_multimesh.name = "Rocks"
	rocks_multimesh.multimesh = MultiMesh.new()
	rocks_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	rocks_multimesh.multimesh.mesh = rock_mesh_medium
	rocks_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(rocks_multimesh)


## Add default exclusion zones (paths, player start area)
func _add_default_exclusion_zones() -> void:
	# Center path (main slope) - wider exclusion
	exclusion_zones.append(Rect2(-50, -terrain_size.y / 2, 100, terrain_size.y))

	# Player start area
	exclusion_zones.append(Rect2(-80, -80, 160, 160))

	# Outside slope boundaries (left and right edges)
	exclusion_zones.append(Rect2(-terrain_size.x / 2, -terrain_size.y / 2, 100, terrain_size.y))
	exclusion_zones.append(Rect2(terrain_size.x / 2 - 100, -terrain_size.y / 2, 100, terrain_size.y))


## Check if position is in exclusion zone
func _is_in_exclusion_zone(pos: Vector3) -> bool:
	var pos_2d = Vector2(pos.x, pos.z)
	for zone in exclusion_zones:
		if zone.has_point(pos_2d):
			return true
	return false


## Set obstacle density mode
func set_obstacle_density(mode: String) -> void:
	if mode not in DENSITY_MULTIPLIERS:
		push_error("Invalid density mode: " + mode)
		return

	current_density = mode
	var multiplier = DENSITY_MULTIPLIERS[mode]

	# Calculate total count based on base (10) * multiplier
	var total_count = int(10 * multiplier)  # sparse=2, normal=10, dense=20

	# ALL modes now use scene-based spawning near player
	spawn_obstacles_near_player(total_count)

	density_changed.emit(mode)


## Generate obstacle positions using noise-based clustering
func _generate_obstacles(multimesh_instance: MultiMeshInstance3D, count: int, min_spacing: float, max_spacing: float) -> void:
	var multimesh = multimesh_instance.multimesh
	multimesh.instance_count = count

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + count  # Different seed per type

	var positions: Array[Vector3] = []

	# Determine height offset based on mesh type
	# CylinderMesh and SphereMesh have origin at geometric center, not bottom
	var height_offset = 0.0  # Will be set based on mesh type
	if multimesh_instance.name == "Trees":
		height_offset = 2.5  # Tree: CylinderMesh height=5.0m, origin at center, so offset = 5.0/2
	elif multimesh_instance.name == "Grass":
		height_offset = 0.3  # Grass: CylinderMesh height=0.6m, origin at center, so offset = 0.6/2
	elif multimesh_instance.name == "Rocks":
		height_offset = 0.7  # Rocks: SphereMesh height≈1.4m, origin at center, so offset ≈ 1.4/2

	for i in range(count):
		var attempts = 0
		var pos: Vector3
		var valid = false

		# Try to find valid position
		while attempts < 50 and not valid:
			# Random position within terrain bounds
			pos = Vector3(
				rng.randf_range(-terrain_size.x / 2, terrain_size.x / 2),
				0,  # Y will be set by terrain height
				rng.randf_range(-terrain_size.y / 2, terrain_size.y / 2)
			)

			# Check exclusion zones
			if _is_in_exclusion_zone(pos):
				attempts += 1
				continue

			# Check spacing from other obstacles
			valid = true
			for other_pos in positions:
				if pos.distance_to(other_pos) < min_spacing:
					valid = false
					break

			attempts += 1

		if valid:
			positions.append(pos)

			# Raycast down to get terrain height
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
				pos + Vector3(0, 100, 0),  # Start above
				pos + Vector3(0, -100, 0)  # Ray down
			)
			query.collision_mask = 2  # Terrain layer
			var result = space_state.intersect_ray(query)

			var final_pos = pos
			if result:
				final_pos = result.position
				final_pos.y += height_offset  # Offset based on mesh type
			else:
				# Use approximate height from config
				var config = DifficultyConfig.get_config("medium")
				var progress = (pos.z + terrain_size.y / 2) / terrain_size.y
				final_pos.y = config.vertical_drop * (1.0 - progress) + height_offset

			# Set transform
			var transform = Transform3D()
			transform.origin = final_pos

			# Random rotation
			transform = transform.rotated(Vector3.UP, rng.randf_range(0, TAU))

			# Random scale variation
			var scale = rng.randf_range(0.8, 1.2)
			transform = transform.scaled(Vector3(scale, scale, scale))

			multimesh.set_instance_transform(i, transform)
		else:
			# No valid position found, use dummy transform
			multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))  # Hide underground


## Get current density mode
func get_current_density() -> String:
	return current_density


## Add custom exclusion zone
func add_exclusion_zone(zone: Rect2) -> void:
	exclusion_zones.append(zone)


## Clear all obstacles
func clear_obstacles() -> void:
	if trees_multimesh and trees_multimesh.multimesh:
		trees_multimesh.multimesh.instance_count = 0
	if grass_multimesh and grass_multimesh.multimesh:
		grass_multimesh.multimesh.instance_count = 0
	if rocks_multimesh and rocks_multimesh.multimesh:
		rocks_multimesh.multimesh.instance_count = 0

	# Clear normal mode obstacles
	for obstacle in normal_mode_obstacles:
		obstacle.queue_free()
	normal_mode_obstacles.clear()


## Find player node in scene tree
func _find_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


## Debug diagnostics
func debug_diagnose() -> void:
	print("\n[ObstacleFactory] === DIAGNOSTIC START ===")

	# Check terrain
	var terrain = _find_terrain_static()
	if terrain:
		print("[Diag] ✓ Terrain StaticBody3D found: ", terrain.name)
		print("[Diag]   - Collision layer: ", terrain.collision_layer)
		print("[Diag]   - Collision mask: ", terrain.collision_mask)
		print("[Diag]   - Has group 'terrain_static': ", terrain.is_in_group("terrain_static"))
	else:
		print("[Diag] ✗ WARNING: No terrain StaticBody3D found!")

	# Check player
	if player:
		print("[Diag] ✓ Player found: ", player.name)
		print("[Diag]   - Position: ", player.global_position)
	else:
		print("[Diag] ✗ WARNING: No player found!")

	# Check MultiMesh setup
	print("[Diag] MultiMesh instances:")
	print("[Diag]   - Trees: ", trees_multimesh.multimesh.instance_count if trees_multimesh and trees_multimesh.multimesh else "NULL")
	print("[Diag]   - Grass: ", grass_multimesh.multimesh.instance_count if grass_multimesh and grass_multimesh.multimesh else "NULL")
	print("[Diag]   - Rocks: ", rocks_multimesh.multimesh.instance_count if rocks_multimesh and rocks_multimesh.multimesh else "NULL")

	# Check mesh origins (AABB)
	if trees_multimesh and trees_multimesh.multimesh and trees_multimesh.multimesh.mesh:
		var aabb = trees_multimesh.multimesh.mesh.get_aabb()
		print("[Diag] Tree mesh AABB: ", aabb)
		print("[Diag]   - Visual bottom Y: ", aabb.position.y)
		print("[Diag]   - Height: ", aabb.size.y)

	print("[ObstacleFactory] === DIAGNOSTIC END ===\n")


## Find terrain static body
func _find_terrain_static() -> StaticBody3D:
	var terrain_nodes = get_tree().get_nodes_in_group("terrain_static")
	if terrain_nodes.size() > 0:
		return terrain_nodes[0]

	# Fallback: search for StaticBody3D with name "Terrain"
	var root = get_tree().root
	for child in root.get_children():
		var terrain = _search_for_terrain(child)
		if terrain:
			return terrain
	return null


## Recursive search for terrain
func _search_for_terrain(node: Node) -> StaticBody3D:
	if node is StaticBody3D and node.name == "Terrain":
		return node
	for child in node.get_children():
		var result = _search_for_terrain(child)
		if result:
			return result
	return null


## Project position to ground using raycast
func project_to_ground(world: World3D, x: float, z: float, cast_height: float = 1000.0, cast_depth: float = 2000.0) -> Dictionary:
	var space = world.direct_space_state
	var from = Vector3(x, cast_height, z)
	var to = Vector3(x, cast_height - cast_depth, z)
	var params = PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = terrain_collision_mask
	params.collide_with_areas = false
	var hit = space.intersect_ray(params)

	if hit.is_empty():
		push_warning("[ObstacleFactory] Raycast miss at (%.1f, %.1f)" % [x, z])

	return hit  # {position, normal, collider, ...} or {}


## Spawn obstacles near player (supports all density modes)
func spawn_obstacles_near_player(count: int) -> void:
	print("\n[ObstacleFactory] Spawning %s mode: %d obstacles near player" % [current_density.to_upper(), count])

	# Clear all existing obstacles
	clear_obstacles()

	# Hide MultiMesh instances (not used anymore)
	if trees_multimesh:
		trees_multimesh.visible = false
	if grass_multimesh:
		grass_multimesh.visible = false
	if rocks_multimesh:
		rocks_multimesh.visible = false

	if not player:
		push_warning("[ObstacleFactory] No player found, cannot spawn near player")
		return

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Create obstacle type distribution based on count
	var obstacle_types: Array[String] = []
	var tree_ratio = 0.3  # 30% trees
	var grass_ratio = 0.4  # 40% grass
	var rock_ratio = 0.3   # 30% rocks

	var num_trees = max(1, int(count * tree_ratio))
	var num_grass = max(1, int(count * grass_ratio))
	var num_rocks = count - num_trees - num_grass

	for i in range(num_trees):
		obstacle_types.append("tree")
	for i in range(num_grass):
		obstacle_types.append("grass")
	for i in range(num_rocks):
		obstacle_types.append("rock")

	# Shuffle for random distribution
	obstacle_types.shuffle()

	var placed = 0
	var attempts = 0
	var max_attempts = count * 10

	while placed < count and attempts < max_attempts:
		attempts += 1

		# Random position around player
		var angle = rng.randf() * TAU
		var dist = rng.randf() * player_radius_m * 0.9 + player_radius_m * 0.1
		var player_pos = player.global_position
		var x = player_pos.x + cos(angle) * dist
		var z = player_pos.z + sin(angle) * dist

		# Raycast to ground
		var hit = project_to_ground(get_world_3d(), x, z)

		if hit.has("position"):
			# Create obstacle instance
			var obstacle_type = obstacle_types[placed]
			var obstacle = _create_obstacle_scene(obstacle_type, rng)

			if obstacle:
				# Position obstacle on terrain
				var ground_pos = hit.position
				var height_offset = _get_obstacle_height_offset(obstacle_type)
				obstacle.global_position = Vector3(x, ground_pos.y + height_offset, z)

				# Random rotation
				obstacle.rotate_y(rng.randf() * TAU)

				# Add to scene
				add_child(obstacle)
				normal_mode_obstacles.append(obstacle)
				placed += 1

	print("[ObstacleFactory] %s mode: Placed %d obstacles (attempts: %d)" % [current_density.to_upper(), placed, attempts])


## Create obstacle scene based on type
func _create_obstacle_scene(type: String, rng: RandomNumberGenerator) -> Node3D:
	# Use StaticBody3D for collision
	var obstacle = StaticBody3D.new()
	obstacle.collision_layer = 2  # Environment layer (same as terrain)
	obstacle.collision_mask = 0

	var collision_shape: CollisionShape3D
	var shape: Shape3D
	var label_text = ""
	var label_height = 0.0

	if type == "tree":
		# Create tree mesh instance
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = tree_mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		obstacle.add_child(mesh_instance)
		obstacle.name = "Tree"

		# Add collision shape (cylinder for tree trunk)
		collision_shape = CollisionShape3D.new()
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.radius = 0.8  # Slightly smaller than visual
		cylinder_shape.height = 5.0
		collision_shape.shape = cylinder_shape
		collision_shape.position = Vector3(0, 0, 0)  # Center
		obstacle.add_child(collision_shape)

		label_text = "Tree"
		label_height = 3.0  # Above tree

	elif type == "grass":
		# Create grass mesh instance
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = grass_mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		obstacle.add_child(mesh_instance)
		obstacle.name = "Grass"

		# Add collision shape (small cylinder)
		collision_shape = CollisionShape3D.new()
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.radius = 0.2
		cylinder_shape.height = 0.6
		collision_shape.shape = cylinder_shape
		collision_shape.position = Vector3(0, 0, 0)
		obstacle.add_child(collision_shape)

		label_text = "Grass"
		label_height = 0.8  # Above grass

	elif type == "rock":
		# Create rock mesh instance (random size)
		var mesh_instance = MeshInstance3D.new()
		var rock_choice = rng.randi_range(0, 2)
		var rock_radius = 0.5
		var rock_size_name = "Medium"
		if rock_choice == 0:
			mesh_instance.mesh = rock_mesh_small
			rock_radius = 0.3 * 0.8
			rock_size_name = "Small"
		elif rock_choice == 1:
			mesh_instance.mesh = rock_mesh_medium
			rock_radius = 0.6 * 0.8
			rock_size_name = "Medium"
		else:
			mesh_instance.mesh = rock_mesh_large
			rock_radius = 1.2 * 0.8
			rock_size_name = "Large"
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		obstacle.add_child(mesh_instance)
		obstacle.name = "Rock"

		# Add collision shape (sphere)
		collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = rock_radius
		collision_shape.shape = sphere_shape
		collision_shape.position = Vector3(0, 0, 0)
		obstacle.add_child(collision_shape)

		label_text = "Rock (" + rock_size_name + ")"
		label_height = rock_radius * 1.5 + 0.5  # Above rock

	# Add 3D label above obstacle
	_add_3d_label(obstacle, label_text, label_height)

	# Random scale variation
	var scale = rng.randf_range(0.8, 1.2)
	obstacle.scale = Vector3(scale, scale, scale)

	return obstacle


## Add 3D label above obstacle
func _add_3d_label(obstacle: Node3D, text: String, height: float) -> void:
	var label = Label3D.new()
	label.text = text
	label.position = Vector3(0, height, 0)

	# Label settings
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Always visible through objects
	label.modulate = Color(1, 1, 1, 1)  # White
	label.outline_modulate = Color(0, 0, 0, 1)  # Black outline
	label.outline_size = 8  # Outline thickness
	label.font_size = 32
	label.pixel_size = 0.01  # Scale in 3D space

	# Center alignment
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	obstacle.add_child(label)


## Get height offset for obstacle type
func _get_obstacle_height_offset(type: String) -> float:
	if type == "tree":
		return 2.5  # Tree: CylinderMesh height=5.0m, origin at center
	elif type == "grass":
		return 0.3  # Grass: CylinderMesh height=0.6m, origin at center
	elif type == "rock":
		return 0.7  # Rock: SphereMesh height≈1.4m, origin at center
	return 0.0
