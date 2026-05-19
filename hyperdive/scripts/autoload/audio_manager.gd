extends Node
class_name AudioManagerClass

@export var coin_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var game_over_sfx: AudioStream
@export var ui_click_sfx: AudioStream

const SFX_POOL_SIZE: int = 6
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)

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
