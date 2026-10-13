class_name GameState
extends RefCounted

signal state_changed

const ACTIONS_PER_TURN := 3
const GEAR_SLOTS := 3
const DEBUG_SHOW_SECRETS := true
const START_TILE := "village_market"
const PLAYER_COLORS: Array[Color] = [
	Color8(231, 76, 60),
	Color8(52, 152, 219),
	Color8(241, 196, 15),
	Color8(46, 204, 113),
	Color8(230, 126, 34),
]
const SEARCH_TILES: Array[String] = ["junkyard", "archeology_site", "lake", "spaceship"]

var players: Array = []
var current_index: int = 0
var actions_left: int = ACTIONS_PER_TURN
var decks: Dictionary = {}
var found_card_id: String = ""


func start_game(player_count: int) -> void:
	if player_count < 2 or player_count > 5:
		print("Refused: player count must be between 2 and 5")
		return
	players = []
	for i in player_count:
		var hand: Array[String] = CardData.starting_hand()
		var fresh: Array[bool] = []
		fresh.resize(hand.size())
		fresh.fill(false)
		var played: Array[String] = []
		var played_fresh: Array[bool] = []
		var gear: Array[String] = []
		players.append({
			"index": i,
			"name": "Player %d" % (i + 1),
			"color": PLAYER_COLORS[i],
			"tile": START_TILE,
			"hand": hand,
			"fresh": fresh,
			"played": played,
			"played_fresh": played_fresh,
			"gear": gear,
			"gold": 0,
			"purple": 0,
		})
	decks = {}
	for tile_id in SEARCH_TILES:
		var deck: Array[String] = DeckData.build_deck(tile_id)
		deck.shuffle()
		decks[tile_id] = deck
	current_index = 0
	actions_left = ACTIONS_PER_TURN
	found_card_id = ""
	state_changed.emit()


func current_player() -> Dictionary:
	return players[current_index]


func deck_count(tile_id: String) -> int:
	if not decks.has(tile_id):
		return -1
	var deck: Array = decks[tile_id]
	return deck.size()


func can_play_card(hand_index: int) -> bool:
	if not _hand_has(hand_index):
		return false
	if actions_left <= 0:
		return false
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION:
		return false
	if int(card["action"]) == CardData.ActionType.SEARCH:
		return _search_block_reason() == ""
	return true


func play_reason(hand_index: int) -> String:
	if not _hand_has(hand_index):
		return ""
	var card := _card_at(hand_index)
	var kind := int(card["kind"])
	if kind == CardData.Kind.RESOURCE:
		return "Resources can't be played"
	if actions_left <= 0:
		return "No actions left"
	if kind == CardData.Kind.GEAR:
		return ""
	if kind == CardData.Kind.ACTION and int(card["action"]) == CardData.ActionType.SEARCH:
		return _search_block_reason()
	return ""


func get_move_destinations(hand_index: int) -> Array[String]:
	var destinations: Array[String] = []
	if not _hand_has(hand_index):
		return destinations
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION:
		return destinations
	if int(card["action"]) != CardData.ActionType.MOVE:
		return destinations
	if not card.has("move_paths"):
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
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION or int(card["action"]) != CardData.ActionType.MOVE:
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


