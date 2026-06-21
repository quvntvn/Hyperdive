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
	# Sélecteur de langue (lot 0 i18n). Les libellés sont des ENDONYMES (chaque langue dans sa
	# propre langue) → on NE les traduit PAS ; chaque item porte son code en métadonnée.
	%LanguageOption.add_item("Français")
	%LanguageOption.set_item_metadata(0, "fr")
	%LanguageOption.add_item("English")
	%LanguageOption.set_item_metadata(1, "en")
	%LanguageOption.item_selected.connect(_on_language_selected)
	%CloseButton.pressed.connect(close)
	UIAnimations.wire_buttons(self)
	# Panneau en verre translucide (plus de fond bleu opaque) → laisse voir le décor flouté derrière.
	UIAnimations.make_glass_panel($SettingsPanel)

func _refresh_values() -> void:
	%MasterSlider.set_value_no_signal(Settings.master_volume)
	%MusicSlider.set_value_no_signal(Settings.music_volume)
	%SfxSlider.set_value_no_signal(Settings.sfx_volume)
	%VibrationCheck.set_pressed_no_signal(Settings.vibration_enabled)
	# Position le sélecteur sur la langue courante (sans déclencher item_selected).
	%LanguageOption.select(1 if Locale.current == "en" else 0)

func _on_language_selected(idx: int) -> void:
	Audio.play_ui_click()
	# Bascule à chaud : Locale applique au TranslationServer (les Control à clé .tscn de CET écran
	# — titre, label "Langue" — se retraduisent seuls) + émet language_changed (le menu derrière
	# réassigne ses libellés posés en code).
	Locale.set_language(String(%LanguageOption.get_item_metadata(idx)))

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
