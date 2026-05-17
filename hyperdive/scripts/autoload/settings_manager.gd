extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH, TILT }

signal control_mode_changed(new_mode: ControlMode)
signal coin_collected(new_total: int)

var control_mode: ControlMode = ControlMode.KEYBOARD
var coins_total: int = 0

const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func add_coin() -> void:
	coins_total += 1
	coin_collected.emit(coins_total)
	save_settings()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("input", "control_mode", control_mode)
	cfg.set_value("stats", "coins_total", coins_total)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("input", "control_mode", ControlMode.KEYBOARD)
	coins_total = cfg.get_value("stats", "coins_total", 0)
