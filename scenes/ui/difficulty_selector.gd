extends Control

## Difficulty selector UI for terrain generation
## Emits signals when difficulty is changed

signal difficulty_changed(new_difficulty: String)
signal regenerate_requested()

@onready var _easy_button: Button = $VBoxContainer/EasyButton
@onready var _medium_button: Button = $VBoxContainer/MediumButton
@onready var _hard_button: Button = $VBoxContainer/HardButton
@onready var _regenerate_button: Button = $VBoxContainer/RegenerateButton
@onready var _current_label: Label = $VBoxContainer/CurrentLabel

var _current_difficulty: String = "medium"


func _ready() -> void:
	_easy_button.pressed.connect(_on_easy_pressed)
	_medium_button.pressed.connect(_on_medium_pressed)
	_hard_button.pressed.connect(_on_hard_pressed)
	_regenerate_button.pressed.connect(_on_regenerate_pressed)

	_update_button_states()


func _on_easy_pressed() -> void:
	_current_difficulty = "easy"
	_update_button_states()
	difficulty_changed.emit("easy")
	print("[UI] Difficulty set to: EASY")


func _on_medium_pressed() -> void:
	_current_difficulty = "medium"
	_update_button_states()
	difficulty_changed.emit("medium")
	print("[UI] Difficulty set to: MEDIUM")


func _on_hard_pressed() -> void:
	_current_difficulty = "hard"
	_update_button_states()
	difficulty_changed.emit("hard")
	print("[UI] Difficulty set to: HARD")


func _on_regenerate_pressed() -> void:
	regenerate_requested.emit()
	print("[UI] Regenerate terrain requested with difficulty: %s" % _current_difficulty.to_upper())


func _update_button_states() -> void:
	# Visual feedback for selected difficulty
	_easy_button.disabled = (_current_difficulty == "easy")
	_medium_button.disabled = (_current_difficulty == "medium")
	_hard_button.disabled = (_current_difficulty == "hard")

	_current_label.text = "Current: %s" % _current_difficulty.to_upper()


func get_current_difficulty() -> String:
	return _current_difficulty
