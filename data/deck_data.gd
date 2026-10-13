class_name DeckData
extends RefCounted

const DECKS := {
	"junkyard": {
		"metal_detector": 2,
		"scrap_hoverboard": 2,
		"grappling_claw": 2,
		"junk_radio": 2,
		"alien_tracker": 2,
		"scrap_metal": 4,
	},
	"archeology_site": {
		"obsidian_machete": 2,
		"ancient_trowel": 2,
		"scholars_notebook": 2,
		"map": 2,
		"relic_shard": 6,
	},
	"lake": {
		"reed_raft": 2,
		"fishing_net": 2,
		"lucky_lure": 2,
		"river_pearl": 8,
	},
	"spaceship": {
		"patchwork_glider": 2,
		"cargo_manifest": 2,
		"passenger_club_card": 2,
		"copper_wire": 8,
	},
}


static func has_deck(tile_id: String) -> bool:
	return DECKS.has(tile_id)


static func build_deck(tile_id: String) -> Array[String]:
	var deck: Array[String] = []
	var counts: Dictionary = DECKS[tile_id]
	for card_id in counts:
		var copies: int = int(counts[card_id])
		for _copy in copies:
			deck.append(card_id)
	return deck
