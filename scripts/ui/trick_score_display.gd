extends Control

## Trick Score Display UI
## Shows current trick rotation and score when landing

# UI Components
@onready var trick_name_label: Label = $TrickNameLabel
@onready var rotation_label: Label = $RotationLabel
@onready var score_popup_label: Label = $ScorePopupLabel
@onready var total_score_label: Label = $TotalScoreLabel

# Player reference (set from parent scene)
var player: CharacterBody3D = null

# Animation state
var score_popup_timer: float = 0.0
var score_popup_fade_duration: float = 2.0
var score_popup_rise_speed: float = 50.0  # pixels/sec
var score_popup_start_y: float = 0.0


func _ready() -> void:
	# Hide all elements initially
	if trick_name_label:
		trick_name_label.visible = false
	if rotation_label:
		rotation_label.visible = false
	if score_popup_label:
		score_popup_label.visible = false
		score_popup_label.modulate.a = 0.0

	# Show total score (always visible)
	if total_score_label:
		total_score_label.text = "Score: 0"
		total_score_label.visible = true


func _process(delta: float) -> void:
	if not player:
		return

	# Update trick rotation display (when in air and tricking)
	_update_trick_rotation_display()

	# Update total score
	_update_total_score_display()

	# Animate score popup
	_animate_score_popup(delta)


## Update trick rotation display (real-time during airborne tricks)
func _update_trick_rotation_display() -> void:
	if not player:
		return

	# Check if player is in air and performing a flip trick
	# V3: Use PlayerState enum (FLIP = 3)
	var is_airborne = player.state == 3  # PlayerState.FLIP = 3
	var is_tricking = player.trick_in_progress

	if is_airborne and is_tricking:
		# Show trick name
		if trick_name_label:
			trick_name_label.text = player.current_trick
			trick_name_label.visible = true

		# Show current rotation
		if rotation_label:
			var rotation_abs = abs(player.trick_rotation_x_total)
			rotation_label.text = "%.0f°" % rotation_abs
			rotation_label.visible = true

			# Color code based on proximity to 360° multiples
			var remainder = fmod(rotation_abs, 360.0)
			var error = min(remainder, 360.0 - remainder)

			if error <= 10.0:
				rotation_label.modulate = Color.GOLD  # Perfect
			elif error <= 30.0:
				rotation_label.modulate = Color.GREEN  # Good
			else:
				rotation_label.modulate = Color.WHITE  # Neutral
	else:
		# Hide when not tricking
		if trick_name_label:
			trick_name_label.visible = false
		if rotation_label:
			rotation_label.visible = false


## Update total score display
func _update_total_score_display() -> void:
	if not player or not total_score_label:
		return

	total_score_label.text = "Score: %d" % player.total_score


## Show score popup when trick is landed
func show_score_popup(trick_name: String, score: int, is_perfect: bool = false) -> void:
	if not score_popup_label:
		return

	# Set text
	var prefix = "✨ " if is_perfect else ""
	score_popup_label.text = "%s%s\n+%d pts!" % [prefix, trick_name, score]

	# Set color
	if is_perfect:
		score_popup_label.modulate = Color.GOLD
	elif score >= 250:
		score_popup_label.modulate = Color.ORANGE
	else:
		score_popup_label.modulate = Color.GREEN_YELLOW

	# Reset alpha and position
	score_popup_label.modulate.a = 1.0
	score_popup_start_y = score_popup_label.position.y
	score_popup_label.visible = true

	# Start animation timer
	score_popup_timer = score_popup_fade_duration


## Animate score popup (fade out and rise up)
func _animate_score_popup(delta: float) -> void:
	if not score_popup_label or not score_popup_label.visible:
		return

	if score_popup_timer > 0.0:
		score_popup_timer -= delta

		# Calculate fade alpha (0.0 to 1.0)
		var fade_progress = score_popup_timer / score_popup_fade_duration
		score_popup_label.modulate.a = fade_progress

		# Rise up
		var rise_offset = (score_popup_fade_duration - score_popup_timer) * score_popup_rise_speed
		score_popup_label.position.y = score_popup_start_y - rise_offset

		# Hide when done
		if score_popup_timer <= 0.0:
			score_popup_label.visible = false
			score_popup_label.position.y = score_popup_start_y


## Connect to player's trick_performed signal
func connect_to_player(player_node: CharacterBody3D) -> void:
	player = player_node

	# Connect to trick signal
	if player.has_signal("trick_performed"):
		player.trick_performed.connect(_on_trick_performed)
		print("[TrickScoreDisplay] Connected to player trick signals")


## Called when player performs a trick
func _on_trick_performed(trick_name: String) -> void:
	if not player:
		return

	var score = player.trick_score
	var is_perfect = (score % 50 == 0 and score > 100)  # Has perfect landing bonus

	show_score_popup(trick_name, score, is_perfect)
	print("[TrickScoreDisplay] Showing score popup: %s = %d pts" % [trick_name, score])
