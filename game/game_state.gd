class_name GameState
extends RefCounted

signal state_changed
signal prompt_opened(prompt: Dictionary)
signal prompt_closed

const ACTIONS_PER_TURN := 3
const GEAR_SLOTS := 3
const DEBUG_SHOW_SECRETS := true
const DEBUG_GIVE_ALL_ITEMS := false
const STARTING_GOLD := 5
const MARKET_OFFER_SIZE := 3
const MARKET_BUY_PRICE := 2
const MARKET_SELL_PRICE := 3
const START_TILE := "village_market"
const PLAYER_COLORS: Array[Color] = [
	Color8(231, 76, 60),
	Color8(52, 152, 219),
	Color8(241, 196, 15),
	Color8(46, 204, 113),
	Color8(230, 126, 34),
]
const SEARCH_TILES: Array[String] = ["junkyard", "archeology_site", "lake", "spaceship"]
const LURE_SEARCHES: Array[String] = [
	"rummage",
	"metal_detector",
	"grappling_claw",
	"ancient_trowel",
	"cargo_manifest",
]

var players: Array = []
var current_index: int = 0
var actions_left: int = ACTIONS_PER_TURN
var decks: Dictionary = {}
var found_card_ids: Array[String] = []
var public_log: Array[String] = []
var prompt: Dictionary = {}
var market_visit: Dictionary = {}


func start_game(player_count: int) -> void:
	if player_count < 2 or player_count > 5:
		print("Refused: player count must be between 2 and 5")
		return
	players = []
	for i in player_count:
		var hand: Array[String] = CardData.starting_hand()
		if DEBUG_GIVE_ALL_ITEMS:
			for item_id in CardData.item_ids():
				hand.append(item_id)
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
			"gold": STARTING_GOLD,
			"market_offer": [],
			"purple": 0,
			"lure_used": false,
		})
	decks = {}
	for tile_id in SEARCH_TILES:
		var deck: Array[String] = DeckData.build_deck(tile_id)
		deck.shuffle()
		decks[tile_id] = deck
	for player in players:
		refresh_market_offer(player)
	current_index = 0
	actions_left = ACTIONS_PER_TURN
	found_card_ids.clear()
	public_log.clear()
	prompt = {}
	market_visit = {}
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
		return _search_block_reason_for(card) == ""
	if int(card["action"]) == CardData.ActionType.INTERACT:
		return BoardData.has_interaction(str(current_player()["tile"]))
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
		if _wearing(current_player(), str(card["id"])):
			return "You already have this gear"
		return ""
	if kind == CardData.Kind.ACTION and int(card["action"]) == CardData.ActionType.SEARCH:
		return _search_block_reason_for(card)
	if kind == CardData.Kind.ACTION and int(card["action"]) == CardData.ActionType.INTERACT:
		if not BoardData.has_interaction(str(current_player()["tile"])):
			return "Nothing to interact with here"
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
	var steps := 1
	if card.has("move_steps"):
		steps = int(card["move_steps"])
	return _reachable(str(current_player()["tile"]), card["move_paths"], steps)


func get_claw_targets() -> Array[String]:
	var targets: Array[String] = []
	if players.is_empty():
		return targets
	var origin: Vector2i = BoardData.get_tile(current_player()["tile"])["grid_pos"]
	for tile_id in BoardData.get_tile_ids():
		var pos: Vector2i = BoardData.get_tile(tile_id)["grid_pos"]
		if absi(pos.x - origin.x) + absi(pos.y - origin.y) != 1:
			continue
		if deck_count(tile_id) > 0:
			targets.append(tile_id)
	return targets


func play_move_card(hand_index: int, destination: String) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION or int(card["action"]) != CardData.ActionType.MOVE:
		print("Refused: that card cannot move")
		return false
	var destinations := get_move_destinations(hand_index)
	if destination not in destinations:
		print("Refused: can't reach that tile")
		return false
	var from_tile: String = player["tile"]
	var path := _path_between(from_tile, destination, card["move_paths"])
	var path_label := "normal"
	if path >= 0:
		path_label = BoardData.path_type_name(path)
	player["tile"] = destination
	_pay(player, hand_index)
	print("%s played %s: %s -> %s (%s)" % [
		player["name"],
		card["name"],
		_tile_name(from_tile),
		_tile_name(destination),
		path_label,
	])
	_log_only("%s moved %s → %s (%s)" % [
		player["name"],
		_tile_name(from_tile),
		_tile_name(destination),
		card["name"],
	])
	if destination == START_TILE and from_tile != START_TILE:
		refresh_market_offer(player)
	_maybe_map(player, destination)
	state_changed.emit()
	return true


