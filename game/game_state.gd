class_name GameState
extends RefCounted

signal state_changed
signal prompt_opened(prompt: Dictionary)
signal prompt_closed
signal turn_ended
signal skrim_announced(player_name: String)
signal game_won(player_index: int)

const ACTIONS_PER_TURN := 3
const GEAR_SLOTS := 4
const DEBUG_SHOW_SECRETS := true
const DEBUG_GIVE_ALL_ITEMS := false
const DEBUG_START_ALIENS := 0
const ALIENS_TO_WIN := 5
const STARTING_GOLD := 5
const STARTING_RESOURCES := 2
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
const ANY_PATH: Array = [
	BoardData.PathType.NORMAL,
	BoardData.PathType.JUNGLE,
	BoardData.PathType.RIVER,
	BoardData.PathType.PLANE,
]
const TOP_DRAW_ABILITIES: Array[String] = ["ancient_trowel", "cargo_manifest", "grappling_claw"]

var players: Array = []
var current_index: int = 0
var actions_left: int = ACTIONS_PER_TURN
var decks: Dictionary = {}
var discard: Array[String] = []
var found_card_ids: Array[String] = []
var public_log: Array[String] = []
var prompt: Dictionary = {}
var market_visit: Dictionary = {}
var missing_alien := ""
var crystal_pool := 0
var game_over := false
var winner_index := -1
var _pending_end := false


func start_game(player_count: int) -> void:
	if player_count < 2 or player_count > 4:
		print("Refused: player count must be between 2 and 4")
		return
	players = []
	for i in player_count:
		var hand: Array[String] = CardData.random_starting_hand(STARTING_RESOURCES)
		if DEBUG_GIVE_ALL_ITEMS:
			for item_id in CardData.item_ids():
				hand.append(item_id)
		players.append({
			"index": i,
			"name": "Player %d" % (i + 1),
			"color": PLAYER_COLORS[i],
			"tile": START_TILE,
			"hand": hand,
			"gear": [],
			"gear_used_this_turn": [],
			"gold": STARTING_GOLD,
			"market_offer": [],
			"purple": 0,
			"lure_used_this_turn": false,
			"aliens": [],
			"checklist": _blank_checklist(),
		})
	decks = {}
	for tile_id in SEARCH_TILES:
		var deck: Array[String] = DeckData.build_deck(tile_id)
		decks[tile_id] = deck
	discard = []
	crystal_pool = 0
	game_over = false
	winner_index = -1
	_deal_aliens()
	for player in players:
		refresh_market_offer(player)
	current_index = 0
	actions_left = ACTIONS_PER_TURN
	found_card_ids.clear()
	public_log.clear()
	prompt = {}
	market_visit = {}
	_pending_end = false
	_give_debug_aliens()
	state_changed.emit()


func current_player() -> Dictionary:
	return players[current_index]


func deck_count(tile_id: String) -> int:
	if not decks.has(tile_id):
		return -1
	var deck: Array = decks[tile_id]
	return deck.size()


func move_paths(player: Dictionary) -> Array:
	var paths: Array = [BoardData.PathType.NORMAL]
	var gear: Array = player["gear"]
	for gear_id in gear:
		var card: Dictionary = CardData.get_card(str(gear_id))
		if not card.has("grants_paths"):
			continue
		var granted: Array = card["grants_paths"]
		for path in granted:
			if not _path_allowed(path, paths):
				paths.append(path)
	return paths


func get_move_destinations() -> Array[String]:
	if players.is_empty():
		var none: Array[String] = []
		return none
	return _reachable(str(current_player()["tile"]), move_paths(current_player()), 1)


func can_move() -> bool:
	return move_reason() == ""


func move_reason() -> String:
	var blocked := _turn_block()
	if blocked != "":
		return blocked
	if get_move_destinations().is_empty():
		return "Nowhere to move"
	return ""


