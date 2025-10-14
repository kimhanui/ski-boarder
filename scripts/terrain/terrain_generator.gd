extends Node
class_name TerrainGenerator

## Generates procedural mountain terrain for ski boarding
## Based on CREATE_SLOPE.md specifications

static func apply_slope_data(data: Dictionary, difficulty: String = "", seed_value: int = -1) -> Node3D:
	var root = Node3D.new()
	root.name = "ProceduralSlope"

	# If difficulty is specified, generate procedurally
	var use_procedural = not difficulty.is_empty()
	var config = DifficultyConfig.get_config(difficulty) if use_procedural else {}

	# Setup random seed
	var rng = RandomNumberGenerator.new()
	if seed_value == -1:
		rng.randomize()
	else:
		rng.seed = seed_value

	# Generate or use provided data
	var terrain_data = data.get("terrain", {})
	var path_data = data.get("path_spline", {})
	var obstacles_data = data.get("obstacles", [])
	var checkpoints_data = data.get("checkpoints", [])

	if use_procedural:
		# Override with procedural generation
		print("Generating procedural terrain with difficulty: %s, seed: %d" % [difficulty, rng.seed])

		# Update terrain dimensions from config
		terrain_data["width_m"] = DifficultyConfig.get_terrain_width(difficulty)
		terrain_data["length_m"] = config.slope_length
		terrain_data["cell_size"] = DifficultyConfig.get_cell_size(difficulty)

		# Generate procedural path
		path_data = _generate_procedural_path(config, rng, terrain_data)

		# Generate procedural obstacles
		obstacles_data = _generate_procedural_obstacles(config, rng, path_data, terrain_data)

		# Generate procedural checkpoints
		checkpoints_data = _generate_procedural_checkpoints(config, path_data)

	# Generate heightmap if not provided
	if terrain_data.get("heights", []).is_empty():
		terrain_data["heights"] = _generate_heightmap(terrain_data, path_data, config if use_procedural else {})

	# Build terrain mesh from heightmap
	var terrain_mesh = _build_terrain_mesh(terrain_data)
	if terrain_mesh:
		root.add_child(terrain_mesh)

	# Create path spline
	var path_3d = _build_path_spline(data.get("path_spline", {}))
	if path_3d:
		root.add_child(path_3d)

	# Add obstacles
	var obstacles_node = _build_obstacles(data.get("obstacles", []))
	if obstacles_node:
		root.add_child(obstacles_node)

	# Add checkpoints
	var checkpoints_node = _build_checkpoints(data.get("checkpoints", []))
	if checkpoints_node:
		root.add_child(checkpoints_node)

	return root