func play_search_card(hand_index: int) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION or int(card["action"]) != CardData.ActionType.SEARCH:
		print("Refused: that card cannot search")
		return false
	var card_id := str(card["id"])
	if card_id == "grappling_claw":
		print("Refused: choose a tile to grab")
		return false
	if _wants_lure(card_id):
		_ask_lure(hand_index, card_id, "")
		return true
	return _resolve_search(hand_index, card_id, false, "")


func play_claw(hand_index: int, tile_id: String) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var card := _card_at(hand_index)
	if str(card["id"]) != "grappling_claw":
		print("Refused: that card cannot grab")
		return false
	if tile_id not in get_claw_targets():
		print("Refused: no deck there")
		return false
	if _wants_lure("grappling_claw"):
		_ask_lure(hand_index, "grappling_claw", tile_id)
		return true
	return _resolve_search(hand_index, "grappling_claw", false, tile_id)


func choose_prompt_card(index: int) -> void:
	if prompt.is_empty() or str(prompt["kind"]) != "keep_one":
		return
	var shown: Array = prompt["cards"]
	if index < 0 or index >= shown.size():
		return
	var tile_id := str(prompt["tile_id"])
	var from_bottom: bool = bool(prompt["from_bottom"])
	var deck: Array = decks[tile_id]
	if deck.size() < 2:
		_close_prompt()
		return
	var first := ""
	var second := ""
	if from_bottom:
		first = str(deck.pop_back())
		second = str(deck.pop_back())
	else:
		first = str(deck.pop_front())
		second = str(deck.pop_front())
	var kept := str(shown[index])
	var other := second
	if kept != first:
		kept = second
		other = first
	deck.append(other)
	var player := current_player()
	_add_to_hand(player, kept, true)
	found_card_ids.append(kept)
	_announce_search(player, tile_id, "metal_detector")
	_secret("%s drew: %s" % [player["name"], CardData.get_card(kept)["name"]])
	_secret("%s put back: %s" % [player["name"], CardData.get_card(other)["name"]])
	_close_prompt()
	state_changed.emit()


func choose_prompt_button(label: String) -> void:
	if prompt.is_empty():
		return
	var kind := str(prompt["kind"])
	if kind == "lure":
		_resolve_lure(label)
	elif kind == "radio_pick":
		_resolve_radio(label)
	elif kind == "notebook" and label == "Swap order":
		_swap_notebook()
	else:
		_close_prompt()


func begin_turn() -> void:
	if players.is_empty() or not prompt.is_empty():
		return
	var player := current_player()
	if not _wearing(player, "junk_radio"):
		return
	var buttons: Array[String] = []
	var tile_for: Dictionary = {}
	for tile_id in SEARCH_TILES:
		if deck_count(tile_id) <= 0:
			continue
		var label := _tile_name(tile_id)
		buttons.append(label)
		tile_for[label] = tile_id
	buttons.append("Skip")
	_open_prompt({
		"kind": "radio_pick",
		"title": "Junk Radio",
		"message": "Junk Radio: peek at which deck?",
		"cards": [],
		"clickable": false,
		"buttons": buttons,
		"tile_for": tile_for,
	})


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
	if action == CardData.ActionType.INTERACT:
		return begin_market(hand_index)
	if action != CardData.ActionType.FIGHT:
		print("Refused: that card cannot be played")
		return false
	_pay(player, hand_index)
	_public("%s played %s (no effect yet)" % [player["name"], card["name"]])
	state_changed.emit()
	return true


func can_equip(hand_index: int) -> bool:
	if actions_left <= 0 or not _hand_has(hand_index):
		return false
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.GEAR:
		return false
	return not _wearing(current_player(), str(card["id"]))


func equip_gear(hand_index: int, replace_slot: int = -1) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
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
	if _wearing(player, str(card["id"])):
		print("Refused: You already have this gear")
		return false
	var gear: Array = player["gear"]
	var card_id: String = player["hand"][hand_index]
	if gear.size() < GEAR_SLOTS:
		_take_from_hand(player, hand_index)
		gear.append(card_id)
		actions_left -= 1
		_public("%s equipped %s" % [player["name"], card["name"]])
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
	_public("%s equipped %s (swapped out %s)" % [
		player["name"],
		card["name"],
		CardData.get_card(old_id)["name"],
	])
	state_changed.emit()
	return true


