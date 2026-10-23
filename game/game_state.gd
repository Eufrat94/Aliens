class_name GameState
extends RefCounted

signal state_changed
signal prompt_opened(prompt: Dictionary)
signal prompt_closed
signal turn_ended
signal skrim_announced(player_name: String)
signal game_won(player_index: int)
signal handoff_screen(title: String, hint: String, color: Color)
signal public_banner(headline: String)

const ACTIONS_PER_TURN := 3
const GEAR_SLOTS := 4
const DEBUG_SHOW_SECRETS := true
const DEBUG_GIVE_ALL_ITEMS := false
const DEBUG_START_ALIENS := 0
const DEBUG_PLAYER_ALIENS: Dictionary = {}
const DEBUG_START_PURPLE := 0
const ALIENS_TO_WIN := 5
const NERFOIL_HAND_LIMIT := 7
const STARTING_GOLD := 5
const STARTING_PURPLE := 1
const STARTING_RESOURCES := 2
const MARKET_OFFER_SIZE := 3
const MARKET_BUY_PRICE := 2
const MARKET_SELL_PRICE := 1
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
var alien_choice: Dictionary = {}
var _handoff: Dictionary = {}
var _incoming: Array = []
var _delivering := false
var _after_gains := ""
var _finish_message := ""
var _follow: Dictionary = {}
var _passenger: Dictionary = {}


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
			"purple": DEBUG_START_PURPLE if DEBUG_START_PURPLE > 0 else STARTING_PURPLE,
			"lure_used_this_turn": false,
			"aliens": [],
			"aliens_used_this_turn": [],
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
	alien_choice = {}
	_handoff = {}
	_incoming = []
	_delivering = false
	_after_gains = ""
	_finish_message = ""
	_follow = {}
	_passenger = {}
	_give_debug_aliens()
	state_changed.emit()


func current_player() -> Dictionary:
	return players[current_index]


func discard_top() -> String:
	if discard.is_empty():
		return ""
	return discard[discard.size() - 1]


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
	if prompt.is_empty():
		return
	var prompt_kind := str(prompt["kind"])
	if prompt_kind != "keep_one":
		_choose_alien_card(prompt_kind, index)
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
	_secret("%s drew: %s" % [player["name"], CardData.get_card(kept)["name"]])
	_secret("%s put back: %s" % [player["name"], CardData.get_card(other)["name"]])
	_close_prompt()
	found_card_ids.append(kept)
	_give_card(player, kept)
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
	elif kind == "alien_player" or kind == "alien_mimix_hand" or kind == "alien_mimix_copy" or kind == "alien_ugg":
		if label == "Cancel":
			cancel_alien_choice()
		else:
			_choose_alien_button(label)
	elif kind == "passenger_choice":
		_choose_passenger(label)
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
	elif kind == "nerfoil_discard" or kind == "handoff_card" or kind == "pucky_discard":
		print("Refused: choose a card")
	elif kind == "alien_player" or kind == "alien_mimix_hand" or kind == "alien_mimix_copy" or kind == "alien_ugg":
		cancel_alien_choice()
	elif kind == "passenger_choice":
		_choose_passenger("Stay")
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
	_add_gold(player, MARKET_SELL_PRICE)
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
	_add_gold(player, -MARKET_BUY_PRICE)
	_give_card(player, card_id)
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
	starting["aliens_used_this_turn"] = []
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
	_leave_for(player, destination, true)
	_public("%s played %s (%s → %s)" % [
		player["name"],
		card["name"],
		_tile_name(from_tile),
		_tile_name(destination),
	])
	_maybe_map(player, destination)
	_queue_passenger(player, from_tile, destination)
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
	_give_card(player, drawn)
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
	_give_card(player, drawn)
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
		_give_card(player, card_id)
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
		_give_card(player, card_id)
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
	_give_card(player, drawn)
	found_card_ids.append(drawn)
	_public("%s played Cargo Manifest" % player["name"])
	_secret("%s drew: %s" % [player["name"], CardData.get_card(drawn)["name"]])
	if _gain_waiting():
		_follow = {"kind": "cargo", "tile_id": tile_id, "from_bottom": from_bottom}
		state_changed.emit()
		return true
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
		_give_card(player, drawn)
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
	_leave_for(player, destination, true)
	_public("%s moved %s → %s" % [player["name"], _tile_name(from_tile), _tile_name(destination)])
	_maybe_map(player, destination)
	_queue_passenger(player, from_tile, destination)


