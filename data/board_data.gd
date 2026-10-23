class_name BoardData
extends RefCounted

enum PathType { NORMAL, JUNGLE, RIVER, PLANE }
enum TileType { SEARCH, HUB, BLACK_MARKET, PURPLE_SOURCE, ORACLE, UNASSIGNED }

const TILES := {
	"archeology_site": {
		"name": "Archeology site",
		"grid_pos": Vector2i(0, 0),
		"type": TileType.SEARCH,
	},
	"junkyard": {
		"name": "Junkyard",
		"grid_pos": Vector2i(1, 0),
		"type": TileType.SEARCH,
	},
	"sacred_altar": {
		"name": "Sacred altar",
		"grid_pos": Vector2i(2, 0),
		"type": TileType.ORACLE,
	},
	"arena": {
		"name": "Arena",
		"grid_pos": Vector2i(0, 1),
		"type": TileType.UNASSIGNED,
	},
	"village_market": {
		"name": "Village market",
		"grid_pos": Vector2i(1, 1),
		"type": TileType.HUB,
	},
	"bandit_camp": {
		"name": "Bandit camp",
		"grid_pos": Vector2i(2, 1),
		"type": TileType.BLACK_MARKET,
	},
	"crystal_mount": {
		"name": "Crystal mount",
		"grid_pos": Vector2i(0, 2),
		"type": TileType.PURPLE_SOURCE,
	},
	"lake": {
		"name": "Lake",
		"grid_pos": Vector2i(1, 2),
		"type": TileType.SEARCH,
	},
	"spaceship": {
		"name": "Spaceship",
		"grid_pos": Vector2i(2, 2),
		"type": TileType.SEARCH,
	},
}

const CONNECTIONS: Array[Dictionary] = [
	{"a": "archeology_site", "b": "junkyard", "path": PathType.NORMAL},
	{"a": "junkyard", "b": "village_market", "path": PathType.NORMAL},
	{"a": "arena", "b": "village_market", "path": PathType.NORMAL},
	{"a": "village_market", "b": "bandit_camp", "path": PathType.NORMAL},
	{"a": "village_market", "b": "lake", "path": PathType.NORMAL},
	{"a": "lake", "b": "spaceship", "path": PathType.NORMAL},
	{"a": "archeology_site", "b": "arena", "path": PathType.JUNGLE},
	{"a": "arena", "b": "crystal_mount", "path": PathType.JUNGLE},
	{"a": "junkyard", "b": "sacred_altar", "path": PathType.JUNGLE},
	{"a": "bandit_camp", "b": "spaceship", "path": PathType.JUNGLE},
	{"a": "archeology_site", "b": "lake", "path": PathType.RIVER},
	{"a": "junkyard", "b": "bandit_camp", "path": PathType.RIVER},
	{"a": "bandit_camp", "b": "lake", "path": PathType.RIVER},
	{"a": "crystal_mount", "b": "lake", "path": PathType.PLANE},
	{"a": "sacred_altar", "b": "spaceship", "path": PathType.PLANE},
]


static func get_tile_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in TILES:
		ids.append(id)
	return ids


static func get_tile(id: String) -> Dictionary:
	return TILES[id]


static func get_neighbors(id: String) -> Array:
	var neighbors: Array = []
	for connection in CONNECTIONS:
		var a: String = connection["a"]
		var b: String = connection["b"]
		if a == id:
			neighbors.append({"tile": b, "path": connection["path"]})
		elif b == id:
			neighbors.append({"tile": a, "path": connection["path"]})
	return neighbors


static func grid_adjacent(tile_id: String) -> Array[String]:
	var origin: Vector2i = get_tile(tile_id)["grid_pos"]
	var found: Array[String] = []
	for id in get_tile_ids():
		var pos: Vector2i = get_tile(id)["grid_pos"]
		if absi(pos.x - origin.x) + absi(pos.y - origin.y) == 1:
			found.append(id)
	return found


static func has_interaction(tile_id: String) -> bool:
	return tile_id == "village_market" or tile_id == "crystal_mount"


static func path_type_name(path: PathType) -> String:
	match path:
		PathType.NORMAL:
			return "normal"
		PathType.JUNGLE:
			return "jungle"
		PathType.RIVER:
			return "river"
		PathType.PLANE:
			return "plane"
	return "unknown"


static func validate() -> bool:
	var ok := true
	if TILES.size() != 9:
		push_error("BoardData: expected exactly 9 tiles, found %d." % TILES.size())
		ok = false
	if CONNECTIONS.size() != 15:
		push_error("BoardData: expected exactly 15 connections, found %d." % CONNECTIONS.size())
		ok = false

	var seen := {}
	for connection in CONNECTIONS:
		var a := str(connection["a"])
		var b := str(connection["b"])
		if not TILES.has(a):
			push_error("BoardData: connection %s — %s uses unknown tile '%s'." % [a, b, a])
			ok = false
		if not TILES.has(b):
			push_error("BoardData: connection %s — %s uses unknown tile '%s'." % [a, b, b])
			ok = false
		if a == b:
			push_error("BoardData: connection links tile '%s' to itself." % a)
			ok = false
			continue
		var left := a
		var right := b
		if right < left:
			left = b
			right = a
		var key := "%s|%s" % [left, right]
		if seen.has(key):
			push_error("BoardData: duplicate connection between '%s' and '%s'." % [a, b])
			ok = false
		else:
			seen[key] = true
	return ok