static func _generate_heightmap(terrain_data: Dictionary, path_data: Dictionary, config: Dictionary = {}) -> Array:
	var width_m = terrain_data.get("width_m", 400)
	var length_m = terrain_data.get("length_m", 1500)
	var cell_size = terrain_data.get("cell_size", 2.0)
	var origin = terrain_data.get("origin", [0, 0, 0])

	var width_cells = int(width_m / cell_size)
	var length_cells = int(length_m / cell_size)

	print("Generating heightmap: %dx%d cells (%.0fx%.0f meters)" % [width_cells, length_cells, width_m, length_m])

	var heights = []
	var path_points = path_data.get("points", [])
	var path_width = path_data.get("path_width_m", 5.0)

	# Get noise parameters from config or use defaults
	var vertical_drop = config.get("vertical_drop", 350.0)
	var noise_amplitudes = config.get("noise_amplitude", [8.0, 4.0, 2.0])
	var noise_freqs = config.get("noise_frequencies", [0.005, 0.012, 0.025])

	# Generate heightmap with natural terrain variation
	# Start terrain slightly ahead (positive Z) of origin to ensure coverage
	var z_offset = 50.0  # meters of terrain before start point

	# Create random seed for irregular noise (based on terrain data for consistency)
	var noise_seed = hash(str(width_m) + str(length_m))
	var rng = RandomNumberGenerator.new()
	rng.seed = noise_seed

	# Generate FIXED random phase offsets for each noise layer (not per-vertex!)
	var phase_offsets = []
	for i in range(6):
		phase_offsets.append(rng.randf() * 6.28)

	for x in range(width_cells):
		var row = []
		for z in range(length_cells):
			var world_x = origin[0] + x * cell_size - width_m / 2.0
			var world_z = origin[2] + z_offset - z * cell_size

			# Progress down the slope (0.0 at top, 1.0 at bottom)
			var slope_progress = float(z) / length_cells

			# Base height: non-linear slope with varied sections
			var base_height = vertical_drop * (1.0 - slope_progress)

			# Add slope sections: gentle slopes, steep drops, and plateaus
			# Upper section (0.0 - 0.25): Gentle starting area
			if slope_progress < 0.25:
				base_height += sin(slope_progress * PI * 2.0) * 10.0  # Smooth undulation

			# Mid-upper section (0.25 - 0.40): First steep drop
			elif slope_progress < 0.40:
				var drop_progress = (slope_progress - 0.25) / 0.15
				base_height -= drop_progress * drop_progress * 30.0  # Moderate descent

			# Mid section (0.40 - 0.55): Gentle plateau
			elif slope_progress < 0.55:
				base_height += sin((slope_progress - 0.40) * PI * 3.0) * 5.0  # Mild rolling

			# Mid-lower section (0.55 - 0.70): Second steep section
			elif slope_progress < 0.70:
				var drop_progress = (slope_progress - 0.55) / 0.15
				base_height -= drop_progress * drop_progress * 25.0  # Moderate descent

			# Lower section (0.70 - 1.0): Final approach with jumps
			else:
				base_height += sin((slope_progress - 0.70) * PI * 3.0) * 8.0  # Gentle bumps

			# Add smooth natural terrain variation using multi-octave noise
			var noise_val = 0.0

			# Large-scale terrain features (mountains, valleys) - very slow frequency
			noise_val += sin(world_x * noise_freqs[0] + phase_offsets[0]) * cos(world_z * noise_freqs[0] + phase_offsets[1]) * noise_amplitudes[0]

			# Medium-scale features (hills, dips) - smooth patterns
			noise_val += sin(world_x * noise_freqs[1] + world_z * noise_freqs[1] * 0.5 + phase_offsets[2]) * noise_amplitudes[1]
			noise_val += cos(world_x * noise_freqs[1] * 0.7 + world_z * noise_freqs[1] + phase_offsets[3]) * noise_amplitudes[1] * 0.6

			# Small-scale details (gentle bumps) - subtle variation
			noise_val += sin(world_x * noise_freqs[2] + world_z * noise_freqs[2] * 0.8 + phase_offsets[4]) * noise_amplitudes[2]
			noise_val += cos(world_x * noise_freqs[2] * 0.6 + world_z * noise_freqs[2] + phase_offsets[5]) * noise_amplitudes[2] * 0.4

			# Carve path depression
			var closest_dist = INF
			for point in path_points:
				var dist = sqrt(pow(world_x - point[0], 2) + pow(world_z - point[2], 2))
				closest_dist = min(closest_dist, dist)

			# Smooth carve near path
			var carve_factor = 0.0
			if closest_dist < path_width * 2.0:
				carve_factor = (1.0 - closest_dist / (path_width * 2.0)) * 3.0

			var final_height = base_height + noise_val - carve_factor
			row.append(final_height)

		heights.append(row)

	print("Heightmap generated: %d rows x %d columns = %d vertices" % [heights.size(), heights[0].size() if heights.size() > 0 else 0, heights.size() * (heights[0].size() if heights.size() > 0 else 0)])
	return heights