func _leave_for(player: Dictionary, destination: String, own_move: bool) -> void:
	var from_tile := str(player["tile"])
	if from_tile == destination:
		return
	if own_move:
		_charge_muddk(player, from_tile)
	player["tile"] = destination
	if destination == START_TILE and from_tile != START_TILE:
		refresh_market_offer(player)


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
	return not prompt.is_empty() or not market_visit.is_empty() or not alien_choice.is_empty() or not _handoff.is_empty() or _delivering


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
	var reserved := _reserved_aliens()
	var ids: Array[String] = []
	for alien_id in CardData.all_alien_ids():
		if alien_id not in reserved:
			ids.append(alien_id)
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
	_place_debug_aliens()


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
	var kind := str(prompt.get("kind", ""))
	prompt = {}
	prompt_closed.emit()
	if kind == "peek":
		_resume_passenger()


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


func can_use_alien(area_index: int) -> bool:
	if not _area_is_active(area_index):
		return false
	return alien_use_reason(area_index) == ""


func alien_use_reason(area_index: int) -> String:
	if players.is_empty() or not _area_is_active(area_index):
		return ""
	if game_over:
		return "The game is over"
	if _is_busy():
		return "Finish the current choice first"
	if actions_left < 1:
		return "No actions left"
	var alien_id := _area_alien(area_index)
	var used: Array = current_player()["aliens_used_this_turn"]
	if alien_id in used:
		return "Already used this turn"
	if _blocked_by_stopots(current_player()):
		return "Blocked by Stopots"
	var cost := _alien_purple_cost(alien_id)
	if int(current_player()["purple"]) < cost:
		return "Needs %d purple" % cost
	return _alien_target_reason(alien_id)


func alien_use_label(alien_id: String) -> String:
	if alien_id == "mimix":
		return "Use (1 + discard)"
	var cost := _alien_purple_cost(alien_id)
	if cost > 0:
		return "Use (1 + %d purple)" % cost
	return "Use (1)"


func use_alien(area_index: int) -> void:
	if not can_use_alien(area_index):
		var reason := alien_use_reason(area_index)
		print("Refused: %s" % (reason if reason != "" else "that alien cannot be used"))
		return
	var alien_id := _area_alien(area_index)
	alien_choice = {
		"area_index": area_index,
		"alien_id": alien_id,
		"effect_id": alien_id,
		"step": "",
		"mimix_index": -1,
		"target": -1,
		"bonus": [],
	}
	if alien_id == "mimix":
		_prompt_mimix_hand()
		return
	_begin_effect(alien_id)


func can_cancel_alien() -> bool:
	return not alien_choice.is_empty() and prompt.is_empty() and _handoff.is_empty() and not _delivering


func is_alien_pending() -> bool:
	return not alien_choice.is_empty() or not _handoff.is_empty() or _delivering


func cancel_alien_choice() -> void:
	if alien_choice.is_empty() and _handoff.is_empty():
		return
	if not _handoff.is_empty() or _delivering:
		print("Refused: choose a card")
		return
	if not prompt.is_empty():
		var kind := str(prompt["kind"])
		if kind == "nerfoil_discard" or kind == "handoff_card" or kind == "pucky_discard":
			print("Refused: choose a card")
			return
		_close_prompt()
	alien_choice = {}
	state_changed.emit()


func alien_hint() -> String:
	if alien_choice.is_empty():
		return ""
	var step := str(alien_choice.get("step", ""))
	if step == "wingo":
		return "Wingo: choose any other tile (Esc to cancel)"
	if step == "wush_tile":
		return "Wush: choose a tile next to that player (Esc to cancel)"
	return ""


func alien_tile_targets() -> Array[String]:
	var found: Array[String] = []
	if alien_choice.is_empty() or not prompt.is_empty():
		return found
	var step := str(alien_choice.get("step", ""))
	if step == "wingo":
		var here := str(current_player()["tile"])
		for tile_id in BoardData.get_tile_ids():
			if tile_id != here:
				found.append(tile_id)
		return found
	if step == "wush_tile":
		var target: Dictionary = players[int(alien_choice["target"])]
		return BoardData.grid_adjacent(str(target["tile"]))
	return found


func choose_alien_tile(tile_id: String) -> void:
	if tile_id not in alien_tile_targets():
		print("Refused: that tile isn't a choice")
		return
	var step := str(alien_choice.get("step", ""))
	if step == "wingo":
		_resolve_wingo(tile_id)
	elif step == "wush_tile":
		_resolve_wush(tile_id)


func handoff_phase() -> String:
	if _handoff.is_empty():
		return ""
	return str(_handoff.get("phase", ""))


func handoff_screen_dismissed() -> void:
	var phase := handoff_phase()
	if phase == "arrive":
		var actor: Dictionary = players[int(_handoff["actor"])]
		_handoff["phase"] = "choose"
		if str(_handoff.get("purpose", "")) == "passenger":
			_open_prompt({
				"kind": "passenger_choice",
				"title": str(actor["name"]),
				"message": "Follow for 1 gold?",
				"cards": [],
				"clickable": false,
				"buttons": ["Follow", "Stay"],
			})
			return
		_open_prompt({
			"kind": "handoff_card",
			"title": str(actor["name"]),
			"message": str(_handoff["reason"]),
			"cards": _hand_ids(actor),
			"clickable": true,
			"buttons": [],
		})
		return
	if phase == "return":
		_apply_handoff_pick()


