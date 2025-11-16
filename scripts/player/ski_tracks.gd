extends Node3D
class_name SkiTracks

## Ski track/footprint system using Decal approach
## Creates visual trails that fade over time

signal tracks_updated(track_count: int)

@export var player: CharacterBody3D  # Reference to player
@export var max_tracks := 500  # Maximum number of track decals
@export var track_lifetime := 30.0  # Fade time (seconds)
@export var track_width := 2.0  # Width of ski track (enlarged for testing)
@export var track_length := 5.0  # Length of ski track (enlarged for testing)

# Decal material
var track_material: StandardMaterial3D

# Active track decals
var active_tracks: Array[Dictionary] = []  # {decal: Decal, spawn_time: float, position: Vector3}

# Track mesh (simple quad)
var track_mesh: Mesh


func _ready() -> void:
	_create_track_material()
	_create_track_mesh()

	if not player:
		push_warning("SkiTracks: No player reference set!")


## Create material for ski tracks
func _create_track_material() -> void:
	track_material = StandardMaterial3D.new()

	# Bright red for testing visibility
	track_material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)

	# Transparent for fading
	track_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	track_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX

	# No emission
	track_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Create simple quad mesh for track
func _create_track_mesh() -> void:
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(track_width, track_length)
	track_mesh = quad_mesh


func _process(delta: float) -> void:
	# Update and fade tracks
	_update_tracks(delta)


## Create simple track texture (gradient)
func _create_track_texture() -> Texture2D:
	# Create simple white texture (decal will modulate color)
	var image = Image.create(32, 64, false, Image.FORMAT_RGBA8)

	# Fill with gradient (darker in center, lighter at edges)
	for y in range(64):
		for x in range(32):
			var dist_from_center = abs(x - 16) / 16.0
			var alpha = 1.0 - (dist_from_center * 0.5)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(image)


## Update tracks and fade old ones
func _update_tracks(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check tracks from oldest to newest
	var i = 0
	while i < active_tracks.size():
		var track_data = active_tracks[i]
		var age = current_time - track_data["spawn_time"]

		if age >= track_lifetime:
			# Remove expired track
			_remove_track(i)
			# Don't increment i, check same index again
		else:
			# Fade track based on age (works for both Decal and MeshInstance3D)
			var fade_progress = age / track_lifetime
			var node = track_data["decal"]  # Can be Decal or MeshInstance3D

			# Try to fade (works for MeshInstance3D material)
			if node is MeshInstance3D:
				var mat = node.material_override as StandardMaterial3D
				if mat:
					var alpha = 1.0 - fade_progress
					mat.albedo_color.a = alpha
			elif node is Decal:
				var alpha = 1.0 - fade_progress
				node.modulate.a = alpha

			i += 1


## Remove track at index
func _remove_track(index: int) -> void:
	if index < 0 or index >= active_tracks.size():
		return

	var track_data = active_tracks[index]
	var node = track_data["decal"]  # Can be Decal or MeshInstance3D

	# Remove from scene
	if node:
		node.queue_free()

	# Remove from array
	active_tracks.remove_at(index)

	tracks_updated.emit(active_tracks.size())


## Clear all tracks
func clear_tracks() -> void:
	for track_data in active_tracks:
		var decal: Decal = track_data["decal"]
		if decal:
			decal.queue_free()

	active_tracks.clear()
	tracks_updated.emit(0)


## Get current track count
func get_track_count() -> int:
	return active_tracks.size()


## Set track lifetime
func set_track_lifetime(seconds: float) -> void:
	track_lifetime = max(10.0, seconds)  # Minimum 10 seconds


## Create track at specific position with custom size (called from player collision detection)
func create_track_at_position(pos: Vector3, size: Vector3, part_name: String):
	# Remove oldest track if at limit
	if active_tracks.size() >= max_tracks:
		_remove_track(0)

	# Create MeshInstance3D (using debug red box)
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(size.x * 0.5, size.y, size.z)  # Width 50% thinner
	mesh_instance.mesh = box_mesh

	# Bright red unshaded material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0)
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material

	# Position slightly above ground
	mesh_instance.global_position = pos + Vector3(0, 0.05, 0)
	mesh_instance.rotation.y = player.rotation.y if player else 0.0

	# Add to scene root (independent of player)
	get_tree().root.add_child(mesh_instance)

	# Track for fading
	active_tracks.append({
		"decal": mesh_instance,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"position": pos
	})

	tracks_updated.emit(active_tracks.size())
