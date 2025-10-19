shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Snow appearance parameters
uniform vec3 base_color : source_color = vec3(0.98, 0.98, 0.96); // Slightly warm white
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_intensity : hint_range(0.0, 1.0) = 0.2;

// Sparkle parameters
uniform float sparkle_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float sparkle_scale : hint_range(1.0, 100.0) = 20.0;
uniform float sparkle_threshold : hint_range(0.0, 1.0) = 0.85;

// Density map (compacted paths)
uniform sampler2D density_map : hint_default_white;
uniform float density_strength : hint_range(0.0, 1.0) = 0.3;

// Normal map for micro-roughness
uniform sampler2D normal_map : hint_normal;

void vertex() {
	// UV can be used for density map
	UV = UV;
}

float hash(vec2 p) {
	// Simple hash function for sparkle noise
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float sparkle_noise(vec2 uv, vec3 view_dir, vec3 normal) {
	// View-dependent sparkle
	float view_angle = dot(view_dir, normal);

	// Only sparkle at grazing angles
	float angle_factor = smoothstep(0.3, 0.7, abs(view_angle));

	// Grid-based noise for sparkle points
	vec2 grid_uv = uv * sparkle_scale;
	vec2 grid_id = floor(grid_uv);
	vec2 grid_local = fract(grid_uv);

	// Random sparkle per grid cell
	float sparkle = hash(grid_id);

	// Only bright sparkles
	sparkle = smoothstep(sparkle_threshold, 1.0, sparkle);

	// Circular sparkle shape
	float dist = length(grid_local - 0.5);
	float shape = 1.0 - smoothstep(0.2, 0.5, dist);

	return sparkle * shape * angle_factor;
}

void fragment() {
	// Base color
	vec3 snow_color = base_color;

	// Apply density map (darker on compacted paths)
	float density = texture(density_map, UV).r;
	snow_color *= mix(1.0, 0.85, density * density_strength);

	// Normal mapping for micro-roughness
	vec3 normal_map_value = texture(normal_map, UV).rgb;
	NORMAL_MAP = normal_map_value;
	NORMAL_MAP_DEPTH = normal_intensity;

	// Calculate view direction
	vec3 view_dir = normalize(VIEW);
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Add sparkle
	float sparkle = sparkle_noise(UV, view_dir, world_normal);
	vec3 sparkle_color = vec3(0.9, 0.95, 1.0); // Slightly blue-white
	snow_color += sparkle_color * sparkle * sparkle_intensity;

	// Output
	ALBEDO = snow_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	// Emission for subtle glow (matches existing terrain material)
	EMISSION = vec3(0.15, 0.15, 0.2) * 0.5;
}