func _begin_effect(effect_id: String) -> void:
	alien_choice["effect_id"] = effect_id
	alien_choice["step"] = effect_id
	match effect_id:
		"wingo":
			state_changed.emit()
		"magnet":
			_begin_magnet()
		"disko":
			_resolve_disko()
		"mani":
			_resolve_mani()
		"ugg":
			_prompt_ugg()
		"wush":
			_prompt_players("wush", _other_indexes(), "Wush", "Choose a player to move.")
		"shadow":
			_resolve_shadow()
		"pucky":
			_prompt_players("pucky", _players_with_cards(), "Pucky", "Choose a player to take a card from.")
		"pikupiku":
			var here := _others_here_with_cards()
			if here.size() == 1:
				_resolve_pikupiku(here[0])
			else:
				_prompt_players("pikupiku", here, "Pikupiku", "Choose a player on your tile.")
		"quizazz":
			_prompt_players("quizazz", _other_indexes(), "Quizazz", "Choose a player to ask.")
		"gloop":
			_prompt_players("gloop", _other_indexes(), "Gloop", "Choose a player to swap with.")
		_:
			print("Refused: that alien cannot be used")
			_drop_choice()


func _resolve_wingo(tile_id: String) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var player := current_player()
	var from_tile := str(player["tile"])
	_leave_for(player, tile_id, true)
	_complete_use("%s used %s (%s → %s)" % [player["name"], _effect_label(), _tile_name(from_tile), _tile_name(tile_id)])
	_maybe_map(player, tile_id)
	_queue_passenger(player, from_tile, tile_id)


func _begin_magnet() -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	alien_choice["queue"] = _others_here_with_cards()
	alien_choice["step"] = "magnet"
	_next_magnet()


func _next_magnet() -> void:
	if alien_choice.is_empty() or game_over:
		if not alien_choice.is_empty():
			_complete_use("")
		return
	var queue: Array = alien_choice["queue"]
	if queue.is_empty():
		_complete_use("")
		return
	var next_index := int(queue.pop_front())
	_begin_handoff(next_index, "%s used Magnet: choose a card to give." % str(current_player()["name"]), "magnet")


func _resolve_disko() -> void:
	if discard.is_empty():
		print("Refused: Discard pile is empty")
		_drop_choice()
		return
	if not _pay_for_alien():
		_drop_choice()
		return
	var card_id := str(discard.pop_back())
	_finish_message = "%s took %s (%s)" % [current_player()["name"], CardData.get_card(card_id)["name"], _effect_label()]
	_after_gains = "finish"
	_give_card(current_player(), card_id)


func _resolve_mani() -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	_add_gold(current_player(), 5)
	_complete_use("%s used %s (+5 gold)" % [current_player()["name"], _effect_label()])


func _prompt_ugg() -> void:
	var entries := _aliens_in_areas()
	if entries.is_empty():
		print("Refused: No aliens on the table")
		_drop_choice()
		return
	alien_choice["step"] = "ugg"
	var cards: Array[String] = []
	var captions: Array[String] = []
	var owners: Array[int] = []
	var slots: Array[int] = []
	for entry in entries:
		var info: Dictionary = entry
		cards.append(str(info["id"]))
		captions.append(str(info["owner_name"]))
		owners.append(int(info["owner"]))
		slots.append(int(info["slot"]))
	_open_prompt({
		"kind": "alien_ugg",
		"title": "Ugg",
		"message": "Choose an alien on the table to discard.",
		"cards": cards,
		"captions": captions,
		"clickable": true,
		"buttons": ["Cancel"],
		"owners": owners,
		"slots": slots,
	})


func _accept_ugg(index: int) -> void:
	var owners: Array = prompt["owners"]
	var slots: Array = prompt["slots"]
	var cards: Array = prompt["cards"]
	var owner_index := int(owners[index])
	var slot := int(slots[index])
	var alien_id := str(cards[index])
	_close_prompt()
	if not _pay_for_alien():
		_drop_choice()
		return
	var owner: Dictionary = players[owner_index]
	_remove_area_alien(owner, slot, alien_id)
	discard.append(alien_id)
	_complete_use("%s discarded %s's %s (%s)" % [
		current_player()["name"],
		owner["name"],
		CardData.get_card(alien_id)["name"],
		_effect_label(),
	])


func _resolve_wush(tile_id: String) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var target: Dictionary = players[int(alien_choice["target"])]
	_leave_for(target, tile_id, false)
	_complete_use("%s used %s (%s → %s)" % [
		current_player()["name"],
		_effect_label(),
		target["name"],
		_tile_name(tile_id),
	])


