extends Panel

const MINI_SCENE := preload("res://scenes/ui/mini_card.tscn")


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
	var count_w := 78.0
	var gear_w := UiConfig.MINI_SIZE.x * 3.0 + 4.0
	var flex := inner_w - gear_w - count_w - 12.0
	var backs_w := flex * 0.4
	var played_w := flex - backs_w
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
	x += count_w + 8.0

	var played := _fan_host()
	played.position = Vector2(x, row_top)
	add_child(played)
	_fill_played(played, player["played"], false)
	UiConfig.layout_fan(played, played_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)

	var gear := _fan_host()
	gear.position = Vector2(inset + inner_w - gear_w, row_top)
	add_child(gear)
	_fill_gear(gear, player["gear"])
	UiConfig.layout_fan(gear, gear_w, UiConfig.MINI_SIZE, row_h - UiConfig.MINI_SIZE.y)


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

	var gear_h := 20.0 + UiConfig.HOVER_LIFT + UiConfig.MINI_SIZE.y
	var gear_top := size.y - 6.0 - gear_h
	var played_h := gear_top - 8.0 - y
	var played := _fan_host()
	played.position = Vector2(inset, y)
	played.size = Vector2(width, maxf(played_h, UiConfig.MINI_SIZE.y))
	add_child(played)
	_fill_played(played, player["played"], false)
	_layout_wrapped(played, width, maxf(played_h, UiConfig.MINI_SIZE.y))

	var gear_title := _small_label("Gear (%d/%d)" % [player["gear"].size(), GameState.GEAR_SLOTS])
	gear_title.position = Vector2(inset, gear_top)
	gear_title.size = Vector2(width, 20)
	add_child(gear_title)
	var gear := _fan_host()
	gear.position = Vector2(inset, gear_top + 20.0)
	add_child(gear)
	_fill_gear(gear, player["gear"])
	UiConfig.layout_fan(gear, width, UiConfig.MINI_SIZE, UiConfig.HOVER_LIFT)


func _header(player: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(_name_label(str(player["name"]), player["color"], 18))
	row.add_child(UiConfig.circle_token(UiConfig.GOLD, int(player["gold"]), Color(0.12, 0.09, 0.02)))
	row.add_child(UiConfig.circle_token(UiConfig.PURPLE, int(player["purple"]), Color.WHITE))
	var location := _location_label(player)
	location.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(location)
	var gear := _small_label("Gear (%d/%d)" % [player["gear"].size(), GameState.GEAR_SLOTS])
	gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gear.size_flags_horizontal = SIZE_SHRINK_END
	row.add_child(gear)
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


func _fill_played(host: Control, played: Array, faded: bool) -> void:
	for card_id in played:
		var mini: Control = MINI_SCENE.instantiate()
		host.add_child(mini)
		mini.call("setup", str(card_id))
		if faded:
			mini.modulate = Color(1, 1, 1, 0.6)


func _fill_gear(host: Control, gear: Array) -> void:
	for slot in GameState.GEAR_SLOTS:
		if slot < gear.size():
			var mini: Control = MINI_SCENE.instantiate()
			host.add_child(mini)
			mini.call("setup", str(gear[slot]))
		else:
			host.add_child(UiConfig.empty_slot())


func _layout_wrapped(host: Control, width: float, height: float) -> void:
	var cards: Array[Control] = []
	for child in host.get_children():
		var control: Control = child as Control
		if control != null:
			cards.append(control)
	var count := cards.size()
	var card_size := UiConfig.MINI_SIZE
	host.size = Vector2(width, height)
	if count == 0:
		return
	var per_row := 1
	if width >= card_size.x + 6.0:
		per_row = maxi(1, int((width + 6.0) / (card_size.x + 6.0)))
	var rows := int(ceil(float(count) / float(per_row)))
	var row_step := card_size.y + 6.0
	if rows > 1 and card_size.y + float(rows - 1) * row_step > height - UiConfig.HOVER_LIFT:
		row_step = (height - UiConfig.HOVER_LIFT - card_size.y) / float(rows - 1)
	var col_step := card_size.x + 6.0
	if per_row > 1 and card_size.x + float(per_row - 1) * col_step > width:
		col_step = (width - card_size.x) / float(per_row - 1)
	for i in count:
		var card: Control = cards[i]
		var col := i % per_row
		var row := int(float(i) / float(per_row))
		var x := col_step * float(col)
		var y := UiConfig.HOVER_LIFT + row_step * float(row)
		card.position = Vector2(x, y)
		card.z_index = i
		card.set_meta("fan_x", x)
		card.set_meta("fan_base", y)
		card.set_meta("fan_rest", y)
		card.set_meta("fan_z", i)
		if bool(card.get_meta("fan_wired", false)):
			continue
		card.set_meta("fan_wired", true)
		card.mouse_entered.connect(UiConfig.raise_card.bind(card))
		card.mouse_exited.connect(UiConfig.lower_card.bind(card))
