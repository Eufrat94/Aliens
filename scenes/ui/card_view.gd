class_name CardView
extends Panel

signal card_clicked(hand_index: int)

const CARD_SIZE := Vector2(120, 170)

var hand_index: int = -1

var _style: StyleBoxFlat
var _playable := false

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


func setup(card_id: String, index: int, playable: bool, faded: bool, selected: bool, is_new: bool = false, reason: String = "") -> void:
	hand_index = index
	var card: Dictionary = CardData.get_card(card_id)
	_name_label.text = card["name"]
	_name_label.offset_right = 74.0 if is_new else 116.0
	_body_label.text = card["text"]
	var soon: bool = bool(card.get("soon", false))
	_soon_label.visible = soon
	_soon_label.text = CardData.SOON_TEXT
	_body_label.offset_bottom = 120.0 if soon else 164.0
	_new_badge.visible = is_new
	_apply_kind(card)
	_playable = playable and not faded
	tooltip_text = ""
	if faded:
		modulate = Color(1, 1, 1, 0.6)
		mouse_filter = MOUSE_FILTER_IGNORE
	elif playable:
		modulate = Color.WHITE
		mouse_filter = MOUSE_FILTER_STOP
	else:
		modulate = Color(0.55, 0.55, 0.55, 1)
		mouse_filter = MOUSE_FILTER_STOP
		tooltip_text = reason
	_apply_selected(selected)


func _apply_kind(card: Dictionary) -> void:
	var kind := int(card["kind"])
	if kind == CardData.Kind.GEAR:
		_action_label.text = "GEAR"
		_action_strip.color = Color8(93, 109, 126)
		_action_label.add_theme_color_override("font_color", Color.WHITE)
		return
	if kind == CardData.Kind.RESOURCE:
		_action_label.text = "RESOURCE"
		_action_strip.color = Color8(212, 172, 13)
		_action_label.add_theme_color_override("font_color", Color(0.12, 0.09, 0.02))
		return
	var action: CardData.ActionType = card["action"]
	_action_label.text = CardData.action_name(action).to_upper()
	_action_strip.color = _action_color(action)
	_action_label.add_theme_color_override("font_color", Color.WHITE)


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


func _action_color(action: CardData.ActionType) -> Color:
	match action:
		CardData.ActionType.MOVE:
			return Color8(139, 90, 43)
		CardData.ActionType.SEARCH:
			return Color8(22, 160, 133)
		CardData.ActionType.INTERACT:
			return Color8(142, 68, 173)
		CardData.ActionType.FIGHT:
			return Color8(192, 57, 43)
	return Color.GRAY
