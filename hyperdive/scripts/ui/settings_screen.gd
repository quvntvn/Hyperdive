extends CanvasLayer
class_name SettingsScreen

var _was_paused: bool = false

func _ready() -> void:
	add_to_group("settings_screen")
	visible = false
	%MasterSlider.value_changed.connect(Settings.set_master_volume)
	%MusicSlider.value_changed.connect(Settings.set_music_volume)
	%SfxSlider.value_changed.connect(Settings.set_sfx_volume)
	%TouchButton.pressed.connect(_on_touch_pressed)
	%TiltButton.pressed.connect(_on_tilt_pressed)
	%CloseButton.pressed.connect(close)

func _on_touch_pressed() -> void:
	Settings.set_control_mode_value(Settings.ControlMode.TOUCH)
	_refresh_control_highlight()

func _on_tilt_pressed() -> void:
	Settings.set_control_mode_value(Settings.ControlMode.TILT)
	_refresh_control_highlight()

func _refresh_control_highlight() -> void:
	%TouchButton.disabled = Settings.control_mode == Settings.ControlMode.TOUCH
	%TiltButton.disabled = Settings.control_mode == Settings.ControlMode.TILT

func _refresh_values() -> void:
	%MasterSlider.set_value_no_signal(Settings.master_volume)
	%MusicSlider.set_value_no_signal(Settings.music_volume)
	%SfxSlider.set_value_no_signal(Settings.sfx_volume)
	_refresh_control_highlight()

func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh_values()
	visible = true

func close() -> void:
	Audio.play_ui_click()
	visible = false
	get_tree().paused = _was_paused

