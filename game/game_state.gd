class_name GameState
extends RefCounted

signal state_changed

const ACTIONS_PER_TURN := 3
const START_TILE := "village_market"
const PLAYER_COLORS: Array[Color] = [
	Color8(231, 76, 60),
	Color8(52, 152, 219),
	Color8(241, 196, 15),
	Color8(46, 204, 113),
	Color8(230, 126, 34),
]

var players: Array = []
var current_index: int = 0
var actions_left: int = ACTIONS_PER_TURN


func start_game(player_count: int) -> void:
	if player_count < 2 or player_count > 5:
		print("Refused: player count must be between 2 and 5")
		return
	players = []
	for i in player_count:
		var hand: Array[String] = CardData.starting_hand()
		var played: Array[String] = []
		players.append({
			"index": i,
			"name": "Player %d" % (i + 1),
			"color": PLAYER_COLORS[i],
			"tile": START_TILE,
			"hand": hand,
			"played": played,
		})
	current_index = 0
	actions_left = ACTIONS_PER_TURN
	state_changed.emit()


func current_player() -> Dictionary:
	return players[current_index]


func can_play_card(hand_index: int) -> bool:
	if actions_left <= 0:
		return false
	var hand: Array = current_player()["hand"]
	return hand_index >= 0 and hand_index < hand.size()


func get_move_destinations(hand_index: int) -> Array[String]:
	var destinations: Array[String] = []
	var hand: Array = current_player()["hand"]
	if hand_index < 0 or hand_index >= hand.size():
		return destinations
	var card: Dictionary = CardData.get_card(hand[hand_index])
	if int(card["action"]) != CardData.ActionType.MOVE:
		return destinations
	var allowed: Array = card["move_paths"]
	var here: String = current_player()["tile"]
	for neighbor in BoardData.get_neighbors(here):
		var dest: String = neighbor["tile"]
		if dest in destinations:
			continue
		if _path_allowed(neighbor["path"], allowed):
			destinations.append(dest)
	return destinations


func play_move_card(hand_index: int, destination: String) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var player: Dictionary = current_player()
	var card_id: String = player["hand"][hand_index]
	var card: Dictionary = CardData.get_card(card_id)
	if int(card["action"]) != CardData.ActionType.MOVE:
		print("Refused: that card cannot move")
		return false
	var allowed: Array = card["move_paths"]
	var path := _path_between(player["tile"], destination, allowed)
	if path < 0:
		print("Refused: can't reach that tile")
		return false
	var from_tile: String = player["tile"]
	player["tile"] = destination
	_spend_card(player, hand_index)
	actions_left -= 1
	print("%s played %s: %s -> %s (%s)" % [
		player["name"],
		card["name"],
		BoardData.get_tile(from_tile)["name"],
		BoardData.get_tile(destination)["name"],
		BoardData.path_type_name(path),
	])
	state_changed.emit()
	return true


func play_placeholder_card(hand_index: int) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var player: Dictionary = current_player()
	var card_id: String = player["hand"][hand_index]
	var card: Dictionary = CardData.get_card(card_id)
	var action := int(card["action"])
	if action == CardData.ActionType.MOVE:
		print("Refused: choose a tile to move")
		return false
	if action != CardData.ActionType.SEARCH and action != CardData.ActionType.INTERACT and action != CardData.ActionType.FIGHT:
		print("Refused: that card cannot be played")
		return false
	_spend_card(player, hand_index)
	actions_left -= 1
	print("%s played %s (no effect yet)" % [player["name"], card["name"]])
	state_changed.emit()
	return true


func can_recall() -> bool:
	return actions_left > 0 and not current_player()["played"].is_empty()


func recall() -> bool:
	if actions_left <= 0:
		print("Refused: no actions left")
		return false
	var player: Dictionary = current_player()
	var played: Array = player["played"]
	if played.is_empty():
		print("Refused: nothing to recall")
		return false
	var count := played.size()
	var hand: Array = player["hand"]
	for card_id in played:
		hand.append(card_id)
	played.clear()
	actions_left -= 1
	var noun := "card" if count == 1 else "cards"
	print("%s recalled %d %s" % [player["name"], count, noun])
	state_changed.emit()
	return true


func end_turn() -> void:
	if players.is_empty():
		print("Refused: game has not started")
		return
	var name: String = current_player()["name"]
	var unused := actions_left
	var noun := "action" if unused == 1 else "actions"
	print("%s ended turn with %d %s unused" % [name, unused, noun])
	current_index = (current_index + 1) % players.size()
	actions_left = ACTIONS_PER_TURN
	print("--- %s's turn ---" % current_player()["name"])
	state_changed.emit()


func _refuse_unplayable(hand_index: int) -> bool:
	if actions_left <= 0:
		print("Refused: no actions left")
		return true
	var hand: Array = current_player()["hand"]
	if hand_index < 0 or hand_index >= hand.size():
		print("Refused: no card there")
		return true
	return false


func _spend_card(player: Dictionary, hand_index: int) -> void:
	var hand: Array = player["hand"]
	var card_id: String = hand[hand_index]
	hand.remove_at(hand_index)
	player["played"].append(card_id)


func _path_between(from_id: String, to_id: String, allowed: Array) -> int:
	for neighbor in BoardData.get_neighbors(from_id):
		if neighbor["tile"] == to_id and _path_allowed(neighbor["path"], allowed):
			return int(neighbor["path"])
	return -1


func _path_allowed(path, allowed: Array) -> bool:
	var path_type := int(path)
	for entry in allowed:
		if int(entry) == path_type:
			return true
	return false
