extends Node
class_name TerrainGeneratorV2

## Generates sloped terrain optimized for shadow reception
## Simplified version focused on shadow rendering quality
## Creates ski slopes with adjustable steepness (0-45 degrees)

## Creates a sloped terrain with optimal shadow settings
## @param width_m: Width of terrain in meters (default: 500)
## @param length_m: Length of terrain in meters (default: 1500)
## @param height_y: Height position at the start of terrain (default: 0)
## @param slope_angle_deg: Slope angle in degrees (default: 20, range: 0-45)
## @param animal_count: Number of animals to spawn (default: 0)
## @return StaticBody3D containing the terrain mesh and collision
static func create_flat_terrain(width_m: float = 500.0, length_m: float = 1500.0, height_y: float = 0.0, slope_angle_deg: float = 20.0, animal_count: int = 0) -> StaticBody3D:
	print("[TerrainV2] Creating sloped terrain: %.1fx%.1f meters at Y=%.1f, slope=%.1f°" % [width_m, length_m, height_y, slope_angle_deg])

	# Mesh resolution (vertices per axis) - Reduced for performance (30k → 7.5k vertices)
	var segments_x = 50  # Was 100
	var segments_z = 150  # Was 300

	# Build sloped terrain mesh
	var terrain_mesh = _build_flat_mesh(width_m, length_m, height_y, segments_x, segments_z, slope_angle_deg)

	# Create material optimized for shadow reception
	var material = _create_shadow_optimized_material()
	terrain_mesh.surface_set_material(0, material)

	# Create MeshInstance3D with shadow settings
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	mesh_instance.name = "TerrainMesh"

	# Shadow reception settings:
	# - cast_shadow=ON: Terrain casts its own shadow from directional light
	# - gi_mode=STATIC: Terrain receives dynamic shadows from moving objects (player)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC

	# Create StaticBody3D with collision
	var static_body = StaticBody3D.new()
	static_body.name = "Terrain"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0

	# Add to terrain group for:
	# 1. Obstacle placement raycast detection (used by obstacle_factory.gd)
	# 2. Ski track collision detection (used by player_v3.gd)
	static_body.add_to_group("terrain")

	# Create collision shape from mesh
	var collision_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	var faces = mesh_instance.mesh.get_faces()
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape

	# No collision offset - player stands directly on visual surface
	collision_shape.position.y = 0.0

	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)

	print("[TerrainV2] Terrain created: %d faces, collision enabled" % [faces.size() / 3])

	# Generate obstacles (rocks, trees, and animals)
	_generate_obstacles(static_body, width_m, length_m, height_y, slope_angle_deg, 12345, animal_count)

	return static_body


