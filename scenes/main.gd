extends Node3D

## Main scene controller
## Manages camera switching and terrain regeneration

@onready var player: CharacterBody3D = $Player
@onready var procedural_slope: Node3D = $ProceduralSlope
@onready var difficulty_selector: Control = $UI/DifficultySelector
@onready var free_camera: Camera3D = $FreeCamera

var _is_free_camera_active: bool = false


func _ready() -> void:
	# Connect UI signals
	if difficulty_selector:
		difficulty_selector.difficulty_changed.connect(_on_difficulty_changed)
		difficulty_selector.regenerate_requested.connect(_on_regenerate_requested)

	print("Main scene initialized")
	print("Press Tab to toggle free camera mode")


func _input(event: InputEvent) -> void:
	# Tab key to toggle free camera
	if event.is_action_pressed("toggle_camera"):
		_toggle_free_camera()


func _toggle_free_camera() -> void:
	_is_free_camera_active = not _is_free_camera_active

	if _is_free_camera_active:
		# Switch to free camera
		player.set_cameras_active(false)
		free_camera.activate()
	else:
		# Switch back to player camera
		free_camera.deactivate()
		player.set_cameras_active(true)


func _on_difficulty_changed(new_difficulty: String) -> void:
	print("[Main] Difficulty changed to: %s" % new_difficulty)
	# Difficulty is set, will be used on next regeneration


func _on_regenerate_requested() -> void:
	print("[Main] Regenerating terrain...")

	# Get current difficulty from UI
	var current_difficulty = difficulty_selector.get_current_difficulty()

	# Regenerate terrain
	procedural_slope.regenerate_terrain(current_difficulty)

	print("[Main] Terrain regeneration complete!")
