extends Node3D
class_name SkiTracks

## Ski track/footprint system using Decal approach
## Creates visual trails that fade over time

signal tracks_updated(track_count: int)

@export var player: CharacterBody3D  # Reference to player
@export var max_tracks := 200  # Maximum number of track decals
@export var track_spacing := 0.5  # Minimum distance between tracks (meters)
@export var track_lifetime := 90.0  # Fade time (seconds)
@export var track_width := 0.15  # Width of ski track
@export var track_length := 1.2  # Length of ski track

# Decal material
var track_material: StandardMaterial3D

# Active track decals
var active_tracks: Array[Dictionary] = []  # {decal: Decal, spawn_time: float, position: Vector3}

# Last track position
var last_track_position := Vector3.ZERO
var last_track_rotation := 0.0

# Track mesh (simple quad)
var track_mesh: Mesh


func _ready() -> void:
	_create_track_material()
	_create_track_mesh()

	if not player:
		push_warning("SkiTracks: No player reference set!")
	else:
		# Initialize last position to player's current position
		last_track_position = player.global_position


## Create material for ski tracks
func _create_track_material() -> void:
	track_material = StandardMaterial3D.new()

	# Dark compacted snow
	track_material.albedo_color = Color(0.7, 0.7, 0.75, 0.8)

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
	if not player or not player.is_on_floor():
		return

	# Check if player moved enough to create new track
	var player_pos = player.global_position
	var distance_moved = player_pos.distance_to(last_track_position)

	if distance_moved >= track_spacing:
		_create_track_decal(player_pos, player.rotation.y)
		last_track_position = player_pos
		last_track_rotation = player.rotation.y
		if active_tracks.size() == 1:
			print("SkiTracks: First track created at ", player_pos)

	# Update and fade tracks
	_update_tracks(delta)


## Create ski track decal at position
func _create_track_decal(pos: Vector3, yaw: float) -> void:
	# Remove oldest track if at limit
	if active_tracks.size() >= max_tracks:
		_remove_track(0)

	# Create decal node (projected onto terrain)
	var decal = Decal.new()

	# Position slightly above ground
	decal.global_position = pos + Vector3(0, 0.05, 0)

	# Rotate to match ski direction
	decal.rotation.y = yaw

	# Rotate to project downward
	decal.rotation.x = deg_to_rad(-90)

	# Set decal size (width x depth x height/projection)
	decal.size = Vector3(track_width, track_length, 1.0)

	# Set texture (use simple albedo modulation)
	decal.texture_albedo = _create_track_texture()
	decal.modulate = Color(0.7, 0.7, 0.75, 1.0)

	# Blend mode
	decal.upper_fade = 0.1
	decal.lower_fade = 0.1

	# Add to scene
	add_child(decal)

	# Track for fading
	active_tracks.append({
		"decal": decal,
		"spawn_time": Time.get_ticks_msec() / 1000.0,
		"position": pos
	})

	tracks_updated.emit(active_tracks.size())


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
			# Fade track based on age
			var fade_progress = age / track_lifetime
			var decal: Decal = track_data["decal"]

			# Fade alpha
			var alpha = 1.0 - fade_progress
			decal.modulate.a = alpha

			i += 1


## Remove track at index
func _remove_track(index: int) -> void:
	if index < 0 or index >= active_tracks.size():
		return

	var track_data = active_tracks[index]
	var decal: Decal = track_data["decal"]

	# Remove from scene
	if decal:
		decal.queue_free()

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
