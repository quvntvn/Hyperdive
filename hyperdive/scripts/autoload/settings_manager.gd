extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH }

const INFINITE_UNLOCK_LEVEL: int = 5
const ENVOL_UNLOCK_LEVEL: int = 10

signal control_mode_changed(new_mode: ControlMode)
signal coin_collected(new_total: int)
signal owned_skins_changed
signal equipped_skin_changed(skin_id: String)
signal owned_trails_changed
signal equipped_trail_changed(trail_id: String)
signal owned_themes_changed
signal equipped_theme_changed(theme_id: String)
signal mission_claimed
signal daily_claimed_signal
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
var owned_trails: Array[String] = ["none"]
var equipped_trail: String = "none"
var owned_themes: Array[String] = ["default"]
var equipped_theme: String = "default"
var claimed_missions: Array[String] = []
var campaign_level: int = 1
var active_mode: String = "infinite"
var active_level: int = 1

var daily_date: String = ""
var daily_challenges: Array = []
var daily_progress: Dictionary = {}
var daily_claimed: Array[String] = []
var daily_coins: int = 0
var daily_distance: int = 0
var daily_time: int = 0
var daily_games: int = 0

const SAVE_PATH: String = "user://settings.cfg"

const DAILY_POOL: Array = [
	{"type": "distance", "targets": [300, 500, 800]},
	{"type": "coins",    "targets": [20, 40, 60]},
	{"type": "time",     "targets": [60, 120, 180]},
	{"type": "games",    "targets": [3, 5, 8]},
]

func _ready() -> void:
	load_settings()
	ensure_daily_challenges()
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
	daily_coins += 1
	update_daily_progress()
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

func buy_theme(theme_id: String) -> bool:
	var theme: Dictionary = Catalog.get_theme(theme_id)
	if coins_total < theme["price"]:
		return false
	if theme_id in owned_themes:
		return false
	coins_total -= theme["price"]
	owned_themes.append(theme_id)
	owned_themes_changed.emit()
	coin_collected.emit(coins_total)
	save_settings()
	return true

func equip_theme(theme_id: String) -> bool:
	if not theme_id in owned_themes:
		return false
	equipped_theme = theme_id
	equipped_theme_changed.emit(theme_id)
	save_settings()
	return true

func get_mission_progress(mission: Dictionary) -> int:
	match mission["type"]:
		"campaign_level":
			return campaign_level
		"distance":
			return best_distance
		"owned_skins":
			return owned_skins.size()
		"owned_themes":
			return owned_themes.size()
		"trail_equipped":
			return 1 if equipped_trail != "default" else 0
	return 0

func is_mission_complete(mission: Dictionary) -> bool:
	return get_mission_progress(mission) >= mission["target"]

func is_mission_claimed(id: String) -> bool:
	return id in claimed_missions

func claim_mission(mission: Dictionary) -> bool:
	var id: String = mission["id"]
	if not is_mission_complete(mission) or is_mission_claimed(id):
		return false
	coins_total += mission["reward"]
	claimed_missions.append(id)
	coin_collected.emit(coins_total)
	mission_claimed.emit()
	save_settings()
	return true

func _today_string() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]

func ensure_daily_challenges() -> void:
	var today: String = _today_string()
	if daily_date == today:
		return
	daily_date = today
	var rng := RandomNumberGenerator.new()
	rng.seed = int(daily_date.replace("-", ""))
	var available: Array[int] = [0, 1, 2, 3]
	var chosen: Array[int] = []
	while chosen.size() < 3:
		var pick: int = rng.randi_range(0, available.size() - 1)
		chosen.append(available[pick])
		available.remove_at(pick)
	daily_challenges = []
	var slot: int = 0
	for pool_idx in chosen:
		var entry: Dictionary = DAILY_POOL[pool_idx]
		var targets: Array = entry["targets"]
		var target: int = targets[rng.randi_range(0, targets.size() - 1)]
		daily_challenges.append(_make_daily_challenge(entry["type"], target, slot))
		slot += 1
	daily_progress = {}
	daily_claimed.clear()
	daily_coins = 0
	daily_distance = 0
	daily_time = 0
	daily_games = 0
	save_settings()

func _make_daily_challenge(type: String, target: int, slot: int) -> Dictionary:
	var id: String = "daily_" + str(slot)
	var desc: String
	var reward: int
	match type:
		"distance":
			desc = "Parcours %dm cumulé aujourd'hui" % target
			reward = target / 10
		"coins":
			desc = "Ramasse %d pièces aujourd'hui" % target
			reward = target
		"time":
			desc = "Joue %ds aujourd'hui" % target
			reward = target / 2
		"games":
			desc = "Joue %d parties aujourd'hui" % target
			reward = target * 8
		_:
			desc = "?"
			reward = 0
	return {"id": id, "type": type, "target": target, "desc": desc, "reward": reward}

