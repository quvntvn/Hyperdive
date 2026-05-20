extends Node
class_name AudioManagerClass

@export var coin_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var game_over_sfx: AudioStream
@export var ui_click_sfx: AudioStream
@export var gameplay_music: AudioStream
@export var fall_whoosh: AudioStream

const SFX_POOL_SIZE: int = 6
const DUCKED_VOLUME_DB: float = -12.0
const NORMAL_VOLUME_DB: float = 0.0
const WHOOSH_MIN_DB: float = -10.0
const WHOOSH_MAX_DB: float = 0.0
const WHOOSH_MAX_FALL_SPEED: float = 18.0
const WHOOSH_DUCKED_DB: float = -40.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _whoosh_player: AudioStreamPlayer
var _is_ducked: bool = false

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
