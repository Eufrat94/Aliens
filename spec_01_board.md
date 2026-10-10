# Spec 01 — Board data and board display

## Goal
Show the 3×3 game board on screen: 9 tiles with names and all 15 connections, drawn and color-coded by path type. No players, cards or turns yet.

This spec also creates the **single source of truth for the map** (`BoardData`), which later specs (movement, searching) will read from.

---

## Assumptions (flagged)
- **Engine:** Godot 4.x (latest stable), **GDScript** only (no C#).
- **Window:** 1600×900, stretch mode `canvas_items`, aspect `keep`.
- **Visuals are placeholders:** plain rectangles, lines and text. Art comes much later.
- **Right-hand river** has a stop at Bandit camp, so it is two connections (Junkyard↔Bandit camp, Bandit camp↔Lake), **not** a direct Junkyard↔Lake link.
- All connections are **two-way**.

---

## Step 0 — done by the human, before using Cursor
1. Open Godot → **New Project** → pick an empty folder (e.g. `alien-board-game`).
   - Renderer: **Compatibility** (fine for 2D).
   - Version control metadata: **Git** (this creates a `.gitignore` that excludes the `.godot/` folder).
2. Create the project, then close Godot.
3. Open the same folder in Cursor and paste this spec.

---

## Files to create

```
res://
├── data/
│   └── board_data.gd        # map definition + helper functions
├── scenes/
│   ├── main.tscn            # main scene (set as Main Scene in Project Settings)
│   ├── main.gd
│   └── board/
│       ├── board.tscn
│       ├── board.gd
│       ├── connections_layer.gd
│       ├── tile.tscn
│       └── tile.gd
```

Cursor may edit `project.godot` **only** to set the main scene and the window/stretch settings above.

---

## 1. `board_data.gd`

`class_name BoardData`, extends `RefCounted`. Contains only constants and static functions.

### Path types
```gdscript
enum PathType { NORMAL, JUNGLE, RIVER, PLANE }
```

### Tile types
```gdscript
enum TileType { SEARCH, HUB, BLACK_MARKET, PURPLE_SOURCE, ORACLE, UNASSIGNED }
```

### Tiles
A constant dictionary keyed by tile id (`String`). Each entry has `name`, `grid_pos` (`Vector2i`, x = column 0–2, y = row 0–2, origin top-left) and `type`.

| id | name | grid_pos | type |
|---|---|---|---|
| `archeology_site` | Archeology site | (0,0) | SEARCH |
| `junkyard` | Junkyard | (1,0) | SEARCH |
| `sacred_altar` | Sacred altar | (2,0) | ORACLE |
| `arena` | Arena | (0,1) | UNASSIGNED |
| `village_market` | Village market | (1,1) | HUB |
| `bandit_camp` | Bandit camp | (2,1) | BLACK_MARKET |
| `crystal_mount` | Crystal mount | (0,2) | PURPLE_SOURCE |
| `lake` | Lake | (1,2) | SEARCH |
| `spaceship` | Spaceship | (2,2) | SEARCH |

### Connections
A constant array of dictionaries `{ "a": id, "b": id, "path": PathType }`. Exactly these **15**:

| # | a | b | path |
|---|---|---|---|
| 1 | archeology_site | junkyard | NORMAL |
| 2 | junkyard | village_market | NORMAL |
| 3 | arena | village_market | NORMAL |
| 4 | village_market | bandit_camp | NORMAL |
| 5 | village_market | lake | NORMAL |
| 6 | lake | spaceship | NORMAL |
| 7 | archeology_site | arena | JUNGLE |
| 8 | arena | crystal_mount | JUNGLE |
| 9 | junkyard | sacred_altar | JUNGLE |
| 10 | bandit_camp | spaceship | JUNGLE |
| 11 | archeology_site | lake | RIVER |
| 12 | junkyard | bandit_camp | RIVER |
| 13 | bandit_camp | lake | RIVER |
| 14 | crystal_mount | lake | PLANE |
| 15 | sacred_altar | spaceship | PLANE |

### Static functions
- `get_tile_ids() -> Array[String]`
- `get_tile(id: String) -> Dictionary`
- `get_neighbors(id: String) -> Array` — returns an array of `{ "tile": neighbor_id, "path": PathType }`, checking both directions of every connection.
- `path_type_name(path: PathType) -> String` — returns `"normal"`, `"jungle"`, `"river"`, `"plane"`.
- `validate() -> bool` — checks, and prints a clear error for each failure:
  - exactly 9 tiles and 15 connections;
  - every connection's `a` and `b` are existing tile ids;
  - no connection links a tile to itself;
  - no duplicate connections (A–B and B–A count as the same).

---

## 2. Tile scene (`tile.tscn` / `tile.gd`)
- Root: `Panel`, size **260×150**.
- Style: white background, black border 4 px, corner radius 12.
- Children:
  - a `Label` with the tile **name**, centered, font size 26, black;
  - a smaller `Label` under it with the tile **type** in plain words (e.g. "search", "hub", "oracle"), font size 16, grey `#666666`.
- `tile.gd` has `var tile_id: String` and a `setup(id: String)` function that fills in both labels from `BoardData`.
- Left-clicking the tile emits `signal tile_clicked(tile_id: String)`.

---

## 3. Board scene (`board.tscn` / `board.gd`)
- Root: `Node2D`.
- Children, in this order (so connections are drawn **under** tiles):
  1. `ConnectionsLayer` (`Node2D` with `connections_layer.gd`)
  2. `Tiles` (`Node2D`) — container that the board fills with 9 tile instances at runtime.
  3. `Legend` (see below)

### Layout
- Tile size 260×150, horizontal gap 140 px, vertical gap 110 px.
- Tile top-left position = `board_origin + Vector2(col * (260 + 140), row * (150 + 110))`.
- `board_origin` = `(120, 115)`. (The board is then 1060×670 and sits left of center, leaving room for the legend on the right.)
- `board.gd` exposes `get_tile_center(id) -> Vector2` for the connections layer and future specs.

### Connections drawing (`connections_layer.gd`, using `_draw()`)
Colors and widths:

| path | color | width |
|---|---|---|
| NORMAL | brown `#8B5A2B` | 14 |
| JUNGLE | green `#7CC242` | 14 |
| RIVER | blue `#1E90FF` | 10 |
| PLANE | light blue `#87CEEB` | 5 |

- NORMAL, JUNGLE, RIVER: straight line from tile center to tile center. Because tiles are drawn on top, only the part in the gaps is visible. This is intended.
- PLANE: a **curved** line, because the Sacred altar ↔ Spaceship straight line would pass behind Bandit camp.
  - Quadratic Bézier curve from center A to center B, sampled into ~24 points and drawn with `draw_polyline`.
  - Control point = midpoint of A–B, pushed **220 px** perpendicular to the A–B line, in the direction **away from the board center** (the Village market's center).
  - Result: the Crystal mount ↔ Lake curve bulges **downward** below the board; the Sacred altar ↔ Spaceship curve bulges **right**, outside the board.
  - Draw a small text label "PLANE" at the curve's midpoint.
- Draw order: NORMAL lines last, so brown bridges appear **on top of** rivers where they cross (Arena↔Village, Village↔Bandit camp).

### Legend
- Top-right area, starting at around (1300, 120).
- Title "Paths", then one row per path type: a 40×14 color swatch and its name ("Normal", "Jungle", "River", "Plane").

---

## 4. Main scene (`main.tscn` / `main.gd`)
- Root `Node2D` with a background `ColorRect` filling the window, color `#C8BFE7` (lavender, matching the sketch), behind everything.
- Instances `board.tscn`.
- In `_ready()`:
  1. Call `BoardData.validate()`. If it passes, print `Board data OK: 9 tiles, 15 connections`.
  2. For each tile, print one line: `<Tile name>: <neighbor name> (<path>), ...`
- When any tile is clicked, print: `Clicked: <Tile name> | neighbors: <neighbor name> (<path>), ...`

---

## Out of scope (do NOT build yet)
Players, tokens, movement, cards, decks, turns, purple, markets, menus, sound, art, animations.

---

## How to test (human, in Godot)
1. Open the project and press **F5** (Run Project). The window opens with no errors in the **Debugger** panel.
2. **9 tiles** in a 3×3 grid, names matching the table in section 1, on a lavender background.
3. Count the visible connections: **6 brown, 4 green, 3 blue, 2 light-blue curved** (15 total).
4. Check specific details:
   - There is **no** direct line between Junkyard and Lake. The right-hand river goes through Bandit camp.
   - Crystal mount and Sacred altar have **no brown** connection.
   - The two plane curves bulge outward and don't run behind any tile.
   - The brown bridges are drawn on top of the blue river lines.
5. The **Output** panel shows `Board data OK: 9 tiles, 15 connections` plus 9 neighbor lines. Spot-check one: `Bandit camp` should list Village market (normal), Spaceship (jungle), Junkyard (river), Lake (river).
6. Click **Lake**: Output shows its neighbors: Village market (normal), Spaceship (normal), Archeology site (river), Bandit camp (river), Crystal mount (plane).
7. The legend shows all 4 path types with correct colors.

When everything passes, save a checkpoint in PowerShell from the project folder:
```powershell
git add .
git commit -m "Spec 01: board data and board display"
git push
```

## What to report back
- Did it run without errors? (If not, copy the red error text from the Debugger.)
- A screenshot of the board.
- Anything that looks different from your paint sketch.
