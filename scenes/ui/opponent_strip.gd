extends Panel

const MINI_SCENE := preload("res://scenes/ui/mini_card.tscn")
const GEAR_SIZE := UiConfig.OPPONENT_GEAR_SIZE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func show_player(player: Dictionary, column: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_apply_chrome(player["color"])
	if column:
		_build_column(player)
	else:
		_build_row(player)


func _apply_chrome(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiConfig.OPPONENT_BG
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)


func _build_row(player: Dictionary) -> void:
	var inset := 6.0
	var header := _header(player)
	header.position = Vector2(inset, 4)
	header.size = Vector2(size.x - inset * 2.0, 26)
	add_child(header)

	var row_top := 34.0
	var row_h := size.y - row_top - 4.0
	var inner_w := size.x - inset * 2.0
	var count_w := 70.0
	var gear_w := GEAR_SIZE.x * float(GameState.GEAR_SLOTS) + 8.0
	var alien_w := 150.0
	var backs_w := inner_w - gear_w - alien_w - count_w - 24.0
	var x := inset

	var backs := _fan_host()
	backs.position = Vector2(x, row_top)
	add_child(backs)
	_fill_backs(backs, player["hand"])
	UiConfig.layout_fan(backs, backs_w, UiConfig.BACK_SIZE, row_h - UiConfig.BACK_SIZE.y)
	x += backs_w

	var count := _count_label(player["hand"].size())
	count.position = Vector2(x, row_top)
	count.size = Vector2(count_w, row_h)
	add_child(count)

	var gear_x := x + count_w + 8.0
	var gear := _fan_host()
	gear.position = Vector2(gear_x, row_top)
	add_child(gear)
	_fill_gear(gear, player["gear"])
	UiConfig.layout_fan(gear, gear_w, GEAR_SIZE, row_h - GEAR_SIZE.y)

	var aliens := _fan_host()
	aliens.position = Vector2(gear_x + gear_w + 8.0, row_top)
	add_child(aliens)
	_fill_aliens(aliens, player["aliens"])
	UiConfig.layout_fan(aliens, alien_w, GEAR_SIZE, row_h - GEAR_SIZE.y)


func _build_column(player: Dictionary) -> void:
	var inset := 6.0
	var width := size.x - inset * 2.0
	var y := 6.0
	var name_label := _name_label(str(player["name"]), player["color"], 16)
	name_label.position = Vector2(inset, y)
	name_label.size = Vector2(width, 22)
	add_child(name_label)
	y += 24.0

	var tokens := HBoxContainer.new()
	tokens.mouse_filter = MOUSE_FILTER_IGNORE
	tokens.add_theme_constant_override("separation", 4)
	tokens.position = Vector2(inset, y)
	tokens.size = Vector2(width, 28)
	tokens.add_child(UiConfig.circle_token(UiConfig.GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02)))
	tokens.add_child(UiConfig.circle_token(UiConfig.PURPLE, int(player["purple"]), Color.WHITE))
	add_child(tokens)
	y += 30.0

	var location := _location_label(player)
	location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location.position = Vector2(inset, y)
	location.size = Vector2(width, 36)
	add_child(location)
	y += 38.0

	var count := _count_label(player["hand"].size())
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count.position = Vector2(inset, y)
	count.size = Vector2(width, 20)
	add_child(count)
	y += 22.0

	var backs_h := UiConfig.HOVER_LIFT + UiConfig.BACK_SIZE.y
	var backs := _fan_host()
	backs.position = Vector2(inset, y)
	add_child(backs)
	_fill_backs(backs, player["hand"])
	UiConfig.layout_fan(backs, width, UiConfig.BACK_SIZE, UiConfig.HOVER_LIFT)
	y += backs_h + 8.0

	var gear_title := _small_label("Gear (%d/%d)" % [player["gear"].size(), GameState.GEAR_SLOTS])
	gear_title.position = Vector2(inset, y)
	gear_title.size = Vector2(width, 20)
	add_child(gear_title)
	y += 20.0
	var gear := _fan_host()
	gear.position = Vector2(inset, y)
	add_child(gear)
	_fill_gear(gear, player["gear"])
	UiConfig.layout_fan(gear, width, GEAR_SIZE, UiConfig.HOVER_LIFT)
	y += UiConfig.HOVER_LIFT + GEAR_SIZE.y + 8.0

	var alien_title := _small_label("Aliens (%d)" % player["aliens"].size())
	alien_title.position = Vector2(inset, y)
	alien_title.size = Vector2(width, 20)
	add_child(alien_title)
	y += 20.0
	var aliens := _fan_host()
	aliens.position = Vector2(inset, y)
	add_child(aliens)
	_fill_aliens(aliens, player["aliens"])
	UiConfig.layout_fan(aliens, width, GEAR_SIZE, UiConfig.HOVER_LIFT)


func _header(player: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(_name_label(str(player["name"]), player["color"], 18))
	row.add_child(UiConfig.circle_token(UiConfig.GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02)))
	row.add_child(UiConfig.circle_token(UiConfig.PURPLE, int(player["purple"]), Color.WHITE))
	if _has_skrim(player):
		var badge := _small_label("SKRIM")
		badge.add_theme_color_override("font_color", Color8(210, 160, 255))
		row.add_child(badge)
	var location := _location_label(player)
	location.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(location)
	var gear := _small_label("Gear (%d/%d)" % [player["gear"].size(), GameState.GEAR_SLOTS])
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gear.size_flags_horizontal = SIZE_SHRINK_END
	row.add_child(gear)
	var aliens := _small_label("Aliens (%d)" % player["aliens"].size())
	aliens.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(aliens)
	return row


func _name_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	var bold := SystemFont.new()
	bold.font_weight = 700
	label.add_theme_font_override("font", bold)
	label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	return label


func _location_label(player: Dictionary) -> Label:
	var tile_name: String = BoardData.get_tile(player["tile"])["name"]
	var label := _small_label("On: %s" % tile_name)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	label.add_theme_font_size_override("font_size", 14)
	return label


func _count_label(count: int) -> Label:
	var label := _small_label(UiConfig.card_count_text(count))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _fan_host() -> Control:
	var host := Control.new()
	host.mouse_filter = MOUSE_FILTER_IGNORE
	return host


func _fill_backs(host: Control, hand: Array) -> void:
	for _card in hand:
		host.add_child(UiConfig.card_back())


func _has_skrim(player: Dictionary) -> bool:
	var hand: Array = player["hand"]
	for card_id in hand:
		if str(card_id) == "skrim":
			return true
	return false


func _fill_aliens(host: Control, aliens: Array) -> void:
	for alien_id in aliens:
		var mini: Control = MINI_SCENE.instantiate()
		host.add_child(mini)
		mini.call("setup", str(alien_id))
		mini.call("apply_size", GEAR_SIZE)


func _fill_gear(host: Control, gear: Array) -> void:
	for slot in GameState.GEAR_SLOTS:
		if slot < gear.size():
			var mini: Control = MINI_SCENE.instantiate()
			host.add_child(mini)
			mini.call("setup", str(gear[slot]))
			mini.call("apply_size", GEAR_SIZE)
		else:
			host.add_child(UiConfig.empty_slot(GEAR_SIZE))
