extends Node3D
class_name WolfController

## Wolf controller for FBX imported model
## - Uses raycast to stay on terrain surface
## - Plays walk animation from FBX
## - Simple patrol movement (back and forth)

@export var patrol_speed: float = 2.0  # m/s
@export var patrol_range: float = 20.0  # Meters from start position
@export var raycast_height: float = 10.0  # How high above terrain to start raycast (reduced from 100.0)
@export var patrol_direction_multiplier: float = 1.0  # Sign: +1 forward, -1 backward
var _start_x: float = 0.0
var _start_z: float = 0.0
var _animation_player: AnimationPlayer = null
var _raycast: RayCast3D = null
var _collision_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null

# Ground position caching for performance
var _cached_ground_y: float = 0.0
var _raycast_timer: float = 0.0
const RAYCAST_UPDATE_INTERVAL: float = 0.1  # Update every 0.1s instead of every frame

func _ready() -> void:
	# Store starting position for patrol boundaries
	_start_x = global_position.x
	_start_z = global_position.z

	# Create collision body and shape (so player can collide with animal)
	_collision_body = StaticBody3D.new()
	_collision_body.name = "CollisionBody"
	_collision_body.collision_layer = 2  # Environment layer (same as terrain)
	_collision_body.collision_mask = 1  # Collide with player (layer 1)
	add_child(_collision_body)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape"
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.5  # Adjust based on animal size
	capsule_shape.height = 1.5  # Adjust based on animal size
	_collision_shape.shape = capsule_shape
	_collision_shape.position = Vector3(0, 0.75, 0)  # Center capsule on animal
	_collision_body.add_child(_collision_shape)

	# Find AnimationPlayer in FBX children
	_animation_player = _find_animation_player(self)

	if _animation_player:
		var anim_list = _animation_player.get_animation_list()
		print("[Wolf] Found AnimationPlayer with animations: ", anim_list)

		# Try to play walk animation (check common animation names)
		var walk_anim = ""
		if _animation_player.has_animation("Walk"):
			walk_anim = "Walk"
		elif _animation_player.has_animation("walk"):
			walk_anim = "walk"
		elif _animation_player.has_animation("Walking"):
			walk_anim = "Walking"
		elif anim_list.size() > 0:
			# Use first animation as fallback
			walk_anim = anim_list[0]

		if walk_anim != "":
			_animation_player.play(walk_anim)
			print("[Wolf] Playing animation: ", walk_anim)
		else:
			print("[Wolf] No suitable walk animation found")
	else:
		print("[Wolf] No AnimationPlayer found in FBX")


func _physics_process(delta: float) -> void:
	# Movement disabled - animals stay fixed in place
	pass


## Recursively find AnimationPlayer in node tree
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = _find_animation_player(child)
		if result:
			return result

	return null