func _resolve_shadow() -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var user := current_player()
	var count := players.size()
	for step in range(1, count):
		var who: Dictionary = players[(current_index + step) % count]
		if int(who["gold"]) <= 0:
			continue
		_add_gold(who, -1)
		_add_gold(user, 1)
		_public("%s gave 1 gold to %s (Shadow)" % [who["name"], user["name"]])
	_complete_use("")


func _resolve_pucky(target_index: int) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var target: Dictionary = players[target_index]
	var hand: Array = target["hand"]
	if hand.is_empty():
		print("Refused: no card there")
		_drop_choice()
		return
	var card_id := _take_from_hand(target, randi() % hand.size())
	_public("%s took a card from %s (%s)" % [current_player()["name"], target["name"], _effect_label()])
	_secret("%s took %s from %s" % [current_player()["name"], CardData.get_card(card_id)["name"], target["name"]])
	_after_gains = "pucky_discard"
	_give_card(current_player(), card_id)


func _prompt_pucky_discard() -> void:
	alien_choice["step"] = "pucky_discard"
	_open_prompt({
		"kind": "pucky_discard",
		"title": "Pucky",
		"message": "Discard 1 card from your hand.",
		"cards": _hand_ids(current_player()),
		"clickable": true,
		"buttons": [],
	})


func _resolve_pikupiku(target_index: int) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var target: Dictionary = players[target_index]
	var cards := _hand_ids(target)
	_secret("%s saw %s's hand: %s" % [current_player()["name"], target["name"], _name_list(cards)])
	_complete_use("%s looked at %s's hand (%s)" % [current_player()["name"], target["name"], _effect_label()])
	_open_prompt({
		"kind": "peek",
		"title": "Pikupiku",
		"message": "%s's hand." % str(target["name"]),
		"cards": cards,
		"clickable": false,
		"buttons": ["Done"],
	})


func _resolve_quizazz(target_index: int) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var target: Dictionary = players[target_index]
	var has_alien := false
	var hand: Array = target["hand"]
	for card_id in hand:
		if CardData.is_alien(str(card_id)):
			has_alien = true
			break
	var answer := "YES" if has_alien else "NO"
	var headline := "%s has an alien in hand: %s" % [target["name"], answer]
	_public(headline)
	public_banner.emit(headline)
	if has_alien:
		current_player()["purple"] = int(current_player()["purple"]) + 1
	else:
		_add_gold(current_player(), 1)
	_complete_use("")


func _prompt_mimix_hand() -> void:
	alien_choice["step"] = "mimix_hand"
	_open_prompt({
		"kind": "alien_mimix_hand",
		"title": "Mimix",
		"message": "Choose a card to discard. You pay it when the copy is confirmed.",
		"cards": _hand_ids(current_player()),
		"clickable": true,
		"buttons": ["Cancel"],
	})


func _accept_mimix_discard(index: int) -> void:
	var hand: Array = current_player()["hand"]
	if index < 0 or index >= hand.size():
		return
	alien_choice["mimix_index"] = index
	_close_prompt()
	var copies := _copyable_aliens()
	if copies.is_empty():
		print("Refused: No active aliens on the table")
		_drop_choice()
		return
	alien_choice["step"] = "mimix_copy"
	var cards: Array[String] = []
	var captions: Array[String] = []
	for entry in copies:
		var info: Dictionary = entry
		cards.append(str(info["id"]))
		captions.append("%s's %s" % [info["owner_name"], CardData.get_card(str(info["id"]))["name"]])
	_open_prompt({
		"kind": "alien_mimix_copy",
		"title": "Mimix",
		"message": "Choose an active alien to copy.",
		"cards": cards,
		"captions": captions,
		"clickable": true,
		"buttons": ["Cancel"],
	})


func _accept_mimix_copy(index: int) -> void:
	var cards: Array = prompt["cards"]
	var effect_id := str(cards[index])
	var cost := _alien_purple_cost(effect_id)
	if int(current_player()["purple"]) < cost:
		print("Refused: Needs %d purple" % cost)
		return
	_close_prompt()
	_begin_effect(effect_id)


func _resolve_gloop(target_index: int) -> void:
	if not _pay_for_alien():
		_drop_choice()
		return
	var user := current_player()
	var target: Dictionary = players[target_index]
	user["purple"] = int(user["purple"]) - 1
	target["purple"] = int(target["purple"]) + 1
	var from_user := str(user["tile"])
	var from_target := str(target["tile"])
	if from_user != from_target:
		_charge_muddk(user, from_user)
		user["tile"] = from_target
		target["tile"] = from_user
		if from_target == START_TILE and from_user != START_TILE:
			refresh_market_offer(user)
		if from_user == START_TILE and from_target != START_TILE:
			refresh_market_offer(target)
	_complete_use("%s used %s (gave 1 purple to %s and swapped tiles)" % [user["name"], _effect_label(), target["name"]])
	if from_user != from_target:
		_maybe_map(user, str(user["tile"]))
		_queue_passenger(user, from_user, str(user["tile"]))