func do_move(destination: String) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_move():
		print("Refused: %s" % move_reason())
		return false
	if destination not in get_move_destinations():
		print("Refused: can't reach that tile")
		return false
	_move_to(current_player(), destination)
	actions_left -= 1
	state_changed.emit()
	return true


func can_search() -> bool:
	return search_reason() == ""


func search_reason() -> String:
	var blocked := _turn_block()
	if blocked != "":
		return blocked
	return _deck_here_reason()


func do_search() -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_search():
		print("Refused: %s" % search_reason())
		return false
	if _lure_applies():
		_ask_lure("base", -1, "", str(current_player()["tile"]), -1)
		return true
	return _perform_base_search(false)


func can_interact() -> bool:
	return interact_reason() == ""


func interact_reason() -> String:
	var blocked := _turn_block()
	if blocked != "":
		return blocked
	var tile_id := str(current_player()["tile"])
	if tile_id == "crystal_mount":
		if crystal_pool <= 0:
			return "The pool is empty"
		return ""
	if not BoardData.has_interaction(tile_id):
		return "Nothing to interact with here"
	return ""


func do_interact() -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_interact():
		print("Refused: %s" % interact_reason())
		return false
	if str(current_player()["tile"]) == "crystal_mount":
		return _collect_crystal_pool()
	var bought: Array[String] = []
	market_visit = {"sold": 0, "bought": bought}
	return true


func can_fight() -> bool:
	return false


func fight_reason() -> String:
	return "No enemies here"


func can_play_card(hand_index: int) -> bool:
	if _is_busy() or not _hand_has(hand_index):
		return false
	return play_reason(hand_index) == ""


func play_reason(hand_index: int) -> String:
	if not _hand_has(hand_index):
		return ""
	if game_over:
		return "The game is over"
	var card := _card_at(hand_index)
	var kind := int(card["kind"])
	if kind == CardData.Kind.RESOURCE:
		return "Resources can't be played"
	if kind == CardData.Kind.ALIEN and str(card.get("alien_mode", "")) == "unplayable":
		return "Skrim can't be played"
	if actions_left <= 0:
		return "No actions left"
	if kind == CardData.Kind.GEAR:
		if _wearing(current_player(), str(card["id"])):
			return "You already have this gear"
		return ""
	if kind == CardData.Kind.ABILITY:
		return _ability_block_reason(card)
	if kind == CardData.Kind.ALIEN:
		return ""
	return "That card cannot be played"


func ability_destinations(hand_index: int) -> Array[String]:
	var destinations: Array[String] = []
	if not _hand_has(hand_index):
		return destinations
	var card := _card_at(hand_index)
	var card_id := str(card["id"])
	var player := current_player()
	if card_id == "scrap_hoverboard":
		return _reachable(str(player["tile"]), move_paths(player), 2)
	if card_id == "patchwork_glider":
		return _reachable(str(player["tile"]), ANY_PATH, 1)
	return destinations


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


func play_gear(hand_index: int, replace_slot: int = -1) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_play_card(hand_index):
		var reason := play_reason(hand_index)
		print("Refused: %s" % (reason if reason != "" else "that card cannot be played"))
		return false
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.GEAR:
		print("Refused: that card can't be equipped")
		return false
	var gear: Array = player["gear"]
	var card_id := _take_from_hand(player, hand_index)
	if gear.size() < GEAR_SLOTS:
		gear.append(card_id)
		actions_left -= 1
		_public("%s put down %s" % [player["name"], card["name"]])
		state_changed.emit()
		return true
	if replace_slot < 0 or replace_slot >= gear.size():
		player["hand"].insert(hand_index, card_id)
		print("Refused: choose a gear slot to replace")
		return false
	var old_id: String = gear[replace_slot]
	gear[replace_slot] = card_id
	discard.append(old_id)
	actions_left -= 1
	_public("%s put down %s (discarded %s)" % [
		player["name"],
		card["name"],
		CardData.get_card(old_id)["name"],
	])
	state_changed.emit()
	return true


