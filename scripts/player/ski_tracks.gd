extends Node3D
class_name SkiTracks

## Ski track/footprint system using Decal approach
## Creates visual trails that fade over time

signal tracks_updated(track_count: int)

@export var player: CharacterBody3D  # Reference to player
@export var max_tracks := 30  # Maximum number of track decals (FIFO)

# MultiMesh system for performance
var multi_mesh_instance: MultiMeshInstance3D
var multi_mesh: MultiMesh
var current_track_index: int = 0


func _ready() -> void:
	_initialize_multi_mesh()

	if not player:
		push_warning("SkiTracks: No player reference set!")


## Initialize MultiMesh system for high-performance track rendering
func _initialize_multi_mesh() -> void:
	# Create MultiMesh
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = max_tracks

	# Create shared mesh (ski size: 0.075m width × 0.05m height × 1.2m length)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.075, 0.05, 1.2)
	multi_mesh.mesh = box_mesh

	# Create MultiMeshInstance3D
	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Create material (light gray unshaded)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.7, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.7, 0.7, 0.7)
	material.emission_energy_multiplier = 2.0
	multi_mesh_instance.material_override = material

	# Add to scene
	get_tree().root.add_child(multi_mesh_instance)

	# Initialize all instances as invisible (move far away)
	for i in range(max_tracks):
		var t = Transform3D()
		t.origin = Vector3(0, -1000, 0)  # Hide below terrain
		multi_mesh.set_instance_transform(i, t)

	print("[SkiTracks] MultiMesh initialized with %d slots" % max_tracks)


## Clear all tracks (hide all instances)
func clear_tracks() -> void:
	for i in range(max_tracks):
		var t = Transform3D()
		t.origin = Vector3(0, -1000, 0)  # Hide below terrain
		multi_mesh.set_instance_transform(i, t)

	current_track_index = 0
	tracks_updated.emit(0)


## Get current track count (always max_tracks after initial fill)
func get_track_count() -> int:
	return max_tracks


## Create track at specific position (MultiMesh version - high performance)
## size and part_name parameters ignored - all tracks use ski size
func create_track_at_position(pos: Vector3, size: Vector3, part_name: String):
	# Create transform for this track
	var t = Transform3D()
	t.origin = pos + Vector3(0, 0.05, 0)  # Slightly above ground

	# Rotate to match player direction
	if player:
		t.basis = t.basis.rotated(Vector3.UP, player.rotation.y)

	# Set instance transform (FIFO: overwrites oldest track)
	multi_mesh.set_instance_transform(current_track_index, t)
	multi_mesh.set_instance_color(current_track_index, Color(0.7, 0.7, 0.7, 1.0))

	# Move to next slot (circular buffer: 0→1→...→29→0)
	current_track_index = (current_track_index + 1) % max_tracks

	# Emit signal (always 30 tracks after initial fill)
	tracks_updated.emit(max_tracks)
