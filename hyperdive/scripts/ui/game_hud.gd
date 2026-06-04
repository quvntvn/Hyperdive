extends CanvasLayer
class_name GameHUD

@export var player_path: NodePath

var _player: PlayerController
var _distance_label: Label
var _coin_label: Label
var _campaign_mode: bool = false
# Pastilles power-up : un widget par type (icone coloree + barre de compte a rebours).
# Cle = type, valeur = { "root": PanelContainer, "bar": ProgressBar }.
var _pills: Dictionary = {}

# Couleurs par type (memes teintes que les power-up 3D).
const PILL_COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),
	"boost": Color(0.914, 0.310, 0.216, 1.0),
	"slowmo": Color(0.612, 0.796, 0.906, 1.0),
	"magnet": Color(0.949, 0.757, 0.306, 1.0),
}
const PILL_NAMES: Dictionary = {
	"shield": "BOUCLIER", "boost": "BOOST", "slowmo": "RALENTI", "magnet": "AIMANT",
}

func _ready() -> void:
	var node := get_node_or_null(player_path)
	if node is PlayerController:
		_player = node as PlayerController
		_player.game_over.connect(_on_game_over)
	_distance_label = $InfoBar/VBox/DistanceLabel
	_coin_label = $InfoBar/VBox/CoinCounter/CoinLabel
	_build_powerup_pills()
	_coin_label.text = UIAnimations.format_number(Settings.coins_total)
	Settings.coin_collected.connect(_on_coin_collected)
	%PauseButton.pressed.connect(_on_pause_pressed)
	# Bandeau d'infos en verre flouté (score + pièces sur la même rangée), comme les boutons.
	$InfoBar.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	GlassBlur.add_behind($InfoBar)
	UIAnimations.wire_buttons(self)   # feedback + haptique sur le bouton pause
	# Descend les éléments hauts du HUD sous la safe area (encoche/caméra frontale).
	UIAnimations.apply_top_safe_area($InfoBar, 12.0)
	UIAnimations.apply_top_safe_area(%PauseButton, 12.0)
	# Hauteur adaptative : recalée après le 1er layout (largeur fixe en scène, hauteur = contenu).
	_resize_info_bar.call_deferred()

# Largeur FIXE (offsets gauche/droite de la scène) ; hauteur ADAPTÉE au contenu visible du VBox
# (2 lignes en classique/jetpack, 1 ligne en campagne quand les pièces sont masquées). Le
# GlassBlur plein-rect derrière suit cette hauteur et recalcule son masque sur 'resized'.
func _resize_info_bar() -> void:
	var bar := $InfoBar as Panel
	var vbox := $InfoBar/VBox as Control
	var content_h: float = vbox.get_combined_minimum_size().y
	bar.offset_bottom = bar.offset_top + content_h + 16.0   # +16 = padding vertical (8 haut + 8 bas)

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled
	$InfoBar/VBox/CoinCounter.visible = not enabled
	# Le contenu du VBox change (1 ou 2 lignes) → recaler la hauteur du fond (différé : la
	# taille mini du conteneur se met à jour après le toggle de visibilité).
	_resize_info_bar.call_deferred()

# Coop : on garde l'affichage distance/altitude (mode classique/jetpack) mais on masque les
# pièces (aucune pièce en coop). On NE touche PAS à _campaign_mode (sinon la distance n'est
# plus mise à jour dans _process — elle attendrait update_campaign_time, jamais appelé en coop).
func set_coins_hidden(hidden: bool) -> void:
	$InfoBar/VBox/CoinCounter.visible = not hidden
	_resize_info_bar.call_deferred()

func update_campaign_time(seconds: float) -> void:
	_distance_label.text = str(ceili(seconds)) + "s"

func _process(_delta: float) -> void:
	if _player == null:
		return
	if not _campaign_mode:
		_distance_label.text = UIAnimations.format_number(int(abs(_player.global_position.y))) + " m"
	_update_powerup_indicator()

# Construit les 4 pastilles (cachees par defaut). Ordre d'empilement bas-gauche.
func _build_powerup_pills() -> void:
	var container := $PowerupIndicator as VBoxContainer
	for type: String in ["shield", "boost", "slowmo", "magnet"]:
		var timed: bool = type != "shield"   # le bouclier n'a pas de timer
		var pill := _make_pill(PILL_COLORS[type], PILL_NAMES[type], timed)
		container.add_child(pill["root"])
		_pills[type] = pill

func _make_pill(color: Color, text: String, timed: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	panel.visible = false
	var mc := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(side, 10)
	panel.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mc.add_child(vb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	vb.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150.0, 8.0)
	bar.visible = timed
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1.0, 1.0, 1.0, 0.15)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	vb.add_child(bar)
	return {"root": panel, "bar": bar}

func _update_powerup_indicator() -> void:
	_set_pill("shield", _player.has_shield, 1.0)
	_set_pill("boost", _player.boost_timer > 0.0, _player.boost_timer / PlayerController.BOOST_DURATION)
	_set_pill("slowmo", _player.slowmo_timer > 0.0, _player.slowmo_timer / PlayerController.SLOWMO_DURATION)
	_set_pill("magnet", _player.magnet_timer > 0.0, _player.magnet_timer / PlayerController.MAGNET_DURATION)

func _set_pill(type: String, active: bool, frac: float) -> void:
	var pill: Dictionary = _pills.get(type, {})
	if pill.is_empty():
		return
	var root := pill["root"] as PanelContainer
	root.visible = active
	if active:
		var bar := pill["bar"] as ProgressBar
		if bar.visible:
			bar.value = clampf(frac, 0.0, 1.0)

func _on_game_over() -> void:
	print("GAME OVER")

func _on_coin_collected(new_total: int) -> void:
	_coin_label.text = UIAnimations.format_number(new_total)

func _on_pause_pressed() -> void:
	Audio.play_ui_click()
	var pause := get_tree().get_first_node_in_group("pause_screen")
	if pause:
		pause.open()
