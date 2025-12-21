extends Node

## Player Customization System
## Handles applying items (colors, meshes) to player body parts

# Default colors (from player.tscn)
const DEFAULT_JACKET_COLOR = Color(0.2, 0.4, 0.8)  # Blue
const DEFAULT_SKI_COLOR = Color(0.9, 0.1, 0.1)  # Red
const DEFAULT_POLE_COLOR = Color(0.3, 0.3, 0.3)  # Grey
const DEFAULT_HELMET_COLOR = Color(1.0, 0.9, 0.8)  # Skin tone

# Player references
var player: CharacterBody3D
var body: Node3D

# Body part references
var torso: MeshInstance3D
var left_arm_upper: MeshInstance3D
var right_arm_upper: MeshInstance3D
var left_leg_upper: MeshInstance3D
var left_leg_lower: MeshInstance3D
var right_leg_upper: MeshInstance3D
var right_leg_lower: MeshInstance3D

var left_ski: MeshInstance3D
var right_ski: MeshInstance3D

var left_pole: MeshInstance3D
var right_pole: MeshInstance3D

var head: MeshInstance3D
var helmet_node: Node3D = null  # Current helmet instance (as child of head)

# Current equipment (item IDs)
var current_equipment: Dictionary = {
	"jacket": "jacket_blue",
	"ski": "ski_red",
	"pole": "pole_grey",
	"helmet": "helmet_white"
}


func _ready() -> void:
	player = get_parent()
	_cache_body_parts()

	# Load saved equipment
	load_equipment()

	# Apply current equipment
	_apply_current_equipment()

	print("[PlayerCustomization] Ready - equipment: %s" % current_equipment)


func _cache_body_parts() -> void:
	body = player.get_node("Body")

	# Jacket parts (torso, arms, legs)
	torso = body.get_node("Torso")
	left_arm_upper = body.get_node("LeftArm/UpperArm")
	right_arm_upper = body.get_node("RightArm/UpperArm")
	left_leg_upper = body.get_node("LeftLeg/UpperLeg")
	left_leg_lower = body.get_node("LeftLeg/LowerLeg")
	right_leg_upper = body.get_node("RightLeg/UpperLeg")
	right_leg_lower = body.get_node("RightLeg/LowerLeg")

	# Skis
	left_ski = body.get_node("LeftLeg/Ski")
	right_ski = body.get_node("RightLeg/Ski")

	# Poles
	left_pole = body.get_node("LeftArm/SkiPole")
	right_pole = body.get_node("RightArm/SkiPole")

	# Helmet (head)
	head = body.get_node("Head")


## Apply an item to player
func apply_item(item_id: String) -> void:
	var item = ItemDatabase.get_item(item_id)
	if item.is_empty():
		print("[PlayerCustomization] Item not found: %s" % item_id)
		return

	# Update current equipment
	current_equipment[item.category] = item_id

	# Check if "착용 안 함" (none item)
	var is_none = item.get("is_none", false)

	# Apply to player mesh
	match item.category:
		"jacket":
			var color = DEFAULT_JACKET_COLOR if is_none else item.color
			_apply_jacket_color(color)
			# TODO: Add jacket mesh replacement if needed
		"ski":
			# Check if mesh path is provided (3D model)
			if item.has("mesh_path") and not item.mesh_path.is_empty() and not is_none:
				_apply_ski_mesh(item.mesh_path)
			else:
				# Fallback to color change
				var color = DEFAULT_SKI_COLOR if is_none else item.color
				_apply_ski_color(color)
		"pole":
			var color = DEFAULT_POLE_COLOR if is_none else item.color
			_apply_pole_color(color)
			# TODO: Add pole mesh replacement if needed
		"helmet":
			# Check if mesh path is provided (3D model)
			if item.has("mesh_path") and not item.mesh_path.is_empty() and not is_none:
				_apply_helmet_mesh(item.mesh_path)
			else:
				# Fallback to color change
				var color = DEFAULT_HELMET_COLOR if is_none else item.color
				_apply_helmet_color(color)

	print("[PlayerCustomization] Applied %s: %s" % [item.category, item.name])


## Apply all current equipment (used on load/start)
func _apply_current_equipment() -> void:
	for category in current_equipment:
		var item_id = current_equipment[category]
		var item = ItemDatabase.get_item(item_id)
		if not item.is_empty():
			var is_none = item.get("is_none", false)
			match category:
				"jacket":
					var color = DEFAULT_JACKET_COLOR if is_none else item.color
					_apply_jacket_color(color)
				"ski":
					var color = DEFAULT_SKI_COLOR if is_none else item.color
					_apply_ski_color(color)
				"pole":
					var color = DEFAULT_POLE_COLOR if is_none else item.color
					_apply_pole_color(color)
				"helmet":
					if item.has("mesh_path") and not item.mesh_path.is_empty() and not is_none:
						_apply_helmet_mesh(item.mesh_path)
					else:
						var color = DEFAULT_HELMET_COLOR if is_none else item.color
						_apply_helmet_color(color)


func _apply_jacket_color(color: Color) -> void:
	# Jacket affects: Torso, Arms (Upper), Legs (Upper/Lower)
	var parts = [
		torso,
		left_arm_upper,
		right_arm_upper,
		left_leg_upper,
		left_leg_lower,
		right_leg_upper,
		right_leg_lower
	]

	for part in parts:
		if part and part is MeshInstance3D:
			_set_material_color(part, color)


