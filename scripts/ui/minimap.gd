extends Control
class_name Minimap

## Minimap system with top-down orthographic view
## Shows player position, direction, and simplified terrain

signal minimap_visibility_changed(is_visible: bool)
signal minimap_zoom_changed(zoom_level: float)

@export var player: Node3D  # Reference to player
@export var obstacle_factory: Node3D  # Reference to obstacle factory
@export var minimap_size := Vector2(180, 180)  # Minimap dimensions (px)
@export var view_radius := 120.0  # How many meters around player to show
@export var zoom_level := 1.0:  # Zoom multiplier
	set(value):
		zoom_level = clamp(value, 0.5, 2.0)
		_update_camera_size()
		minimap_zoom_changed.emit(zoom_level)

# UI nodes
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var minimap_camera: Camera3D
var player_arrow: TextureRect
var obstacle_overlay: Control  # Overlay for drawing obstacle dots

# Camera follow settings
var camera_height := 150.0  # Fixed height above terrain
var camera_update_smoothing := 0.1  # Lower = smoother but more lag


func _ready() -> void:
	_setup_ui()
	_setup_viewport()
	_setup_camera()
	_create_player_arrow()
	_create_obstacle_overlay()

	if not player:
		push_warning("Minimap: No player reference set!")

	set_process(true)


## Setup UI container
func _setup_ui() -> void:
	# Self configuration (CanvasLayer child)
	custom_minimum_size = minimap_size
	size = minimap_size

	# Anchor to top-right corner
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -minimap_size.x - 20  # 20px margin
	offset_top = 20  # 20px margin
	offset_right = -20
	offset_bottom = minimap_size.y + 20


## Setup SubViewport and container
func _setup_viewport() -> void:
	# Container for viewport
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = minimap_size
	viewport_container.size = minimap_size
	add_child(viewport_container)

	# SubViewport
	sub_viewport = SubViewport.new()
	sub_viewport.name = "MinimapViewport"
	sub_viewport.size = minimap_size
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false
	viewport_container.add_child(sub_viewport)


## Setup orthographic camera
func _setup_camera() -> void:
	minimap_camera = Camera3D.new()
	minimap_camera.name = "MinimapCamera"
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = view_radius * 2.0 / zoom_level
	minimap_camera.near = 0.1
	minimap_camera.far = 300.0

	# Look straight down
	minimap_camera.rotation_degrees = Vector3(-90, 0, 0)

	sub_viewport.add_child(minimap_camera)


## Create player arrow indicator
func _create_player_arrow() -> void:
	player_arrow = TextureRect.new()
	player_arrow.name = "PlayerArrow"

	# Create simple arrow texture
	player_arrow.texture = _create_arrow_texture()

	# Center in minimap
	player_arrow.pivot_offset = Vector2(8, 8)  # Half of 16x16
	player_arrow.position = (minimap_size / 2) - Vector2(8, 8)
	player_arrow.size = Vector2(16, 16)

	# Add as overlay (not in viewport)
	add_child(player_arrow)


## Create simple arrow texture
func _create_arrow_texture() -> Texture2D:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)

	# Draw simple upward-pointing arrow (player faces forward/up on map)
	var arrow_color = Color(1, 0, 0, 1)  # Red

	# Vertical line (body)
	for y in range(4, 14):
		image.set_pixel(7, y, arrow_color)
		image.set_pixel(8, y, arrow_color)

	# Arrow head (triangle pointing up)
	for i in range(6):
		var y = 3 + i
		var x_start = 7 - i
		var x_end = 8 + i
		for x in range(x_start, x_end + 1):
			if y >= 0 and y < 16 and x >= 0 and x < 16:
				image.set_pixel(x, y, arrow_color)

	return ImageTexture.create_from_image(image)


func _process(_delta: float) -> void:
	if not player or not minimap_camera:
		return

	_follow_player()
	_update_player_arrow()
	_update_obstacle_dots()


## Follow player with camera
func _follow_player() -> void:
	var player_pos = player.global_position

	# Target position (above player)
	var target_pos = Vector3(player_pos.x, player_pos.y + camera_height, player_pos.z)

	# Smooth follow (lerp for slight delay)
	minimap_camera.global_position = minimap_camera.global_position.lerp(
		target_pos,
		camera_update_smoothing
	)


## Update player arrow rotation
func _update_player_arrow() -> void:
	if not player_arrow:
		return

	# Get player's Y rotation (yaw)
	var player_yaw = player.rotation.y

	# Rotate arrow to match player direction (arrow now points up = forward)
	# Negate rotation to match 2D coordinate system (2D rotation is opposite of 3D Y-axis)
	player_arrow.rotation = -player_yaw


