class_name CardData
extends RefCounted

enum Kind { GEAR, ABILITY, RESOURCE }
enum ActionType { NONE, MOVE, SEARCH, INTERACT, FIGHT }

const SOON_TEXT := "Effect coming soon."

const CARDS := {
	"obsidian_machete": {
		"id": "obsidian_machete",
		"name": "Obsidian Machete",
		"kind": Kind.GEAR,
		"action": ActionType.MOVE,
		"gear_mode": "passive",
		"grants_paths": [BoardData.PathType.JUNGLE],
		"text": "Your Move action can also use jungle paths.",
	},
	"reed_raft": {
		"id": "reed_raft",
		"name": "Reed Raft",
		"kind": Kind.GEAR,
		"action": ActionType.MOVE,
		"gear_mode": "passive",
		"grants_paths": [BoardData.PathType.RIVER],
		"text": "Your Move action can also use river paths.",
	},
	"junk_radio": {
		"id": "junk_radio",
		"name": "Junk Radio",
		"kind": Kind.GEAR,
		"action": ActionType.SEARCH,
		"gear_mode": "passive",
		"text": "At the start of your turn, peek at the top card of any one deck.",
	},
	"map": {
		"id": "map",
		"name": "Map",
		"kind": Kind.GEAR,
		"action": ActionType.MOVE,
		"gear_mode": "passive",
		"text": "When you move onto a tile with a deck, look at its top card.",
	},
	"lucky_lure": {
		"id": "lucky_lure",
		"name": "Lucky Lure",
		"kind": Kind.GEAR,
		"action": ActionType.SEARCH,
		"gear_mode": "passive",
		"text": "Once per turn, when you Search, you may draw from the bottom of the deck instead of the top.",
	},
	"scholars_notebook": {
		"id": "scholars_notebook",
		"name": "Scholar's Notebook",
		"kind": Kind.GEAR,
		"action": ActionType.SEARCH,
		"gear_mode": "passive",
		"text": "At the end of your turn, look at the top 2 cards of the deck where you stand and put them back in any order.",
	},
	"passenger_club_card": {
		"id": "passenger_club_card",
		"name": "Passenger Club Membership Card",
		"kind": Kind.GEAR,
		"action": ActionType.MOVE,
		"gear_mode": "passive",
		"text": "When a player moves away from your tile, you may pay 1 gold to move with them.",
		"soon": true,
	},
	"metal_detector": {
		"id": "metal_detector",
		"name": "Metal Detector",
		"kind": Kind.GEAR,
		"action": ActionType.SEARCH,
		"gear_mode": "active",
		"text": "Use (1 action, once per turn): Draw 2 cards from the deck here. Keep 1, put the other on the bottom of the deck.",
	},
	"scrap_hoverboard": {
		"id": "scrap_hoverboard",
		"name": "Scrap Hoverboard",
		"kind": Kind.ABILITY,
		"action": ActionType.MOVE,
		"text": "Move up to 2 tiles, using any paths your Move action can use.",
	},
	"patchwork_glider": {
		"id": "patchwork_glider",
		"name": "Patchwork Glider",
		"kind": Kind.ABILITY,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along any path, including plane routes.",
	},
	"grappling_claw": {
		"id": "grappling_claw",
		"name": "Grappling Claw",
		"kind": Kind.ABILITY,
		"action": ActionType.SEARCH,
		"text": "Draw the top card of the deck on a grid-adjacent tile, without moving.",
	},
	"ancient_trowel": {
		"id": "ancient_trowel",
		"name": "Ancient Trowel",
		"kind": Kind.ABILITY,
		"action": ActionType.SEARCH,
		"text": "Draw 2 cards from the deck here. If either is a resource, reveal it and draw 1 more (max 1 extra).",
	},
	"fishing_net": {
		"id": "fishing_net",
		"name": "Fishing Net",
		"kind": Kind.ABILITY,
		"action": ActionType.SEARCH,
		"text": "Draw the bottom 2 cards of the deck here.",
	},
	"cargo_manifest": {
		"id": "cargo_manifest",
		"name": "Cargo Manifest",
		"kind": Kind.ABILITY,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the deck here, then look at the next 2 and put them back in any order.",
	},
	"alien_tracker": {
		"id": "alien_tracker",
		"name": "Alien Tracker",
		"kind": Kind.ABILITY,
		"action": ActionType.SEARCH,
		"text": "Look at the top 3 cards of any deck and put them back in the same order. If you saw an alien, gain 1 purple.",
	},
	"scrap_metal": {
		"id": "scrap_metal",
		"name": "Scrap Metal",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Resource. Sell at a market.",
		"sell_value": 1,
	},
	"relic_shard": {
		"id": "relic_shard",
		"name": "Relic Shard",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Resource. Sell at a market.",
		"sell_value": 2,
	},
	"river_pearl": {
		"id": "river_pearl",
		"name": "River Pearl",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Resource. Sell at a market.",
		"sell_value": 2,
	},
	"copper_wire": {
		"id": "copper_wire",
		"name": "Copper Wire",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Resource. Sell at a market.",
		"sell_value": 1,
	},
}

const RESOURCE_IDS: Array[String] = ["scrap_metal", "relic_shard", "river_pearl", "copper_wire"]


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
		_:
			return ""


static func random_starting_hand(count: int = 2) -> Array[String]:
	var hand: Array[String] = []
	for _copy in count:
		hand.append(RESOURCE_IDS[randi() % RESOURCE_IDS.size()])
	return hand


static func market_pool() -> Array[String]:
	var ids: Array[String] = []
	for card_id in CARDS:
		var kind := int(CARDS[card_id]["kind"])
		if kind == Kind.GEAR or kind == Kind.ABILITY:
			ids.append(card_id)
	return ids


static func item_ids() -> Array[String]:
	return market_pool()


static func is_alien(_card_id: String) -> bool:
	return false


static func is_resource(card_id: String) -> bool:
	return int(get_card(card_id)["kind"]) == Kind.RESOURCE