func play_alien(hand_index: int) -> bool:
	if game_over:
		print("Refused: the game is over")
		return false
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_play_card(hand_index):
		var reason := play_reason(hand_index)
		print("Refused: %s" % (reason if reason != "" else "that card cannot be played"))
		return false
	var player := current_player()
	var card := _card_at(hand_index)
	if int(card["kind"]) != CardData.Kind.ALIEN:
		print("Refused: that card cannot be played")
		return false
	var card_id := _take_from_hand(player, hand_index)
	var aliens: Array = player["aliens"]
	aliens.append(card_id)
	crystal_pool += 1
	actions_left -= 1
	_public("%s played alien %s (+1 purple to Crystal mount)" % [player["name"], card["name"]])
	_check_win()
	state_changed.emit()
	return true


func alien_count(player: Dictionary) -> int:
	var count := 0
	var hand: Array = player["hand"]
	for card_id in hand:
		if CardData.is_alien(str(card_id)):
			count += 1
	var aliens: Array = player["aliens"]
	return count + aliens.size()


func set_checklist(alien_id: String, ticked: bool) -> void:
	if players.is_empty() or game_over or not CardData.is_alien(alien_id):
		return
	var checks: Dictionary = current_player()["checklist"]
	checks[alien_id] = ticked


func play_ability(hand_index: int, destination: String = "", source_tile: String = "") -> bool:
	if not _prepare_ability(hand_index):
		return false
	var card_id := str(current_player()["hand"][hand_index])
	if card_id == "scrap_hoverboard" or card_id == "patchwork_glider":
		return _resolve_move_ability(hand_index, destination)
	if card_id == "grappling_claw":
		if source_tile == "":
			print("Refused: choose a tile to grab")
			return false
		if source_tile not in get_claw_targets():
			print("Refused: no deck there")
			return false
		if _lure_applies():
			_ask_lure("ability", hand_index, card_id, source_tile, -1)
			return true
		return _resolve_claw(hand_index, source_tile, false)
	if card_id == "alien_tracker":
		return _ask_tracker(hand_index)
	if _lure_applies() and card_id in TOP_DRAW_ABILITIES:
		_ask_lure("ability", hand_index, card_id, str(current_player()["tile"]), -1)
		return true
	return _resolve_search_ability(hand_index, card_id, false, str(current_player()["tile"]))


func can_use_gear(slot: int) -> bool:
	if players.is_empty():
		return false
	var gear: Array = current_player()["gear"]
	if slot < 0 or slot >= gear.size():
		return false
	var card: Dictionary = CardData.get_card(str(gear[slot]))
	if str(card.get("gear_mode", "")) != "active":
		return false
	return gear_use_reason(slot) == ""


func gear_use_reason(slot: int) -> String:
	if players.is_empty():
		return ""
	var gear: Array = current_player()["gear"]
	if slot < 0 or slot >= gear.size():
		return ""
	var card_id := str(gear[slot])
	var card: Dictionary = CardData.get_card(card_id)
	if str(card.get("gear_mode", "")) != "active":
		return ""
	var used: Array = current_player()["gear_used_this_turn"]
	if card_id in used:
		return "Used"
	var blocked := _turn_block()
	if blocked != "":
		return blocked
	if card_id == "metal_detector":
		return _deck_here_reason()
	return ""


