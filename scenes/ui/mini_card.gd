extends Panel

const CARD_SIZE := Vector2(72, 100)

var _card_id := ""
var _style: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Color.WHITE
	_style.border_color = Color(0.12, 0.12, 0.12)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_selected(on: bool) -> void:
	if _style == null:
		return
	if on:
		_style.border_color = Color8(241, 196, 15)
		_style.set_border_width_all(4)
	else:
		_style.border_color = Color(0.12, 0.12, 0.12)
		_style.set_border_width_all(2)


func setup(card_id: String) -> void:
	_card_id = card_id
	var card: Dictionary = CardData.get_card(card_id)
	var strip: Dictionary = CardView.strip_for(card)
	$Strip.color = strip["color"]
	$NameLabel.text = str(card["name"])


func _on_mouse_entered() -> void:
	var tree := get_tree()
	if tree == null or _card_id == "":
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("begin_hover"):
		preview.call("begin_hover", _card_id)


func _on_mouse_exited() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var preview := tree.get_first_node_in_group("card_preview")
	if preview != null and preview.has_method("end_hover"):
		preview.call("end_hover")
