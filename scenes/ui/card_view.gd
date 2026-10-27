class_name CardView
extends Panel

signal card_clicked(hand_index: int)

const CARD_SIZE := Vector2(130, 180)

var hand_index: int = -1
var _card_id := ""

var _style: StyleBoxFlat
var _playable := false
var _tag_label: Label

@onready var _name_label: Label = $NameLabel
@onready var _action_strip: ColorRect = $ActionStrip
@onready var _action_label: Label = $ActionStrip/ActionLabel
@onready var _body_label: Label = $BodyLabel
@onready var _soon_label: Label = $SoonLabel
@onready var _new_badge: ColorRect = $NewBadge

var _recipe_label: Label
var _recipe_rule: ColorRect


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color.WHITE
	_style.border_color = Color(0.12, 0.12, 0.12)
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", _style)
	var bold := SystemFont.new()
	bold.font_weight = 700
	_name_label.add_theme_font_override("font", bold)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_tag_label = Label.new()
	_tag_label.mouse_filter = MOUSE_FILTER_IGNORE
	_tag_label.position = Vector2(6, 64)
	_tag_label.size = Vector2(118, 16)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_label.add_theme_font_size_override("font_size", 11)
	_tag_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	add_child(_tag_label)
	_recipe_label = Label.new()
	_recipe_label.visible = false
	_recipe_label.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_label.clip_text = false
	_recipe_label.add_theme_font_size_override("font_size", 10)
	_recipe_label.add_theme_color_override("font_color", Color(0.12, 0.32, 0.38))
	_recipe_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_recipe_label)
	_recipe_rule = ColorRect.new()
	_recipe_rule.visible = false
	_recipe_rule.mouse_filter = MOUSE_FILTER_IGNORE
	_recipe_rule.color = Color(0.22, 0.28, 0.32, 0.7)
	add_child(_recipe_rule)


func setup(card_id: String, index: int, playable: bool, faded: bool, selected: bool, is_new: bool = false, reason: String = "") -> void:
	hand_index = index
	_card_id = card_id
	var card: Dictionary = CardData.get_card(card_id)
	_name_label.text = card["name"]
	_name_label.offset_right = 82.0 if is_new else 126.0
	var soon := bool(card.get("soon", false))
	_soon_label.visible = soon
	_soon_label.text = CardData.SOON_TEXT
	_body_label.offset_bottom = 128.0 if soon else 174.0
	_new_badge.visible = is_new
	_apply_kind(card)
	_show_recipe(card)
	_playable = playable and not faded
	tooltip_text = ""
	if faded:
		modulate = Color(1, 1, 1, 0.6)
		mouse_filter = MOUSE_FILTER_STOP
	elif playable:
		modulate = Color.WHITE
		mouse_filter = MOUSE_FILTER_STOP
	else:
		modulate = Color(0.55, 0.55, 0.55, 1)
		mouse_filter = MOUSE_FILTER_STOP
		tooltip_text = reason
	_apply_selected(selected)


func allow_hover_only() -> void:
	_playable = false
	mouse_filter = MOUSE_FILTER_STOP
	tooltip_text = ""
	modulate = Color.WHITE


func _on_mouse_entered() -> void:
	_preview_call("begin_hover", _card_id)


func _on_mouse_exited() -> void:
	_preview_call("end_hover", "")


func _preview_call(method: String, card_id: String) -> void:
	if card_id == "" and method == "begin_hover":
		return
	var tree := get_tree()
	if tree == null:
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method(method):
		if method == "begin_hover":
			preview.call(method, card_id)
		else:
			preview.call(method)


static func strip_for(card: Dictionary) -> Dictionary:
	var kind := int(card["kind"])
	if bool(card.get("invention", false)):
		return {
			"color": Color8(31, 122, 140),
			"title": "INVENTION",
			"title_color": Color.WHITE,
		}
	if kind == CardData.Kind.GEAR:
		var active := str(card.get("gear_mode", "")) == "active"
		return {
			"color": Color8(93, 109, 126),
			"title": "GEAR · ACTIVE" if active else "GEAR",
			"title_color": Color.WHITE,
		}
	if kind == CardData.Kind.ABILITY:
		return {"color": Color8(230, 126, 34), "title": "ABILITY", "title_color": Color.WHITE}
	if kind == CardData.Kind.RESOURCE:
		return {
			"color": Color8(212, 172, 13),
			"title": "MATERIAL",
			"title_color": Color(0.12, 0.09, 0.02),
		}
	if kind == CardData.Kind.ALIEN:
		return {"color": Color8(142, 68, 173), "title": "ALIEN", "title_color": Color.WHITE}
	return {"color": Color.GRAY, "title": "", "title_color": Color.WHITE}


