extends Node
class_name TerrainGeneratorV2

## Generates flat terrain optimized for shadow reception
## Simplified version focused on shadow rendering quality

## Creates a flat terrain with optimal shadow settings
## @param width_m: Width of terrain in meters (default: 500)
## @param length_m: Length of terrain in meters (default: 1500)
## @param height_y: Height position of terrain (default: 0)
## @return StaticBody3D containing the terrain mesh and collision
static func create_flat_terrain(width_m: float = 500.0, length_m: float = 1500.0, height_y: float = 0.0) -> StaticBody3D:
	print("[TerrainV2] Creating flat terrain: %.1fx%.1f meters at Y=%.1f" % [width_m, length_m, height_y])

	# Mesh resolution (vertices per axis)
	var segments_x = 100
	var segments_z = 300

	# Build flat terrain mesh
	var terrain_mesh = _build_flat_mesh(width_m, length_m, height_y, segments_x, segments_z)

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

	return static_body


## Builds a flat rectangular mesh at specified height
static func _build_flat_mesh(width_m: float, length_m: float, height_y: float, segments_x: int, segments_z: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Calculate step size
	var step_x = width_m / float(segments_x)
	var step_z = length_m / float(segments_z)

	# Start position (centered on X, forward on Z)
	var start_x = -width_m / 2.0
	var start_z = 50.0  # Match original z_offset

	# Generate vertices
	for z in range(segments_z + 1):
		for x in range(segments_x + 1):
			var pos_x = start_x + x * step_x
			var pos_z = start_z - z * step_z

			vertices.append(Vector3(pos_x, height_y, pos_z))
			normals.append(Vector3.UP)  # All normals point up for flat terrain

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
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	print("[TerrainV2] Flat mesh created: %d vertices, %d triangles" % [vertices.size(), indices.size() / 3])

	return array_mesh


## Creates a material optimized for receiving shadows
static func _create_shadow_optimized_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Pure white albedo for maximum shadow visibility
	# Gray colors reduce shadow contrast
	material.albedo_color = Color(1.0, 1.0, 1.0)

	# Smooth surface for clean shadow edges
	material.roughness = 0.3
	material.metallic = 0.0

	# Disable emission to improve shadow contrast
	material.emission_enabled = false

	# Per-pixel shading required for proper shadow rendering
	# SHADING_MODE_UNSHADED would disable shadows completely
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	return material
