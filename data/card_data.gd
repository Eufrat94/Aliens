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
		"text": "Use one action at this location. (Not active yet)",
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
		"soon": true,
	},
	"scrap_hoverboard": {
		"id": "scrap_hoverboard",
		"name": "Scrap Hoverboard",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move up to 2 tiles along normal paths.",
		"move_paths": [BoardData.PathType.NORMAL],
		"soon": true,
	},
	"grappling_claw": {
		"id": "grappling_claw",
		"name": "Grappling Claw",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the deck of a tile next to you, without moving.",
		"soon": true,
	},
	"junk_radio": {
		"id": "junk_radio",
		"name": "Junk Radio",
		"kind": Kind.GEAR,
		"text": "At the start of your turn, peek at the top card of any one deck.",
		"soon": true,
	},
	"alien_tracker": {
		"id": "alien_tracker",
		"name": "Alien Tracker",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Look at the top 3 cards of the deck here and return them in the same order. If you saw an alien, gain 1 purple.",
		"soon": true,
	},
	"obsidian_machete": {
		"id": "obsidian_machete",
		"name": "Obsidian Machete",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal or jungle path.",
		"move_paths": [BoardData.PathType.NORMAL],
		"soon": true,
	},
	"ancient_trowel": {
		"id": "ancient_trowel",
		"name": "Ancient Trowel",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card. If it's a resource, reveal it and draw 1 more.",
		"soon": true,
	},
	"scholars_notebook": {
		"id": "scholars_notebook",
		"name": "Scholar's Notebook",
		"kind": Kind.GEAR,
		"text": "When you Rest, look at the top 2 cards of the deck where you stand and put them back in any order.",
		"soon": true,
	},
	"map": {
		"id": "map",
		"name": "Map",
		"kind": Kind.GEAR,
		"text": "When you move to a tile with a deck, look at the top card of that deck.",
		"soon": true,
	},
	"reed_raft": {
		"id": "reed_raft",
		"name": "Reed Raft",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along a normal or river path.",
		"move_paths": [BoardData.PathType.NORMAL],
		"soon": true,
	},
	"fishing_net": {
		"id": "fishing_net",
		"name": "Fishing Net",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card from the bottom of the deck.",
		"soon": true,
	},
	"lucky_lure": {
		"id": "lucky_lure",
		"name": "Lucky Lure",
		"kind": Kind.GEAR,
		"text": "Once per turn, when you Search, you may draw from the bottom of the deck instead of the top.",
		"soon": true,
	},
	"patchwork_glider": {
		"id": "patchwork_glider",
		"name": "Patchwork Glider",
		"kind": Kind.ACTION,
		"action": ActionType.MOVE,
		"text": "Move 1 tile along any path, including plane routes.",
		"move_paths": [BoardData.PathType.NORMAL],
		"soon": true,
	},
	"cargo_manifest": {
		"id": "cargo_manifest",
		"name": "Cargo Manifest",
		"kind": Kind.ACTION,
		"action": ActionType.SEARCH,
		"text": "Draw 1 card, then peek at the next card of this deck.",
		"soon": true,
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
