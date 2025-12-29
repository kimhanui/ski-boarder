extends Label

## 화면 상단에 키 가이드를 표시하는 UI

func _ready() -> void:
	# 텍스트 설정
	text = "[W/A/S/D] 이동  [Space] 점프  [Shift] 묘기(Tail Grab)  [Tab] 카메라 전환  [R] 리스폰"

	# 위치 설정: 화면 상단 중앙
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -300  # 중앙 정렬을 위한 오프셋 (텍스트 길이의 절반)
	offset_right = 300
	offset_top = 10
	offset_bottom = 40

	# 폰트 설정
	add_theme_font_size_override("font_size", 18)

	# 텍스트 정렬
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# 색상 설정 (흰색 텍스트)
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	# 외곽선 설정 (가독성 향상)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	add_theme_constant_override("outline_size", 2)

	# 그림자 설정 (선택사항)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)

	print("[KeyGuide] Key guide displayed")
