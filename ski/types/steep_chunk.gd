class_name SteepChunk
extends ChunkType
## 중간이 급경사, 앞뒤 1/4 지점은 완만. 총 하강량(DROP)은 동일.
## s(v) = v + c·(sin4πv/4π − sin2πv/2π)
## s'(v) = 1 + c·(cos4πv − cos2πv) ∈ [1 − 1.125c, 1 + 2c], 가장자리에서 s'=1.
## c > 0 → 가운데 급경사 (Steep), c < 0 → 가운데 완만 (Rest).

var c: float = 0.5


func _init() -> void:
	type_name = "Steep"
	weight = 0.7
	cooldown = 2
	color = Color(1.0, 0.35, 0.3)


func randomize_params(rng: RandomNumberGenerator) -> void:
	c = rng.randf_range(0.4, 0.7)  # 가운데 경사 = 평균의 1.8~2.4배


func slope(v: float) -> float:
	return v + c * (sin(2.0 * TAU * v) / (2.0 * TAU) - sin(TAU * v) / TAU)


func describe() -> String:
	return "%s x%.1f" % [type_name, 1.0 + 2.0 * c]
