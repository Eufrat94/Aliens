extends Control

signal buy_pressed(slot: int)
signal sell_pressed(hand_index: int)
signal closed

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")

@onready var _gold: Label = $Panel/Margin/Column/Gold
@onready var _buy_row: HBoxContainer = $Panel/Margin/Column/BuyRow
@onready var _sell_scroll: ScrollContainer = $Panel/Margin/Column/SellHost/SellScroll
@onready var _sell_row: HBoxContainer = $Panel/Margin/Column/SellHost/SellScroll/SellRow
@onready var _empty_sell: Label = $Panel/Margin/Column/SellHost/EmptySell
@onready var _done: Button = $Panel/Margin/Column/Done


func _ready() -> void:
	_done.pressed.connect(_on_done)
	_sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_sell_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func present(game: GameState) -> void:
	visible = true
	refresh(game)


func dismiss() -> void:
	visible = false


func refresh(game: GameState) -> void:
	if not visible or game.players.is_empty():
		return
	var player: Dictionary = game.current_player()
	_gold.text = "Gold: %d" % int(player["gold"])
	_done.text = "Done (1 action)" if game.market_has_traded() else "Leave"
	_fill_buy(player)
	_fill_sell(player)


func _fill_buy(player: Dictionary) -> void:
	_clear(_buy_row)
	var offer: Array = player["market_offer"]
	var gold := int(player["gold"])
	for slot in offer.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		_buy_row.add_child(column)
		var card_id := str(offer[slot])
		if card_id == "":
			column.add_child(_sold_slot())
			continue
		var card_view: CardView = CARD_SCENE.instantiate()
		column.add_child(card_view)
		card_view.setup(card_id, slot, true, false, false, false, "")
		card_view.mouse_filter = MOUSE_FILTER_IGNORE
		var button := Button.new()
		button.text = "Buy — 2 gold"
		button.custom_minimum_size = Vector2(120, 40)
		button.disabled = gold < GameState.MARKET_BUY_PRICE
		button.pressed.connect(_on_buy.bind(slot))
		column.add_child(button)


func _fill_sell(player: Dictionary) -> void:
	_clear(_sell_row)
	var hand: Array = player["hand"]
	var found := false
	for i in hand.size():
		var card_id := str(hand[i])
		var card: Dictionary = CardData.get_card(card_id)
		if int(card["kind"]) != CardData.Kind.RESOURCE:
			continue
		found = true
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		_sell_row.add_child(column)
		var card_view: CardView = CARD_SCENE.instantiate()
		column.add_child(card_view)
		card_view.setup(card_id, i, true, false, false, false, "")
		card_view.mouse_filter = MOUSE_FILTER_IGNORE
		var button := Button.new()
		button.text = "Sell — 3 gold"
		button.custom_minimum_size = Vector2(120, 40)
		button.pressed.connect(_on_sell.bind(i))
		column.add_child(button)
	_sell_scroll.visible = found
	_empty_sell.visible = not found


func _sold_slot() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "Sold"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	return panel


func _on_buy(slot: int) -> void:
	buy_pressed.emit(slot)


func _on_sell(hand_index: int) -> void:
	sell_pressed.emit(hand_index)


func _on_done() -> void:
	closed.emit()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