func play_search_card(hand_index: int) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION or int(card["action"]) != CardData.ActionType.SEARCH:
		print("Refused: that card cannot search")
		return false
	var tile_id: String = player["tile"]
	var deck: Array = decks[tile_id]
	var drawn: String = deck.pop_front()
	_spend_card(player, hand_index)
	_add_to_hand(player, drawn, true)
	actions_left -= 1
	found_card_id = drawn
	print("%s searched %s with %s (deck: %d left)" % [
		player["name"],
		BoardData.get_tile(tile_id)["name"],
		card["name"],
		deck.size(),
	])
	if DEBUG_SHOW_SECRETS:
		print("  [secret] %s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	state_changed.emit()
	return true


func play_placeholder_card(hand_index: int) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION:
		print("Refused: that card cannot be played")
		return false
	var action := int(card["action"])
	if action == CardData.ActionType.MOVE:
		print("Refused: choose a tile to move")
		return false
	if action == CardData.ActionType.SEARCH:
		print("Refused: that card cannot be played")
		return false
	if action != CardData.ActionType.INTERACT and action != CardData.ActionType.FIGHT:
		print("Refused: that card cannot be played")
		return false
	_spend_card(player, hand_index)
	actions_left -= 1
	print("%s played %s (no effect yet)" % [player["name"], card["name"]])
	state_changed.emit()
	return true


func can_equip(hand_index: int) -> bool:
	if actions_left <= 0 or not _hand_has(hand_index):
		return false
	return int(_card_at(hand_index)["kind"]) == CardData.Kind.GEAR


func equip_gear(hand_index: int, replace_slot: int = -1) -> bool:
	if not _hand_has(hand_index):
		print("Refused: no card there")
		return false
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.GEAR:
		print("Refused: that card can't be equipped")
		return false
	if actions_left <= 0:
		print("Refused: No actions left")
		return false
	var player := current_player()
	var gear: Array = player["gear"]
	var card_id: String = player["hand"][hand_index]
	if gear.size() < GEAR_SLOTS:
		_take_from_hand(player, hand_index)
		gear.append(card_id)
		actions_left -= 1
		print("%s equipped %s" % [player["name"], card["name"]])
		state_changed.emit()
		return true
	if replace_slot < 0 or replace_slot >= gear.size():
		print("Refused: choose a gear slot to replace")
		return false
	var old_id: String = gear[replace_slot]
	_take_from_hand(player, hand_index)
	gear[replace_slot] = card_id
	_add_to_hand(player, old_id, false)
	actions_left -= 1
	print("%s equipped %s (swapped out %s)" % [
		player["name"],
		card["name"],
		CardData.get_card(old_id)["name"],
	])
	state_changed.emit()
	return true


func can_rest() -> bool:
	return actions_left > 0 and not current_player()["played"].is_empty()


func rest() -> bool:
	if actions_left <= 0:
		print("Refused: No actions left")
		return false
	var player := current_player()
	var played: Array = player["played"]
	if played.is_empty():
		print("Refused: Nothing to rest")
		return false
	var played_fresh: Array = player["played_fresh"]
	var count := played.size()
	for i in count:
		var returned_id: String = played[i]
		var was_fresh: bool = played_fresh[i]
		_add_to_hand(player, returned_id, was_fresh)
	played.clear()
	played_fresh.clear()
	actions_left -= 1
	var noun := "card" if count == 1 else "cards"
	print("%s rested: %d %s back to hand" % [player["name"], count, noun])
	state_changed.emit()
	return true


func end_turn() -> void:
	if players.is_empty():
		print("Refused: game has not started")
		return
	var player := current_player()
	var fresh: Array = player["fresh"]
	for i in fresh.size():
		fresh[i] = false
	var played_fresh: Array = player["played_fresh"]
	for i in played_fresh.size():
		played_fresh[i] = false
	found_card_id = ""
	var name: String = player["name"]
	var unused := actions_left
	var noun := "action" if unused == 1 else "actions"
	print("%s ended turn with %d %s unused" % [name, unused, noun])
	current_index = (current_index + 1) % players.size()
	actions_left = ACTIONS_PER_TURN
	print("--- %s's turn ---" % current_player()["name"])
	state_changed.emit()


func _hand_has(hand_index: int) -> bool:
	var hand: Array = current_player()["hand"]
	return hand_index >= 0 and hand_index < hand.size()


func _card_at(hand_index: int) -> Dictionary:
	var hand: Array = current_player()["hand"]
	var card_id: String = hand[hand_index]
	return CardData.get_card(card_id)


func _search_block_reason() -> String:
	var tile_id: String = current_player()["tile"]
	if not decks.has(tile_id):
		return "No deck here"
	var deck: Array = decks[tile_id]
	if deck.is_empty():
		return "This deck is empty"
	return ""


func _refuse_unplayable(hand_index: int) -> bool:
	if not _hand_has(hand_index):
		print("Refused: no card there")
		return true
	var reason := play_reason(hand_index)
	if reason != "":
		print("Refused: %s" % reason)
		return true
	if not can_play_card(hand_index):
		print("Refused: that card cannot be played")
		return true
	return false


func _spend_card(player: Dictionary, hand_index: int) -> void:
	var taken := _take_from_hand(player, hand_index)
	player["played"].append(taken["id"])
	player["played_fresh"].append(taken["fresh"])


func _take_from_hand(player: Dictionary, hand_index: int) -> Dictionary:
	var hand: Array = player["hand"]
	var fresh: Array = player["fresh"]
	var card_id: String = hand[hand_index]
	var was_fresh: bool = fresh[hand_index]
	hand.remove_at(hand_index)
	fresh.remove_at(hand_index)
	return {"id": card_id, "fresh": was_fresh}


func _add_to_hand(player: Dictionary, card_id: String, is_fresh: bool) -> void:
	player["hand"].append(card_id)
	player["fresh"].append(is_fresh)


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
