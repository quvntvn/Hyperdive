extends Node
class_name SettingsManager

enum ControlMode { KEYBOARD, TOUCH }

# Seuil de distance (mode infini) qui débloque le jetpack.
const JETPACK_UNLOCK_DISTANCE: int = 1000

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
var vibration_enabled: bool = true
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var coins_total: int = 0
var coins_this_run: int = 0
var best_distance: int = 0
var best_infinite_distance: int = 0   # record en mode infini ("Record") — débloque le jetpack à 1000 m
var best_jetpack_distance: int = 0    # record d'altitude en mode jetpack (défis altitude)
var infinite_unlocked: bool = false   # passé true à la 1re fin de niveau campagne

# === Stats cumulées pour les défis (persistées) ===
var coins_lifetime: int = 0           # total de pièces JAMAIS ramassées (ne baisse pas aux achats)
var total_games: int = 0              # parties jouées tous modes
var games_infinite: int = 0
var games_jetpack: int = 0
var games_campaign: int = 0
var total_deaths: int = 0
var total_obstacles_dodged: int = 0   # esquives cumulées (1 par obstacle dépassé)
var best_obstacles_run: int = 0       # MEILLEUR nb d'esquives en une partie
var best_coins_run: int = 0           # MEILLEUR nb de pièces ramassées en une partie
var best_no_wall_time: int = 0        # plus longue série (s) sans toucher un mur
var powerups_used: Array[String] = [] # ensemble des types de power-up déjà utilisés
var ascetic_done: bool = false        # 1500 m en classique sans ramasser une seule pièce

# === Transient (par run, NON persisté) ===
var obstacles_dodged_run: int = 0
var run_active: bool = false          # garde-fou : ne compter les esquives que pendant le run
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

# Retour haptique centralisé. No-op si désactivé (option réglages) ou hors mobile.
# On teste OS.get_name() (fiable sur l'APK) plutôt que has_feature("mobile") qui pouvait
# court-circuiter la vibration. Log debug temporaire pour diagnostiquer sur appareil.
func vibrate(duration_ms: int) -> void:
	if not vibration_enabled:
		return
	var os_name: String = OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		return
	print("[haptic] vibrate called ", duration_ms, " ms (os=", os_name, ")")
	Input.vibrate_handheld(duration_ms)

func set_vibration_enabled(v: bool) -> void:
	vibration_enabled = v
	save_settings()

func set_control_mode_value(mode: ControlMode) -> void:
	control_mode = mode
	control_mode_changed.emit(control_mode)
	save_settings()

func add_coin() -> void:
	coins_total += 1
	coins_this_run += 1
	coins_lifetime += 1   # cumul historique (ne baisse jamais, contrairement à coins_total)
	daily_coins += 1
	update_daily_progress()
	coin_collected.emit(coins_total)
	save_settings()

func reset_run_stats() -> void:
	coins_this_run = 0
	obstacles_dodged_run = 0
	run_active = true

func update_best_distance(distance: int) -> void:
	var changed: bool = false
	if distance > best_distance:
		best_distance = distance
		changed = true
	# Le mode infini ("Record") alimente best_infinite_distance, qui débloque le jetpack.
	if active_mode == "infinite" and distance > best_infinite_distance:
		best_infinite_distance = distance
		changed = true
	if active_mode == "jetpack" and distance > best_jetpack_distance:
		best_jetpack_distance = distance
		changed = true
	if changed:
		save_settings()

# === Hooks de stats pour les défis (un seul point d'appel chacun) ===

# Début de partie (appelé depuis player._ready). Incrémente parties + remet les compteurs de run.
func register_run_start() -> void:
	reset_run_stats()
	total_games += 1
	daily_games += 1
	match active_mode:
		"infinite": games_infinite += 1
		"jetpack":  games_jetpack += 1
		"campaign": games_campaign += 1
	update_daily_progress()
	print("[stats] run start: mode=%s total_games=%d (inf=%d jet=%d camp=%d)" % [active_mode, total_games, games_infinite, games_jetpack, games_campaign])
	save_settings()

