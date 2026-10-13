# Spec 03 — Location decks, real Search, gear slots, gold and purple

## Goal
1. Rename the starting cards and the Recall action to their new names.
2. The 4 search locations get **shuffled decks** containing the first item cards and resources.
3. **Rummage** actually draws a card into your hand.
4. **Gear** cards can be **equipped** into 3 slots, where they stay through Rest.
5. Every player has public **gold** and **purple** counters (both start at 0).

Item cards found in decks **do not have their special effects yet**. In this spec each one simply works like the basic card of its type. Special effects come in Spec 04. This keeps this spec small.

Builds on Spec 02. Do not change the board tiles or connections.

---

## Rules implemented in this spec

### R1 — Renames
| old | new |
|---|---|
| Basic Move | **Walk** |
| Basic Search | **Rummage** |
| Basic Interact | **Talk** |
| Basic Fight | **Brawl** |
| Recall (action/button) | **Rest** |

Rest works exactly like Recall did: 1 action, all played cards return to the hand.

### R2 — Card kinds
Every card has a **kind**:
- **ACTION** — played from hand into the played area, comes back on Rest. Has an action type: MOVE, SEARCH, INTERACT or FIGHT.
- **GEAR** — equipped into a gear slot. Passive. **Not affected by Rest.**
- **RESOURCE** — sits in the hand. Cannot be played or equipped. (Will be sold for gold in a later spec.)

### R3 — Action types are defined by what they work with
- **MOVE** works with your position.
- **SEARCH** works with the deck at your location. **A SEARCH card can only be played on a tile that has a deck, and only if that deck is not empty.**
- **INTERACT** works with a location's special features. (Still a placeholder: no effect yet.)
- **FIGHT** works with an enemy. (Still a placeholder: no effect yet.)

### R4 — Location decks
- Decks exist only on the 4 search tiles: Junkyard, Archeology site, Lake, Spaceship.
- At game start each deck is built from its card list (section 2) and **shuffled**.
- Searching draws from the **top**.
- An empty deck stays empty (no reshuffle). Search is not allowed there.

### R5 — Drawn cards are secret
- Only the current player sees the card they drew. Other players see only that their hand count went up.

### R6 — Gear
- Each player has **3 gear slots**.
- **Equipping** a gear card from your hand costs **1 action**.
- If all 3 slots are full, the player picks one equipped gear to swap out; the old one goes back to their **hand**. Still 1 action in total.
- Equipped gear is **public**.
- Rest does not affect gear.

### R7 — Gold and purple
- Every player has `gold` and `purple`, both starting at **0**, both **public**.
- Nothing gives or costs gold or purple yet; the counters are just displayed.

### R8 — Empty-hand rule (updated)
If the player has **no playable card** in hand (no action cards, no gear), they can only Rest or End turn. Resource cards don't count as playable.

---

## Assumptions (flagged)
- **A1.** Every item appears **2 times** in its deck; resources fill the rest. Each deck has **14 cards**. All numbers are in one data file so they're easy to tweak.
- **A2.** Item cards behave like the basic card of their type until Spec 04, e.g. a Reed Raft moves like Walk (normal paths only) and a Metal Detector draws 1 like Rummage.
- **A3.** Passenger Club Membership Card can be equipped, but does nothing yet. It needs gold income and turn interruptions first.
- **A4.** Hologram Decoy is **not** in any deck yet (on hold until peeking exists).
- **A5.** A **debug switch** prints secret info (drawn card names) to the Output panel. It is **on** by default, because during early testing one person plays all seats.
- **A6.** Resource sell values are stored now but not used yet.

---

## Files
Changed: `card_data.gd`, `game_state.gd`, `hud.gd` / `hud.tscn`, `card_view.gd` / `card_view.tscn`, `tile.gd` / `tile.tscn`.
New: `res://data/deck_data.gd`.

Keep the rule from Spec 02: **all rules live in `game_state.gd`**; UI only displays and calls functions.

---

## 1. `card_data.gd` changes

```gdscript
enum Kind { ACTION, GEAR, RESOURCE }
enum ActionType { MOVE, SEARCH, INTERACT, FIGHT }
```

Every card definition now has: `id`, `name`, `kind`, `action` (only for ACTION cards), `text`, and optionally `move_paths` (MOVE cards) and `sell_value` (RESOURCE cards).

`text` is the **final** card text (what it will do in Spec 04). Cards whose special effect isn't active yet show an extra small grey line on the card: *"Effect coming soon — works like a basic card for now."*

### Starting cards
| id | name | kind | action | text | extra |
|---|---|---|---|---|---|
| `walk` | Walk | ACTION | MOVE | Move 1 tile along a normal path. | `move_paths: [NORMAL]` |
| `rummage` | Rummage | ACTION | SEARCH | Draw 1 card from the deck here. | — |
| `talk` | Talk | ACTION | INTERACT | Use one action at this location. (Not active yet) | — |
| `brawl` | Brawl | ACTION | FIGHT | Strength 1. (Not active yet) | — |

