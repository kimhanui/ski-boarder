extends VBoxContainer

## UI control for adjusting DirectionalLight3D angle

var directional_light: DirectionalLight3D = null

@onready var pitch_label: Label = $PitchLabel
@onready var pitch_slider: HSlider = $PitchSlider


func _ready() -> void:
	# Connect slider signals
	pitch_slider.value_changed.connect(_on_pitch_changed)

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
