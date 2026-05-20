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
	_style_buttons()

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

func _style_buttons() -> void:
	for btn: Button in [%TouchButton, %TiltButton, %CloseButton]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.235, 0.682, 0.639)
		normal.set_corner_radius_all(8)
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		btn.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.32, 0.78, 0.73)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed_style := normal.duplicate() as StyleBoxFlat
		pressed_style.bg_color = Color(0.18, 0.55, 0.51)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", normal.duplicate())
		var disabled_style := normal.duplicate() as StyleBoxFlat
		disabled_style.bg_color = Color(0.914, 0.310, 0.216)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		btn.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.82, 0.72))
		btn.add_theme_color_override("font_disabled_color", Color(0.957, 0.914, 0.804))