## Builds a sloped rectangular mesh at specified height
## Slope descends in -Z direction (forward)
static func _build_flat_mesh(width_m: float, length_m: float, height_y: float, segments_x: int, segments_z: int, slope_angle_deg: float) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()  # Vertex colors for hole coloring
	var indices = PackedInt32Array()

	# Calculate step size
	var step_x = width_m / float(segments_x)
	var step_z = length_m / float(segments_z)

	# Start position (centered on X, forward on Z)
	var start_x = -width_m / 2.0
	var start_z = 50.0  # Match original z_offset

	# Calculate slope parameters
	var slope_angle_rad = deg_to_rad(slope_angle_deg)
	var slope_ratio = tan(slope_angle_rad)  # Y drop per meter in Z

	# Calculate surface normal for sloped terrain
	# Slope descends in -Z direction (forward), so normal tilts backward
	var surface_normal = Vector3(0, cos(slope_angle_rad), sin(slope_angle_rad)).normalized()

	# Define 5 hole positions scattered across slope (player spawns at Z=-30)
	# Adjusted positions to prevent respawn trigger (Y < -70)
	var hole_positions = [
		Vector3(-30, 0, -35),    # Left-top (Y ≈ -31.0m)
		Vector3(25, 0, -50),     # Right-middle (Y ≈ -36.4m)
		Vector3(0, 0, -65),      # Center (Y ≈ -41.9m)
		Vector3(-35, 0, -80),    # Left-bottom (Y ≈ -47.3m)
		Vector3(30, 0, -95),     # Right-bottom (Y ≈ -52.8m)
	]
	var hole_radius = 12.0  # Meters (smaller)
	var hole_depth = 3.0    # Meters at center (shallower)

	# Define 2 hill positions (below holes)
	var hill_positions = [
		Vector3(-40, 0, -110),   # Left hill
		Vector3(40, 0, -120),    # Right hill
	]
	var hill_radius = 12.0  # Same as holes
	var hill_height = 3.0   # Max height = hole max depth

	# Generate vertices
	for z in range(segments_z + 1):
		for x in range(segments_x + 1):
			var pos_x = start_x + x * step_x
			var pos_z = start_z - z * step_z

			# Apply slope: Y decreases as Z increases (going forward/down the slope)
			var z_distance = z * step_z  # Distance from start
			var y_drop = z_distance * slope_ratio
			var pos_y = height_y - y_drop

			# Apply hole depth reduction
			var hole_depth_reduction = 0.0
			var hole_color_intensity = 0.0  # Track color intensity for holes
			for hole_pos in hole_positions:
				# Calculate horizontal distance (XZ plane) to hole center
				var dist_xz = sqrt(pow(pos_x - hole_pos.x, 2) + pow(pos_z - hole_pos.z, 2))

				# Apply cosine falloff for smooth edges
				if dist_xz < hole_radius:
					var normalized_dist = dist_xz / hole_radius
					var falloff = cos(normalized_dist * PI * 0.5)  # Smooth 0-1 curve
					hole_depth_reduction += falloff * hole_depth
					hole_color_intensity = max(hole_color_intensity, falloff)  # Use strongest hole influence

			pos_y -= hole_depth_reduction

			# Apply hill height addition
			var hill_height_addition = 0.0
			var hill_color_intensity = 0.0  # Track color intensity for hills
			for hill_pos in hill_positions:
				# Calculate horizontal distance (XZ plane) to hill center
				var dist_xz = sqrt(pow(pos_x - hill_pos.x, 2) + pow(pos_z - hill_pos.z, 2))

				# Apply cosine falloff for smooth edges
				if dist_xz < hill_radius:
					var normalized_dist = dist_xz / hill_radius
					var falloff = cos(normalized_dist * PI * 0.5)  # Smooth 0-1 curve
					hill_height_addition += falloff * hill_height
					hill_color_intensity = max(hill_color_intensity, falloff)  # Use strongest hill influence

			pos_y += hill_height_addition  # ADD height (opposite of holes)

			# Calculate vertex color (gray in holes, white on hills, gray base)
			var base_color = Color(0.6, 0.6, 0.6)      # Darker gray snow (60% brightness)
			var hole_color = Color(0.4, 0.4, 0.4)      # Medium gray (darker than base)
			var hill_color = Color(1.0, 1.0, 1.0)      # Bright white snow

			# Apply hole color first
			var vertex_color = base_color.lerp(hole_color, hole_color_intensity)
			# Then apply hill color (additive brightening)
			vertex_color = vertex_color.lerp(hill_color, hill_color_intensity)

			vertices.append(Vector3(pos_x, pos_y, pos_z))
			normals.append(surface_normal)  # Consistent normal for entire sloped surface
			colors.append(vertex_color)

			# UV mapping
			var u = float(x) / float(segments_x)
			var v = float(z) / float(segments_z)
			uvs.append(Vector2(u, v))

	# Generate indices (triangles)
	for z in range(segments_z):
		for x in range(segments_x):
			var top_left = z * (segments_x + 1) + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * (segments_x + 1) + x
			var bottom_right = bottom_left + 1

			# First triangle (top-left, bottom-left, top-right)
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)

			# Second triangle (top-right, bottom-left, bottom-right)
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	print("[TerrainV2] Sloped mesh created: %d vertices, %d triangles, slope=%.1f°" % [vertices.size(), indices.size() / 3, slope_angle_deg])
	print("[TerrainV2] Added %d holes (radius=%.1fm, depth=%.1fm)" % [hole_positions.size(), hole_radius, hole_depth])

	return array_mesh


## Creates a material optimized for receiving shadows
static func _create_shadow_optimized_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Use vertex colors for terrain coloring (holes will be green)
	# Albedo color is multiplied with vertex colors, so use white
	material.albedo_color = Color(1.0, 1.0, 1.0)
	material.vertex_color_use_as_albedo = true

	# Smooth surface for clean shadow edges
	material.roughness = 0.3
	material.metallic = 0.0

	# Disable emission to improve shadow contrast
	material.emission_enabled = false

	# Per-pixel shading required for proper shadow rendering
	# SHADING_MODE_UNSHADED would disable shadows completely
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	return material


