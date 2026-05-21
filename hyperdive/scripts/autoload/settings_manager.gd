extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH, TILT }

const INFINITE_UNLOCK_LEVEL: int = 5

signal control_mode_changed(new_mode: ControlMode)
signal coin_collected(new_total: int)
signal owned_skins_changed
signal equipped_skin_changed(skin_id: String)
signal owned_trails_changed
signal equipped_trail_changed(trail_id: String)
signal volume_changed

var control_mode: ControlMode = ControlMode.KEYBOARD
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var coins_total: int = 0
var coins_this_run: int = 0
var best_distance: int = 0
var owned_skins: Array[String] = ["default"]
var equipped_skin: String = "default"
var owned_trails: Array[String] = ["default"]
var equipped_trail: String = "default"
var campaign_level: int = 1
var active_mode: String = "infinite"
var active_level: int = 1

const SAVE_PATH: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()
	if OS.has_feature("mobile") and control_mode == ControlMode.KEYBOARD:
		control_mode = ControlMode.TOUCH

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	volume_changed.emit()
	save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	volume_changed.emit()
	save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	volume_changed.emit()
	save_settings()

func set_control_mode_value(mode: ControlMode) -> void:
	control_mode = mode
	control_mode_changed.emit(control_mode)
	save_settings()

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

func buy_trail(trail_id: String) -> bool:
	var trail: Dictionary = Catalog.get_trail(trail_id)
	if coins_total < trail["price"]:
		return false
	if trail_id in owned_trails:
		return false
	coins_total -= trail["price"]
	owned_trails.append(trail_id)
	owned_trails_changed.emit()
	coin_collected.emit(coins_total)
	save_settings()
	return true

func equip_trail(trail_id: String) -> bool:
	if not trail_id in owned_trails:
		return false
	equipped_trail = trail_id
	equipped_trail_changed.emit(trail_id)
	save_settings()
	return true

func get_level_duration(level: int) -> float:
	return 30.0 + float(level - 1) * 5.0

func get_level_reward(level: int) -> int:
	return 20 + level * 10

func is_infinite_unlocked() -> bool:
	return campaign_level > INFINITE_UNLOCK_LEVEL

func complete_current_level() -> void:
	coins_total += get_level_reward(active_level)
	coin_collected.emit(coins_total)
	if active_level == campaign_level:
		campaign_level += 1
	save_settings()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("input", "control_mode", control_mode)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("stats", "coins_total", coins_total)
	cfg.set_value("stats", "best_distance", best_distance)
	cfg.set_value("cosmetics", "owned_skins", owned_skins)
	cfg.set_value("cosmetics", "equipped_skin", equipped_skin)
	cfg.set_value("cosmetics", "owned_trails", owned_trails)
	cfg.set_value("cosmetics", "equipped_trail", equipped_trail)
	cfg.set_value("campaign", "campaign_level", campaign_level)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("input", "control_mode", ControlMode.KEYBOARD)
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	coins_total = cfg.get_value("stats", "coins_total", 0)
	best_distance = cfg.get_value("stats", "best_distance", 0)
	owned_skins.assign(cfg.get_value("cosmetics", "owned_skins", ["default"]))
	equipped_skin = cfg.get_value("cosmetics", "equipped_skin", "default")
	owned_trails.assign(cfg.get_value("cosmetics", "owned_trails", ["default"]))
	equipped_trail = cfg.get_value("cosmetics", "equipped_trail", "default")
	campaign_level = cfg.get_value("campaign", "campaign_level", 1)
