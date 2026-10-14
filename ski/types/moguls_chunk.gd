class_name MogulsChunk
extends ChunkType
## 코스 안에 둔덕 반복. 벽 근처에서는 사라짐.

var amp: float = 1.0
var spacing: float = 8.0


func _init() -> void:
	type_name = "Moguls"
	weight = 0.8
	cooldown = 2
	color = Color(1.0, 0.8, 0.3)


func randomize_params(rng: RandomNumberGenerator) -> void:
	amp = rng.randf_range(0.5, 1.1)
	spacing = rng.randf_range(6.0, 10.0)


func has_detail() -> bool:
	return true


func detail(d: float, z: float, hw: float) -> float:
	var fade: float = 1.0 - smoothstep(hw - 8.0, hw, absf(d))
	# 대각선으로 엇갈린 둔덕 배치
	return amp * sin(TAU * (d + z * 0.5) / spacing) * sin(TAU * z / spacing) * fade


func describe() -> String:
	return "%s amp=%.1fm sp=%.0fm" % [type_name, amp, spacing]