## Generates obstacles for V2 terrain
static func _generate_obstacles(terrain: StaticBody3D, width_m: float, length_m: float, height_y: float, slope_angle_deg: float, seed_value: int = 12345, animal_count: int = 0) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Obstacle configuration
	var rock_count = 8  # Rocks only
	var tree_count = 7  # Trees (each tree gets 2 animals next to it)
	var start_z = 50.0  # Match mesh generation
	var slope_angle_rad = deg_to_rad(slope_angle_deg)
	var slope_ratio = tan(slope_angle_rad)

	var obstacles_node = Node3D.new()
	obstacles_node.name = "Obstacles"

	var total_animals = 0

	# Generate rocks
	for i in range(rock_count):
		# Random position across terrain
		var x = rng.randf_range(-width_m/2.0 + 10.0, width_m/2.0 - 10.0)
		var z = rng.randf_range(-length_m + 60, -10)  # Avoid spawn area and far edge

		# Calculate height based on slope
		var z_distance = start_z - z
		var y_drop = z_distance * slope_ratio
		var y = height_y - y_drop  # Ground level

		var scale_val = rng.randf_range(0.8, 1.5)
		var y_offset = 0.7  # Rocks: center pivot offset

		# Create rock
		var rock = _create_obstacle_mesh("rock", scale_val, rng)
		rock.position = Vector3(x, y + y_offset, z)
		obstacles_node.add_child(rock)

	# Generate trees with 2 animals next to each
	for i in range(tree_count):
		# Random position across terrain
		var x = rng.randf_range(-width_m/2.0 + 10.0, width_m/2.0 - 10.0)
		var z = rng.randf_range(-length_m + 60, -10)  # Avoid spawn area and far edge

		# Calculate height based on slope
		var z_distance = start_z - z
		var y_drop = z_distance * slope_ratio
		var y = height_y - y_drop  # Ground level

		var scale_val = rng.randf_range(1.0, 3.0)  # Trees 1~3x size

		# Create tree
		var tree = _create_obstacle_mesh("tree", scale_val, rng)
		tree.position = Vector3(x, y, z)  # No offset for tree
		obstacles_node.add_child(tree)

		# Add 2 animals next to the tree (left and right)
		var animal_types = ["wolf", "deer_1", "deer_2"]
		for side in [-1, 1]:  # -1 = left, 1 = right
			var animal_type = animal_types[rng.randi() % animal_types.size()]
			var animal_x_offset = side * rng.randf_range(2.5, 4.0)  # 2.5~4m to the side
			var animal_z_offset = rng.randf_range(-1.0, 1.0)  # Slight Z variation

			var animal_scale = rng.randf_range(2.0, 3.0)  # 2~3x larger
			var animal = _create_obstacle_mesh(animal_type, animal_scale, rng)
			animal.position = Vector3(x + animal_x_offset, y, z + animal_z_offset)  # Same Y as tree

			# Randomly rotate some animals 90 degrees (left or right) for variety
			if rng.randf() > 0.5:
				animal.rotation.y = deg_to_rad(90 if rng.randf() > 0.5 else -90)

			obstacles_node.add_child(animal)
			total_animals += 1

	terrain.add_child(obstacles_node)
	print("[TerrainV2] Generated %d rocks, %d trees, %d animals (2 per tree)" % [rock_count, tree_count, total_animals])