`starting_hand()` returns `["walk", "rummage", "talk", "brawl"]`.

### Item cards
For now, every MOVE item has `move_paths: [NORMAL]` (their special paths come in Spec 04).

| id | name | kind | action | text |
|---|---|---|---|---|
| `metal_detector` | Metal Detector | ACTION | SEARCH | Draw 2 cards. Keep 1, put the other on the bottom of the deck. |
| `scrap_hoverboard` | Scrap Hoverboard | ACTION | MOVE | Move up to 2 tiles along normal paths. |
| `grappling_claw` | Grappling Claw | ACTION | SEARCH | Draw 1 card from the deck of a tile next to you, without moving. |
| `junk_radio` | Junk Radio | GEAR | — | At the start of your turn, peek at the top card of any one deck. |
| `alien_tracker` | Alien Tracker | ACTION | SEARCH | Look at the top 3 cards of the deck here and return them in the same order. If you saw an alien, gain 1 purple. |
| `obsidian_machete` | Obsidian Machete | ACTION | MOVE | Move 1 tile along a normal or jungle path. |
| `ancient_trowel` | Ancient Trowel | ACTION | SEARCH | Draw 1 card. If it's a resource, reveal it and draw 1 more. |
| `scholars_notebook` | Scholar's Notebook | GEAR | — | When you Rest, look at the top 2 cards of the deck where you stand and put them back in any order. |
| `map` | Map | GEAR | — | When you move to a tile with a deck, look at the top card of that deck. |
| `reed_raft` | Reed Raft | ACTION | MOVE | Move 1 tile along a normal or river path. |
| `fishing_net` | Fishing Net | ACTION | SEARCH | Draw 1 card from the bottom of the deck. |
| `lucky_lure` | Lucky Lure | GEAR | — | Once per turn, when you Search, you may draw from the bottom of the deck instead of the top. |
| `patchwork_glider` | Patchwork Glider | ACTION | MOVE | Move 1 tile along any path, including plane routes. |
| `cargo_manifest` | Cargo Manifest | ACTION | SEARCH | Draw 1 card, then peek at the next card of this deck. |
| `passenger_club_card` | Passenger Club Membership Card | GEAR | — | When a player moves away from your tile, you may pay 1 gold to move with them. |

### Resource cards
| id | name | text | sell_value |
|---|---|---|---|
| `scrap_metal` | Scrap Metal | Resource. Sell at a market. | 1 |
| `relic_shard` | Relic Shard | Resource. Sell at a market. | 2 |
| `river_pearl` | River Pearl | Resource. Sell at a market. | 2 |
| `copper_wire` | Copper Wire | Resource. Sell at a market. | 1 |

---

## 2. `deck_data.gd` (new)
`class_name DeckData`, constants only. For each search tile id, a dictionary of `card_id -> count`.

| tile | contents | total |
|---|---|---|
| `junkyard` | metal_detector ×2, scrap_hoverboard ×2, grappling_claw ×2, junk_radio ×2, alien_tracker ×2, scrap_metal ×4 | 14 |
| `archeology_site` | obsidian_machete ×2, ancient_trowel ×2, scholars_notebook ×2, map ×2, relic_shard ×6 | 14 |
| `lake` | reed_raft ×2, fishing_net ×2, lucky_lure ×2, river_pearl ×8 | 14 |
| `spaceship` | patchwork_glider ×2, cargo_manifest ×2, passenger_club_card ×2, copper_wire ×8 | 14 |

Static functions:
- `has_deck(tile_id) -> bool`
- `build_deck(tile_id) -> Array[String]` — expanded list (e.g. `metal_detector` twice), **not** shuffled.

---

## 3. `game_state.gd` changes

### New state
- `decks: Dictionary` — tile id → `Array[String]`. Index 0 = **top** of the deck.
- Each player also has `gear: Array[String]` (max 3), `gold: int = 0`, `purple: int = 0`.
- Constants: `GEAR_SLOTS = 3`, `DEBUG_SHOW_SECRETS = true`.

### `start_game(n)`
Also builds every deck with `DeckData.build_deck` and shuffles it (`Array.shuffle()`).

