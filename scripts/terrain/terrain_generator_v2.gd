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
## @return StaticBody3D containing the terrain mesh and collision
static func create_flat_terrain(width_m: float = 500.0, length_m: float = 1500.0, height_y: float = 0.0, slope_angle_deg: float = 20.0) -> StaticBody3D:
	print("[TerrainV2] Creating sloped terrain: %.1fx%.1f meters at Y=%.1f, slope=%.1f°" % [width_m, length_m, height_y, slope_angle_deg])

	# Mesh resolution (vertices per axis)
	var segments_x = 100
	var segments_z = 300

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

	# Generate obstacles (rocks and trees)
	_generate_obstacles(static_body, width_m, length_m, slope_angle_deg)

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
	var hole_positions = [
		Vector3(-30, 0, -40),    # Left-top
		Vector3(25, 0, -60),     # Right-middle
		Vector3(0, 0, -80),      # Center
		Vector3(-35, 0, -100),   # Left-bottom
		Vector3(30, 0, -120),    # Right-bottom
	]
	var hole_radius = 12.0  # Meters (smaller)
	var hole_depth = 3.0    # Meters at center (shallower)

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

			# Calculate vertex color (green in holes, gray outside)
			var base_color = Color(0.6, 0.6, 0.6)      # Darker gray snow (60% brightness)
			var hole_color = Color(0.15, 0.5, 0.15)    # Very dark green (forest green)
			var vertex_color = base_color.lerp(hole_color, hole_color_intensity)

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
static func _generate_obstacles(terrain: StaticBody3D, width_m: float, length_m: float, slope_angle_deg: float, seed_value: int = 12345) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Obstacle configuration
	var obstacle_count = 15  # Similar to V1
	var start_z = 50.0  # Match mesh generation
	var slope_angle_rad = deg_to_rad(slope_angle_deg)
	var slope_ratio = tan(slope_angle_rad)

	var obstacles_node = Node3D.new()
	obstacles_node.name = "Obstacles"

	for i in range(obstacle_count):
		# Random position across terrain
		var x = rng.randf_range(-width_m/2.0 + 10.0, width_m/2.0 - 10.0)
		var z = rng.randf_range(-length_m + 60, -10)  # Avoid spawn area and far edge

		# Calculate height based on slope
		var z_distance = start_z - z
		var y_drop = z_distance * slope_ratio
		var y = -y_drop + 1.0  # Slight elevation above ground

		# Random obstacle type and scale
		var type = "rock" if rng.randf() > 0.4 else "tree"
		var scale_val = rng.randf_range(0.8, 1.5)

		# Create obstacle mesh
		var obstacle = _create_obstacle_mesh(type, scale_val)
		obstacle.position = Vector3(x, y, z)
		obstacles_node.add_child(obstacle)

	terrain.add_child(obstacles_node)
	print("[TerrainV2] Generated %d obstacles" % obstacle_count)


## Creates a single obstacle mesh (rock or tree)
static func _create_obstacle_mesh(type: String, scale_val: float) -> MeshInstance3D:
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

	return mesh_instance
