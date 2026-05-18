extends CanvasLayer
class_name ShopScreen

var _coins_label: Label
var _skin_list: VBoxContainer
var _was_paused_before_open: bool = false

func _ready() -> void:
	add_to_group("shop_screen")
	_coins_label = $ShopPanel/Layout/CoinsLabel
	_skin_list = $ShopPanel/Layout/SkinList
	Settings.coin_collected.connect(func(_n: int) -> void: refresh())
	Settings.owned_skins_changed.connect(refresh)
	Settings.equipped_skin_changed.connect(func(_id: String) -> void: refresh())
	$ShopPanel/Layout/CloseButton.pressed.connect(close)
	refresh()

func refresh() -> void:
	_coins_label.text = "Pièces : " + str(Settings.coins_total)
	for child in _skin_list.get_children():
		_skin_list.remove_child(child)
		child.queue_free()
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
			btn.pressed.connect(Settings.equip_skin.bind(skin_id))
		elif Settings.coins_total >= price:
			btn.text = "ACHETER"
			btn.pressed.connect(Settings.buy_skin.bind(skin_id))
		else:
			btn.text = "ACHETER"
			btn.disabled = true
		row.add_child(btn)
		_skin_list.add_child(row)

func open() -> void:
	print("[ShopScreen.open] called. visible avant = ", visible, " layer = ", layer)
	_was_paused_before_open = get_tree().paused
	visible = true
	refresh()
	get_tree().paused = true
	print("[ShopScreen.open] visible après = ", visible)

func close() -> void:
	visible = false
	get_tree().paused = _was_paused_before_open