static func _build_terrain_mesh(terrain_data: Dictionary) -> StaticBody3D:
	var heights = terrain_data.get("heights", [])
	if heights.is_empty():
		return null

	var cell_size = terrain_data.get("cell_size", 2.0)
	var width_m = terrain_data.get("width_m", 400)
	var origin = terrain_data.get("origin", [0, 0, 0])

	var width_cells = heights.size()
	var length_cells = heights[0].size() if width_cells > 0 else 0

	if width_cells == 0 or length_cells == 0:
		return null

	# Create mesh arrays
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Generate vertices
	var z_offset = 50.0  # Match the offset used in heightmap generation
	for x in range(width_cells):
		for z in range(length_cells):
			var world_x = origin[0] + x * cell_size - width_m / 2.0
			var world_z = origin[2] + z_offset - z * cell_size
			var world_y = heights[x][z]

			vertices.append(Vector3(world_x, world_y, world_z))
			uvs.append(Vector2(float(x) / width_cells, float(z) / length_cells))

	# Generate indices (triangles)
	for x in range(width_cells - 1):
		for z in range(length_cells - 1):
			var i0 = x * length_cells + z
			var i1 = (x + 1) * length_cells + z
			var i2 = x * length_cells + (z + 1)
			var i3 = (x + 1) * length_cells + (z + 1)

			# First triangle
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)

			# Second triangle
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)

	# Calculate normals
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.UP

	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]

		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]

		var normal = (v1 - v0).cross(v2 - v0).normalized()
		normals[i0] += normal
		normals[i1] += normal
		normals[i2] += normal

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Create material with snow-like properties
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 1.0)
	material.roughness = 0.7  # Slightly rough for realistic snow
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	array_mesh.surface_set_material(0, material)

	# Create MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.name = "TerrainMesh"

	# Create StaticBody3D with collision
	var static_body = StaticBody3D.new()
	static_body.name = "Terrain"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0

	# Create collision shape from mesh
	var collision_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	var faces = mesh_instance.mesh.get_faces()
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape

	print("Collision shape created: %d faces" % [faces.size() / 3])

	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)

	# Add debug boundary markers
	_add_debug_boundaries(static_body, width_m, terrain_data.get("length_m", 1500))

	return static_body


static func _add_debug_boundaries(parent: Node3D, width_m: float, length_m: float) -> void:
	# Add visual markers at the corners of the terrain
	var z_offset = 50.0  # Match the offset used in terrain generation
	var corners = [
		Vector3(-width_m/2, 350, z_offset),  # Top-left (front)
		Vector3(width_m/2, 350, z_offset),   # Top-right (front)
		Vector3(-width_m/2, 0, z_offset - length_m),  # Bottom-left (back)
		Vector3(width_m/2, 0, z_offset - length_m),   # Bottom-right (back)
	]

	for i in range(corners.size()):
		var marker = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 5.0
		sphere.height = 10.0
		marker.mesh = sphere

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.surface_set_material(0, mat)

		marker.position = corners[i]
		marker.name = "DebugMarker_%d" % i
		parent.add_child(marker)

	print("Terrain boundaries: X[%.1f to %.1f], Z[%.1f to %.1f]" % [-width_m/2, width_m/2, z_offset, z_offset - length_m])


static func _build_path_spline(path_data: Dictionary) -> Path3D:
	var points = path_data.get("points", [])
	if points.is_empty():
		return null

	var path_3d = Path3D.new()
	path_3d.name = "RidePath"

	var curve = Curve3D.new()

	for point in points:
		curve.add_point(Vector3(point[0], point[1], point[2]))

	path_3d.curve = curve

	# TODO: Add PathFollow3D for camera tracking

	return path_3d


static func _build_obstacles(obstacles_data: Array) -> Node3D:
	var obstacles_node = Node3D.new()
	obstacles_node.name = "Obstacles"

	for obstacle in obstacles_data:
		var type = obstacle.get("type", "rock")
		var pos = obstacle.get("pos", [0, 0, 0])
		var scale_val = obstacle.get("scale", 1.0)

		var mesh_instance = MeshInstance3D.new()

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

		elif type == "tree":
			# Simple tree: cylinder trunk + cone top
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

		mesh_instance.position = Vector3(pos[0], pos[1], pos[2])
		obstacles_node.add_child(mesh_instance)

	return obstacles_node


static func _build_checkpoints(checkpoints_data: Array) -> Node3D:
	var checkpoints_node = Node3D.new()
	checkpoints_node.name = "Checkpoints"

	for i in range(checkpoints_data.size()):
		var checkpoint = checkpoints_data[i]
		var pos = checkpoint.get("pos", [0, 0, 0])
		var radius = checkpoint.get("radius", 2.5)

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Checkpoint_%d" % i

		var torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = radius
		torus_mesh.outer_radius = radius + 0.2
		torus_mesh.rings = 32
		torus_mesh.ring_segments = 16

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.8, 0.2, 0.6)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		torus_mesh.surface_set_material(0, material)

		mesh_instance.mesh = torus_mesh
		mesh_instance.position = Vector3(pos[0], pos[1], pos[2])
		mesh_instance.rotation_degrees = Vector3(90, 0, 0)  # Orient horizontally

		checkpoints_node.add_child(mesh_instance)

	# TODO: Add Area3D for checkpoint collision detection

	return checkpoints_node


## Procedural generation functions

