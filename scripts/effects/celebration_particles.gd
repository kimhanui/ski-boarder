extends Node3D
class_name CelebrationParticles

## Celebration particle effect that plays once when player reaches finish line

var _particles: CPUParticles3D = null

func _ready() -> void:
	print("[CelebrationParticles] _ready() called at position: ", global_position)

	# Create CPU particles (easier to configure than GPU particles)
	_particles = CPUParticles3D.new()
	_particles.name = "Particles"
	add_child(_particles)
	print("[CelebrationParticles] CPUParticles3D created")

	# IMPORTANT: Set mesh for particles to be visible
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.2
	particle_mesh.height = 0.4
	_particles.mesh = particle_mesh
	print("[CelebrationParticles] Particle mesh set")

	# Emission settings
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 200
	_particles.lifetime = 3.0
	_particles.explosiveness = 1.0  # All particles emit at once

	# Emission shape: Point (explode from center)
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT

	# Direction: Spread in all directions
	_particles.direction = Vector3(0, 1, 0)  # Base direction: up
	_particles.spread = 180.0  # Full sphere spread

	# Speed and velocity
	_particles.initial_velocity_min = 8.0
	_particles.initial_velocity_max = 15.0
	_particles.gravity = Vector3(0, -9.8, 0)  # Gravity pulls down

	# Scale over lifetime (particles start big then shrink)
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.0

	# Color: Rainbow gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.0, 0.0))  # Red
	gradient.add_point(0.2, Color(1.0, 0.5, 0.0))  # Orange
	gradient.add_point(0.4, Color(1.0, 1.0, 0.0))  # Yellow
	gradient.add_point(0.6, Color(0.0, 1.0, 0.0))  # Green
	gradient.add_point(0.8, Color(0.0, 0.5, 1.0))  # Blue
	gradient.add_point(1.0, Color(0.5, 0.0, 1.0))  # Purple

	_particles.color_ramp = gradient
	print("[CelebrationParticles] All particle settings configured")

	# Auto-delete after playing
	await get_tree().create_timer(_particles.lifetime + 0.5).timeout
	queue_free()


## Play the celebration effect
func play() -> void:
	if _particles:
		_particles.emitting = true
		print("[CelebrationParticles] Playing celebration effect!")


## Create and play celebration particles at a specific position
static func create_at(pos: Vector3, parent: Node) -> CelebrationParticles:
	var particles = CelebrationParticles.new()
	particles.global_position = pos
	parent.add_child(particles)
	particles.play()
	return particles
