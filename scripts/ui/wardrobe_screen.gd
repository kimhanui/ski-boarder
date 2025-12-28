extends CanvasLayer

## Wardrobe Screen - Item selection and preview UI

# UI References
@onready var item_grid = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/ItemGrid
@onready var item_name_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/ItemNameLabel

@onready var jacket_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/CategoryButtons/JacketButton
@onready var skis_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/CategoryButtons/SkisButton
@onready var poles_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/CategoryButtons/PolesButton
@onready var helmet_button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/CategoryButtons/HelmetButton

@onready var current_jacket_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/CurrentJacketLabel
@onready var current_skis_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/CurrentSkisLabel
@onready var current_poles_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/CurrentPolesLabel
@onready var current_helmet_label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/CurrentHelmetLabel
@onready var test_mode_checkbox = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/LeftVBox/TestModeCheckBox

# State
var is_open: bool = false
var current_category: String = "jacket"
var selected_items: Dictionary = {}  # Temporary selections (category → item_id)
var player_customization: Node = null
var current_page: Dictionary = {}  # Current page per category (category → page_index)


func _ready() -> void:
	visible = false
	layer = 100  # Above gameplay UI

	# CRITICAL: Allow UI to work during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Find player customization
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_customization = player.get_node_or_null("PlayerCustomization")

	# Set initial category
	_switch_category("jacket")

	# Sync test mode checkbox with TestModeManager
	if test_mode_checkbox:
		test_mode_checkbox.button_pressed = TestModeManager.test_mode_enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_wardrobe"):
		if is_open:
			# Closing wardrobe: revert to original equipment (cancel changes)
			if player_customization:
				player_customization._apply_current_equipment()
			# Clear temporary selections
			selected_items.clear()
		toggle_wardrobe()
		get_viewport().set_input_as_handled()


func toggle_wardrobe() -> void:
	is_open = !is_open
	visible = is_open

	if is_open:
		_open_wardrobe()
	else:
		_close_wardrobe()


func _open_wardrobe() -> void:
	# Pause game
	get_tree().paused = true

	# Show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Clear temporary selections
	selected_items.clear()

	# Refresh UI
	_refresh_current_equipment()
	_populate_item_grid(current_category)

	print("[WardrobeScreen] Opened")


func _close_wardrobe() -> void:
	# Unpause game
	get_tree().paused = false

	# Hide mouse cursor (or restore to game state)
	# Note: Might need to check if game uses captured mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	print("[WardrobeScreen] Closed")


func _switch_category(category: String) -> void:
	current_category = category

	# Initialize page for this category if not exists
	if not current_page.has(category):
		current_page[category] = 0

	# Update button states
	jacket_button.button_pressed = (category == "jacket")
	skis_button.button_pressed = (category == "ski")
	poles_button.button_pressed = (category == "pole")
	helmet_button.button_pressed = (category == "helmet")

	# Populate grid
	_populate_item_grid(category)

	item_name_label.text = "선택된 아이템: 없음"


func _populate_item_grid(category: String) -> void:
	# Clear existing buttons
	for child in item_grid.get_children():
		child.queue_free()

	# Get items for category
	var all_items = ItemDatabase.get_items_by_category(category)

	# Sort: "착용 안 함" first, then others
	var sorted_items: Array = []
	var none_item = null
	for item in all_items:
		if item.get("is_none", false):
			none_item = item
		else:
			sorted_items.append(item)

	# Insert "착용 안 함" at the beginning
	if none_item:
		sorted_items.insert(0, none_item)

	# Get current page
	var page = current_page.get(category, 0)
	var items_per_page = 9
	var total_pages = ceili(float(sorted_items.size()) / float(items_per_page))

	# Calculate page slice
	var start_idx = page * items_per_page
	var end_idx = min(start_idx + items_per_page, sorted_items.size())

	# Create buttons for current page (3x3 grid = 9 slots max)
	for i in range(start_idx, end_idx):
		var item = sorted_items[i]

		# Create button with semi-transparent background
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 150)

		# Create semi-transparent background panel
		var panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks to button
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)

		# Semi-transparent StyleBox
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.2, 0.5)  # 반투명 배경
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style_box)
		button.add_child(panel)

		# Create thumbnail or color indicator (only if not "착용 안 함")
		if not item.get("is_none", false):
			var thumbnail_path = item.get("thumbnail_path", "")

			# Try to load thumbnail first
			if not thumbnail_path.is_empty() and ResourceLoader.exists(thumbnail_path):
				var texture_rect = TextureRect.new()
				var texture = load(thumbnail_path)
				texture_rect.texture = texture
				texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				texture_rect.set_anchors_preset(Control.PRESET_CENTER)
				texture_rect.anchor_left = 0.1
				texture_rect.anchor_top = 0.1
				texture_rect.anchor_right = 0.9
				texture_rect.anchor_bottom = 0.9
				texture_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
				texture_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
				texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				button.add_child(texture_rect)
			else:
				# Fallback to color indicator if no thumbnail
				var color_rect = ColorRect.new()
				color_rect.color = item.color
				color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				color_rect.set_anchors_preset(Control.PRESET_CENTER)
				color_rect.anchor_left = 0.2
				color_rect.anchor_top = 0.2
				color_rect.anchor_right = 0.8
				color_rect.anchor_bottom = 0.8
				color_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
				color_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
				button.add_child(color_rect)

		# Add item name as text on button
		if item.get("is_none", false):
			# "착용 안 함"은 큰 X 표시
			button.text = "✕"
			button.add_theme_font_size_override("font_size", 72)
			button.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2, 1.0))  # 빨간색 X
		else:
			button.text = item.name
			button.add_theme_font_size_override("font_size", 18)

		# Connect signal
		button.pressed.connect(_on_item_selected.bind(item))

		item_grid.add_child(button)

	# Update pagination UI
	_update_pagination_ui(category, page, total_pages)

	print("[WardrobeScreen] Populated grid for category: %s (page %d/%d, %d items total)" % [category, page + 1, total_pages, sorted_items.size()])