# Un obstacle dépassé = une esquive. Appelé au despawn (une seule fois par obstacle).
# Garde-fou run_active : ne compte pas après la mort (le joueur est figé, mais ceinture+bretelles).
func register_obstacle_dodged() -> void:
	if not run_active:
		return
	total_obstacles_dodged += 1
	obstacles_dodged_run += 1
	# Pas de save ici (trop fréquent) : persisté au finalize_run de fin de partie.

# Type de power-up ramassé. On mémorise l'ensemble des types vus (défi "utilise les 4").
func register_powerup_used(ptype: String) -> void:
	if ptype in powerups_used:
		return
	powerups_used.append(ptype)
	print("[stats] powerup used: %s (types=%d/4)" % [ptype, powerups_used.size()])
	save_settings()

func register_death() -> void:
	total_deaths += 1

# Fin de partie (mort OU niveau réussi). Met à jour les MEILLEURS scores par run + flags.
# no_wall_seconds = plus longue série sans toucher un mur (calculée côté player).
func finalize_run(distance: int, no_wall_seconds: int) -> void:
	if coins_this_run > best_coins_run:
		best_coins_run = coins_this_run
	if obstacles_dodged_run > best_obstacles_run:
		best_obstacles_run = obstacles_dodged_run
	if no_wall_seconds > best_no_wall_time:
		best_no_wall_time = no_wall_seconds
	# Ascète : 1500 m en classique sans une seule pièce ramassée sur ce run.
	if active_mode == "infinite" and distance >= 1500 and coins_this_run == 0:
		ascetic_done = true
	run_active = false
	print("[stats] run end: mode=%s dist=%d coins_run=%d(best%d) dodged_run=%d(best%d) no_wall=%ds(best%d) deaths=%d obstacles_tot=%d coins_life=%d ascetic=%s" % [active_mode, distance, coins_this_run, best_coins_run, obstacles_dodged_run, best_obstacles_run, no_wall_seconds, best_no_wall_time, total_deaths, total_obstacles_dodged, coins_lifetime, ascetic_done])
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
		"campaign_level":    return campaign_level
		"infinite_distance": return best_infinite_distance
		"jetpack_distance":  return best_jetpack_distance
		"distance":          return best_distance   # compat héritée
		"coins_lifetime":    return coins_lifetime
		"total_games":       return total_games
		"obstacles_dodged":  return total_obstacles_dodged
		"obstacles_run":     return best_obstacles_run
		"coins_run":         return best_coins_run
		"no_wall_time":      return best_no_wall_time
		"powerups_used":     return powerups_used.size()
		"deaths":            return total_deaths
		"ascetic":           return 1 if ascetic_done else 0
		# Composé : complété quand les DEUX distances atteignent la cible (min >= target).
		"dual_distance":     return mini(best_infinite_distance, best_jetpack_distance)
		"all_shop_skins":    return _owned_shop_count(Catalog.SKINS, owned_skins)
		"all_shop_trails":   return _owned_shop_count(Catalog.TRAILS, owned_trails)
		"all_shop_themes":   return _owned_shop_count(Catalog.THEMES, owned_themes)
		"owned_skins":       return owned_skins.size()
		"owned_themes":      return owned_themes.size()
		"trail_equipped":    return 1 if equipped_trail != "none" else 0
	return 0

# Nombre de cosmétiques ACHETABLES (price >= 0) possédés — les exclusifs défis (price -1)
# ne comptent pas pour les défis "possède tous les X du shop".
func _owned_shop_count(catalog: Array, owned: Array) -> int:
	var n: int = 0
	for item in catalog:
		if int(item.get("price", 0)) >= 0 and item["id"] in owned:
			n += 1
	return n

func is_mission_complete(mission: Dictionary) -> bool:
	return get_mission_progress(mission) >= mission["target"]

