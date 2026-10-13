class_name CardData
extends RefCounted

enum ActionType { MOVE, SEARCH, INTERACT, FIGHT }

const CARDS := {
	"basic_move": {
		"name": "Basic Move",
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal path.",
		"move_paths": [BoardData.PathType.NORMAL],
	},
	"basic_search": {
		"name": "Basic Search",
		"action": ActionType.SEARCH,
		"text": "Draw 1 card here. (Not active yet)",
	},
	"basic_interact": {
		"name": "Basic Interact",
		"action": ActionType.INTERACT,
		"text": "Use one action at this location. (Not active yet)",
	},
	"basic_fight": {
		"name": "Basic Fight",
		"action": ActionType.FIGHT,
		"text": "Attack with strength 1. (Not active yet)",
	},
}

const STARTING_IDS: Array[String] = [
	"basic_move",
	"basic_search",
	"basic_interact",
	"basic_fight",
]


static func get_card(id: String) -> Dictionary:
	return CARDS[id]


static func action_name(action: ActionType) -> String:
	match action:
		ActionType.MOVE:
			return "Move"
		ActionType.SEARCH:
			return "Search"
		ActionType.INTERACT:
			return "Interact"
		ActionType.FIGHT:
			return "Fight"
	return "Unknown"


static func starting_hand() -> Array[String]:
	var hand: Array[String] = []
	hand.append_array(STARTING_IDS)
	return hand
