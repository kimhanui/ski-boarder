class_name RestChunk
extends SteepChunk
## 가운데가 거의 평지인 쉬어가는 구간. 코스도 살짝 넓어짐.
## 랜덤 풀에는 없고(weight 0) Sequencer 규칙으로 주기적으로 등장.


func _init() -> void:
	type_name = "Rest"
	weight = 0.0
	cooldown = 0
	color = Color(0.4, 1.0, 0.5)


func randomize_params(rng: RandomNumberGenerator) -> void:
	c = rng.randf_range(-0.45, -0.3)  # 가운데 경사 = 평균의 0.1~0.4배


func half_width(v: float) -> float:
	return ChunkSpec.HALF_WIDTH + 10.0 * sin(PI * v) * sin(PI * v)


func describe() -> String:
	return "%s x%.1f" % [type_name, 1.0 + 2.0 * c]
