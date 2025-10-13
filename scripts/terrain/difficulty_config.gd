extends Node
class_name DifficultyConfig

## Difficulty configuration presets for procedural terrain generation

static func get_config(difficulty: String) -> Dictionary:
	match difficulty.to_lower():
		"easy":
			return {
				"noise_amplitude": [6.0, 3.0, 1.5],
				"noise_frequencies": [0.003, 0.008, 0.018],  # Very smooth
				"vertical_drop": 200.0,
				"slope_length": 1200.0,
				"path_width": 8.0,
				"turn_sharpness": 0.25,  # 0.0 = straight, 1.0 = very curvy
				"turn_frequency": 0.002,  # How often turns happen
				"obstacle_count_range": [5, 8],
				"obstacle_min_distance": 15.0,
				"obstacle_max_distance": 35.0,
				"obstacle_scale_range": [0.8, 1.5],
				"checkpoint_interval": 300.0
			}
		"hard":
			return {
				"noise_amplitude": [12.0, 6.0, 3.0],
				"noise_frequencies": [0.008, 0.018, 0.035],  # More variation
				"vertical_drop": 500.0,
				"slope_length": 2000.0,
				"path_width": 3.0,
				"turn_sharpness": 0.8,
				"turn_frequency": 0.005,
				"obstacle_count_range": [30, 40],
				"obstacle_min_distance": 3.0,
				"obstacle_max_distance": 15.0,
				"obstacle_scale_range": [1.2, 2.5],
				"checkpoint_interval": 400.0
			}
		_:  # "medium" (default)
			return {
				"noise_amplitude": [8.0, 4.0, 2.0],
				"noise_frequencies": [0.005, 0.012, 0.025],  # Smooth and wide
				"vertical_drop": 350.0,
				"slope_length": 1500.0,
				"path_width": 5.0,
				"turn_sharpness": 0.5,
				"turn_frequency": 0.003,
				"obstacle_count_range": [15, 20],
				"obstacle_min_distance": 8.0,
				"obstacle_max_distance": 20.0,
				"obstacle_scale_range": [1.0, 2.0],
				"checkpoint_interval": 300.0
			}


static func get_terrain_width(difficulty: String) -> float:
	# Terrain width stays constant for all difficulties
	return 400.0


static func get_cell_size(difficulty: String) -> float:
	# Mesh resolution - finer for easier difficulties to look smoother
	match difficulty.to_lower():
		"easy":
			return 3.0
		"hard":
			return 5.0
		_:
			return 4.0
