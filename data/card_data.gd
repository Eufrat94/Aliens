class_name CardData
extends RefCounted

enum Kind { ACTION, GEAR, RESOURCE }
enum ActionType { MOVE, SEARCH, INTERACT, FIGHT }

const SOON_TEXT := "Effect coming soon — works like a basic card for now."

const CARDS := {
	"walk": {
		"id": "walk",
		"name": "Walk",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal path.",
		"move_paths": [BoardData.PathType.NORMAL],
	},
	"rummage": {
		"id": "rummage",
		"name": "Rummage",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the deck here.",
	},
	"talk": {
		"id": "talk",
		"name": "Talk",
		"kind": Kind.ACTION,
		"action": ActionType.INTERACT,
		"text": "Use one action at this location (e.g. the market).",
	},
	"brawl": {
		"id": "brawl",
		"name": "Brawl",
		"kind": Kind.ACTION,
		"action": ActionType.FIGHT,
		"text": "Strength 1. (Not active yet)",
	},
	"metal_detector": {
		"id": "metal_detector",
		"name": "Metal Detector",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 2 cards. Keep 1, put the other on the bottom of the deck.",
	},
	"scrap_hoverboard": {
		"id": "scrap_hoverboard",
		"name": "Scrap Hoverboard",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move up to 2 tiles along normal paths.",
		"move_paths": [BoardData.PathType.NORMAL],
		"move_steps": 2,
	},
	"grappling_claw": {
		"id": "grappling_claw",
		"name": "Grappling Claw",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the deck of a tile next to you, without moving.",
	},
	"junk_radio": {
		"id": "junk_radio",
		"name": "Junk Radio",
		"kind": Kind.GEAR,
		"text": "At the start of your turn, peek at the top card of any one deck.",
	},
	"alien_tracker": {
		"id": "alien_tracker",
		"name": "Alien Tracker",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Look at the top 3 cards of the deck here and return them in the same order. If you saw an alien, gain 1 purple.",
	},
	"obsidian_machete": {
		"id": "obsidian_machete",
		"name": "Obsidian Machete",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal or jungle path.",
		"move_paths": [BoardData.PathType.NORMAL, BoardData.PathType.JUNGLE],
	},
	"ancient_trowel": {
		"id": "ancient_trowel",
		"name": "Ancient Trowel",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card. If it's a resource, reveal it and draw 1 more.",
	},
	"scholars_notebook": {
		"id": "scholars_notebook",
		"name": "Scholar's Notebook",
		"kind": Kind.GEAR,
		"text": "When you Rest, look at the top 2 cards of the deck where you stand and put them back in any order.",
	},
	"map": {
		"id": "map",
		"name": "Map",
		"kind": Kind.GEAR,
		"text": "When you move to a tile with a deck, look at the top card of that deck.",
	},
	"reed_raft": {
		"id": "reed_raft",
		"name": "Reed Raft",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal or river path.",
		"move_paths": [BoardData.PathType.NORMAL, BoardData.PathType.RIVER],
	},
	"fishing_net": {
		"id": "fishing_net",
		"name": "Fishing Net",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the bottom of the deck.",
	},
	"lucky_lure": {
		"id": "lucky_lure",
		"name": "Lucky Lure",
		"kind": Kind.GEAR,
		"text": "Once per turn, when you Search, you may draw from the bottom of the deck instead of the top.",
	},
	"patchwork_glider": {
		"id": "patchwork_glider",
		"name": "Patchwork Glider",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along any path, including plane routes.",
		"move_paths": [BoardData.PathType.NORMAL, BoardData.PathType.JUNGLE, BoardData.PathType.RIVER, BoardData.PathType.PLANE],
	},
	"cargo_manifest": {
		"id": "cargo_manifest",
		"name": "Cargo Manifest",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card, then peek at the next card of this deck.",
	},
	"passenger_club_card": {
		"id": "passenger_club_card",
		"name": "Passenger Club Membership Card",
		"kind": Kind.GEAR,
		"text": "When a player moves away from your tile, you may pay 1 gold to move with them.",
		"soon": true,
	},
	"scrap_metal": {
		"id": "scrap_metal",
		"name": "Scrap Metal",
		"kind": Kind.RESOURCE,
		"text": "Resource. Sell at a market.",
		"sell_value": 1,
	},
	"relic_shard": {
		"id": "relic_shard",
		"name": "Relic Shard",
		"kind": Kind.RESOURCE,
		"text": "Resource. Sell at a market.",
		"sell_value": 2,
	},
	"river_pearl": {
		"id": "river_pearl",
		"name": "River Pearl",
		"kind": Kind.RESOURCE,
		"text": "Resource. Sell at a market.",
		"sell_value": 2,
	},
	"copper_wire": {
		"id": "copper_wire",
		"name": "Copper Wire",
		"kind": Kind.RESOURCE,
		"text": "Resource. Sell at a market.",
		"sell_value": 1,
	},
}

const STARTING_IDS: Array[String] = ["walk", "rummage", "talk", "brawl"]

const ITEM_IDS: Array[String] = [
	"obsidian_machete",
	"reed_raft",
	"patchwork_glider",
	"scrap_hoverboard",
	"metal_detector",
	"grappling_claw",
	"alien_tracker",
	"ancient_trowel",
	"fishing_net",
	"cargo_manifest",
	"junk_radio",
	"scholars_notebook",
	"map",
	"lucky_lure",
	"passenger_club_card",
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


static func item_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(ITEM_IDS)
	return ids


static func market_pool() -> Array[String]:
	return item_ids()


static func is_alien(_card_id: String) -> bool:
	return false