func _on_item_selected(item: Dictionary) -> void:
	# Store temporary selection
	selected_items[item.category] = item.id

	# Update label
	item_name_label.text = "선택된 아이템: %s" % item.name

	# Update "현재 착용 아이템" labels (임시 선택 표시)
	_refresh_current_equipment()

	print("[WardrobeScreen] Selected (temporary): %s (%s)" % [item.name, item.category])


func _refresh_current_equipment() -> void:
	if not player_customization:
		return

	# Get equipment (temporary selection if exists, otherwise current)
	var jacket = _get_display_item("jacket")
	var ski = _get_display_item("ski")
	var pole = _get_display_item("pole")
	var helmet = _get_display_item("helmet")

	# Update labels (show "착용 안 함" for none items)
	current_jacket_label.text = "재킷: %s" % _get_item_display_name(jacket)
	current_skis_label.text = "스키: %s" % _get_item_display_name(ski)
	current_poles_label.text = "폴: %s" % _get_item_display_name(pole)
	current_helmet_label.text = "헬멧: %s" % _get_item_display_name(helmet)


func _get_display_item(category: String) -> Dictionary:
	# Return temporary selection if exists, otherwise current equipment
	if selected_items.has(category):
		var item_id = selected_items[category]
		return ItemDatabase.get_item(item_id)
	else:
		return player_customization.get_equipped_item(category)


func _get_item_display_name(item: Dictionary) -> String:
	if item.is_empty():
		return "없음"
	return item.name


## Category button handlers

func _on_jacket_button_pressed() -> void:
	_switch_category("jacket")


func _on_skis_button_pressed() -> void:
	_switch_category("ski")


func _on_poles_button_pressed() -> void:
	_switch_category("pole")


func _on_helmet_button_pressed() -> void:
	_switch_category("helmet")


## Bottom button handlers

func _on_close_button_pressed() -> void:
	# Revert to original equipment (undo preview)
	if player_customization:
		player_customization._apply_current_equipment()

	# Clear temporary selections
	selected_items.clear()

	toggle_wardrobe()


func _on_apply_button_pressed() -> void:
	# Apply all temporary selections
	if player_customization:
		# Apply each selected item
		for category in selected_items:
			var item_id = selected_items[category]
			player_customization.apply_item(item_id)

		# Save equipment
		player_customization.save_equipment()
		print("[WardrobeScreen] Equipment saved (%d items)" % selected_items.size())

	# Clear temporary selections
	selected_items.clear()

	toggle_wardrobe()


## Test mode checkbox handler

func _on_test_mode_check_box_toggled(button_pressed: bool) -> void:
	TestModeManager.set_test_mode(button_pressed)
	print("[WardrobeScreen] Test mode toggled: %s" % ("ON" if button_pressed else "OFF"))


## Pagination handlers

func _on_prev_page_pressed() -> void:
	_change_page(-1)


func _on_next_page_pressed() -> void:
	_change_page(1)


func _change_page(delta: int) -> void:
	var category = current_category
	var page = current_page.get(category, 0)
	var all_items = ItemDatabase.get_items_by_category(category)
	var items_per_page = 9
	var total_pages = ceili(float(all_items.size()) / float(items_per_page))

	# Calculate new page
	var new_page = page + delta

	# Clamp to valid range
	if new_page < 0 or new_page >= total_pages:
		return

	# Update page
	current_page[category] = new_page

	# Refresh grid
	_populate_item_grid(category)


func _update_pagination_ui(category: String, page: int, total_pages: int) -> void:
	# References to pagination UI (will be added in tscn)
	var prev_button = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/PaginationContainer/PrevPageButton")
	var next_button = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/PaginationContainer/NextPageButton")
	var page_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/PaginationContainer/PageIndicator")

	if not prev_button or not next_button or not page_label:
		return

	# Update label
	page_label.text = "%d / %d" % [page + 1, total_pages]

	# Update button states
	prev_button.disabled = (page <= 0)
	next_button.disabled = (page >= total_pages - 1)

	# Hide pagination if only 1 page
	var pagination_container = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentHBox/RightVBox/PaginationContainer")
	if pagination_container:
		pagination_container.visible = (total_pages > 1)
