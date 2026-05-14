extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH, TILT }

signal control_mode_changed(new_mode: ControlMode)

var control_mode: ControlMode = ControlMode.KEYBOARD

const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("input", "control_mode", control_mode)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("input", "control_mode", ControlMode.KEYBOARD)
