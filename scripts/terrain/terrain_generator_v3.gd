extends Node
class_name TerrainGeneratorV3

## Generates bumpy terrain with heightmap (like V1 but simpler)
## Uses V2's material and shadow settings

## Creates a bumpy terrain with noise-based height variation
## @param width_m: Width of terrain in meters (default: 500)
## @param length_m: Length of terrain in meters (default: 1500)
## @return StaticBody3D containing the terrain mesh and collision
static func create_bumpy_terrain(width_m: float = 500.0, length_m: float = 1500.0) -> StaticBody3D:
	print("[TerrainV3] Creating bumpy terrain: %.1fx%.1f meters" % [width_m, length_m])

	# Mesh resolution
	var cell_size = 2.0
	var segments_x = int(width_m / cell_size)
	var segments_z = int(length_m / cell_size)

	# Build bumpy terrain mesh
	var terrain_mesh = _build_bumpy_mesh(width_m, length_m, cell_size, segments_x, segments_z)

	# Create material (same as V2)
	var material = _create_shadow_optimized_material()
	terrain_mesh.surface_set_material(0, material)

	# Create MeshInstance3D with shadow settings
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	mesh_instance.name = "TerrainMesh"

	# Shadow settings (same as V2)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC

	# Create StaticBody3D with collision
	var static_body = StaticBody3D.new()
	static_body.name = "Terrain"
	static_body.collision_layer = 2  # Environment layer
	static_body.collision_mask = 0

	# Add to terrain group
	static_body.add_to_group("terrain")

	# Create collision shape from mesh
	var collision_shape = CollisionShape3D.new()
	var concave_shape = ConcavePolygonShape3D.new()
	var faces = mesh_instance.mesh.get_faces()
	concave_shape.set_faces(faces)
	collision_shape.shape = concave_shape

	# 1cm collision offset (like V1)
	collision_shape.position.y = 0.01

	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)

	print("[TerrainV3] Terrain created: %d faces, collision enabled" % [faces.size() / 3])

	return static_body


## Builds a bumpy mesh with noise-based height variation
static func _build_bumpy_mesh(width_m: float, length_m: float, cell_size: float, segments_x: int, segments_z: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Start position
	var start_x = -width_m / 2.0
	var start_z = 50.0  # Match V2 z_offset

	# Noise parameters for bumpiness
	var noise_scale = 0.02  # Lower = larger features
	var noise_amplitude = 15.0  # Height variation

	# Generate random phase offsets for noise variety
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var phase_x = rng.randf() * 1000.0
	var phase_z = rng.randf() * 1000.0

	# Generate vertices with height variation
	for z in range(segments_z + 1):
		for x in range(segments_x + 1):
			var pos_x = start_x + x * cell_size
			var pos_z = start_z - z * cell_size

			# Multi-octave noise for natural-looking terrain
			var noise_val = 0.0

			# Large features
			noise_val += sin((pos_x + phase_x) * noise_scale * 0.5) * cos((pos_z + phase_z) * noise_scale * 0.5) * noise_amplitude * 0.6

			# Medium features
			noise_val += sin((pos_x + phase_x) * noise_scale) * cos((pos_z + phase_z) * noise_scale) * noise_amplitude * 0.3

			# Small details
			noise_val += sin((pos_x + phase_x) * noise_scale * 2.0) * cos((pos_z + phase_z) * noise_scale * 2.0) * noise_amplitude * 0.1

			var pos_y = noise_val

			vertices.append(Vector3(pos_x, pos_y, pos_z))

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

			# First triangle
			indices.append(top_left)
			indices.append(bottom_left)
			indices.append(top_right)

			# Second triangle
			indices.append(top_right)
			indices.append(bottom_left)
			indices.append(bottom_right)

	# Calculate normals (per-vertex from triangles)
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.UP  # Initialize

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

	print("[TerrainV3] Bumpy mesh created: %d vertices, %d triangles" % [vertices.size(), indices.size() / 3])

	return array_mesh


## Creates a material optimized for receiving shadows (same as V2)
static func _create_shadow_optimized_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Pure white albedo for maximum shadow visibility
	material.albedo_color = Color(1.0, 1.0, 1.0)

	# Smooth surface for clean shadow edges
	material.roughness = 0.3
	material.metallic = 0.0

	# Disable emission to improve shadow contrast
	material.emission_enabled = false

	# Per-pixel shading required for proper shadow rendering
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	return material
