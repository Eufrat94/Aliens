class_name CardData
extends RefCounted

enum Kind { GEAR, ABILITY, RESOURCE, ALIEN }
enum ActionType { NONE, MOVE, SEARCH, INTERACT, FIGHT }

const SOON_TEXT := "Effect coming soon."
const ALIEN_ACTIVE_NOTE := "Active: 1 action, once per turn. Other players on your tile gain 1 purple."

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
	"copper_wire": {
		"id": "copper_wire",
		"name": "Copper Wire",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"battery": {
		"id": "battery",
		"name": "Battery",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"rope": {
		"id": "rope",
		"name": "Rope",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"scrap_plate": {
		"id": "scrap_plate",
		"name": "Scrap Plate",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"cog": {
		"id": "cog",
		"name": "Cog",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"relic_crystal": {
		"id": "relic_crystal",
		"name": "Relic Crystal",
		"kind": Kind.RESOURCE,
		"action": ActionType.NONE,
		"text": "Material. Build inventions at the Workshop, or sell for 1 gold.",
	},
	"echo_antenna": {
		"id": "echo_antenna",
		"name": "Echo Antenna",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "passive",
		"invention": true,
		"recipe": ["copper_wire", "battery", "relic_crystal"],
		"text": "Whenever another player uses an alien ability, you gain 1 purple.",
	},
	"brass_binoculars": {
		"id": "brass_binoculars",
		"name": "Brass Binoculars",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "passive",
		"invention": true,
		"recipe": ["relic_crystal", "any"],
		"text": "Whenever another player on your tile draws a card from a deck, they must show it to you.",
	},
	"pedal_cart": {
		"id": "pedal_cart",
		"name": "Pedal Cart",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "passive",
		"invention": true,
		"recipe": ["cog", "cog", "rope"],
		"text": "At the start of your turn, you may Move once for free (before doing anything else).",
	},
	"strongbox": {
		"id": "strongbox",
		"name": "Strongbox",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "passive",
		"invention": true,
		"recipe": ["scrap_plate", "scrap_plate", "battery"],
		"text": "Other players can't take cards from your hand.",
	},
	"aether_still": {
		"id": "aether_still",
		"name": "Aether Still",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "active",
		"invention": true,
		"recipe": ["copper_wire", "battery", "rope"],
		"text": "Use (1 action, once per turn): pay 2 gold, gain 1 purple.",
	},
	"truth_lantern": {
		"id": "truth_lantern",
		"name": "Truth Lantern",
		"kind": Kind.GEAR,
		"action": ActionType.NONE,
		"gear_mode": "active",
		"invention": true,
		"recipe": ["relic_crystal", "copper_wire", "rope"],
		"text": "Use (1 action, once per turn): a player on your tile shows you 1 card from their hand. If they have an alien in hand, they must show an alien; otherwise any card they choose.",
	},
	"wingo": {
		"id": "wingo",
		"name": "Wingo",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Pay 1 purple: move to any tile.\n" + ALIEN_ACTIVE_NOTE,
	},
	"magnet": {
		"id": "magnet",
		"name": "Magnet",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Each other player on your tile gives you 1 card of their choice from their hand.\n" + ALIEN_ACTIVE_NOTE,
	},
	"disko": {
		"id": "disko",
		"name": "Disko",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Take the top card of the discard pile into your hand.\n" + ALIEN_ACTIVE_NOTE,
	},
	"mani": {
		"id": "mani",
		"name": "Mani",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Pay 1 purple: gain 5 gold.\n" + ALIEN_ACTIVE_NOTE,
	},
	"ugg": {
		"id": "ugg",
		"name": "Ugg",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Pay 3 purple: discard any alien on the table.\n" + ALIEN_ACTIVE_NOTE,
	},
	"wush": {
		"id": "wush",
		"name": "Wush",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Move another player to a tile directly next to theirs (up, down, left or right).\n" + ALIEN_ACTIVE_NOTE,
	},
	"shadow": {
		"id": "shadow",
		"name": "Shadow",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Every other player gives you 1 gold. If you have 9 or more gold, discard Shadow.\n" + ALIEN_ACTIVE_NOTE,
	},
	"stopots": {
		"id": "stopots",
		"name": "Stopots",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "passive",
		"text": "Other players on your tile can't use alien abilities.",
	},
	"pucky": {
		"id": "pucky",
		"name": "Pucky",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Take a random card from any player's hand, then discard 1 card from your hand.\n" + ALIEN_ACTIVE_NOTE,
	},
	"muddk": {
		"id": "muddk",
		"name": "Muddk",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "passive",
		"text": "Players leaving your tile must pay you 1 gold, if they have any. Being pushed doesn't count.",
	},
	"nerfoil": {
		"id": "nerfoil",
		"name": "Nerfoil",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "passive",
		"text": "Other players have a hand limit of 7. If they would gain a card at 7, they first discard 1.",
	},
	"skrim": {
		"id": "skrim",
		"name": "Skrim",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "unplayable",
		"text": "Can't be played. Whenever anyone gains this card, everyone is told.",
	},
	"pikupiku": {
		"id": "pikupiku",
		"name": "Pikupiku",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Pay 1 purple: look at the hand of a player on your tile.\n" + ALIEN_ACTIVE_NOTE,
	},
	"quizazz": {
		"id": "quizazz",
		"name": "Quizazz",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Pick a player. They reveal to everyone whether they have an alien in hand. Yes: you gain 1 purple. No: you gain 1 gold.\n" + ALIEN_ACTIVE_NOTE,
	},
	"mimix": {
		"id": "mimix",
		"name": "Mimix",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Discard a card from your hand: use the active ability of any alien on the table, paying its costs.\n" + ALIEN_ACTIVE_NOTE,
	},
	"gloop": {
		"id": "gloop",
		"name": "Gloop",
		"kind": Kind.ALIEN,
		"action": ActionType.NONE,
		"alien_mode": "active",
		"text": "Give 1 purple to another player, then swap positions with them.\n" + ALIEN_ACTIVE_NOTE,
	},
}

const RESOURCE_IDS: Array[String] = ["copper_wire", "battery", "rope", "scrap_plate", "cog", "relic_crystal"]
const INVENTION_IDS: Array[String] = ["echo_antenna", "brass_binoculars", "pedal_cart", "strongbox", "aether_still", "truth_lantern"]


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
		if bool(CARDS[card_id].get("invention", false)):
			continue
		var kind := int(CARDS[card_id]["kind"])
		if kind == Kind.GEAR or kind == Kind.ABILITY:
			ids.append(card_id)
	return ids


static func item_ids() -> Array[String]:
	return market_pool()


static func is_alien(card_id: String) -> bool:
	if not CARDS.has(card_id):
		return false
	return int(CARDS[card_id]["kind"]) == Kind.ALIEN


static func all_alien_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in CARDS:
		if int(CARDS[card_id]["kind"]) == Kind.ALIEN:
			ids.append(str(card_id))
	return ids


static func alien_mode_label(card: Dictionary) -> String:
	match str(card.get("alien_mode", "")):
		"active":
			return "Active"
		"passive":
			return "Passive"
		"unplayable":
			return "Can't be played"
	return ""


static func is_resource(card_id: String) -> bool:
	return int(get_card(card_id)["kind"]) == Kind.RESOURCE


static func is_invention(card_id: String) -> bool:
	if not CARDS.has(card_id):
		return false
	return bool(CARDS[card_id].get("invention", false))


static func invention_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in INVENTION_IDS:
		ids.append(card_id)
	return ids


static func recipe_of(card_id: String) -> Array[String]:
	var recipe: Array[String] = []
	if not CARDS.has(card_id):
		return recipe
	var raw: Array = CARDS[card_id].get("recipe", [])
	for part in raw:
		recipe.append(str(part))
	return recipe


static func recipe_line(card: Dictionary) -> String:
	if not bool(card.get("invention", false)):
		return ""
	var names: PackedStringArray = PackedStringArray()
	var raw: Array = card.get("recipe", [])
	for part in raw:
		var part_id := str(part)
		if part_id == "any":
			names.append("Any")
		else:
			names.append(str(CARDS[part_id]["name"]))
	return " · ".join(names)


static func card_body(card: Dictionary) -> String:
	var recipe := recipe_line(card)
	var text := str(card["text"])
	if recipe == "":
		return text
	return "%s\n%s" % [recipe, text]
