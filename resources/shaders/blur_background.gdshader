shader_type canvas_item;

// Simple Gaussian blur shader for background
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec4 color = vec4(0.0);
	float kernel_sum = 0.0;

	// 5x5 Gaussian kernel (simplified)
	int samples = 5;
	float offset = blur_amount / 100.0;

	for (int x = -samples; x <= samples; x++) {
		for (int y = -samples; y <= samples; y++) {
			vec2 uv_offset = vec2(float(x), float(y)) * offset;
			float weight = exp(-0.5 * (float(x * x + y * y)) / 2.0);
			color += texture(TEXTURE, UV + uv_offset) * weight;
			kernel_sum += weight;
		}
	}

	COLOR = color / kernel_sum;
	// 반투명 처리
	COLOR.a *= 0.7;
}
