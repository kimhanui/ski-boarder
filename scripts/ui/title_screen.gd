extends Control

## Title Screen
## Shows game title and start button with blurred background

func _ready() -> void:
	print("[TitleScreen] Title screen loaded")

	# 마우스 커서 표시
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 배경 이미지 로드
	var background_image = $BackgroundImage
	var texture_path = "res://assets/ui/title_background.png"

	# ResourceLoader.exists()를 사용하여 .pck 안의 리소스도 확인 가능
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		if texture:
			background_image.texture = texture
			print("[TitleScreen] Background image loaded")
		else:
			print("[TitleScreen] Failed to load background image")
	else:
		print("[TitleScreen] Background image not found at: ", texture_path)
		print("[TitleScreen] Please save the background image to: assets/ui/title_background.png")

	# START 버튼 스타일 설정 (노란색 배경)
	var start_button = $CenterContainer/VBoxContainer/StartButton
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(1.0, 0.8, 0.0)  # 노란색
	style_normal.corner_radius_top_left = 15
	style_normal.corner_radius_top_right = 15
	style_normal.corner_radius_bottom_left = 15
	style_normal.corner_radius_bottom_right = 15

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(1.0, 0.9, 0.2)  # 밝은 노란색 (호버)
	style_hover.corner_radius_top_left = 15
	style_hover.corner_radius_top_right = 15
	style_hover.corner_radius_bottom_left = 15
	style_hover.corner_radius_bottom_right = 15

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.9, 0.7, 0.0)  # 어두운 노란색 (눌림)
	style_pressed.corner_radius_top_left = 15
	style_pressed.corner_radius_top_right = 15
	style_pressed.corner_radius_bottom_left = 15
	style_pressed.corner_radius_bottom_right = 15

	start_button.add_theme_stylebox_override("normal", style_normal)
	start_button.add_theme_stylebox_override("hover", style_hover)
	start_button.add_theme_stylebox_override("pressed", style_pressed)
	start_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))  # 검은색 텍스트
	start_button.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0))
	start_button.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0))

	# Options, Quit 버튼 숨기기
	$CenterContainer/VBoxContainer/OptionsButton.visible = false
	$CenterContainer/VBoxContainer/QuitButton.visible = false

func _on_start_button_pressed() -> void:
	print("[TitleScreen] Starting game...")
	# 메인 게임 씬으로 전환
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_options_button_pressed() -> void:
	print("[TitleScreen] Options button pressed (not implemented yet)")
	# TODO: 설정 화면 구현

func _on_quit_button_pressed() -> void:
	print("[TitleScreen] Quitting game...")
	get_tree().quit()
