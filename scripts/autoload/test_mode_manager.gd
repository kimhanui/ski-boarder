extends Node

## Test Mode Manager - Autoload Singleton
## Manages visibility of debug/test UI elements

const SAVE_PATH = "user://test_mode.save"

var test_mode_enabled: bool = false

signal test_mode_changed(enabled: bool)


func _ready() -> void:
	load_setting()
	print("[TestModeManager] Test mode: %s" % ("ON" if test_mode_enabled else "OFF"))


## Toggle test mode on/off
func toggle_test_mode() -> void:
	test_mode_enabled = !test_mode_enabled
	test_mode_changed.emit(test_mode_enabled)
	save_setting()
	print("[TestModeManager] Test mode toggled: %s" % ("ON" if test_mode_enabled else "OFF"))


## Set test mode directly
func set_test_mode(enabled: bool) -> void:
	if test_mode_enabled == enabled:
		return

	test_mode_enabled = enabled
	test_mode_changed.emit(test_mode_enabled)
	save_setting()
	print("[TestModeManager] Test mode set: %s" % ("ON" if test_mode_enabled else "OFF"))


## Save test mode setting to file
func save_setting() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"test_mode_enabled": test_mode_enabled
		}
		file.store_string(JSON.stringify(data))
		file.close()
		print("[TestModeManager] Settings saved")
	else:
		print("[TestModeManager] Failed to save settings")


## Load test mode setting from file
func load_setting() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[TestModeManager] No saved settings, using default (OFF)")
		test_mode_enabled = false
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()

		if parse_result == OK:
			var data = json.get_data()
			if data.has("test_mode_enabled"):
				test_mode_enabled = data.test_mode_enabled
				print("[TestModeManager] Settings loaded")
		else:
			print("[TestModeManager] Failed to parse settings JSON")
	else:
		print("[TestModeManager] Failed to load settings file")