static func action_tag(card: Dictionary) -> String:
	if int(card["kind"]) == CardData.Kind.ALIEN:
		return CardData.alien_mode_label(card)
	if int(card["kind"]) == CardData.Kind.RESOURCE:
		return ""
	if not card.has("action"):
		return ""
	if int(card["action"]) == CardData.ActionType.NONE:
		return ""
	return CardData.action_name(card["action"])


func _apply_kind(card: Dictionary) -> void:
	var strip: Dictionary = strip_for(card)
	_action_label.text = str(strip["title"])
	_action_strip.color = strip["color"]
	_action_label.add_theme_color_override("font_color", strip["title_color"])
	_action_label.add_theme_font_size_override("font_size", 11)
	var tag := action_tag(card)
	if _tag_label != null:
		_tag_label.visible = tag != ""
		_tag_label.text = tag
	_body_label.offset_top = 82.0 if tag != "" else 66.0


static func wrapped_height(host: Node, text: String, width: float, font_size: int, font: Font = null) -> float:
	var probe := Label.new()
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	probe.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	host.add_child(probe)
	if font != null:
		probe.add_theme_font_override("font", font)
	probe.add_theme_font_size_override("font_size", font_size)
	probe.text = text
	probe.size = Vector2(width, 4)
	var height := probe.get_minimum_size().y
	host.remove_child(probe)
	probe.free()
	return height


static func settle_label(label: Label, at: Vector2, width: float, text: String, font_size: int) -> float:
	label.visible = true
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2.ZERO
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.position = at
	label.size = Vector2(width, 4)
	var height := label.get_minimum_size().y
	label.size = Vector2(width, height)
	return height


func _show_recipe(card: Dictionary) -> void:
	var recipe := CardData.recipe_block(card)
	if recipe == "":
		_recipe_label.visible = false
		_recipe_rule.visible = false
		_recipe_label.text = ""
		_recipe_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_recipe_label.custom_minimum_size = Vector2.ZERO
		_recipe_label.size = Vector2.ZERO
		_name_label.remove_theme_font_size_override("font_size")
		_name_label.offset_top = 2.0
		_name_label.offset_bottom = 40.0
		_action_strip.offset_top = 42.0
		_action_strip.offset_bottom = 62.0
		_action_label.add_theme_font_size_override("font_size", 11)
		_body_label.remove_theme_font_size_override("font_size")
		_body_label.clip_text = true
		_body_label.offset_left = 6.0
		_body_label.offset_right = 124.0
		_body_label.text = str(card["text"])
		return
	var text_w := 122.0
	var name_font: Font = _name_label.get_theme_font("font")
	_name_label.add_theme_font_size_override("font_size", 12)
	var name_h := wrapped_height(self, str(card["name"]), text_w, 12, name_font) + 2.0
	_name_label.offset_top = 1.0
	_name_label.offset_bottom = 1.0 + name_h
	var strip_top := _name_label.offset_bottom + 1.0
	_action_strip.offset_top = strip_top
	_action_strip.offset_bottom = strip_top + 16.0
	_action_label.add_theme_font_size_override("font_size", 10)
	var content_top := _action_strip.offset_bottom + 2.0
	var room := 176.0 - content_top
	var effect := str(card["text"])
	var gap := 8.0
	var recipe_size := 8
	var effect_size := 7
	var sizes: Array[int] = [12, 11, 10, 9, 8, 7]
	for try_effect in sizes:
		var effect_try: int = int(try_effect)
		var recipe_try := 10
		if effect_try < 9:
			recipe_try = 8
		var rh := wrapped_height(self, recipe, text_w, recipe_try)
		var eh := wrapped_height(self, effect, text_w, effect_try)
		if rh + gap + eh + 4.0 <= room:
			recipe_size = recipe_try
			effect_size = effect_try
			break
	var recipe_h := settle_label(_recipe_label, Vector2(4, content_top), text_w, recipe, recipe_size)
	var rule_y := content_top + recipe_h + 3.0
	_recipe_rule.visible = true
	_recipe_rule.position = Vector2(14, rule_y)
	_recipe_rule.size = Vector2(102, 1)
	settle_label(_body_label, Vector2(4, rule_y + 5.0), text_w, effect, effect_size)


func _apply_selected(selected: bool) -> void:
	if _style == null:
		return
	if selected:
		_style.border_color = Color8(241, 196, 15)
		_style.set_border_width_all(6)
	else:
		_style.border_color = Color(0.12, 0.12, 0.12)
		_style.set_border_width_all(3)


func _gui_input(event: InputEvent) -> void:
	if not _playable:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(hand_index)
			accept_event()