## Update camera orthographic size based on zoom
func _update_camera_size() -> void:
	if minimap_camera:
		minimap_camera.size = view_radius * 2.0 / zoom_level


## Set minimap visibility
func set_minimap_visible(is_visible: bool) -> void:
	visible = is_visible
	minimap_visibility_changed.emit(is_visible)


## Set minimap zoom
func set_minimap_zoom(mult: float) -> void:
	zoom_level = mult


## Get current zoom level
func get_zoom_level() -> float:
	return zoom_level


## Toggle visibility
func toggle_visibility() -> void:
	set_minimap_visible(not visible)


## Create obstacle overlay for drawing dots
func _create_obstacle_overlay() -> void:
	obstacle_overlay = Control.new()
	obstacle_overlay.name = "ObstacleOverlay"
	obstacle_overlay.custom_minimum_size = minimap_size
	obstacle_overlay.size = minimap_size
	obstacle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obstacle_overlay)


## Update obstacle dots on overlay
func _update_obstacle_dots() -> void:
	if not obstacle_overlay:
		return

	# Clear previous frame
	obstacle_overlay.queue_redraw()

	# Connect draw signal if not connected
	if not obstacle_overlay.draw.is_connected(_draw_obstacles):
		obstacle_overlay.draw.connect(_draw_obstacles)


## Draw obstacles as grey dots
func _draw_obstacles() -> void:
	if not obstacle_factory or not player:
		return

	var player_pos = player.global_position
	var dot_color = Color(0.5, 0.5, 0.5, 0.8)  # Grey
	var dot_radius = 4.0  # Increased from 2.0 to 4.0

	# Check if in normal mode (scene-based obstacles)
	if obstacle_factory.current_density == "normal" and obstacle_factory.normal_mode_obstacles.size() > 0:
		# Draw normal mode obstacles (scene-based)
		for obstacle in obstacle_factory.normal_mode_obstacles:
			_draw_obstacle_dot(obstacle.global_position, player_pos, dot_color, dot_radius)
	else:
		# Draw MultiMesh obstacles (sparse/dense modes)
		var trees = obstacle_factory.get_node_or_null("Trees")
		var grass = obstacle_factory.get_node_or_null("Grass")
		var rocks = obstacle_factory.get_node_or_null("Rocks")

		# Draw trees
		if trees and trees.multimesh:
			_draw_multimesh_dots(trees.multimesh, player_pos, dot_color, dot_radius)

		# Draw grass (smaller dots)
		if grass and grass.multimesh:
			_draw_multimesh_dots(grass.multimesh, player_pos, dot_color, 2.5)  # Increased from 1.0 to 2.5

		# Draw rocks
		if rocks and rocks.multimesh:
			_draw_multimesh_dots(rocks.multimesh, player_pos, dot_color, dot_radius)


## Draw single obstacle dot
func _draw_obstacle_dot(world_pos: Vector3, player_pos: Vector3, color: Color, radius: float) -> void:
	# Skip if too far underground (hidden obstacles)
	if world_pos.y < -500:
		return

	# Convert world position to minimap position
	var relative_pos = world_pos - player_pos

	# Check if within camera view radius (actual visible range)
	var camera_view_size = view_radius * 2.0 / zoom_level
	var distance = Vector2(relative_pos.x, relative_pos.z).length()
	if distance > camera_view_size / 2.0:  # Check against radius, not diameter
		return

	# Map to minimap coordinates (player at center)
	var map_x = (relative_pos.x / camera_view_size) * minimap_size.x
	var map_z = (relative_pos.z / camera_view_size) * minimap_size.y

	# Center at minimap center
	var screen_pos = Vector2(
		minimap_size.x / 2.0 + map_x,
		minimap_size.y / 2.0 + map_z
	)

	# Skip if outside minimap screen bounds
	if screen_pos.x < 0 or screen_pos.x > minimap_size.x or \
	   screen_pos.y < 0 or screen_pos.y > minimap_size.y:
		return

	# Draw dot
	obstacle_overlay.draw_circle(screen_pos, radius, color)


## Draw dots for a multimesh
func _draw_multimesh_dots(multimesh: MultiMesh, player_pos: Vector3, color: Color, radius: float) -> void:
	var instance_count = multimesh.instance_count

	for i in range(instance_count):
		var transform = multimesh.get_instance_transform(i)
		var world_pos = transform.origin
		_draw_obstacle_dot(world_pos, player_pos, color, radius)