func _choose_alien_card(kind: String, index: int) -> void:
	if prompt.is_empty():
		return
	var cards: Array = prompt["cards"]
	if index < 0 or index >= cards.size():
		return
	if kind == "handoff_card":
		_handoff["card_index"] = index
		_handoff["phase"] = "return"
		_close_prompt()
		var current := current_player()
		handoff_screen.emit(
			"Pass the device back to %s." % str(current["name"]),
			"Click to continue.",
			current["color"]
		)
		return
	if kind == "nerfoil_discard":
		var discarding := current_player()
		_close_prompt()
		_discard_from_hand(discarding, index)
		_public("%s discarded a card (Nerfoil)" % str(discarding["name"]))
		_delivering = false
		state_changed.emit()
		_pump_incoming()
		return
	if kind == "pucky_discard":
		var discarding := current_player()
		_close_prompt()
		_discard_from_hand(discarding, index)
		_public("%s discarded a card (Pucky)" % str(discarding["name"]))
		_complete_use("")
		return
	if kind == "alien_mimix_hand":
		_accept_mimix_discard(index)
		return
	if kind == "alien_mimix_copy":
		_accept_mimix_copy(index)
		return
	if kind == "alien_ugg":
		_accept_ugg(index)


func _choose_alien_button(label: String) -> void:
	if prompt.is_empty():
		return
	var player_for: Dictionary = prompt["player_for"]
	if not player_for.has(label):
		return
	var target_index := int(player_for[label])
	var step := str(alien_choice.get("step", ""))
	_close_prompt()
	match step:
		"wush":
			alien_choice["target"] = target_index
			alien_choice["step"] = "wush_tile"
			state_changed.emit()
		"pucky":
			_resolve_pucky(target_index)
		"pikupiku":
			_resolve_pikupiku(target_index)
		"quizazz":
			_resolve_quizazz(target_index)
		"gloop":
			_resolve_gloop(target_index)
		_:
			_drop_choice()


func _pay_for_alien() -> bool:
	var effect_id := str(alien_choice["effect_id"])
	var user := current_player()
	var cost := _alien_purple_cost(effect_id)
	if int(user["purple"]) < cost:
		print("Refused: Needs %d purple" % cost)
		return false
	var discard_index := -1
	if str(alien_choice["alien_id"]) == "mimix":
		discard_index = int(alien_choice.get("mimix_index", -1))
		var hand: Array = user["hand"]
		if discard_index < 0 or discard_index >= hand.size():
			print("Refused: Need a card to discard")
			return false
	if discard_index >= 0:
		_discard_from_hand(user, discard_index)
		_public("%s discarded a card (Mimix)" % str(user["name"]))
	if effect_id != "gloop":
		user["purple"] = int(user["purple"]) - cost
	actions_left -= 1
	var used: Array = user["aliens_used_this_turn"]
	var marker := str(alien_choice["alien_id"])
	if marker not in used:
		used.append(marker)
	var bonus: Array[int] = []
	var tile := str(user["tile"])
	for player in players:
		var who: Dictionary = player
		if int(who["index"]) == int(user["index"]):
			continue
		if str(who["tile"]) == tile:
			bonus.append(int(who["index"]))
	alien_choice["bonus"] = bonus
	return true


func _complete_use(message: String) -> void:
	if message != "":
		_public(message)
	_grant_purple_bonus()
	alien_choice = {}
	state_changed.emit()


func _grant_purple_bonus() -> void:
	if alien_choice.is_empty():
		return
	var ids: Array = alien_choice.get("bonus", [])
	if ids.is_empty():
		return
	var names: PackedStringArray = PackedStringArray()
	for entry in ids:
		var who: Dictionary = players[int(entry)]
		who["purple"] = int(who["purple"]) + 1
		names.append(str(who["name"]))
	var alien_name := str(CardData.get_card(str(alien_choice["alien_id"]))["name"])
	_public("%s gained 1 purple (%s)" % [", ".join(names), alien_name])


func _drop_choice() -> void:
	alien_choice = {}
	state_changed.emit()


func _effect_label() -> String:
	var alien_id := str(alien_choice["alien_id"])
	var effect_id := str(alien_choice["effect_id"])
	if alien_id == "mimix" and effect_id != alien_id:
		return "Mimix as %s" % str(CardData.get_card(effect_id)["name"])
	return str(CardData.get_card(effect_id)["name"])


func _prompt_players(step: String, indexes: Array[int], title: String, message: String) -> void:
	if indexes.is_empty():
		print("Refused: No other player")
		_drop_choice()
		return
	alien_choice["step"] = step
	var buttons: Array[String] = []
	var player_for := {}
	for idx in indexes:
		var who: Dictionary = players[idx]
		var player_name := str(who["name"])
		buttons.append(player_name)
		player_for[player_name] = idx
	buttons.append("Cancel")
	_open_prompt({
		"kind": "alien_player",
		"title": title,
		"message": message,
		"cards": [],
		"clickable": false,
		"buttons": buttons,
		"player_for": player_for,
	})


