extends Node
class_name TerrainGeneratorV2

## V2: Enhanced terrain generator with optimized shadow rendering
## Generates procedural mountain terrain with proper shadow reception

static func apply_slope_data(data: Dictionary, difficulty: String = "", seed_value: int = -1) -> Node3D:
	var root = Node3D.new()
	root.name = "ProceduralSlopeV2"

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
		print("[TerrainV2] Generating procedural terrain with difficulty: %s, seed: %d" % [difficulty, rng.seed])

		# Update terrain dimensions from config
		terrain_data["width_m"] = DifficultyConfig.get_terrain_width(difficulty)
		terrain_data["length_m"] = config.slope_length
		terrain_data["cell_size"] = DifficultyConfig.get_cell_size(difficulty)

		# Generate procedural path
		path_data = TerrainGenerator._generate_procedural_path(config, rng, terrain_data)

		# Generate procedural obstacles
		obstacles_data = TerrainGenerator._generate_procedural_obstacles(config, rng, path_data, terrain_data)

		# Generate procedural checkpoints
		checkpoints_data = TerrainGenerator._generate_procedural_checkpoints(config, path_data)

	# Generate heightmap if not provided
	if terrain_data.get("heights", []).is_empty():
		terrain_data["heights"] = TerrainGenerator._generate_heightmap(terrain_data, path_data, config if use_procedural else {})

	# Build terrain mesh with enhanced shadow settings
	var terrain_mesh = _build_terrain_mesh_v2(terrain_data)
	if terrain_mesh:
		root.add_child(terrain_mesh)

	# Create path spline
	var path_3d = TerrainGenerator._build_path_spline(data.get("path_spline", {}))
	if path_3d:
		root.add_child(path_3d)

	# Add obstacles with shadows enabled
	var obstacles_node = _build_obstacles_v2(data.get("obstacles", []))
	if obstacles_node:
		root.add_child(obstacles_node)

	# Add checkpoints
	var checkpoints_node = TerrainGenerator._build_checkpoints(data.get("checkpoints", []))
	if checkpoints_node:
		root.add_child(checkpoints_node)

	return root


## V2: Enhanced terrain mesh with optimized shadow reception
static func _build_terrain_mesh_v2(terrain_data: Dictionary) -> StaticBody3D:
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

	# V2: Enhanced material with better shadow reception
	var material = StandardMaterial3D.new()

	# Slightly darker snow to make shadows more visible
	material.albedo_color = Color(0.88, 0.88, 0.92)  # Darker than v1 (was 0.95)
	material.roughness = 0.5  # Increased roughness for better shadow definition
	material.metallic = 0.0

	# Reduced emission to enhance shadow contrast
	material.emission_enabled = true
	material.emission = Color(0.75, 0.75, 0.8)  # Darker emission
	material.emission_energy_multiplier = 0.08  # Reduced from 0.15

	# Critical: PER_PIXEL shading for proper shadow reception
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# receive shadows (hnuikim)
	material.disable_receive_shadows = false
	print("[TerrainV2] Terrain material shadow receive disabled? %s" % [material.disable_receive_shadows])

	array_mesh.surface_set_material(0, material)

	# Create MeshInstance3D with shadow settings
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh

	# V2: Enhanced shadow settings
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC  # Enable shadow reception
	mesh_instance.gi_lightmap_scale = GeometryInstance3D.LIGHTMAP_SCALE_2X  # Better quality
	mesh_instance.visibility_range_end_margin = 0.0
	mesh_instance.name = "TerrainMeshV2"

	# Create StaticBody3D with collision
	var static_body = StaticBody3D.new()
	static_body.name = "TerrainV2"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0
	static_body.add_to_group("terrain_static")

	# Create collision shape from mesh
	var collision_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	var faces = mesh_instance.mesh.get_faces()
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape

	# Raise collision shape above visual mesh so skis appear on top of snow
	collision_shape.position.y = 0.5  # 50cm above visual terrain

	print("[TerrainV2] Collision shape created: %d faces" % [faces.size() / 3])
	print("[TerrainV2] Shadow settings: cast=%s, gi_mode=STATIC, receive_disabled=%s" % [mesh_instance.cast_shadow, material.disable_receive_shadows])

	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)

	# Add debug boundary markers
	TerrainGenerator._add_debug_boundaries(static_body, width_m, terrain_data.get("length_m", 1500))

	return static_body


## V2: Enhanced obstacles with shadow casting enabled
static func _build_obstacles_v2(obstacles_data: Array) -> Node3D:
	var obstacles_node = Node3D.new()
	obstacles_node.name = "ObstaclesV2"

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
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
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
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON  # V2: Enable shadows

			var trunk_mat = StandardMaterial3D.new()
			trunk_mat.albedo_color = Color(0.3, 0.2, 0.15)
			trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			trunk_mesh.surface_set_material(0, trunk_mat)

			var foliage = MeshInstance3D.new()
			var foliage_mesh = SphereMesh.new()
			foliage_mesh.radius = 2.0 * scale_val
			foliage_mesh.height = 3.0 * scale_val
			foliage.mesh = foliage_mesh
			foliage.position = Vector3(0, 4.0 * scale_val, 0)
			foliage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON  # V2: Enable shadows

			var foliage_mat = StandardMaterial3D.new()
			foliage_mat.albedo_color = Color(0.1, 0.4, 0.2)
			foliage_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			foliage_mesh.surface_set_material(0, foliage_mat)

			mesh_instance.name = "Tree"
			mesh_instance.add_child(trunk)
			mesh_instance.add_child(foliage)

		# V2: Enable shadow casting for all obstacles
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.position = Vector3(pos[0], pos[1], pos[2])
		obstacles_node.add_child(mesh_instance)

	print("[TerrainV2] Obstacles created with shadow casting enabled: %d obstacles" % obstacles_data.size())
	return obstacles_node
