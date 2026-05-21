extends CanvasLayer
class_name ShopScreen

var _coins_label: Label
var _item_list: VBoxContainer
var _skins_btn: Button
var _trails_btn: Button
var _was_paused_before_open: bool = false
var _current_category: String = "skins"

func _ready() -> void:
	add_to_group("shop_screen")
	_coins_label = $ShopPanel/Layout/CoinsLabel
	_item_list = $ShopPanel/Layout/ItemList
	_skins_btn = $ShopPanel/Layout/CategoryButtons/SkinsCatBtn
	_trails_btn = $ShopPanel/Layout/CategoryButtons/TrailsCatBtn
	Settings.coin_collected.connect(func(_n: int) -> void: refresh())
	Settings.owned_skins_changed.connect(refresh)
	Settings.equipped_skin_changed.connect(func(_id: String) -> void: refresh())
	Settings.owned_trails_changed.connect(refresh)
	Settings.equipped_trail_changed.connect(func(_id: String) -> void: refresh())
	$ShopPanel/Layout/CloseButton.pressed.connect(_on_close_pressed)
	_skins_btn.pressed.connect(_on_skins_pressed)
	_trails_btn.pressed.connect(_on_trails_pressed)
	refresh()

func _on_skins_pressed() -> void:
	Audio.play_ui_click()
	_current_category = "skins"
	refresh()

func _on_trails_pressed() -> void:
	Audio.play_ui_click()
	_current_category = "trails"
	refresh()

func refresh() -> void:
	_coins_label.text = "Pièces : " + str(Settings.coins_total)
	_skins_btn.disabled = _current_category == "skins"
	_trails_btn.disabled = _current_category == "trails"
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()
	if _current_category == "skins":
		_refresh_skins()
	else:
		_refresh_trails()

func _refresh_skins() -> void:
	for skin in Catalog.SKINS:
		var skin_id: String = skin["id"]
		var price: int = skin["price"]
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
		_item_list.add_child(row)

func _refresh_trails() -> void:
	for trail in Catalog.TRAILS:
		var trail_id: String = trail["id"]
		var price: int = trail["price"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var preview := ColorRect.new()
		preview.custom_minimum_size = Vector2(64.0, 64.0)
		preview.color = trail["color"]
		row.add_child(preview)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = trail["name"]
		name_label.add_theme_font_size_override("font_size", 24)
		var price_label := Label.new()
		price_label.text = "Prix : " + str(price)
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
		_item_list.add_child(row)

func open() -> void:
	_was_paused_before_open = get_tree().paused
	Audio.duck_music()
	visible = true
	refresh()
	get_tree().paused = true

func _on_close_pressed() -> void:
	Audio.play_ui_click()
	close()

func close() -> void:
	visible = false
	var go_screen := get_tree().get_first_node_in_group("game_over_screen")
	if not (go_screen and go_screen.visible):
		Audio.unduck_music()
	get_tree().paused = _was_paused_before_open