### Playing cards
- `can_play_card(hand_index)` — false for RESOURCE and GEAR cards (gear uses `equip_gear`). For SEARCH cards also false if the current tile has no deck or the deck is empty.
- `play_reason(hand_index) -> String` — a short human-readable reason why a card can't be played right now, or `""` if it can. Examples: `"No actions left"`, `"No deck here"`, `"This deck is empty"`, `"Resources can't be played"`.
- MOVE action cards: unchanged from Spec 02 (use the card's `move_paths`).
- `play_search_card(hand_index) -> bool` — for **any** SEARCH card in this spec: card goes to played area, top card of the current tile's deck goes into the player's hand, `actions_left -= 1`.
- INTERACT and FIGHT cards: still placeholders as in Spec 02.

### Gear
- `can_equip(hand_index) -> bool` — card is GEAR and `actions_left > 0`.
- `equip_gear(hand_index, replace_slot: int = -1) -> bool`
  - If fewer than 3 equipped: add it, remove from hand.
  - If 3 equipped: `replace_slot` (0–2) is required; the gear in that slot goes back to the hand, the new one takes its place.
  - Costs 1 action either way.

### Rest
- Rename `recall()` → `rest()` and `can_recall()` → `can_rest()`. Gear is untouched.

### Logging
- Public line (always printed): `Player 1 searched Junkyard with Rummage (deck: 13 left)`
- Secret line (only when `DEBUG_SHOW_SECRETS` is true): `  [secret] Player 1 drew: Metal Detector`
- `Player 1 equipped Junk Radio`, or `Player 1 equipped Map (swapped out Junk Radio)`
- `Player 1 rested: 3 cards back to hand`
- Refusals print the `play_reason`.

---

## 4. UI changes

### Tiles
- Search tiles show a small line under the type: **"Deck: 14"**, updated after every draw. Show **"Deck: empty"** when it's at 0.

### Card view
- The strip at the top of the card shows the kind/action:
  - Move brown `#8B5A2B`, Search teal `#16A085`, Interact purple `#8E44AD`, Fight dark red `#C0392B`
  - **GEAR** slate `#5D6D7E`
  - **RESOURCE** gold `#D4AC0D`
- Cards may be made smaller (about 120×170) so more fit.
- If a card can't be played, it's greyed out. **Hovering** it shows its `play_reason` as a tooltip.
- A card drawn this turn shows a small **"NEW"** badge until the end of the turn.

### Hand area (bottom strip)
Shows three groups for the current player:
1. **Hand** — all hand cards. If there are too many to fit, the row scrolls sideways (`ScrollContainer`).
2. **Played** — as in Spec 02 (faded, not clickable).
3. **Gear (x/3)** — the 3 slots, empty slots drawn as dashed or faint outlines with "empty".

Buttons: **Rest (1 action)** and **End turn**.

Layout may be rearranged to fit, as long as nothing overlaps and all three groups are visible.

### Interactions
- **SEARCH card:** click → plays immediately. A short message in the info panel instruction line: "You found: Metal Detector" (visible only on this player's screen, during this turn).
- **GEAR card in hand:** click → equips it. If all 3 slots are full, the instruction line says "Choose a gear slot to replace (Esc to cancel)", the 3 equipped cards get a yellow border, and clicking one does the swap.
- **RESOURCE card:** not clickable.

### Info panel (right side)
For each player, add:
- **Gold: 0 · Purple: 0** (public)
- **Gear:** names of equipped gear, or "—" (public)
- Hand count stays a count only (secret contents).

---

## Out of scope (do NOT build yet)
Special effects of item cards (Spec 04), aliens, enemies, selling resources, markets, Talk/Brawl effects, Crystal mount purple pool, the Oracle, Hologram Decoy, Passenger Club triggers, win conditions.

---

## How to test (human, in Godot)
1. **F5**, choose 2 players. Starting hand shows **Walk, Rummage, Talk, Brawl**. The button says **Rest**. No red errors.
2. On Village market, **Rummage is greyed out**. Hover it: "No deck here".
3. The 4 search tiles show **"Deck: 14"**. Village, Bandit camp, Arena, Crystal mount, Sacred altar show no deck line.
4. Walk to **Junkyard** (1 action). Rummage is now playable. Play it (1 action). A new card appears with a **NEW** badge, Junkyard shows **"Deck: 13"**, and the Output shows the public line plus a `[secret]` line.
5. Rest (1 action). End turn. Player 2's pass screen appears. Player 2's hand shows **4 cards** — Player 1's found card is **not** visible. Info panel shows **Player 1 — Hand: 5 cards**.
6. Keep searching across a few turns until you get a **resource** (Scrap Metal, etc.). It has a gold strip and is greyed out; hover says "Resources can't be played".
7. Get a **gear** card (e.g. Junk Radio) and click it: it moves into a gear slot, costs 1 action. Info panel shows it under that player's **Gear** for everyone.
8. Play some action cards, then **Rest**: played cards return, **gear stays** in its slot.
9. Get 4 gear cards (a long search session; you can temporarily turn up gear counts in `deck_data.gd` to make this faster). With 3 equipped, click the 4th: choose a slot, the swapped-out gear returns to the hand. Still only 1 action spent.
10. Play a found item, e.g. **Reed Raft**: it moves along **normal paths only** for now and goes to Played. A **Metal Detector** draws just **1** card for now. Cards show the "Effect coming soon" line.
11. Search one deck until **"Deck: empty"**: all Search cards are greyed there with "This deck is empty".
12. Info panel shows **Gold: 0 · Purple: 0** for every player.
13. Restart (F5) twice and check the first Rummage at Junkyard gives different cards (decks are shuffled).

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 03: location decks, search, gear slots, gold and purple"
git push
```

## What to report back
- Which test steps passed or failed (numbers are enough).
- A screenshot with some found cards in hand and at least one gear equipped.
- Any red error text from the Debugger.
- How searching feels: are there too many resources in the decks, or too few?