func use_gear(slot: int) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not can_use_gear(slot):
		var reason := gear_use_reason(slot)
		print("Refused: %s" % (reason if reason != "" else "that gear cannot be used"))
		return false
	var card_id := str(current_player()["gear"][slot])
	if card_id == "metal_detector" and _lure_applies():
		_ask_lure("gear", -1, card_id, str(current_player()["tile"]), slot)
		return true
	return _finish_gear_use(slot, false)


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
	_add_to_hand(player, kept)
	found_card_ids.append(kept)
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
	elif kind == "notebook":
		if label == "Swap order":
			_swap_visible_pair()
		else:
			var ending := _pending_end
			_close_prompt()
			if ending:
				_advance_turn()
	elif kind == "reorder":
		if label == "Swap order":
			_swap_visible_pair()
		else:
			_close_prompt()
	elif kind == "tracker_pick":
		_resolve_tracker(label)
	else:
		_close_prompt()


func dismiss_prompt() -> void:
	if prompt.is_empty():
		return
	var kind := str(prompt["kind"])
	if kind == "lure":
		_resolve_lure("Top")
	elif kind == "keep_one":
		choose_prompt_card(0)
	elif kind == "notebook" or kind == "reorder":
		choose_prompt_button("Done")
	elif kind == "radio_pick":
		_resolve_radio("Skip")
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
		var deck_label := _tile_name(tile_id)
		buttons.append(deck_label)
		tile_for[deck_label] = tile_id
	if buttons.is_empty():
		return
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


func end_turn() -> void:
	if players.is_empty():
		print("Refused: game has not started")
		return
	if game_over:
		print("Refused: the game is over")
		return
	if _is_busy():
		print("Refused: finish the current choice first")
		return
	var player := current_player()
	if _maybe_notebook(player):
		_pending_end = true
		return
	_advance_turn()


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
	_add_to_hand(player, card_id)
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
	if traded and actions_left > 0:
		actions_left -= 1
		_public(_market_log(player, sold_count, bought))
	market_visit = {}
	state_changed.emit()
	return traded


func refresh_market_offer(player: Dictionary) -> void:
	var pool := CardData.market_pool()
	var offer: Array[String] = []
	for _slot in MARKET_OFFER_SIZE:
		offer.append(pool[randi() % pool.size()])
	player["market_offer"] = offer
	_secret("%s market offer: %s" % [str(player["name"]), _name_list(offer)])


func _advance_turn() -> void:
	_pending_end = false
	var unused := actions_left
	var noun := "action" if unused == 1 else "actions"
	_public("%s ended turn with %d %s unused" % [current_player()["name"], unused, noun])
	found_card_ids.clear()
	current_index = (current_index + 1) % players.size()
	actions_left = ACTIONS_PER_TURN
	var starting := current_player()
	starting["gear_used_this_turn"] = []
	starting["lure_used_this_turn"] = false
	print("--- %s's turn ---" % starting["name"])
	state_changed.emit()
	turn_ended.emit()


func _prepare_ability(hand_index: int) -> bool:
	if _is_busy():
		print("Refused: finish the current choice first")
		return false
	if not _hand_has(hand_index):
		print("Refused: no card there")
		return false
	if int(_card_at(hand_index)["kind"]) != CardData.Kind.ABILITY:
		print("Refused: that card cannot be played")
		return false
	if not can_play_card(hand_index):
		var reason := play_reason(hand_index)
		print("Refused: %s" % (reason if reason != "" else "that card cannot be played"))
		return false
	return true


func _ability_block_reason(card: Dictionary) -> String:
	var card_id := str(card["id"])
	if card_id == "grappling_claw":
		if get_claw_targets().is_empty():
			return "No deck next to you"
		return ""
	if card_id == "alien_tracker":
		if _decks_with_cards().is_empty():
			return "No deck to look at"
		return ""
	if card_id == "scrap_hoverboard":
		var far: Array[String] = _reachable(str(current_player()["tile"]), move_paths(current_player()), 2)
		if far.is_empty():
			return "No reachable tiles"
		return ""
	if card_id == "patchwork_glider":
		var near: Array[String] = _reachable(str(current_player()["tile"]), ANY_PATH, 1)
		if near.is_empty():
			return "No reachable tiles"
		return ""
	return _deck_here_reason()


