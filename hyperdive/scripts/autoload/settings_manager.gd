extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH, TILT }

signal control_mode_changed(new_mode: ControlMode)
signal coin_collected(new_total: int)
signal owned_skins_changed
signal equipped_skin_changed(skin_id: String)

var control_mode: ControlMode = ControlMode.KEYBOARD
var coins_total: int = 0
var coins_this_run: int = 0
var best_distance: int = 0
var owned_skins: Array[String] = ["default"]
var equipped_skin: String = "default"

const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()
	if OS.has_feature("mobile"):
		control_mode = ControlMode.TOUCH

func add_coin() -> void:
	coins_total += 1
	coins_this_run += 1
	coin_collected.emit(coins_total)
	save_settings()

func reset_run_stats() -> void:
	coins_this_run = 0

func update_best_distance(distance: int) -> void:
	if distance > best_distance:
		best_distance = distance
		save_settings()

func buy_skin(skin_id: String) -> bool:
	var skin: Dictionary = Catalog.get_skin_by_id(skin_id)
	if coins_total < skin["price"]:
		return false
	if skin_id in owned_skins:
		return false
	coins_total -= skin["price"]
	owned_skins.append(skin_id)
	owned_skins_changed.emit()
	coin_collected.emit(coins_total)
	save_settings()
	return true

func equip_skin(skin_id: String) -> bool:
	if not skin_id in owned_skins:
		return false
	equipped_skin = skin_id
	equipped_skin_changed.emit(skin_id)
	save_settings()
	return true

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("input", "control_mode", control_mode)
	cfg.set_value("stats", "coins_total", coins_total)
	cfg.set_value("stats", "best_distance", best_distance)
	cfg.set_value("cosmetics", "owned_skins", owned_skins)
	cfg.set_value("cosmetics", "equipped_skin", equipped_skin)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("input", "control_mode", ControlMode.KEYBOARD)
	coins_total = cfg.get_value("stats", "coins_total", 0)
	best_distance = cfg.get_value("stats", "best_distance", 0)
	owned_skins.assign(cfg.get_value("cosmetics", "owned_skins", ["default"]))
	equipped_skin = cfg.get_value("cosmetics", "equipped_skin", "default")
