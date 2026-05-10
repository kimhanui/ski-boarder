extends Area3D
class_name FinishLineDetector

## Detects when player reaches finish line and triggers celebration

func _ready() -> void:
	# Connect to body_entered signal
	body_entered.connect(_on_body_entered)
	print("[FinishLineDetector] Finish line detector ready at position: ", global_position)
	print("[FinishLineDetector] Collision layer: ", collision_layer, " mask: ", collision_mask)


func _on_body_entered(body: Node3D) -> void:
	print("[FinishLineDetector] Body entered! Name: ", body.name, " Type: ", body.get_class())

	# Check if it's the player
	if body.name == "Player" or body is CharacterBody3D:
		print("[FinishLineDetector] Confirmed it's the player!")
		_trigger_celebration()
	else:
		print("[FinishLineDetector] Not the player, ignoring")


func _trigger_celebration() -> void:
	print("[FinishLineDetector] Player reached finish line! 🎉")

	# Find the active camera
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("[FinishLineDetector] ERROR: Could not find camera!")
		return

	# Create "Success!" UI text
	_create_success_text()

	# Create celebration effect with animated colored spheres
	var celebration_container = Node3D.new()
	celebration_container.name = "CelebrationEffect"
	camera.add_child(celebration_container)
	celebration_container.position = Vector3(0, 0, -8.0)  # 8m in front of camera

	# Create multiple colored spheres
	var colors = [
		Color.RED,
		Color.ORANGE,
		Color.YELLOW,
		Color.GREEN,
		Color.CYAN,
		Color.BLUE,
		Color.MAGENTA
	]

	for i in range(30):  # 30 spheres
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.5
		sphere.mesh = sphere_mesh

		var mat = StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere_mesh.surface_set_material(0, mat)

		# Start at center
		sphere.position = Vector3.ZERO

		# Calculate final position in a sphere pattern
		var angle1 = randf() * TAU
		var angle2 = randf() * PI
		var radius = randf_range(3.0, 6.0)
		var final_x = radius * sin(angle2) * cos(angle1)
		var final_y = radius * sin(angle2) * sin(angle1)
		var final_z = radius * cos(angle2)
		var final_pos = Vector3(final_x, final_y, final_z)

		celebration_container.add_child(sphere)

		# Animate sphere: spread out and fade out
		var tween = create_tween()
		tween.set_parallel(true)
		# Move to final position
		tween.tween_property(sphere, "position", final_pos, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Fade out by changing material alpha
		tween.tween_property(mat, "albedo_color:a", 0.0, 2.0).set_ease(Tween.EASE_IN)

	print("[FinishLineDetector] Created 30 animated celebration spheres!")

	# Remove celebration after animation completes
	await get_tree().create_timer(2.5).timeout
	if celebration_container:
		celebration_container.queue_free()
		print("[FinishLineDetector] Celebration effect removed")


func _create_success_text() -> void:
	# Create UI layer for "Success!" text
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SuccessUI"
	get_tree().root.add_child(canvas_layer)

	# Create centered label
	var label = Label.new()
	label.text = "Success!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at screen center
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -50
	label.offset_bottom = 50

	# Style: Large golden text
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)

	canvas_layer.add_child(label)

	# Animate: Fade in, hold, fade out
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)  # Fade in
	tween.tween_interval(2.0)  # Hold for 2 seconds
	tween.tween_property(label, "modulate:a", 0.0, 0.5)  # Fade out

	# Remove after animation
	await get_tree().create_timer(3.0).timeout
	if canvas_layer:
		canvas_layer.queue_free()
		print("[FinishLineDetector] Success text removed")
