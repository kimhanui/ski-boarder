extends VBoxContainer
class_name DensityControls

## UI controls for obstacle density mode switching
## Displays 3 toggle buttons: sparse, normal, dense

signal density_mode_changed(mode: String)

@export var obstacle_factory: ObstacleFactory  # Reference to obstacle factory

# Button references
var sparse_button: Button
var normal_button: Button
var dense_button: Button
var status_label: Label  # Status label for obstacle count

# Current active mode
var current_mode := "normal"


func _ready() -> void:
	_create_buttons()
	_set_active_button("normal")

	if not obstacle_factory:
		push_warning("DensityControls: No obstacle_factory reference set!")
	else:
		# Connect to density change signal
		obstacle_factory.density_changed.connect(_on_density_changed)

	# Update initial status
	_update_status_label()


## Create density mode buttons
func _create_buttons() -> void:
	# Container settings
	custom_minimum_size = Vector2(80, 120)
	size = Vector2(80, 120)

	# Anchor to top-right, below minimap
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -100  # 20px margin from edge
	offset_top = 220  # Below minimap (180px + 20px margin + 20px gap)
	offset_right = -20
	offset_bottom = 340

	# Add label
	var label = Label.new()
	label.text = "Density"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)

	# Sparse button
	sparse_button = Button.new()
	sparse_button.text = "Sparse"
	sparse_button.toggle_mode = true
	sparse_button.custom_minimum_size = Vector2(80, 30)
	sparse_button.pressed.connect(_on_sparse_pressed)
	add_child(sparse_button)

	# Normal button
	normal_button = Button.new()
	normal_button.text = "Normal"
	normal_button.toggle_mode = true
	normal_button.custom_minimum_size = Vector2(80, 30)
	normal_button.pressed.connect(_on_normal_pressed)
	add_child(normal_button)

	# Dense button
	dense_button = Button.new()
	dense_button.text = "Dense"
	dense_button.toggle_mode = true
	dense_button.custom_minimum_size = Vector2(80, 30)
	dense_button.pressed.connect(_on_dense_pressed)
	add_child(dense_button)

	# Status label
	status_label = Label.new()
	status_label.text = "10 near player"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(80, 40)
	add_child(status_label)


## Sparse mode pressed
func _on_sparse_pressed() -> void:
	_set_density_mode("sparse")


## Normal mode pressed
func _on_normal_pressed() -> void:
	_set_density_mode("normal")


## Dense mode pressed
func _on_dense_pressed() -> void:
	_set_density_mode("dense")


## Set density mode
func _set_density_mode(mode: String) -> void:
	if mode == current_mode:
		return

	current_mode = mode
	_set_active_button(mode)

	# Update obstacle factory
	if obstacle_factory:
		obstacle_factory.set_obstacle_density(mode)

	# Update status label
	_update_status_label()

	# Emit signal
	density_mode_changed.emit(mode)


## Set active button visual state
func _set_active_button(mode: String) -> void:
	# Deactivate all
	sparse_button.button_pressed = false
	normal_button.button_pressed = false
	dense_button.button_pressed = false

	# Activate selected
	match mode:
		"sparse":
			sparse_button.button_pressed = true
		"normal":
			normal_button.button_pressed = true
		"dense":
			dense_button.button_pressed = true


## Get current density mode
func get_current_mode() -> String:
	return current_mode


## Set button enabled state
func set_buttons_enabled(enabled: bool) -> void:
	sparse_button.disabled = not enabled
	normal_button.disabled = not enabled
	dense_button.disabled = not enabled


## Handle density change signal from ObstacleFactory
func _on_density_changed(mode: String) -> void:
	_update_status_label()


## Update status label based on current mode
func _update_status_label() -> void:
	if not status_label:
		return

	match current_mode:
		"sparse":
			status_label.text = "2 obstacles\n(sparse)"
		"normal":
			status_label.text = "10 near player\n(NORMAL)"
		"dense":
			status_label.text = "20 obstacles\n(dense)"
		_:
			status_label.text = "Unknown"