func _resolve_move_ability(hand_index: int, destination: String) -> bool:
	var destinations := ability_destinations(hand_index)
	if destination not in destinations:
		print("Refused: can't reach that tile")
		return false
	var player := current_player()
	var card := _commit_ability(player, hand_index)
	var from_tile: String = player["tile"]
	player["tile"] = destination
	_public("%s played %s (%s → %s)" % [
		player["name"],
		card["name"],
		_tile_name(from_tile),
		_tile_name(destination),
	])
	if destination == START_TILE and from_tile != START_TILE:
		refresh_market_offer(player)
	_maybe_map(player, destination)
	state_changed.emit()
	return true


func _resolve_claw(hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	if not _hand_has(hand_index) or str(current_player()["hand"][hand_index]) != "grappling_claw":
		print("Refused: no card there")
		return false
	if tile_id not in get_claw_targets():
		print("Refused: no deck there")
		return false
	var player := current_player()
	var drawn := _pull(decks[tile_id], from_bottom)
	_commit_ability(player, hand_index)
	_add_to_hand(player, drawn)
	found_card_ids.append(drawn)
	_public("%s played Grappling Claw (from %s)" % [player["name"], _tile_name(tile_id)])
	_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	state_changed.emit()
	return true


func _resolve_search_ability(hand_index: int, card_id: String, from_bottom: bool, tile_id: String) -> bool:
	if not _hand_has(hand_index) or str(current_player()["hand"][hand_index]) != card_id:
		print("Refused: no card there")
		return false
	if deck_count(tile_id) <= 0:
		print("Refused: %s" % _deck_here_reason())
		return false
	var player := current_player()
	if card_id == "fishing_net":
		return _fishing_net(player, hand_index, tile_id)
	if card_id == "ancient_trowel":
		return _ancient_trowel(player, hand_index, tile_id, from_bottom)
	if card_id == "cargo_manifest":
		return _cargo_manifest(player, hand_index, tile_id, from_bottom)
	print("Refused: that card cannot be played")
	return false


func _perform_base_search(from_bottom: bool) -> bool:
	var player := current_player()
	var tile_id := str(player["tile"])
	if deck_count(tile_id) <= 0:
		print("Refused: %s" % _deck_here_reason())
		return false
	var drawn := _pull(decks[tile_id], from_bottom)
	actions_left -= 1
	_add_to_hand(player, drawn)
	found_card_ids.append(drawn)
	_public("%s searched %s" % [player["name"], _tile_name(tile_id)])
	_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	state_changed.emit()
	return true


func _fishing_net(player: Dictionary, hand_index: int, tile_id: String) -> bool:
	var deck: Array = decks[tile_id]
	var drawn: Array[String] = []
	var pulls: int = mini(2, deck.size())
	for _i in pulls:
		drawn.append(_pull(deck, true))
	_commit_ability(player, hand_index)
	for card_id in drawn:
		_add_to_hand(player, card_id)
		found_card_ids.append(card_id)
		_secret("%s drew: %s" % [player["name"], CardData.get_card(card_id)["name"]])
	_public("%s played Fishing Net" % player["name"])
	state_changed.emit()
	return true


func _ancient_trowel(player: Dictionary, hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	var deck: Array = decks[tile_id]
	var drawn: Array[String] = []
	var pulls: int = mini(2, deck.size())
	for _i in pulls:
		drawn.append(_pull(deck, from_bottom))
	var revealed_first := false
	for i in pulls:
		if CardData.is_resource(drawn[i]):
			revealed_first = true
	if revealed_first and not deck.is_empty():
		drawn.append(_pull(deck, from_bottom))
	_commit_ability(player, hand_index)
	for i in drawn.size():
		var card_id: String = drawn[i]
		_add_to_hand(player, card_id)
		found_card_ids.append(card_id)
		if i < pulls and CardData.is_resource(card_id):
			_public("%s revealed %s (Ancient Trowel)" % [player["name"], CardData.get_card(card_id)["name"]])
		else:
			_secret("%s drew: %s" % [player["name"], CardData.get_card(card_id)["name"]])
	_public("%s played Ancient Trowel" % player["name"])
	state_changed.emit()
	return true


func _cargo_manifest(player: Dictionary, hand_index: int, tile_id: String, from_bottom: bool) -> bool:
	var deck: Array = decks[tile_id]
	var drawn := _pull(deck, from_bottom)
	_commit_ability(player, hand_index)
	_add_to_hand(player, drawn)
	found_card_ids.append(drawn)
	_public("%s played Cargo Manifest" % player["name"])
	_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	var shown := _next_pair(deck, from_bottom)
	state_changed.emit()
	if shown.is_empty():
		return true
	var buttons: Array[String] = []
	if shown.size() > 1:
		buttons.append("Swap order")
	buttons.append("Done")
	_open_prompt({
		"kind": "reorder",
		"title": "Cargo Manifest",
		"message": "The next cards of the %s deck. Put them back in any order." % _tile_name(tile_id),
		"cards": shown,
		"clickable": false,
		"buttons": buttons,
		"tile_id": tile_id,
		"from_bottom": from_bottom,
	})
	return true


func _finish_gear_use(slot: int, from_bottom: bool) -> bool:
	var player := current_player()
	var gear: Array = player["gear"]
	if slot < 0 or slot >= gear.size():
		print("Refused: no gear there")
		return false
	var card_id := str(gear[slot])
	if card_id != "metal_detector":
		print("Refused: that gear cannot be used")
		return false
	if deck_count(str(player["tile"])) <= 0:
		print("Refused: %s" % _deck_here_reason())
		return false
	var used: Array = player["gear_used_this_turn"]
	if card_id not in used:
		used.append(card_id)
	actions_left -= 1
	_public("%s used Metal Detector" % player["name"])
	var tile_id := str(player["tile"])
	var deck: Array = decks[tile_id]
	if deck.size() < 2:
		var drawn := _pull(deck, from_bottom)
		_add_to_hand(player, drawn)
		found_card_ids.append(drawn)
		_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
		state_changed.emit()
		return true
	var shown: Array[String] = []
	if from_bottom:
		shown.append(str(deck[deck.size() - 1]))
		shown.append(str(deck[deck.size() - 2]))
	else:
		shown.append(str(deck[0]))
		shown.append(str(deck[1]))
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


func _ask_tracker(hand_index: int) -> bool:
	var buttons: Array[String] = []
	var tile_for: Dictionary = {}
	for tile_id in _decks_with_cards():
		var deck_label := _tile_name(tile_id)
		buttons.append(deck_label)
		tile_for[deck_label] = tile_id
	if buttons.is_empty():
		print("Refused: No deck to look at")
		return false
	_open_prompt({
		"kind": "tracker_pick",
		"title": "Alien Tracker",
		"message": "Look at the top 3 cards of which deck?",
		"cards": [],
		"clickable": false,
		"buttons": buttons,
		"tile_for": tile_for,
		"hand_index": hand_index,
	})
	return true


func _resolve_tracker(label: String) -> void:
	var tile_for: Dictionary = prompt["tile_for"]
	var hand_index := int(prompt["hand_index"])
	if not tile_for.has(label):
		_close_prompt()
		return
	var tile_id := str(tile_for[label])
	_close_prompt()
	if not _hand_has(hand_index) or str(current_player()["hand"][hand_index]) != "alien_tracker":
		print("Refused: no card there")
		return
	if deck_count(tile_id) <= 0:
		print("Refused: This deck is empty")
		return
	var player := current_player()
	var deck: Array = decks[tile_id]
	var shown: Array[String] = []
	var count: int = mini(3, deck.size())
	var saw_alien := false
	for i in count:
		var seen_id := str(deck[i])
		shown.append(seen_id)
		if CardData.is_alien(seen_id):
			saw_alien = true
	_commit_ability(player, hand_index)
	_public("%s played Alien Tracker" % player["name"])
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


func _resolve_lure(label: String) -> void:
	if label != "Top" and label != "Bottom":
		return
	var mode := str(prompt["mode"])
	var hand_index := int(prompt["hand_index"])
	var card_id := str(prompt["card_id"])
	var tile_id := str(prompt["tile_id"])
	var slot := int(prompt["slot"])
	var from_bottom := label == "Bottom"
	if from_bottom:
		current_player()["lure_used_this_turn"] = true
	_close_prompt()
	if mode == "base":
		_perform_base_search(from_bottom)
	elif mode == "gear":
		_finish_gear_use(slot, from_bottom)
	elif card_id == "grappling_claw":
		_resolve_claw(hand_index, tile_id, from_bottom)
	else:
		_resolve_search_ability(hand_index, card_id, from_bottom, tile_id)


func _ask_lure(mode: String, hand_index: int, card_id: String, tile_id: String, slot: int) -> void:
	_open_prompt({
		"kind": "lure",
		"title": "Lucky Lure",
		"message": "Lucky Lure: draw from the Top or the Bottom?",
		"cards": [],
		"clickable": false,
		"buttons": ["Top", "Bottom"],
		"mode": mode,
		"hand_index": hand_index,
		"card_id": card_id,
		"tile_id": tile_id,
		"slot": slot,
	})


func _lure_applies() -> bool:
	var player := current_player()
	if bool(player["lure_used_this_turn"]):
		return false
	return _wearing(player, "lucky_lure")


func _move_to(player: Dictionary, destination: String) -> void:
	var from_tile: String = player["tile"]
	player["tile"] = destination
	_public("%s moved %s → %s" % [player["name"], _tile_name(from_tile), _tile_name(destination)])
	if destination == START_TILE and from_tile != START_TILE:
		refresh_market_offer(player)
	_maybe_map(player, destination)


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


func _maybe_notebook(player: Dictionary) -> bool:
	if not _wearing(player, "scholars_notebook"):
		return false
	var tile_id := str(player["tile"])
	if deck_count(tile_id) <= 0:
		return false
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
		"from_bottom": false,
	})
	return true


