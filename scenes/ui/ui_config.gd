class_name UiConfig
extends RefCounted

# Side seats face their edge of the table. Set false for upright side columns.
const ROTATE_SIDE_SEATS := true

const HOVER_LIFT := 10.0
const MINI_SIZE := Vector2(86, 120)
const OPPONENT_GEAR_SIZE := Vector2(104, 118)
const BACK_SIZE := Vector2(56, 80)
const DEPTH := 166.0

const LEFT_REGION := Rect2(4, 4, 166, 822)
const TOP_REGION := Rect2(178, 4, 1564, 166)
const RIGHT_REGION := Rect2(1750, 4, 166, 822)
const BOARD_REGION := Rect2(178, 178, 1564, 610)
const LOG_REGION := Rect2(178, 796, 1564, 30)
const BOTTOM_REGION := Rect2(0, 830, 1920, 250)

const GOLD := Color8(212, 172, 13)
const PURPLE := Color8(142, 68, 173)
const OPPONENT_BG := Color8(43, 43, 58)
const CURRENT_BG := Color8(58, 58, 82)


static func place_centered(panel: Control, panel_size: Vector2) -> void:
	var center := BOARD_REGION.get_center()
	var origin := center - panel_size * 0.5
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = origin.x
	panel.offset_top = origin.y
	panel.offset_right = origin.x + panel_size.x
	panel.offset_bottom = origin.y + panel_size.y


static func layout_fan(host: Control, width: float, card_size: Vector2, rest_y: float) -> void:
	var cards: Array[Control] = []
	for child in host.get_children():
		var control: Control = child as Control
		if control != null:
			cards.append(control)
	var count := cards.size()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size = Vector2(width, rest_y + card_size.y)
	host.size = Vector2(width, rest_y + card_size.y)
	if count == 0:
		return
	var step := card_size.x
	if count > 1:
		var needed := card_size.x + float(count - 1) * step
		if needed > width:
			step = (width - card_size.x) / float(count - 1)
	for i in count:
		var card: Control = cards[i]
		var base_y := rest_y
		if bool(card.get_meta("fan_raised", false)):
			base_y -= 8.0
		var x := step * float(i)
		card.position = Vector2(x, base_y)
		card.z_index = i
		card.set_meta("fan_x", x)
		card.set_meta("fan_base", base_y)
		card.set_meta("fan_rest", rest_y)
		card.set_meta("fan_z", i)
		if bool(card.get_meta("fan_wired", false)):
			continue
		card.set_meta("fan_wired", true)
		card.mouse_entered.connect(raise_card.bind(card))
		card.mouse_exited.connect(lower_card.bind(card))


static func raise_card(card: Control) -> void:
	var x := float(card.get_meta("fan_x", 0.0))
	var rest := float(card.get_meta("fan_rest", 0.0))
	card.position = Vector2(x, rest - HOVER_LIFT)
	card.z_index = 80


static func lower_card(card: Control) -> void:
	var x := float(card.get_meta("fan_x", 0.0))
	var base := float(card.get_meta("fan_base", 0.0))
	card.position = Vector2(x, base)
	card.z_index = int(card.get_meta("fan_z", 0))


static func circle_token(bg: Color, number: int, text_color: Color) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(26, 26)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(13)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = str(number)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	return panel


static func card_back() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = BACK_SIZE
	panel.size = BACK_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = Color(0.86, 0.86, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func empty_slot(slot_size: Vector2 = MINI_SIZE) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = slot_size
	panel.size = slot_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.border_color = Color(1, 1, 1, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func card_count_text(count: int) -> String:
	if count == 1:
		return "1 card"
	return "%d cards" % count