func _apply_ski_color(color: Color) -> void:
	for ski in [left_ski, right_ski]:
		if ski and ski is MeshInstance3D:
			_set_material_color(ski, color)


## Apply ski mesh (3D model replacement)
func _apply_ski_mesh(mesh_path: String) -> void:
	if mesh_path.is_empty():
		return

	# Load mesh from file
	var mesh_scene = load(mesh_path)
	if not mesh_scene:
		print("[PlayerCustomization] Failed to load mesh: %s" % mesh_path)
		return

	# If it's a PackedScene (GLB/GLTF), instantiate it
	if mesh_scene is PackedScene:
		var instance = mesh_scene.instantiate()
		if instance is MeshInstance3D:
			left_ski.mesh = instance.mesh
			right_ski.mesh = instance.mesh
			instance.queue_free()  # Clean up temporary instance
		elif instance.get_child_count() > 0:
			# GLB might have mesh as child
			var first_mesh = instance.find_child("*", true, false)
			if first_mesh is MeshInstance3D:
				left_ski.mesh = first_mesh.mesh
				right_ski.mesh = first_mesh.mesh
			instance.queue_free()
	# If it's a direct Mesh resource
	elif mesh_scene is Mesh:
		left_ski.mesh = mesh_scene
		right_ski.mesh = mesh_scene

	print("[PlayerCustomization] Applied ski mesh: %s" % mesh_path)


func _apply_pole_color(color: Color) -> void:
	for pole in [left_pole, right_pole]:
		if pole and pole is MeshInstance3D:
			_set_material_color(pole, color)


func _apply_helmet_color(color: Color) -> void:
	# Remove helmet mesh if exists
	if helmet_node:
		helmet_node.queue_free()
		helmet_node = null

	# Apply color to original head mesh
	if head and head is MeshInstance3D:
		_set_material_color(head, color)


## Apply helmet mesh (3D model as child node)
func _apply_helmet_mesh(mesh_path: String) -> void:
	if mesh_path.is_empty():
		return

	# Remove old helmet if exists
	if helmet_node:
		helmet_node.queue_free()
		helmet_node = null

	# Load mesh from file
	var mesh_scene = load(mesh_path)
	if not mesh_scene:
		print("[PlayerCustomization] Failed to load mesh: %s" % mesh_path)
		return

	# If it's a PackedScene (GLB/GLTF), instantiate it
	if mesh_scene is PackedScene:
		var instance = mesh_scene.instantiate()

		# Create a container node for the helmet
		helmet_node = Node3D.new()
		helmet_node.name = "HelmetNode"

		# Apply transforms to fit head
		helmet_node.scale = Vector3(0.5, 0.5, 0.5)  # Scale down to 30%
		helmet_node.rotation_degrees.y = 180.0  # Flip front/back
		helmet_node.position = Vector3(0, -0.2, 0)  # Adjust if needed

		# Add helmet instance to container
		helmet_node.add_child(instance)

		# Add container to Head (as child, keeping original head mesh)
		head.add_child(helmet_node)

		print("[PlayerCustomization] Applied helmet mesh: %s (scale: %s)" % [mesh_path, helmet_node.scale])

	# If it's a direct Mesh resource
	elif mesh_scene is Mesh:
		# Create MeshInstance3D for the helmet
		helmet_node = MeshInstance3D.new()
		helmet_node.name = "HelmetNode"
		helmet_node.mesh = mesh_scene

		# Apply transforms
		helmet_node.scale = Vector3(0.3, 0.3, 0.3)
		helmet_node.rotation_degrees.y = 180.0

		# Add to Head
		head.add_child(helmet_node)

		print("[PlayerCustomization] Applied helmet mesh: %s" % mesh_path)


## Helper: Set material albedo color
func _set_material_color(mesh_instance: MeshInstance3D, color: Color) -> void:
	var mat = mesh_instance.get_surface_override_material(0)
	if mat and mat is StandardMaterial3D:
		mat.albedo_color = color


## Save equipment to file
func save_equipment() -> void:
	var save_data = {
		"equipment": current_equipment
	}

	var file = FileAccess.open("user://player_equipment.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[PlayerCustomization] Equipment saved to user://player_equipment.json")
	else:
		print("[PlayerCustomization] Failed to save equipment")


## Load equipment from file
func load_equipment() -> void:
	if not FileAccess.file_exists("user://player_equipment.json"):
		print("[PlayerCustomization] No saved equipment, using defaults")
		return

	var file = FileAccess.open("user://player_equipment.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()

		if parse_result == OK:
			var data = json.get_data()
			if data.has("equipment"):
				current_equipment = data.equipment
				print("[PlayerCustomization] Equipment loaded: %s" % current_equipment)
		else:
			print("[PlayerCustomization] Failed to parse equipment JSON")
	else:
		print("[PlayerCustomization] Failed to open equipment file")


## Get currently equipped item for a category
func get_equipped_item(category: String) -> Dictionary:
	if current_equipment.has(category):
		return ItemDatabase.get_item(current_equipment[category])
	return {}