func _swap_visible_pair() -> void:
	var tile_id := str(prompt["tile_id"])
	var from_bottom: bool = bool(prompt.get("from_bottom", false))
	var deck: Array = decks[tile_id]
	if deck.size() < 2:
		return
	if from_bottom:
		var last := deck.size() - 1
		var swap_a: String = deck[last]
		deck[last] = deck[last - 1]
		deck[last - 1] = swap_a
		prompt["cards"] = [str(deck[last]), str(deck[last - 1])]
	else:
		var swap_top: String = deck[0]
		deck[0] = deck[1]
		deck[1] = swap_top
		prompt["cards"] = [str(deck[0]), str(deck[1])]
	var shown: Array = prompt["cards"]
	_secret("%s reordered the %s deck: %s" % [current_player()["name"], _tile_name(tile_id), _name_list(shown)])
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


func _commit_ability(player: Dictionary, hand_index: int) -> Dictionary:
	var card := CardData.get_card(str(player["hand"][hand_index]))
	_discard_from_hand(player, hand_index)
	actions_left -= 1
	return card


func _discard_from_hand(player: Dictionary, hand_index: int) -> String:
	var card_id := _take_from_hand(player, hand_index)
	discard.append(card_id)
	return card_id


func _next_pair(deck: Array, from_bottom: bool) -> Array[String]:
	var shown: Array[String] = []
	if deck.is_empty():
		return shown
	if from_bottom:
		shown.append(str(deck[deck.size() - 1]))
		if deck.size() > 1:
			shown.append(str(deck[deck.size() - 2]))
	else:
		shown.append(str(deck[0]))
		if deck.size() > 1:
			shown.append(str(deck[1]))
	return shown