static func _generate_procedural_path(config: Dictionary, rng: RandomNumberGenerator, terrain_data: Dictionary) -> Dictionary:
	var length_m = config.slope_length
	var width_m = terrain_data.get("width_m", 400.0)
	var vertical_drop = config.vertical_drop
	var path_width = config.path_width
	var turn_sharpness = config.turn_sharpness
	var turn_frequency = config.turn_frequency

	var num_segments = int(length_m / 50.0)  # One point every 50 meters
	var segment_length = length_m / num_segments

	var path_points = []
	var current_x = 0.0
	var current_z = -20.0  # Start slightly behind origin
	var current_direction = 0.0  # Lateral velocity

	for i in range(num_segments + 1):
		# Calculate height at this position
		var progress = float(i) / num_segments
		var height = vertical_drop * (1.0 - progress)

		path_points.append([current_x, height, current_z])

		# Update position for next segment
		if i < num_segments:
			current_z -= segment_length

			# Apply smooth direction changes (like steering)
			var turn_noise = rng.randf_range(-1.0, 1.0)
			var target_direction = turn_noise * turn_sharpness * 30.0  # Max 30m lateral per segment

			# Smooth interpolation toward target direction
			current_direction = lerp(current_direction, target_direction, turn_frequency * 50.0)

			# Apply direction and clamp to terrain bounds
			current_x += current_direction
			current_x = clamp(current_x, -width_m/2.0 + 30.0, width_m/2.0 - 30.0)

	print("Generated procedural path: %d points" % path_points.size())

	return {
		"type": "Curve3D",
		"points": path_points,
		"path_width_m": path_width
	}


static func _generate_procedural_obstacles(config: Dictionary, rng: RandomNumberGenerator, path_data: Dictionary, terrain_data: Dictionary) -> Array:
	var path_points = path_data.get("points", [])
	if path_points.is_empty():
		return []

	var obstacle_count = rng.randi_range(config.obstacle_count_range[0], config.obstacle_count_range[1])
	var min_dist = config.obstacle_min_distance
	var max_dist = config.obstacle_max_distance
	var scale_range = config.obstacle_scale_range
	var width_m = terrain_data.get("width_m", 400.0)

	var obstacles = []

	for i in range(obstacle_count):
		# Pick a random segment along the path
		var segment_idx = rng.randi_range(2, path_points.size() - 3)  # Avoid start and end
		var path_point = path_points[segment_idx]

		# Calculate lateral offset from path center
		var side = 1 if rng.randf() > 0.5 else -1  # Left or right
		var lateral_offset = side * rng.randf_range(min_dist, max_dist)

		var obs_x = path_point[0] + lateral_offset
		var obs_z = path_point[2]

		# Clamp to terrain bounds
		obs_x = clamp(obs_x, -width_m/2.0 + 10.0, width_m/2.0 - 10.0)

		# Estimate height at this position (simple linear approximation)
		var progress = float(segment_idx) / path_points.size()
		var obs_y = config.vertical_drop * (1.0 - progress)

		# Random obstacle type and scale
		var type = "rock" if rng.randf() > 0.4 else "tree"
		var scale = rng.randf_range(scale_range[0], scale_range[1])

		obstacles.append({
			"type": type,
			"pos": [obs_x, obs_y, obs_z],
			"scale": scale
		})

	print("Generated procedural obstacles: %d obstacles" % obstacles.size())
	return obstacles


static func _generate_procedural_checkpoints(config: Dictionary, path_data: Dictionary) -> Array:
	var path_points = path_data.get("points", [])
	if path_points.is_empty():
		return []

	var checkpoint_interval = config.checkpoint_interval
	var slope_length = config.slope_length

	var num_checkpoints = int(slope_length / checkpoint_interval)
	var checkpoints = []

	for i in range(1, num_checkpoints + 1):
		# Find path point closest to this checkpoint distance
		var target_distance = i * checkpoint_interval
		var target_idx = int(path_points.size() * (target_distance / slope_length))
		target_idx = clamp(target_idx, 0, path_points.size() - 1)

		var checkpoint_pos = path_points[target_idx]

		checkpoints.append({
			"pos": [checkpoint_pos[0], checkpoint_pos[1], checkpoint_pos[2]],
			"radius": 2.5
		})

	print("Generated procedural checkpoints: %d checkpoints" % checkpoints.size())
	return checkpoints