func can_rest() -> bool:
	return actions_left > 0 and not current_player()["played"].is_empty()


func rest() -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
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
	_public("%s rested: %d %s back to hand" % [player["name"], count, noun])
	_maybe_notebook(player)
	state_changed.emit()
	return true


func end_turn() -> void:
	if players.is_empty():
		print("Refused: game has not started")
		return
	if _is_busy():
		print("Refused: finish the current choice first")
		return
	var player := current_player()
	var fresh: Array = player["fresh"]
	for i in fresh.size():
		fresh[i] = false
	var played_fresh: Array = player["played_fresh"]
	for i in played_fresh.size():
		played_fresh[i] = false
	found_card_ids.clear()
	var unused := actions_left
	var noun := "action" if unused == 1 else "actions"
	_public("%s ended turn with %d %s unused" % [player["name"], unused, noun])
	current_index = (current_index + 1) % players.size()
	actions_left = ACTIONS_PER_TURN
	current_player()["lure_used"] = false
	print("--- %s's turn ---" % current_player()["name"])
	state_changed.emit()


func _resolve_lure(label: String) -> void:
	if label != "Top" and label != "Bottom":
		return
	var hand_index := int(prompt["hand_index"])
	var card_id := str(prompt["card_id"])
	var tile_id := str(prompt["tile_id"])
	var from_bottom := label == "Bottom"
	if from_bottom:
		current_player()["lure_used"] = true
	_close_prompt()
	_resolve_search(hand_index, card_id, from_bottom, tile_id)


func _resolve_search(hand_index: int, card_id: String, from_bottom: bool, source_tile: String) -> bool:
	if not _hand_has(hand_index) or str(current_player()["hand"][hand_index]) != card_id:
		print("Refused: no card there")
		return false
	if _refuse_unplayable(hand_index):
		return false
	var player := current_player()
	var tile_id := source_tile if source_tile != "" else str(player["tile"])
	if card_id == "grappling_claw":
		if tile_id not in get_claw_targets():
			print("Refused: no deck there")
			return false
	elif deck_count(tile_id) <= 0:
		print("Refused: %s" % _deck_here_reason())
		return false
	if card_id == "fishing_net":
		from_bottom = true
	if card_id == "metal_detector":
		return _metal_detector(player, hand_index, tile_id, from_bottom)
	if card_id == "alien_tracker":
		return _alien_tracker(player, hand_index, tile_id)
	if card_id == "ancient_trowel":
		return _ancient_trowel(player, hand_index, tile_id, from_bottom)
	if card_id == "cargo_manifest":
		return _cargo_manifest(player, hand_index, tile_id, from_bottom)
	return _draw_one(player, hand_index, tile_id, card_id, from_bottom)


func _draw_one(player: Dictionary, hand_index: int, tile_id: String, card_id: String, from_bottom: bool) -> bool:
	var deck: Array = decks[tile_id]
	var drawn := str(_pull(deck, from_bottom))
	_pay(player, hand_index)
	_add_to_hand(player, drawn, true)
	found_card_ids.append(drawn)
	_announce_search(player, tile_id, card_id)
	_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	state_changed.emit()
	return true