func _queue_passenger(mover: Dictionary, from_tile: String, destination: String) -> void:
	if from_tile == destination or game_over or not _passenger.is_empty():
		return
	var queue: Array = _passenger_candidates(from_tile, int(mover["index"]))
	if queue.is_empty():
		return
	_passenger = {
		"queue": queue,
		"destination": destination,
		"from_tile": from_tile,
		"mover_name": str(mover["name"]),
		"waiting": not prompt.is_empty(),
	}
	if prompt.is_empty():
		_next_passenger()


func _passenger_candidates(from_tile: String, mover_index: int) -> Array:
	var found: Array = []
	var count := players.size()
	for step in range(1, count):
		var who: Dictionary = players[(current_index + step) % count]
		if int(who["index"]) == mover_index:
			continue
		if str(who["tile"]) != from_tile:
			continue
		if not _wearing(who, "passenger_club_card"):
			continue
		if int(who["gold"]) < 1:
			continue
		found.append(int(who["index"]))
	return found


func _resume_passenger() -> void:
	if _passenger.is_empty() or not bool(_passenger.get("waiting", false)):
		return
	_passenger["waiting"] = false
	_next_passenger()


func _next_passenger() -> void:
	if _passenger.is_empty():
		return
	if game_over:
		_passenger = {}
		return
	var queue: Array = _passenger["queue"]
	while not queue.is_empty():
		var idx: int = int(queue.pop_front())
		var who: Dictionary = players[idx]
		if str(who["tile"]) != str(_passenger["from_tile"]):
			continue
		if not _wearing(who, "passenger_club_card") or int(who["gold"]) < 1:
			continue
		_ask_passenger(who)
		return
	_passenger = {}


func _ask_passenger(who: Dictionary) -> void:
	var mover_name := str(_passenger["mover_name"])
	var destination := str(_passenger["destination"])
	var reason := "%s is leaving %s for %s." % [
		mover_name,
		_tile_name(str(_passenger["from_tile"])),
		_tile_name(destination),
	]
	_handoff = {
		"actor": int(who["index"]),
		"reason": reason,
		"purpose": "passenger",
		"phase": "arrive",
		"card_index": -1,
		"follow": false,
		"destination": destination,
		"mover_name": mover_name,
	}
	handoff_screen.emit("%s, take the device." % str(who["name"]), reason, who["color"])


func _choose_passenger(label: String) -> void:
	if _handoff.is_empty() or (label != "Follow" and label != "Stay"):
		return
	_handoff["follow"] = label == "Follow"
	_handoff["phase"] = "return"
	_close_prompt()
	var current := current_player()
	handoff_screen.emit(
		"Pass the device back to %s." % str(current["name"]),
		"Click to continue.",
		current["color"]
	)


func _finish_passenger_choice() -> void:
	var actor_index: int = int(_handoff["actor"])
	var follow := bool(_handoff["follow"])
	var destination := str(_handoff["destination"])
	var mover_name := str(_handoff["mover_name"])
	_handoff = {}
	var actor: Dictionary = players[actor_index]
	if follow and int(actor["gold"]) >= 1 and str(actor["tile"]) != destination:
		_add_gold(actor, -1)
		_leave_for(actor, destination, true)
		_public("%s followed %s to %s (Passenger Club, -1 gold)" % [
			actor["name"],
			mover_name,
			_tile_name(destination),
		])
	_next_passenger()
	state_changed.emit()


func _begin_handoff(actor_index: int, reason: String, purpose: String) -> void:
	var actor: Dictionary = players[actor_index]
	_handoff = {
		"actor": actor_index,
		"reason": reason,
		"purpose": purpose,
		"phase": "arrive",
		"card_index": -1,
	}
	handoff_screen.emit("%s, take the device." % str(actor["name"]), reason, actor["color"])


func _apply_handoff_pick() -> void:
	if str(_handoff.get("purpose", "")) == "passenger":
		_finish_passenger_choice()
		return
	var actor_index := int(_handoff["actor"])
	var card_index := int(_handoff["card_index"])
	var purpose := str(_handoff["purpose"])
	_handoff = {}
	var actor: Dictionary = players[actor_index]
	var hand: Array = actor["hand"]
	if card_index < 0 or card_index >= hand.size():
		print("Refused: no card there")
		return
	if purpose == "nerfoil":
		_discard_from_hand(actor, card_index)
		_public("%s discarded a card (Nerfoil)" % str(actor["name"]))
		_delivering = false
		state_changed.emit()
		_pump_incoming()
		return
	var card_id := _take_from_hand(actor, card_index)
	_public("%s gave a card to %s (Magnet)" % [actor["name"], current_player()["name"]])
	_secret("%s gave %s to %s" % [actor["name"], CardData.get_card(card_id)["name"], current_player()["name"]])
	_after_gains = "magnet_next"
	_give_card(current_player(), card_id)