func _decks_with_cards() -> Array[String]:
	var found: Array[String] = []
	for tile_id in SEARCH_TILES:
		if deck_count(tile_id) > 0:
			found.append(tile_id)
	return found


func _deck_here_reason() -> String:
	var tile_id := str(current_player()["tile"])
	if not decks.has(tile_id):
		return "No deck here"
	var deck: Array = decks[tile_id]
	if deck.is_empty():
		return "This deck is empty"
	return ""


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


func _turn_block() -> String:
	if game_over:
		return "The game is over"
	if _is_busy():
		return "Finish the current choice first"
	if actions_left <= 0:
		return "No actions left"
	return ""


func _blank_checklist() -> Dictionary:
	var checks := {}
	for alien_id in CardData.all_alien_ids():
		checks[alien_id] = false
	return checks


func _deal_aliens() -> void:
	var ids: Array[String] = CardData.all_alien_ids()
	ids.shuffle()
	missing_alien = ids.pop_back()
	_secret("Missing alien: %s" % str(CardData.get_card(missing_alien)["name"]))
	var order: Array[String] = []
	for tile_id in SEARCH_TILES:
		order.append(tile_id)
	var start := randi() % order.size()
	for i in ids.size():
		var tile_id: String = order[(start + i) % order.size()]
		var deck: Array = decks[tile_id]
		deck.append(ids[i])
	for tile_id in SEARCH_TILES:
		var deck: Array = decks[tile_id]
		deck.shuffle()


