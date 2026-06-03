extends Node
class_name AudioManagerClass

@export var coin_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var game_over_sfx: AudioStream
@export var ui_click_sfx: AudioStream
@export var gameplay_music: AudioStream
@export var fall_whoosh: AudioStream
@export var jetpack_sfx: AudioStream

const SFX_POOL_SIZE: int = 6
const DUCKED_VOLUME_DB: float = -12.0
const NORMAL_VOLUME_DB: float = 0.0
const WHOOSH_MIN_DB: float = -10.0
const WHOOSH_MAX_DB: float = 0.0
const WHOOSH_MAX_FALL_SPEED: float = 18.0
const WHOOSH_DUCKED_DB: float = -40.0
# Jetpack (mode jetpack) : MÊME logique que le whoosh — volume piloté par la vitesse
# verticale, lerp min↔max. Pas de RNG (le whoosh n'en a pas non plus).
const JETPACK_MIN_DB: float = -10.0
const JETPACK_MAX_DB: float = 0.0
const JETPACK_DUCKED_DB: float = -40.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _whoosh_player: AudioStreamPlayer
var _jetpack_player: AudioStreamPlayer
var _is_ducked: bool = false
# SFX power-up SYNTHÉTISÉS en code (aucun fichier) : pré-générés une fois au démarrage en
# PCM 16 bits, joués via le pool SFX normal. Un timbre distinct par type + le "shield break".
var _powerup_sfx: Dictionary = {}
var _shield_break_sfx: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	Settings._apply_bus_volume("Master", Settings.master_volume)
	Settings._apply_bus_volume("Music", Settings.music_volume)
	Settings._apply_bus_volume("SFX", Settings.sfx_volume)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.autoplay = false
	add_child(_music_player)
	if gameplay_music is AudioStreamMP3:
		(gameplay_music as AudioStreamMP3).loop = true
	_music_player.stream = gameplay_music
	play_music()
	_whoosh_player = AudioStreamPlayer.new()
	_whoosh_player.bus = "SFX"
	_whoosh_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if fall_whoosh is AudioStreamMP3:
		(fall_whoosh as AudioStreamMP3).loop = true
	_whoosh_player.stream = fall_whoosh
	_whoosh_player.volume_db = WHOOSH_MIN_DB
	add_child(_whoosh_player)
	_whoosh_player.play()
	# Jetpack : player dédié, même bus SFX, en boucle. Pas d'autoplay (lancé via
	# play_jetpack() seulement en mode jetpack).
	_jetpack_player = AudioStreamPlayer.new()
	_jetpack_player.bus = "SFX"
	_jetpack_player.process_mode = Node.PROCESS_MODE_ALWAYS
	if jetpack_sfx is AudioStreamMP3:
		(jetpack_sfx as AudioStreamMP3).loop = true
	_jetpack_player.stream = jetpack_sfx
	_jetpack_player.volume_db = JETPACK_MIN_DB
	add_child(_jetpack_player)
	_generate_powerup_sfx()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_idx: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_idx: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := _sfx_pool[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.play()

func play_coin() -> void: _play_sfx(coin_sfx)
func play_hit() -> void: _play_sfx(hit_sfx)
func play_game_over() -> void: _play_sfx(game_over_sfx)
func play_ui_click() -> void: _play_sfx(ui_click_sfx)

func play_music() -> void:
	if _music_player and not _music_player.playing:
		_music_player.play()

func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()

func pause_music() -> void:
	if _music_player:
		_music_player.stream_paused = true

func resume_music() -> void:
	if _music_player:
		_music_player.stream_paused = false

func duck_music() -> void:
	if _music_player:
		_music_player.volume_db = DUCKED_VOLUME_DB
	if _whoosh_player:
		_whoosh_player.volume_db = WHOOSH_DUCKED_DB
	if _jetpack_player:
		_jetpack_player.volume_db = JETPACK_DUCKED_DB
	_is_ducked = true

func unduck_music() -> void:
	if _music_player:
		_music_player.volume_db = NORMAL_VOLUME_DB
	_is_ducked = false

func play_whoosh() -> void:
	if _whoosh_player:
		_whoosh_player.volume_db = WHOOSH_MIN_DB
		_whoosh_player.play()

func stop_whoosh() -> void:
	if _whoosh_player:
		_whoosh_player.stop()

func set_whoosh_intensity(fall_speed: float) -> void:
	if _is_ducked or _whoosh_player == null:
		return
	var t: float = clamp(absf(fall_speed) / WHOOSH_MAX_FALL_SPEED, 0.0, 1.0)
	_whoosh_player.volume_db = lerpf(WHOOSH_MIN_DB, WHOOSH_MAX_DB, t)

# Ralenti : baisse la hauteur du vent (le temps s'etire). 1.0 = normal, ~0.7 = ralenti.
func set_whoosh_pitch(p: float) -> void:
	if _whoosh_player != null:
		_whoosh_player.pitch_scale = p

func play_jetpack() -> void:
	if _jetpack_player:
		_jetpack_player.volume_db = JETPACK_MIN_DB
		_jetpack_player.play()

func stop_jetpack() -> void:
	if _jetpack_player:
		_jetpack_player.stop()

# Même mécanique que set_whoosh_intensity : volume piloté par la vitesse, pas de RNG.
func set_jetpack_intensity(speed: float) -> void:
	if _is_ducked or _jetpack_player == null:
		return
	var t: float = clamp(absf(speed) / WHOOSH_MAX_FALL_SPEED, 0.0, 1.0)
	_jetpack_player.volume_db = lerpf(JETPACK_MIN_DB, JETPACK_MAX_DB, t)

# ── SFX power-up synthétisés ────────────────────────────────────────────────────────────
# On bake des AudioStreamWAV en mémoire (PCM 16 bits mono). Coût unique au démarrage, ensuite
# c'est un AudioStream comme un autre joué par le pool. Évite d'embarquer des fichiers et donne
# un grain "arcade rétro" cohérent. Taux réduit (22 kHz) = suffisant pour des bips courts.
const SYNTH_RATE: int = 22050

enum Wave { SINE, SQUARE, SAW, TRI }

func _generate_powerup_sfx() -> void:
	# Ramassage : un timbre par type, immédiatement reconnaissable à l'oreille.
	# shield = petit arpège majeur montant (rassurant) ; slowmo = glissando descendant
	# (le temps qui s'étire) ; magnet = bourdon montant qui "buzz" ; boost = sweep punchy.
	_powerup_sfx["shield"] = _make_arp([523.0, 659.0, 784.0], 0.075, Wave.TRI, 0.5)
	_powerup_sfx["slowmo"] = _make_sweep(0.5, 760.0, 280.0, Wave.SINE, 0.01, 0.45, 6.0, 14.0, 0.0, 0.0, 0.5)
	_powerup_sfx["magnet"] = _make_sweep(0.45, 180.0, 480.0, Wave.SQUARE, 0.02, 0.4, 0.0, 0.0, 20.0, 0.0, 0.32)
	_powerup_sfx["boost"] = _make_sweep(0.35, 320.0, 1300.0, Wave.SAW, 0.005, 0.3, 0.0, 0.0, 0.0, 0.1, 0.5)
	# Bouclier qui éclate : zap descendant + bruit → "verre qui casse", distinct du hit de mort.
	_shield_break_sfx = _make_sweep(0.35, 1000.0, 180.0, Wave.SQUARE, 0.003, 0.32, 0.0, 0.0, 0.0, 0.3, 0.55)

func play_powerup(type: String) -> void:
	var s: AudioStream = _powerup_sfx.get(type, null)
	if s != null:
		_play_sfx(s)

func play_shield_break() -> void:
	_play_sfx(_shield_break_sfx)

func _osc(phase: float, wave: int) -> float:
	match wave:
		Wave.SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		Wave.SAW:
			return fmod(phase / TAU, 1.0) * 2.0 - 1.0
		Wave.TRI:
			return asin(sin(phase)) * (2.0 / PI)
		_:
			return sin(phase)

# Empaquète un tableau d'échantillons [-1..1] en PCM 16 bits little-endian (AudioStreamWAV).
func _pcm_to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var n: int = samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var iv: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		# & 0xFF / >> 8 marchent en complément à 2 sur les ints négatifs en GDScript.
		data[i * 2] = iv & 0xFF
		data[i * 2 + 1] = (iv >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SYNTH_RATE
	stream.stereo = false
	stream.data = data
	return stream

# Glissando : fréquence interpolée f0→f1, enveloppe attaque puis release exponentielle.
# vibrato (Hz/profondeur) = ondulation de hauteur ; tremolo = ondulation de volume ;
# noise = mélange de bruit blanc (0..1) ; gain = volume crête.
func _make_sweep(duration: float, f0: float, f1: float, wave: int, attack: float, release: float,
		vibrato_hz: float, vibrato_depth: float, tremolo_hz: float, noise: float, gain: float) -> AudioStreamWAV:
	var n: int = int(duration * SYNTH_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / SYNTH_RATE
		var u: float = t / duration
		var freq: float = lerpf(f0, f1, u)
		if vibrato_hz > 0.0:
			freq += sin(TAU * vibrato_hz * t) * vibrato_depth
		phase += TAU * freq / SYNTH_RATE
		var s: float = _osc(phase, wave)
		if noise > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, noise)
		var env: float = t / attack if t < attack else exp(-((t - attack) / maxf(release, 0.0001)) * 3.0)
		if tremolo_hz > 0.0:
			env *= 0.7 + 0.3 * sin(TAU * tremolo_hz * t)
		samples[i] = s * env * gain
	return _pcm_to_stream(samples)

# Arpège : suite de notes égales, chacune avec sa propre petite enveloppe (attaque douce,
# release sur la fin de la note) → "bip-bip-bip" montant net.
func _make_arp(freqs: Array, note_dur: float, wave: int, gain: float) -> AudioStreamWAV:
	var per: int = int(note_dur * SYNTH_RATE)
	var samples := PackedFloat32Array()
	samples.resize(per * freqs.size())
	var idx: int = 0
	for f: float in freqs:
		var phase: float = 0.0
		for i in per:
			var t: float = float(i) / SYNTH_RATE
			phase += TAU * f / SYNTH_RATE
			var env: float = t / 0.008 if t < 0.008 else exp(-((t - 0.008) / (note_dur * 0.6)) * 3.0)
			samples[idx] = _osc(phase, wave) * env * gain
			idx += 1
	return _pcm_to_stream(samples)