func update_daily_progress() -> void:
	for ch in daily_challenges:
		var val: int
		match ch["type"]:
			"distance": val = daily_distance
			"coins":    val = daily_coins
			"time":     val = daily_time
			"games":    val = daily_games
			_:          val = 0
		daily_progress[ch["id"]] = val

func is_daily_complete(ch: Dictionary) -> bool:
	return daily_progress.get(ch["id"], 0) >= ch["target"]

func is_daily_claimed(id: String) -> bool:
	return id in daily_claimed

func claim_daily(ch: Dictionary) -> bool:
	var id: String = ch["id"]
	if not is_daily_complete(ch) or is_daily_claimed(id):
		return false
	coins_total += ch["reward"]
	daily_claimed.append(id)
	coin_collected.emit(coins_total)
	daily_claimed_signal.emit()
	save_settings()
	return true

func get_level_duration(level: int) -> float:
	return 30.0 + float(level - 1) * 5.0

func get_level_reward(level: int) -> int:
	return 20 + level * 10

func is_infinite_unlocked() -> bool:
	return campaign_level > INFINITE_UNLOCK_LEVEL

func is_envol_unlocked() -> bool:
	return campaign_level > ENVOL_UNLOCK_LEVEL

# Signe vertical centralisé (source de vérité unique pour l'inversion du mode envol).
# +1.0 en envol (le joueur MONTE), -1.0 sinon (chute). Tous les scripts lisent ça.
func get_fall_dir() -> float:
	return 1.0 if active_mode == "envol" else -1.0

func complete_current_level() -> void:
	coins_total += get_level_reward(active_level)
	coin_collected.emit(coins_total)
	if active_level == campaign_level:
		campaign_level += 1
	save_settings()

func _migrate_trails() -> void:
	var legacy_ids: Array[String] = ["default", "turquoise", "orange", "mustard", "bordeaux", "creme"]
	if equipped_trail in legacy_ids:
		equipped_trail = "none"
	var cleaned: Array[String] = []
	for tid in owned_trails:
		if not tid in legacy_ids:
			cleaned.append(tid)
	if not "none" in cleaned:
		cleaned.insert(0, "none")
	owned_trails.assign(cleaned)

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
	cfg.set_value("cosmetics", "owned_themes", owned_themes)
	cfg.set_value("cosmetics", "equipped_theme", equipped_theme)
	cfg.set_value("missions", "claimed_missions", claimed_missions)
	cfg.set_value("campaign", "campaign_level", campaign_level)
	cfg.set_value("daily", "date", daily_date)
	cfg.set_value("daily", "challenges", daily_challenges)
	cfg.set_value("daily", "progress", daily_progress)
	cfg.set_value("daily", "claimed", daily_claimed)
	cfg.set_value("daily", "coins", daily_coins)
	cfg.set_value("daily", "distance", daily_distance)
	cfg.set_value("daily", "time", daily_time)
	cfg.set_value("daily", "games", daily_games)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("input", "control_mode", ControlMode.KEYBOARD)
	if control_mode > ControlMode.TOUCH:
		control_mode = ControlMode.TOUCH
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	coins_total = cfg.get_value("stats", "coins_total", 0)
	best_distance = cfg.get_value("stats", "best_distance", 0)
	owned_skins.assign(cfg.get_value("cosmetics", "owned_skins", ["default"]))
	equipped_skin = cfg.get_value("cosmetics", "equipped_skin", "default")
	owned_trails.assign(cfg.get_value("cosmetics", "owned_trails", ["none"]))
	equipped_trail = cfg.get_value("cosmetics", "equipped_trail", "none")
	_migrate_trails()
	owned_themes.assign(cfg.get_value("cosmetics", "owned_themes", ["default"]))
	equipped_theme = cfg.get_value("cosmetics", "equipped_theme", "default")
	claimed_missions.assign(cfg.get_value("missions", "claimed_missions", []))
	campaign_level = cfg.get_value("campaign", "campaign_level", 1)
	daily_date = cfg.get_value("daily", "date", "")
	daily_challenges = cfg.get_value("daily", "challenges", [])
	daily_progress = cfg.get_value("daily", "progress", {})
	daily_claimed.assign(cfg.get_value("daily", "claimed", []))
	daily_coins = cfg.get_value("daily", "coins", 0)
	daily_distance = cfg.get_value("daily", "distance", 0)
	daily_time = cfg.get_value("daily", "time", 0)
	daily_games = cfg.get_value("daily", "games", 0)
