extends Control

signal card_picked(index: int)
signal button_picked(label: String)

const CARD_SCENE := preload("res://scenes/ui/card_view.tscn")

@onready var _title: Label = $Panel/Margin/Column/Title
@onready var _message: Label = $Panel/Margin/Column/Message
@onready var _card_row: HBoxContainer = $Panel/Margin/Column/CardRow
@onready var _button_row: HBoxContainer = $Panel/Margin/Column/ButtonRow


func _ready() -> void:
	UiConfig.place_centered($Panel as Control, Vector2(1000, 560))


func present(data: Dictionary) -> void:
	_title.text = str(data["title"])
	_message.text = str(data["message"])
	_clear(_card_row)
	_clear(_button_row)
	var cards: Array = data["cards"]
	var captions: Array = data.get("captions", [])
	var clickable: bool = bool(data["clickable"])
	for i in cards.size():
		var card_id := str(cards[i])
		var wrap := VBoxContainer.new()
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_theme_constant_override("separation", 4)
		if i < captions.size():
			var caption := Label.new()
			caption.text = str(captions[i])
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", 14)
			caption.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
			wrap.add_child(caption)
		var card_view: CardView = CARD_SCENE.instantiate()
		wrap.add_child(card_view)
		_card_row.add_child(wrap)
		card_view.setup(card_id, i, true, false, false, false, "")
		if clickable:
			card_view.card_clicked.connect(_on_card)
		else:
			card_view.allow_hover_only()
	_card_row.visible = not cards.is_empty()
	var buttons: Array = data["buttons"]
	for entry in buttons:
		var label := str(entry)
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(150, 44)
		button.add_theme_font_size_override("font_size", 16)
		_button_row.add_child(button)
		button.pressed.connect(_on_button.bind(label))
	_button_row.visible = not buttons.is_empty()
	visible = true


func dismiss() -> void:
	visible = false


func _on_card(index: int) -> void:
	card_picked.emit(index)


func _on_button(label: String) -> void:
	button_picked.emit(label)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
