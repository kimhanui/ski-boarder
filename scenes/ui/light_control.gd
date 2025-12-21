extends VBoxContainer

## UI control for adjusting DirectionalLight3D angle and shadow settings (V3 only)

var directional_light: DirectionalLight3D = null
var procedural_slope: Node3D = null
var was_v3: bool = false  # Track previous V3 state

@onready var pitch_label: Label = $PitchLabel
@onready var pitch_slider: HSlider = $PitchSlider

# Shadow test mode button
var shadow_test_button: Button = null

# V3-only shadow settings UI (dynamically created)
var shadow_ui_container: VBoxContainer = null
var shadow_enabled_checkbox: CheckBox = null
var shadow_opacity_slider: HSlider = null
var shadow_bias_slider: HSlider = null
var shadow_normal_bias_slider: HSlider = null
var shadow_max_distance_slider: HSlider = null
var shadow_fade_start_slider: HSlider = null

# Labels for sliders
var shadow_opacity_label: Label = null
var shadow_bias_label: Label = null
var shadow_normal_bias_label: Label = null
var shadow_max_distance_label: Label = null
var shadow_fade_start_label: Label = null


func _ready() -> void:
	# Connect slider signals
	pitch_slider.value_changed.connect(_on_pitch_changed)

	# Disable all focus on pitch slider (mouse drag only)
	pitch_slider.focus_mode = Control.FOCUS_NONE

	# Create shadow test mode button (always visible)
	_create_shadow_test_button()

	# Create shadow settings UI (V3 only, initially hidden)
	_create_shadow_ui()

	print("[LightControl] Light control UI initialized")


## Set the DirectionalLight3D to control
func set_light(light: DirectionalLight3D) -> void:
	directional_light = light

	if directional_light:
		# Set initial slider values from current light settings
		var current_rotation = directional_light.rotation_degrees
		pitch_slider.value = current_rotation.x

		# Update labels
		_update_labels()

		print("[LightControl] Connected to DirectionalLight3D")


func _on_pitch_changed(value: float) -> void:
	if directional_light:
		directional_light.rotation_degrees.x = value
		_update_labels()


func _update_labels() -> void:
	pitch_label.text = "Light Pitch (상하): %.0f°" % pitch_slider.value

	# Update shadow setting labels
	if shadow_opacity_label and shadow_opacity_slider:
		shadow_opacity_label.text = "Opacity: %.2f" % shadow_opacity_slider.value
	if shadow_bias_label and shadow_bias_slider:
		shadow_bias_label.text = "Bias: %.3f" % shadow_bias_slider.value
	if shadow_normal_bias_label and shadow_normal_bias_slider:
		shadow_normal_bias_label.text = "Normal Bias: %.2f" % shadow_normal_bias_slider.value
	if shadow_max_distance_label and shadow_max_distance_slider:
		shadow_max_distance_label.text = "Max Distance: %.0fm" % shadow_max_distance_slider.value
	if shadow_fade_start_label and shadow_fade_start_slider:
		shadow_fade_start_label.text = "Fade Start: %.2f" % shadow_fade_start_slider.value


## Set the ProceduralSlope reference for V3 detection
func set_procedural_slope(slope: Node3D) -> void:
	procedural_slope = slope
	print("[LightControl] Connected to ProceduralSlope")


## Check if V3 terrain is active and show/hide shadow UI
func _process(_delta: float) -> void:
	if procedural_slope and shadow_ui_container:
		var is_v3 = (procedural_slope.terrain_version == 2)
		var is_test_mode = procedural_slope.get("shadow_test_mode") if procedural_slope else false

		# V3 AND test mode에서만 shadow settings 표시
		shadow_ui_container.visible = is_v3 and is_test_mode

		# Apply V3 shadow settings when switching to V3 (only on transition)
		if is_v3 and not was_v3 and directional_light:
			_apply_v3_shadow_settings()

		was_v3 = is_v3


