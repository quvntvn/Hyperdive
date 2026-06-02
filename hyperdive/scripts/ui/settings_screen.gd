extends CanvasLayer
class_name SettingsScreen

var _was_paused: bool = false

func _ready() -> void:
	add_to_group("settings_screen")
	visible = false
	%MasterSlider.value_changed.connect(Settings.set_master_volume)
	%MusicSlider.value_changed.connect(Settings.set_music_volume)
	%SfxSlider.value_changed.connect(Settings.set_sfx_volume)
	%VibrationCheck.toggled.connect(Settings.set_vibration_enabled)
	%CloseButton.pressed.connect(close)
	UIAnimations.wire_buttons(self)

func _refresh_values() -> void:
	%MasterSlider.set_value_no_signal(Settings.master_volume)
	%MusicSlider.set_value_no_signal(Settings.music_volume)
	%SfxSlider.set_value_no_signal(Settings.sfx_volume)
	%VibrationCheck.set_pressed_no_signal(Settings.vibration_enabled)

func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	_refresh_values()
	visible = true
	UIAnimations.pop_in($SettingsPanel, $Background)

func close() -> void:
	Audio.play_ui_click()
	visible = false
	get_tree().paused = _was_paused
