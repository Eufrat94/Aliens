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


func setup(card_id: String, index: int, playable: bool, faded: bool, selected: bool, is_new: bool = false, reason: String = "") -> void:
	hand_index = index
	_card_id = card_id
	var card: Dictionary = CardData.get_card(card_id)
	_name_label.text = card["name"]
	_name_label.offset_right = 82.0 if is_new else 126.0
	_body_label.text = card["text"]
	var soon := bool(card.get("soon", false))
	_soon_label.visible = soon
	_soon_label.text = CardData.SOON_TEXT
	_body_label.offset_bottom = 128.0 if soon else 174.0
	_new_badge.visible = is_new
	_apply_kind(card)
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
			"title": "RESOURCE",
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