## Creates a single obstacle with collision (rock, tree, or animal)
static func _create_obstacle_mesh(type: String, scale_val: float, rng: RandomNumberGenerator = null) -> StaticBody3D:
	# Create StaticBody3D for collision (same as V1)
	var obstacle = StaticBody3D.new()
	obstacle.collision_layer = 2  # Environment layer (same as terrain)
	obstacle.collision_mask = 0

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if type == "rock":
		var mesh = SphereMesh.new()
		mesh.radius = 1.5 * scale_val
		mesh.height = 2.0 * scale_val
		mesh.radial_segments = 8
		mesh.rings = 6
		mesh_instance.mesh = mesh
		mesh_instance.name = "Rock"

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.4, 0.45)
		material.roughness = 0.9
		mesh.surface_set_material(0, material)

		# Add mesh to obstacle
		obstacle.add_child(mesh_instance)

		# Add collision shape
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 1.5 * scale_val
		collision_shape.shape = sphere_shape
		obstacle.add_child(collision_shape)

	elif type == "tree":
		# Simple tree: cylinder trunk + sphere foliage
		var trunk = MeshInstance3D.new()
		var trunk_mesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.3 * scale_val
		trunk_mesh.bottom_radius = 0.3 * scale_val
		trunk_mesh.height = 3.0 * scale_val
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(0, 1.5 * scale_val, 0)

		var trunk_mat = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.3, 0.2, 0.15)
		trunk_mesh.surface_set_material(0, trunk_mat)

		var foliage = MeshInstance3D.new()
		var foliage_mesh = SphereMesh.new()
		foliage_mesh.radius = 2.0 * scale_val
		foliage_mesh.height = 3.0 * scale_val
		foliage.mesh = foliage_mesh
		foliage.position = Vector3(0, 4.0 * scale_val, 0)

		var foliage_mat = StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(0.1, 0.4, 0.2)
		foliage_mesh.surface_set_material(0, foliage_mat)

		mesh_instance.name = "Tree"
		mesh_instance.add_child(trunk)
		mesh_instance.add_child(foliage)

		# Add mesh to obstacle
		obstacle.add_child(mesh_instance)

		# Add collision shape (cylinder for trunk)
		var collision_shape = CollisionShape3D.new()
		var cylinder_shape = CylinderShape3D.new()
		cylinder_shape.radius = 0.8  # Slightly smaller than visual
		cylinder_shape.height = 5.0
		collision_shape.shape = cylinder_shape
		obstacle.add_child(collision_shape)

	elif type == "wolf" or type == "deer_1" or type == "deer_2":
		# Load animal FBX model
		var animal_paths = {
			"wolf": "res://assets/models/animals/Free Wild Animal 3D Models/fbx/unity/wolf.fbx",
			"deer_1": "res://assets/models/animals/Free Wild Animal 3D Models/fbx/unity/deer_1.fbx",
			"deer_2": "res://assets/models/animals/Free Wild Animal 3D Models/fbx/unity/deer_2.fbx"
		}

		var animal_scene = load(animal_paths[type])
		if animal_scene:
			var animal = animal_scene.instantiate()
			animal.scale = Vector3.ONE * scale_val

			# Apply wolf_controller script for patrol behavior
			var controller_script = load("res://scripts/animals/wolf_controller.gd")
			if controller_script:
				animal.set_script(controller_script)

				# Set patrol properties
				if rng:
					animal.set("patrol_speed", rng.randf_range(1.5, 3.0))
					animal.set("patrol_range", 2.0)  # 2m back-and-forth movement
					var direction = 1.0 if rng.randf() > 0.5 else -1.0
					animal.set("patrol_direction_multiplier", direction)

			# Apply color to animal based on type
			var animal_color = Color.WHITE
			if type == "wolf":
				animal_color = Color(0.5, 0.5, 0.5)  # Gray
			elif type == "deer_1":
				animal_color = Color(0.6, 0.4, 0.2)  # Brown
			elif type == "deer_2":
				animal_color = Color(0.7, 0.5, 0.3)  # Light brown

			_apply_color_to_meshes(animal, animal_color)

			obstacle.add_child(animal)

		# Add simple collision shape for animal
		var collision_shape = CollisionShape3D.new()
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.radius = 0.5 * scale_val
		capsule_shape.height = 1.5 * scale_val
		collision_shape.shape = capsule_shape
		obstacle.add_child(collision_shape)

	return obstacle


## Recursively apply color to all MeshInstance3D nodes in a tree
static func _apply_color_to_meshes(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D

		# Create new material with specified color
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		material.metallic = 0.0

		# Apply material to all surfaces of the mesh
		if mesh_instance.mesh:
			var surface_count = mesh_instance.mesh.get_surface_count()
			for i in range(surface_count):
				mesh_instance.set_surface_override_material(i, material)

	# Recursively apply to all children
	for child in node.get_children():
		_apply_color_to_meshes(child, color)


## Creates a finish line platform at the end of the terrain
static func create_finish_line(z_position: float, y_position: float) -> Node3D:
	var finish_node = Node3D.new()
	finish_node.name = "FinishLine"

	# Golden platform (visual marker)
	var platform = MeshInstance3D.new()
	var platform_mesh = CylinderMesh.new()
	platform_mesh.top_radius = 5.0
	platform_mesh.bottom_radius = 5.0
	platform_mesh.height = 0.5
	platform.mesh = platform_mesh
	platform.position = Vector3(0, y_position + 0.25, z_position)

	var gold_material = StandardMaterial3D.new()
	gold_material.albedo_color = Color(1.0, 0.84, 0.0)  # Gold color
	gold_material.metallic = 0.8
	gold_material.roughness = 0.2
	gold_material.emission_enabled = true
	gold_material.emission = Color(1.0, 0.84, 0.0)
	gold_material.emission_energy_multiplier = 0.5
	platform_mesh.surface_set_material(0, gold_material)

	finish_node.add_child(platform)

	# Detection area for player
	var area = Area3D.new()
	area.name = "FinishArea"
	area.collision_layer = 4  # Layer 4 for finish line
	area.collision_mask = 1  # Detect player (layer 1)
	area.monitoring = true  # Enable monitoring
	area.monitorable = true  # Make it monitorable
	area.position = Vector3(0, y_position + 1.0, z_position)

	# Attach detection script
	var detector_script = load("res://scripts/terrain/finish_line_detector.gd")
	if detector_script:
		area.set_script(detector_script)
		print("[TerrainV2] Finish line detector script attached")

	var collision_shape = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.radius = 5.0
	cylinder_shape.height = 3.0
	collision_shape.shape = cylinder_shape
	area.add_child(collision_shape)

	finish_node.add_child(area)

	print("[TerrainV2] Created finish line at Z=%.1f, Y=%.1f" % [z_position, y_position])

	return finish_node