func _give_card(player: Dictionary, card_id: String) -> void:
	_incoming.append({"index": int(player["index"]), "card_id": card_id})
	_pump_incoming()


func _gain_waiting() -> bool:
	return _delivering or not _incoming.is_empty()


func _pump_incoming() -> void:
	if _delivering:
		return
	var added := false
	while not _incoming.is_empty():
		if game_over:
			_flush_incoming()
			return
		var next: Dictionary = _incoming[0]
		var player: Dictionary = players[int(next["index"])]
		var hand: Array = player["hand"]
		if _nerfoil_applies(player) and hand.size() >= NERFOIL_HAND_LIMIT:
			_delivering = true
			_ask_nerfoil(player)
			return
		_incoming.pop_front()
		_add_to_hand(player, str(next["card_id"]))
		added = true
		if game_over:
			_flush_incoming()
			return
	if added and _after_gains == "" and _follow.is_empty():
		state_changed.emit()
	_run_after_gains()


func _flush_incoming() -> void:
	while not _incoming.is_empty():
		var next: Dictionary = _incoming.pop_front()
		var player: Dictionary = players[int(next["index"])]
		_add_to_hand(player, str(next["card_id"]))
	_delivering = false
	_after_gains = ""
	_finish_message = ""
	_follow = {}
	alien_choice = {}
	state_changed.emit()


func _ask_nerfoil(player: Dictionary) -> void:
	if int(player["index"]) == current_index:
		_open_prompt({
			"kind": "nerfoil_discard",
			"title": "Nerfoil",
			"message": "Your hand is at 7 cards. Discard 1, then you gain a card.",
			"cards": _hand_ids(player),
			"clickable": true,
			"buttons": [],
		})
		return
	_begin_handoff(int(player["index"]), "%s must discard a card (Nerfoil)." % str(player["name"]), "nerfoil")


func _run_after_gains() -> void:
	if _delivering or not _incoming.is_empty():
		return
	if game_over:
		_after_gains = ""
		_finish_message = ""
		_follow = {}
		alien_choice = {}
		state_changed.emit()
		return
	var follow: Dictionary = _follow.duplicate()
	var after := _after_gains
	var message := _finish_message
	_follow = {}
	_after_gains = ""
	_finish_message = ""
	if str(follow.get("kind", "")) == "cargo":
		_open_cargo_reorder(str(follow["tile_id"]), bool(follow["from_bottom"]))
	if after == "magnet_next":
		_next_magnet()
	elif after == "pucky_discard":
		_prompt_pucky_discard()
	elif after == "finish":
		_complete_use(message)


func _open_cargo_reorder(tile_id: String, from_bottom: bool) -> void:
	var deck: Array = decks[tile_id]
	var shown := _next_pair(deck, from_bottom)
	if shown.is_empty():
		state_changed.emit()
		return
	var buttons: Array[String] = []
	if shown.size() > 1:
		buttons.append("Swap order")
	buttons.append("Done")
	state_changed.emit()
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


func _add_gold(player: Dictionary, amount: int) -> void:
	player["gold"] = int(player["gold"]) + amount
	_shadow_check(player)


func _shadow_check(player: Dictionary) -> void:
	if int(player["gold"]) < 9:
		return
	if not _remove_area_alien(player, -1, "shadow"):
		return
	discard.append("shadow")
	_public("%s's Shadow left (9+ gold)" % str(player["name"]))


func _charge_muddk(mover: Dictionary, from_tile: String) -> void:
	var count := players.size()
	var start := int(mover["index"])
	for step in range(1, count):
		var who: Dictionary = players[(start + step) % count]
		if str(who["tile"]) != from_tile or not _area_has(who, "muddk"):
			continue
		if int(mover["gold"]) <= 0:
			return
		_add_gold(mover, -1)
		_add_gold(who, 1)
		_public("%s paid 1 gold to %s (Muddk)" % [mover["name"], who["name"]])


func _nerfoil_applies(player: Dictionary) -> bool:
	for other in players:
		var who: Dictionary = other
		if int(who["index"]) == int(player["index"]):
			continue
		if _area_has(who, "nerfoil"):
			return true
	return false


func _blocked_by_stopots(user: Dictionary) -> bool:
	var tile := str(user["tile"])
	for other in players:
		var who: Dictionary = other
		if int(who["index"]) == int(user["index"]):
			continue
		if str(who["tile"]) == tile and _area_has(who, "stopots"):
			return true
	return false


func _alien_purple_cost(alien_id: String) -> int:
	match alien_id:
		"wingo", "mani", "pikupiku", "gloop":
			return 1
		"ugg":
			return 3
		_:
			return 0


