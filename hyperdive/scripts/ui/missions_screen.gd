extends CanvasLayer
class_name MissionsScreen

var _coins_label: Label
var _mission_list: VBoxContainer

func _ready() -> void:
	add_to_group("missions_screen")
	_coins_label = $Panel/Layout/CoinsLabel
	_mission_list = $Panel/Layout/ScrollContainer/MissionList
	$Panel/Layout/MenuButton.pressed.connect(_on_menu_pressed)
	Settings.mission_claimed.connect(func() -> void: refresh())
	Settings.coin_collected.connect(func(_n: int) -> void: refresh())
	refresh()

func refresh() -> void:
	_coins_label.text = "Pièces : " + str(Settings.coins_total)
	for child in _mission_list.get_children():
		_mission_list.remove_child(child)
		child.queue_free()
	for mission in Catalog.MISSIONS:
		_build_row(mission)

func _build_row(mission: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = mission["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
	var desc_label := Label.new()
	desc_label.text = mission["desc"]
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	info.add_child(name_label)
	info.add_child(desc_label)
	row.add_child(info)

	var mission_id: String = mission["id"]
	var progress: int = Settings.get_mission_progress(mission)
	var target: int = mission["target"]
	var reward: int = mission["reward"]

	if Settings.is_mission_claimed(mission_id):
		var claimed_label := Label.new()
		claimed_label.text = "✓ Réclamé"
		claimed_label.add_theme_font_size_override("font_size", 18)
		claimed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		row.add_child(claimed_label)
	elif Settings.is_mission_complete(mission):
		var btn := Button.new()
		btn.text = "RÉCLAMER " + str(reward)
		btn.custom_minimum_size = Vector2(148.0, 48.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.235, 0.682, 0.639)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.32, 0.78, 0.73)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_color_override("font_color", Color(0.957, 0.914, 0.804))
		btn.pressed.connect(func() -> void:
			Audio.play_ui_click()
			Settings.claim_mission(mission))
		row.add_child(btn)
	else:
		var prog_label := Label.new()
		prog_label.text = _format_progress(mission, progress, target)
		prog_label.add_theme_font_size_override("font_size", 18)
		prog_label.add_theme_color_override("font_color", Color(0.949, 0.757, 0.306))
		row.add_child(prog_label)

	_mission_list.add_child(row)

func _format_progress(mission: Dictionary, progress: int, target: int) -> String:
	match mission["type"]:
		"campaign_level":
			return "Niveau %d/%d" % [progress, target]
		"distance":
			return "%d/%d m" % [progress, target]
		"owned_skins":
			return "%d/%d skins" % [progress, target]
		"owned_themes":
			return "%d/%d thèmes" % [progress, target]
		"trail_equipped":
			return "Non équipé" if progress == 0 else "Équipé"
	return "%d/%d" % [progress, target]

func open() -> void:
	visible = true
	refresh()

func _on_menu_pressed() -> void:
	Audio.play_ui_click()
	visible = false