func is_mission_claimed(id: String) -> bool:
	return id in claimed_missions

func claim_mission(mission: Dictionary) -> bool:
	var id: String = mission["id"]
	if not is_mission_complete(mission) or is_mission_claimed(id):
		return false
	coins_total += mission["reward"]
	# Récompense cosmétique exclusive (jalons) : débloque le skin/trail s'il n'est pas déjà possédé.
	if mission.has("reward_skin"):
		var sid: String = mission["reward_skin"]
		if not sid in owned_skins:
			owned_skins.append(sid)
			owned_skins_changed.emit()
			print("[missions] skin exclusif débloqué : %s" % sid)
	if mission.has("reward_trail"):
		var tid: String = mission["reward_trail"]
		if not tid in owned_trails:
			owned_trails.append(tid)
			owned_trails_changed.emit()
			print("[missions] trail exclusif débloqué : %s" % tid)
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
			reward = floori(target / 10.0)
		"coins":
			desc = "Ramasse %d pièces aujourd'hui" % target
			reward = target
		"time":
			desc = "Joue %ds aujourd'hui" % target
			reward = floori(target / 2.0)
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
	# Débloqué dès la 1re fin de niveau campagne (flag) ; campaign_level > 1 = garde-fou.
	return infinite_unlocked or campaign_level > 1

func is_jetpack_unlocked() -> bool:
	# Débloqué après avoir atteint 1000 m en mode infini ("Record").
	return best_infinite_distance >= JETPACK_UNLOCK_DISTANCE

# Signe vertical centralisé (source de vérité unique pour l'inversion du mode jetpack).
# +1.0 en jetpack (le joueur MONTE), -1.0 sinon (chute). Tous les scripts lisent ça.
func get_fall_dir() -> float:
	return 1.0 if active_mode == "jetpack" else -1.0

func complete_current_level() -> void:
	coins_total += get_level_reward(active_level)
	coin_collected.emit(coins_total)
	# Terminer un niveau (le 1er suffit) débloque définitivement le mode infini ("Record").
	infinite_unlocked = true
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