func _give_debug_aliens() -> void:
	if DEBUG_START_ALIENS <= 0:
		return
	for player in players:
		var who: Dictionary = player
		var given := 0
		while given < DEBUG_START_ALIENS and not game_over:
			var card_id := _pull_random_alien()
			if card_id == "":
				return
			_add_to_hand(who, card_id)
			given += 1


func _pull_random_alien() -> String:
	var located: Array[String] = []
	for tile_id in SEARCH_TILES:
		var deck: Array = decks[tile_id]
		for i in deck.size():
			if CardData.is_alien(str(deck[i])):
				located.append("%s:%d" % [tile_id, i])
	if located.is_empty():
		return ""
	var pick := located[randi() % located.size()]
	var split_at := pick.rfind(":")
	var tile_id := pick.substr(0, split_at)
	var index := int(pick.substr(split_at + 1))
	var deck: Array = decks[tile_id]
	var card_id := str(deck[index])
	deck.remove_at(index)
	return card_id


func _collect_crystal_pool() -> bool:
	if crystal_pool <= 0:
		print("Refused: The pool is empty")
		return false
	var player := current_player()
	var taken := crystal_pool
	player["purple"] = int(player["purple"]) + taken
	crystal_pool = 0
	actions_left -= 1
	_public("%s collected %d purple at Crystal mount" % [player["name"], taken])
	state_changed.emit()
	return true


func _check_win() -> void:
	if game_over:
		return
	for player in players:
		var who: Dictionary = player
		if alien_count(who) >= ALIENS_TO_WIN:
			game_over = true
			winner_index = int(who["index"])
			_public("%s wins" % str(who["name"]))
			game_won.emit(winner_index)
			return


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


func _pull(deck: Array, from_bottom: bool) -> String:
	if from_bottom:
		return str(deck.pop_back())
	return str(deck.pop_front())


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


func _take_from_hand(player: Dictionary, hand_index: int) -> String:
	var hand: Array = player["hand"]
	var card_id: String = hand[hand_index]
	hand.remove_at(hand_index)
	return card_id


func _add_to_hand(player: Dictionary, card_id: String) -> void:
	player["hand"].append(card_id)
	if card_id == "skrim":
		_public("%s has Skrim" % str(player["name"]))
		skrim_announced.emit(str(player["name"]))
	_check_win()


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