func _metal_detector(player: Dictionary, hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	var deck: Array = decks[tile_id]
	if deck.size() < 2:
		return _draw_one(player, hand_index, tile_id, "metal_detector", from_bottom)
	var shown: Array[String] = []
	if from_bottom:
		shown.append(str(deck[deck.size() - 1]))
		shown.append(str(deck[deck.size() - 2]))
	else:
		shown.append(str(deck[0]))
		shown.append(str(deck[1]))
	_pay(player, hand_index)
	state_changed.emit()
	_open_prompt({
		"kind": "keep_one",
		"title": "Metal Detector",
		"message": "Click the card you want to keep. The other goes to the bottom of the deck.",
		"cards": shown,
		"clickable": true,
		"buttons": [],
		"tile_id": tile_id,
		"from_bottom": from_bottom,
	})
	return true


func _alien_tracker(player: Dictionary, hand_index: int, tile_id: String) -> bool:
	var deck: Array = decks[tile_id]
	var shown: Array[String] = []
	var count: int = mini(3, deck.size())
	var saw_alien := false
	for i in count:
		var card_id := str(deck[i])
		shown.append(card_id)
		if CardData.is_alien(card_id):
			saw_alien = true
	_pay(player, hand_index)
	_announce_search(player, tile_id, "alien_tracker")
	if saw_alien:
		player["purple"] = int(player["purple"]) + 1
		_public("%s gained 1 purple (Alien Tracker)" % player["name"])
	_secret("%s saw: %s" % [player["name"], _name_list(shown)])
	state_changed.emit()
	_open_prompt({
		"kind": "peek",
		"title": "Alien Tracker",
		"message": "Top cards of the %s deck. They stay in this order." % _tile_name(tile_id),
		"cards": shown,
		"clickable": false,
		"buttons": ["Done"],
	})
	return true


func _ancient_trowel(player: Dictionary, hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	var deck: Array = decks[tile_id]
	var drawn := str(_pull(deck, from_bottom))
	_pay(player, hand_index)
	_add_to_hand(player, drawn, true)
	found_card_ids.append(drawn)
	var drawn_card := CardData.get_card(drawn)
	var revealed := int(drawn_card["kind"]) == CardData.Kind.RESOURCE
	if revealed and not deck.is_empty():
		var extra := str(_pull(deck, from_bottom))
		_add_to_hand(player, extra, true)
		found_card_ids.append(extra)
		_secret("%s drew: %s" % [player["name"], CardData.get_card(extra)["name"]])
	elif not revealed:
		_secret("%s drew: %s" % [player["name"], drawn_card["name"]])
	_announce_search(player, tile_id, "ancient_trowel")
	if revealed:
		_public("%s revealed %s (Ancient Trowel)" % [player["name"], drawn_card["name"]])
	state_changed.emit()
	return true


func _cargo_manifest(player: Dictionary, hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	_draw_one(player, hand_index, tile_id, "cargo_manifest", from_bottom)
	var deck: Array = decks[tile_id]
	if deck.is_empty():
		return true
	var nxt := str(_peek_at(deck, from_bottom))
	_secret("%s saw next: %s" % [player["name"], CardData.get_card(nxt)["name"]])
	_open_prompt({
		"kind": "peek",
		"title": "Cargo Manifest",
		"message": "The next card of this deck is…",
		"cards": [nxt],
		"clickable": false,
		"buttons": ["Done"],
	})
	return true


func _maybe_map(player: Dictionary, tile_id: String) -> void:
	if not _wearing(player, "map") or deck_count(tile_id) <= 0:
		return
	var top := str(decks[tile_id][0])
	_public("%s used Map" % player["name"])
	_secret("%s saw with Map: %s" % [player["name"], CardData.get_card(top)["name"]])
	_open_prompt({
		"kind": "peek",
		"title": "Map",
		"message": "Map: the top card of the %s deck is…" % _tile_name(tile_id),
		"cards": [top],
		"clickable": false,
		"buttons": ["Done"],
	})


func _maybe_notebook(player: Dictionary) -> void:
	if not _wearing(player, "scholars_notebook"):
		return
	var tile_id := str(player["tile"])
	if deck_count(tile_id) <= 0:
		return
	var deck: Array = decks[tile_id]
	var shown: Array[String] = []
	var count: int = mini(2, deck.size())
	for i in count:
		shown.append(str(deck[i]))
	_public("%s used Scholar's Notebook" % player["name"])
	_secret("%s saw with Scholar's Notebook: %s" % [player["name"], _name_list(shown)])
	var buttons: Array[String] = []
	if shown.size() > 1:
		buttons.append("Swap order")
	buttons.append("Done")
	_open_prompt({
		"kind": "notebook",
		"title": "Scholar's Notebook",
		"message": "Top cards of the %s deck." % _tile_name(tile_id),
		"cards": shown,
		"clickable": false,
		"buttons": buttons,
		"tile_id": tile_id,
	})


func _swap_notebook() -> void:
	var tile_id := str(prompt["tile_id"])
	var deck: Array = decks[tile_id]
	if deck.size() < 2:
		return
	var first := str(deck[0])
	deck[0] = deck[1]
	deck[1] = first
	var shown: Array[String] = [str(deck[0]), str(deck[1])]
	prompt["cards"] = shown
	_secret("%s swapped the %s deck: %s" % [current_player()["name"], _tile_name(tile_id), _name_list(shown)])
	prompt_opened.emit(prompt)


func _resolve_radio(label: String) -> void:
	if label == "Skip":
		_close_prompt()
		return
	var tile_for: Dictionary = prompt["tile_for"]
	if not tile_for.has(label):
		_close_prompt()
		return
	var tile_id := str(tile_for[label])
	var deck: Array = decks[tile_id]
	if deck.is_empty():
		_close_prompt()
		return
	var top := str(deck[0])
	var player := current_player()
	_public("%s used Junk Radio" % player["name"])
	_secret("%s saw with Junk Radio: %s" % [player["name"], CardData.get_card(top)["name"]])
	state_changed.emit()
	_open_prompt({
		"kind": "peek",
		"title": "Junk Radio",
		"message": "The top card of the %s deck is…" % label,
		"cards": [top],
		"clickable": false,
		"buttons": ["Done"],
	})


func _ask_lure(hand_index: int, card_id: String, tile_id: String) -> void:
	_open_prompt({
		"kind": "lure",
		"title": "Lucky Lure",
		"message": "Lucky Lure: draw from the Top or the Bottom?",
		"cards": [],
		"clickable": false,
		"buttons": ["Top", "Bottom"],
		"hand_index": hand_index,
		"card_id": card_id,
		"tile_id": tile_id,
	})


func _wants_lure(card_id: String) -> bool:
	if card_id not in LURE_SEARCHES:
		return false
	var player := current_player()
	if bool(player["lure_used"]):
		return false
	return _wearing(player, "lucky_lure")


func _announce_search(player: Dictionary, tile_id: String, card_id: String) -> void:
	var tile_name := _tile_name(tile_id)
	var card_name: String = CardData.get_card(card_id)["name"]
	var left := deck_count(tile_id)
	if card_id == "grappling_claw":
		print("%s grabbed from %s with %s (deck: %d left)" % [player["name"], tile_name, card_name, left])
		_log_only("%s grabbed from %s (%s)" % [player["name"], tile_name, card_name])
	else:
		print("%s searched %s with %s (deck: %d left)" % [player["name"], tile_name, card_name, left])
		_log_only("%s searched %s (%s)" % [player["name"], tile_name, card_name])


func _reachable(start: String, allowed: Array, steps: int) -> Array[String]:
	var destinations: Array[String] = []
	var frontier: Array[String] = [start]
	var seen := {start: true}
	for _step in steps:
		var next: Array[String] = []
		for tile_id in frontier:
			for neighbor in BoardData.get_neighbors(tile_id):
				var dest: String = neighbor["tile"]
				if seen.has(dest):
					continue
				if not _path_allowed(neighbor["path"], allowed):
					continue
				seen[dest] = true
				destinations.append(dest)
				next.append(dest)
		frontier = next
	return destinations


func _search_block_reason_for(card: Dictionary) -> String:
	if str(card["id"]) == "grappling_claw":
		if get_claw_targets().is_empty():
			return "No deck next to you"
		return ""
	return _deck_here_reason()


func _deck_here_reason() -> String:
	var tile_id := str(current_player()["tile"])
	if not decks.has(tile_id):
		return "No deck here"
	var deck: Array = decks[tile_id]
	if deck.is_empty():
		return "This deck is empty"
	return ""


func refresh_market_offer(player: Dictionary) -> void:
	var pool := CardData.market_pool()
	var offer: Array[String] = []
	for _slot in MARKET_OFFER_SIZE:
		offer.append(pool[randi() % pool.size()])
	player["market_offer"] = offer
	_secret("%s market offer: %s" % [str(player["name"]), _name_list(offer)])


func begin_market(hand_index: int) -> bool:
	if _refuse_unplayable(hand_index):
		return false
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ACTION or int(card["action"]) != CardData.ActionType.INTERACT:
		print("Refused: that card cannot interact")
		return false
	var bought: Array[String] = []
	market_visit = {
		"hand_index": hand_index,
		"card_id": str(card["id"]),
		"sold": 0,
		"bought": bought,
	}
	return true


func market_sell(resource_hand_index: int) -> bool:
	if market_visit.is_empty():
		print("Refused: the market is not open")
		return false
	var player := current_player()
	var hand: Array = player["hand"]
	if resource_hand_index < 0 or resource_hand_index >= hand.size():
		print("Refused: no card there")
		return false
	var card_id := str(hand[resource_hand_index])
	var card := CardData.get_card(card_id)
	if int(card["kind"]) != CardData.Kind.RESOURCE:
		print("Refused: only resources can be sold")
		return false
	_take_from_hand(player, resource_hand_index)
	player["gold"] = int(player["gold"]) + MARKET_SELL_PRICE
	market_visit["sold"] = int(market_visit["sold"]) + 1
	if resource_hand_index < int(market_visit["hand_index"]):
		market_visit["hand_index"] = int(market_visit["hand_index"]) - 1
	state_changed.emit()
	return true


func market_buy(offer_slot: int) -> bool:
	if market_visit.is_empty():
		print("Refused: the market is not open")
		return false
	var player := current_player()
	var offer: Array = player["market_offer"]
	if offer_slot < 0 or offer_slot >= offer.size():
		print("Refused: no card there")
		return false
	var card_id := str(offer[offer_slot])
	if card_id == "":
		print("Refused: that card was already sold")
		return false
	if int(player["gold"]) < MARKET_BUY_PRICE:
		print("Refused: not enough gold")
		return false
	offer[offer_slot] = ""
	player["gold"] = int(player["gold"]) - MARKET_BUY_PRICE
	_add_to_hand(player, card_id, false)
	var bought: Array = market_visit["bought"]
	bought.append(card_id)
	state_changed.emit()
	return true


func market_has_traded() -> bool:
	if market_visit.is_empty():
		return false
	var bought: Array = market_visit["bought"]
	return int(market_visit["sold"]) > 0 or not bought.is_empty()


func market_finish() -> bool:
	if market_visit.is_empty():
		return false
	var player := current_player()
	var sold_count := int(market_visit["sold"])
	var bought: Array = market_visit["bought"]
	var traded := sold_count > 0 or not bought.is_empty()
	if traded:
		var hand_index := int(market_visit["hand_index"])
		var card_id := str(market_visit["card_id"])
		var hand: Array = player["hand"]
		if hand_index < 0 or hand_index >= hand.size() or str(hand[hand_index]) != card_id:
			var found: int = int(hand.find(card_id))
			hand_index = found
		if hand_index >= 0:
			_pay(player, hand_index)
		_public(_market_log(player, sold_count, bought))
	market_visit = {}
	state_changed.emit()
	return traded


func _market_log(player: Dictionary, sold_count: int, bought: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if sold_count > 0:
		var noun := "resource" if sold_count == 1 else "resources"
		parts.append("sold %d %s (+%d)" % [sold_count, noun, sold_count * MARKET_SELL_PRICE])
	if not bought.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for card_id in bought:
			names.append(str(CardData.get_card(str(card_id))["name"]))
		parts.append("bought %s (-%d)" % [", ".join(names), bought.size() * MARKET_BUY_PRICE])
	return "%s at the market: %s" % [str(player["name"]), ", ".join(parts)]


func _is_busy() -> bool:
	return not prompt.is_empty() or not market_visit.is_empty()


func _refuse_unplayable(hand_index: int) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return true
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


func _pay(player: Dictionary, hand_index: int) -> void:
	_spend_card(player, hand_index)
	actions_left -= 1


func _pull(deck: Array, from_bottom: bool) -> String:
	if from_bottom:
		return str(deck.pop_back())
	return str(deck.pop_front())


func _peek_at(deck: Array, from_bottom: bool) -> String:
	if from_bottom:
		return str(deck[deck.size() - 1])
	return str(deck[0])


func _open_prompt(data: Dictionary) -> void:
	prompt = data
	prompt_opened.emit(prompt)


func _close_prompt() -> void:
	if prompt.is_empty():
		return
	prompt = {}
	prompt_closed.emit()


func _public(text: String) -> void:
	print(text)
	_log_only(text)


func _log_only(text: String) -> void:
	public_log.insert(0, text)


func _secret(text: String) -> void:
	if DEBUG_SHOW_SECRETS:
		print("  [secret] %s" % text)


func _wearing(player: Dictionary, card_id: String) -> bool:
	var gear: Array = player["gear"]
	return card_id in gear


func _hand_has(hand_index: int) -> bool:
	var hand: Array = current_player()["hand"]
	return hand_index >= 0 and hand_index < hand.size()


func _card_at(hand_index: int) -> Dictionary:
	var hand: Array = current_player()["hand"]
	var card_id: String = hand[hand_index]
	return CardData.get_card(card_id)


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


func _tile_name(tile_id: String) -> String:
	return str(BoardData.get_tile(tile_id)["name"])


func _name_list(card_ids: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for card_id in card_ids:
		names.append(str(CardData.get_card(str(card_id))["name"]))
	return ", ".join(names)