## Create shadow settings UI (V3 only)
func _create_shadow_ui() -> void:
	# Create container
	shadow_ui_container = VBoxContainer.new()
	shadow_ui_container.name = "ShadowSettings"
	shadow_ui_container.visible = false  # Initially hidden
	add_child(shadow_ui_container)

	# Separator
	var separator = HSeparator.new()
	shadow_ui_container.add_child(separator)

	# Header
	var header = Label.new()
	header.text = "=== Shadow Settings (V3 Only) ==="
	header.add_theme_font_size_override("font_size", 14)
	shadow_ui_container.add_child(header)

	# Shadow Enabled CheckBox
	shadow_enabled_checkbox = CheckBox.new()
	shadow_enabled_checkbox.text = "Shadow Enabled"
	shadow_enabled_checkbox.button_pressed = true
	shadow_enabled_checkbox.focus_mode = Control.FOCUS_NONE  # No keyboard input
	shadow_enabled_checkbox.toggled.connect(_on_shadow_enabled_toggled)
	shadow_ui_container.add_child(shadow_enabled_checkbox)

	# Shadow Opacity Slider
	shadow_opacity_label = Label.new()
	shadow_ui_container.add_child(shadow_opacity_label)
	shadow_opacity_slider = _create_slider(0.0, 1.0, 0.01, 0.8)
	shadow_opacity_slider.value_changed.connect(_on_shadow_opacity_changed)
	shadow_ui_container.add_child(shadow_opacity_slider)

	# Shadow Bias Slider
	shadow_bias_label = Label.new()
	shadow_ui_container.add_child(shadow_bias_label)
	shadow_bias_slider = _create_slider(0.0, 1.0, 0.01, 0.03)
	shadow_bias_slider.value_changed.connect(_on_shadow_bias_changed)
	shadow_ui_container.add_child(shadow_bias_slider)

	# Shadow Normal Bias Slider
	shadow_normal_bias_label = Label.new()
	shadow_ui_container.add_child(shadow_normal_bias_label)
	shadow_normal_bias_slider = _create_slider(0.0, 2.0, 0.1, 0.3)
	shadow_normal_bias_slider.value_changed.connect(_on_shadow_normal_bias_changed)
	shadow_ui_container.add_child(shadow_normal_bias_slider)

	# Shadow Max Distance Slider
	shadow_max_distance_label = Label.new()
	shadow_ui_container.add_child(shadow_max_distance_label)
	shadow_max_distance_slider = _create_slider(50.0, 500.0, 10.0, 180.0)
	shadow_max_distance_slider.value_changed.connect(_on_shadow_max_distance_changed)
	shadow_ui_container.add_child(shadow_max_distance_slider)

	# Shadow Fade Start Slider
	shadow_fade_start_label = Label.new()
	shadow_ui_container.add_child(shadow_fade_start_label)
	shadow_fade_start_slider = _create_slider(0.0, 1.0, 0.05, 0.9)
	shadow_fade_start_slider.value_changed.connect(_on_shadow_fade_start_changed)
	shadow_ui_container.add_child(shadow_fade_start_slider)

	# Update labels
	_update_labels()

	print("[LightControl] Shadow UI created")


## Create slider helper
func _create_slider(min_val: float, max_val: float, step: float, default_val: float) -> HSlider:
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.custom_minimum_size = Vector2(200, 0)
	slider.focus_mode = Control.FOCUS_NONE  # No focus, mouse drag only
	return slider


## Apply V3 shadow settings
func _apply_v3_shadow_settings() -> void:
	if not directional_light:
		return

	directional_light.shadow_enabled = true
	directional_light.shadow_opacity = 0.8
	directional_light.shadow_bias = 0.03
	directional_light.shadow_normal_bias = 0.3
	directional_light.directional_shadow_max_distance = 180.0
	directional_light.directional_shadow_fade_start = 0.9

	print("[LightControl] Applied V3 shadow settings")


## Shadow setting change handlers
func _on_shadow_enabled_toggled(enabled: bool) -> void:
	if directional_light:
		directional_light.shadow_enabled = enabled


func _on_shadow_opacity_changed(value: float) -> void:
	if directional_light:
		directional_light.shadow_opacity = value
		_update_labels()


func _on_shadow_bias_changed(value: float) -> void:
	if directional_light:
		directional_light.shadow_bias = value
		_update_labels()


func _on_shadow_normal_bias_changed(value: float) -> void:
	if directional_light:
		directional_light.shadow_normal_bias = value
		_update_labels()


func _on_shadow_max_distance_changed(value: float) -> void:
	if directional_light:
		directional_light.directional_shadow_max_distance = value
		_update_labels()


func _on_shadow_fade_start_changed(value: float) -> void:
	if directional_light:
		directional_light.directional_shadow_fade_start = value
		_update_labels()


## Create shadow test mode button
func _create_shadow_test_button() -> void:
	shadow_test_button = Button.new()
	shadow_test_button.text = "지형그림자테스트: OFF"
	shadow_test_button.toggle_mode = true
	shadow_test_button.button_pressed = false
	shadow_test_button.focus_mode = Control.FOCUS_NONE  # No keyboard input
	shadow_test_button.toggled.connect(_on_shadow_test_toggled)
	add_child(shadow_test_button)

	print("[LightControl] Shadow test button created")


## Shadow test mode toggle handler
func _on_shadow_test_toggled(enabled: bool) -> void:
	if procedural_slope and procedural_slope.has_method("set_shadow_test_mode"):
		procedural_slope.set_shadow_test_mode(enabled)
		shadow_test_button.text = "지형그림자테스트: " + ("ON" if enabled else "OFF")

		# Notify Main scene (player/camera switching)
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("_on_shadow_test_mode_changed"):
			main._on_shadow_test_mode_changed(enabled)
