extends Control

## Title Screen
## Shows game title and start button with blurred background

func _ready() -> void:
	print("[TitleScreen] Title screen loaded")

	# 마우스 커서 표시
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
