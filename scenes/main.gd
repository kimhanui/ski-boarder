extends Node3D

## Main scene controller
## Manages terrain regeneration

@onready var player: CharacterBody3D = $Player
@onready var procedural_slope: Node3D = $ProceduralSlope
@onready var difficulty_selector: Control = $UI/DifficultySelector
@onready var minimap: Control = $UI/Minimap
@onready var density_controls: VBoxContainer = $UI/DensityControls


func _ready() -> void:
	# Connect UI signals
	if difficulty_selector:
		difficulty_selector.difficulty_changed.connect(_on_difficulty_changed)
		difficulty_selector.regenerate_requested.connect(_on_regenerate_requested)

	# Get ObstacleFactory reference
	var obstacle_factory = null
	if procedural_slope:
		obstacle_factory = procedural_slope.get_node_or_null("ObstacleFactory")

	# Connect Minimap to Player and ObstacleFactory
	if minimap and player:
		minimap.player = player
		if obstacle_factory:
			minimap.obstacle_factory = obstacle_factory

	# Connect DensityControls to ObstacleFactory
	if density_controls and obstacle_factory:
		density_controls.obstacle_factory = obstacle_factory

	print("Main scene initialized")
	print("Press F1 to cycle camera modes")


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
