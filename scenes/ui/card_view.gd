extends Panel

signal card_clicked(hand_index: int)

const CARD_SIZE := Vector2(140, 190)

var hand_index: int = -1

var _style: StyleBoxFlat
var _playable := false

@onready var _name_label: Label = $NameLabel
@onready var _action_strip: ColorRect = $ActionStrip
@onready var _action_label: Label = $ActionStrip/ActionLabel
@onready var _body_label: Label = $BodyLabel


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


func setup(card_id: String, index: int, playable: bool, faded: bool, selected: bool) -> void:
	hand_index = index
	var card: Dictionary = CardData.get_card(card_id)
	_name_label.text = card["name"]
	var action: CardData.ActionType = card["action"]
	_action_label.text = CardData.action_name(action).to_upper()
	_action_strip.color = _action_color(action)
	_body_label.text = card["text"]
	_playable = playable and not faded
	if faded:
		modulate = Color(1, 1, 1, 0.6)
		mouse_filter = MOUSE_FILTER_IGNORE
	elif playable:
		modulate = Color.WHITE
		mouse_filter = MOUSE_FILTER_STOP
	else:
		modulate = Color(0.55, 0.55, 0.55, 1)
		mouse_filter = MOUSE_FILTER_IGNORE
	_apply_selected(selected)


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