# DEBUG TEMP — débloque TOUT (cosmétiques + pièces) pour tester sans faire les défis.
# À RETIRER avant la sortie. Déclenché par la touche "U" / appui long sur le titre (main_menu).
func debug_unlock_all() -> void:
	for skin in Catalog.SKINS:
		if not skin["id"] in owned_skins:
			owned_skins.append(skin["id"])
	for trail in Catalog.TRAILS:
		if not trail["id"] in owned_trails:
			owned_trails.append(trail["id"])
	for theme in Catalog.THEMES:
		if not theme["id"] in owned_themes:
			owned_themes.append(theme["id"])
	coins_total = 99999
	owned_skins_changed.emit()
	owned_trails_changed.emit()
	owned_themes_changed.emit()
	coin_collected.emit(coins_total)
	save_settings()
	print("[debug] tout débloqué")

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("input", "control_mode", control_mode)
	cfg.set_value("input", "vibration_enabled", vibration_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("stats", "coins_total", coins_total)
	cfg.set_value("stats", "best_distance", best_distance)
	cfg.set_value("stats", "best_infinite_distance", best_infinite_distance)
	cfg.set_value("stats", "best_jetpack_distance", best_jetpack_distance)
	cfg.set_value("stats", "coins_lifetime", coins_lifetime)
	cfg.set_value("stats", "total_games", total_games)
	cfg.set_value("stats", "games_infinite", games_infinite)
	cfg.set_value("stats", "games_jetpack", games_jetpack)
	cfg.set_value("stats", "games_campaign", games_campaign)
	cfg.set_value("stats", "total_deaths", total_deaths)
	cfg.set_value("stats", "total_obstacles_dodged", total_obstacles_dodged)
	cfg.set_value("stats", "best_obstacles_run", best_obstacles_run)
	cfg.set_value("stats", "best_coins_run", best_coins_run)
	cfg.set_value("stats", "best_no_wall_time", best_no_wall_time)
	cfg.set_value("stats", "powerups_used", powerups_used)
	cfg.set_value("stats", "ascetic_done", ascetic_done)
	cfg.set_value("cosmetics", "owned_skins", owned_skins)
	cfg.set_value("cosmetics", "equipped_skin", equipped_skin)
	cfg.set_value("cosmetics", "owned_trails", owned_trails)
	cfg.set_value("cosmetics", "equipped_trail", equipped_trail)
	cfg.set_value("cosmetics", "owned_themes", owned_themes)
	cfg.set_value("cosmetics", "equipped_theme", equipped_theme)
	cfg.set_value("missions", "claimed_missions", claimed_missions)
	cfg.set_value("campaign", "campaign_level", campaign_level)
	cfg.set_value("campaign", "infinite_unlocked", infinite_unlocked)
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
	vibration_enabled = cfg.get_value("input", "vibration_enabled", true)
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	coins_total = cfg.get_value("stats", "coins_total", 0)
	best_distance = cfg.get_value("stats", "best_distance", 0)
	best_infinite_distance = cfg.get_value("stats", "best_infinite_distance", 0)
	best_jetpack_distance = cfg.get_value("stats", "best_jetpack_distance", 0)
	coins_lifetime = cfg.get_value("stats", "coins_lifetime", 0)
	total_games = cfg.get_value("stats", "total_games", 0)
	games_infinite = cfg.get_value("stats", "games_infinite", 0)
	games_jetpack = cfg.get_value("stats", "games_jetpack", 0)
	games_campaign = cfg.get_value("stats", "games_campaign", 0)
	total_deaths = cfg.get_value("stats", "total_deaths", 0)
	total_obstacles_dodged = cfg.get_value("stats", "total_obstacles_dodged", 0)
	best_obstacles_run = cfg.get_value("stats", "best_obstacles_run", 0)
	best_coins_run = cfg.get_value("stats", "best_coins_run", 0)
	best_no_wall_time = cfg.get_value("stats", "best_no_wall_time", 0)
	powerups_used.assign(cfg.get_value("stats", "powerups_used", []))
	ascetic_done = cfg.get_value("stats", "ascetic_done", false)
	# Migration : best_infinite_distance est un champ récent. Pour les sauvegardes
	# antérieures (où il vaut 0 alors que best_distance reflète déjà des runs infini),
	# on le sème depuis best_distance pour ne pas re-verrouiller le jetpack à tort.
	if best_infinite_distance == 0 and best_distance > 0:
		best_infinite_distance = best_distance
	owned_skins.assign(cfg.get_value("cosmetics", "owned_skins", ["default"]))
	equipped_skin = cfg.get_value("cosmetics", "equipped_skin", "default")
	owned_trails.assign(cfg.get_value("cosmetics", "owned_trails", ["none"]))
	equipped_trail = cfg.get_value("cosmetics", "equipped_trail", "none")
	_migrate_trails()
	owned_themes.assign(cfg.get_value("cosmetics", "owned_themes", ["default"]))
	equipped_theme = cfg.get_value("cosmetics", "equipped_theme", "default")
	claimed_missions.assign(cfg.get_value("missions", "claimed_missions", []))
	campaign_level = cfg.get_value("campaign", "campaign_level", 1)
	infinite_unlocked = cfg.get_value("campaign", "infinite_unlocked", false)
	daily_date = cfg.get_value("daily", "date", "")
	daily_challenges = cfg.get_value("daily", "challenges", [])
	daily_progress = cfg.get_value("daily", "progress", {})
	daily_claimed.assign(cfg.get_value("daily", "claimed", []))
	daily_coins = cfg.get_value("daily", "coins", 0)
	daily_distance = cfg.get_value("daily", "distance", 0)
	daily_time = cfg.get_value("daily", "time", 0)
	daily_games = cfg.get_value("daily", "games", 0)
