extends CanvasLayer
class_name ShopScreen

var _coins_label: Label
var _item_list: VBoxContainer
var _skins_btn: Button
var _trails_btn: Button
var _themes_btn: Button
var _was_paused_before_open: bool = false
var _current_category: String = "skins"

func _ready() -> void:
	add_to_group("shop_screen")
	_coins_label = $Content/CoinsLabel
	_item_list = $Content/ScrollContainer/ItemList
	_skins_btn = $Content/CategoryButtons/SkinsCatBtn
	_trails_btn = $Content/CategoryButtons/TrailsCatBtn
	_themes_btn = $Content/CategoryButtons/ThemesCatBtn
	Settings.coin_collected.connect(func(_n: int) -> void: refresh())
	Settings.owned_skins_changed.connect(refresh)
	Settings.equipped_skin_changed.connect(func(_id: String) -> void: refresh())
	Settings.owned_trails_changed.connect(refresh)
	Settings.equipped_trail_changed.connect(func(_id: String) -> void: refresh())
	Settings.owned_themes_changed.connect(refresh)
	Settings.equipped_theme_changed.connect(func(_id: String) -> void: refresh())
	$Content/CloseButton.pressed.connect(_on_close_pressed)
	_skins_btn.pressed.connect(_on_skins_pressed)
	_trails_btn.pressed.connect(_on_trails_pressed)
	_themes_btn.pressed.connect(_on_themes_pressed)
	UIAnimations.wire_buttons(self)
	refresh()

func _on_skins_pressed() -> void:
	Audio.play_ui_click()
	_current_category = "skins"
	refresh()

func _on_trails_pressed() -> void:
	Audio.play_ui_click()
	_current_category = "trails"
	refresh()

func _on_themes_pressed() -> void:
	Audio.play_ui_click()
	_current_category = "themes"
	refresh()

func refresh() -> void:
	_coins_label.text = "Pièces : " + str(Settings.coins_total)
	_skins_btn.disabled = _current_category == "skins"
	_trails_btn.disabled = _current_category == "trails"
	_themes_btn.disabled = _current_category == "themes"
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	if _current_category == "skins":
		_refresh_skins()
	elif _current_category == "trails":
		_refresh_trails()
	else:
		_refresh_themes()
	UIAnimations.wire_buttons(_item_list)

# Enveloppe une ligne d'item dans une "carte verre" (translucide + arête + ombre) posée
# sur le fond décor flouté de l'écran. Pas de blur par carte (le backdrop plein écran suffit).
func _add_card(row: Control) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIAnimations.glass_card_style())
	card.add_child(row)
	_item_list.add_child(card)

func _refresh_skins() -> void:
	for skin in Catalog.SKINS:
		var skin_id: String = skin["id"]
		var price: int = skin["price"]
		if price < 0:
			continue  # exclusif défi : pas vendu au shop
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var preview := ColorRect.new()
		preview.custom_minimum_size = Vector2(64.0, 64.0)
		preview.color = skin["color"]
		row.add_child(preview)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = skin["name"]
		name_label.add_theme_font_size_override("font_size", 24)
		var price_label := Label.new()
		price_label.text = "Prix : " + str(price)
		info.add_child(name_label)
		info.add_child(price_label)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110.0, 48.0)
		if skin_id == Settings.equipped_skin:
			btn.text = "ÉQUIPÉ"
			btn.disabled = true
		elif skin_id in Settings.owned_skins:
			btn.text = "ÉQUIPER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.equip_skin(skin_id))
		elif Settings.coins_total >= price:
			btn.text = "ACHETER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.buy_skin(skin_id))
		else:
			btn.text = "ACHETER"
			btn.disabled = true
		row.add_child(btn)
		_add_card(row)

func _refresh_trails() -> void:
	for trail in Catalog.TRAILS:
		var trail_id: String = trail["id"]
		var price: int = trail["price"]
		if price < 0:
			continue  # exclusif défi : pas vendu au shop
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var preview := ColorRect.new()
		preview.custom_minimum_size = Vector2(64.0, 64.0)
		if trail_id == "none":
			preview.color = Color(0.3, 0.3, 0.3, 0.4)
			var dash := Label.new()
			dash.text = "–"
			dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dash.add_theme_font_size_override("font_size", 32)
			preview.add_child(dash)
		else:
			preview.color = trail["color"]
		row.add_child(preview)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = trail["name"]
		name_label.add_theme_font_size_override("font_size", 24)
		var price_label := Label.new()
		price_label.text = "Prix : " + str(price) if price > 0 else "Gratuit"
		info.add_child(name_label)
		info.add_child(price_label)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110.0, 48.0)
		if trail_id == Settings.equipped_trail:
			btn.text = "ÉQUIPÉ"
			btn.disabled = true
		elif trail_id in Settings.owned_trails:
			btn.text = "ÉQUIPER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.equip_trail(trail_id))
		elif Settings.coins_total >= price:
			btn.text = "ACHETER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.buy_trail(trail_id))
		else:
			btn.text = "ACHETER"
			btn.disabled = true
		row.add_child(btn)
		_add_card(row)

func _refresh_themes() -> void:
	for theme in Catalog.THEMES:
		var theme_id: String = theme["id"]
		var price: int = theme["price"]
		if price < 0:
			continue  # exclusif défi : pas vendu au shop
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var preview_box := HBoxContainer.new()
		preview_box.add_theme_constant_override("separation", 4)
		var swatch_wall := ColorRect.new()
		swatch_wall.custom_minimum_size = Vector2(30.0, 64.0)
		swatch_wall.color = theme["wall_color"]
		var swatch_line := ColorRect.new()
		swatch_line.custom_minimum_size = Vector2(30.0, 64.0)
		swatch_line.color = theme["line_color"]
		preview_box.add_child(swatch_wall)
		preview_box.add_child(swatch_line)
		row.add_child(preview_box)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = theme["name"]
		name_label.add_theme_font_size_override("font_size", 24)
		var price_label := Label.new()
		price_label.text = "Prix : " + str(price) if price > 0 else "Gratuit"
		info.add_child(name_label)
		info.add_child(price_label)
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110.0, 48.0)
		if theme_id == Settings.equipped_theme:
			btn.text = "ÉQUIPÉ"
			btn.disabled = true
		elif theme_id in Settings.owned_themes:
			btn.text = "ÉQUIPER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.equip_theme(theme_id))
		elif Settings.coins_total >= price:
			btn.text = "ACHETER"
			btn.pressed.connect(func() -> void:
				Audio.play_ui_click()
				Settings.buy_theme(theme_id))
		else:
			btn.text = "ACHETER"
			btn.disabled = true
		row.add_child(btn)
		_add_card(row)

func open() -> void:
	# On NE force PAS la pause : ouvert depuis le menu, on laisse la ville défiler derrière
	# (fond décor flouté). Ouvert depuis le game over, le jeu est déjà en pause (figé) → on
	# conserve l'état précédent et on le restaure à la fermeture.
	_was_paused_before_open = get_tree().paused
	Audio.duck_music()
	visible = true
	refresh()
	UIAnimations.pop_in($Content, $Tint)

func _on_close_pressed() -> void:
	Audio.play_ui_click()
	close()

func close() -> void:
	visible = false
	var go_screen := get_tree().get_first_node_in_group("game_over_screen")
	if not (go_screen and go_screen.visible):
		Audio.unduck_music()
	get_tree().paused = _was_paused_before_open