func _alien_target_reason(alien_id: String) -> String:
	match alien_id:
		"magnet":
			if _others_on_tile().is_empty():
				return "No other player here"
			if _others_here_with_cards().is_empty():
				return "Nobody here has a card"
		"disko":
			if discard.is_empty():
				return "Discard pile is empty"
		"ugg":
			if _aliens_in_areas().is_empty():
				return "No aliens on the table"
		"wush", "quizazz", "gloop":
			if _other_indexes().is_empty():
				return "No other player"
		"shadow":
			if not _other_has_gold():
				return "No other player has gold"
		"pucky":
			if _players_with_cards().is_empty():
				return "No other player has a card"
		"pikupiku":
			if _others_on_tile().is_empty():
				return "No other player here"
			if _others_here_with_cards().is_empty():
				return "Nobody here has a card"
		"mimix":
			var mimix_hand: Array = current_player()["hand"]
			if mimix_hand.is_empty():
				return "Need a card to discard"
			if _copyable_aliens().is_empty():
				return "No active aliens on the table"
	return ""


func _other_indexes() -> Array[int]:
	var found: Array[int] = []
	var count := players.size()
	for step in range(1, count):
		var who: Dictionary = players[(current_index + step) % count]
		found.append(int(who["index"]))
	return found


func _others_on_tile() -> Array[int]:
	var found: Array[int] = []
	var tile := str(current_player()["tile"])
	for idx in _other_indexes():
		var who: Dictionary = players[idx]
		if str(who["tile"]) == tile:
			found.append(idx)
	return found


func _others_here_with_cards() -> Array[int]:
	var found: Array[int] = []
	for idx in _others_on_tile():
		var hand: Array = players[idx]["hand"]
		if not hand.is_empty():
			found.append(idx)
	return found


func _players_with_cards() -> Array[int]:
	var found: Array[int] = []
	for idx in _other_indexes():
		var hand: Array = players[idx]["hand"]
		if not hand.is_empty():
			found.append(idx)
	return found


func _other_has_gold() -> bool:
	for idx in _other_indexes():
		if int(players[idx]["gold"]) > 0:
			return true
	return false


func _aliens_in_areas() -> Array:
	var found: Array = []
	for player in players:
		var who: Dictionary = player
		var aliens: Array = who["aliens"]
		for slot in aliens.size():
			found.append({
				"id": str(aliens[slot]),
				"owner": int(who["index"]),
				"owner_name": str(who["name"]),
				"slot": slot,
			})
	return found


func _copyable_aliens() -> Array:
	var found: Array = []
	for entry in _aliens_in_areas():
		var info: Dictionary = entry
		var alien_id := str(info["id"])
		if alien_id == "mimix":
			continue
		if str(CardData.get_card(alien_id).get("alien_mode", "")) != "active":
			continue
		found.append(info)
	return found


func _area_is_active(area_index: int) -> bool:
	var alien_id := _area_alien(area_index)
	if alien_id == "":
		return false
	return str(CardData.get_card(alien_id).get("alien_mode", "")) == "active"


func _area_alien(area_index: int) -> String:
	if players.is_empty():
		return ""
	var aliens: Array = current_player()["aliens"]
	if area_index < 0 or area_index >= aliens.size():
		return ""
	return str(aliens[area_index])


func _area_has(player: Dictionary, alien_id: String) -> bool:
	var aliens: Array = player["aliens"]
	return alien_id in aliens


func _remove_area_alien(player: Dictionary, slot: int, alien_id: String) -> bool:
	var aliens: Array = player["aliens"]
	if slot >= 0 and slot < aliens.size() and str(aliens[slot]) == alien_id:
		aliens.remove_at(slot)
		return true
	for i in aliens.size():
		if str(aliens[i]) == alien_id:
			aliens.remove_at(i)
			return true
	return false


func _hand_ids(player: Dictionary) -> Array[String]:
	var cards: Array[String] = []
	var hand: Array = player["hand"]
	for card_id in hand:
		cards.append(str(card_id))
	return cards


func _reserved_aliens() -> Array[String]:
	var reserved: Array[String] = []
	for key in DEBUG_PLAYER_ALIENS.keys():
		var index := int(key)
		if index < 0 or index >= players.size():
			continue
		var list: Array = DEBUG_PLAYER_ALIENS[key]
		for alien_id in list:
			var id := str(alien_id)
			if CardData.is_alien(id) and id not in reserved:
				reserved.append(id)
	return reserved


func _place_debug_aliens() -> void:
	for key in DEBUG_PLAYER_ALIENS.keys():
		var index := int(key)
		if index < 0 or index >= players.size():
			continue
		var who: Dictionary = players[index]
		var aliens: Array = who["aliens"]
		var list: Array = DEBUG_PLAYER_ALIENS[key]
		for alien_id in list:
			var id := str(alien_id)
			if CardData.is_alien(id):
				aliens.append(id)
	_check_win()
