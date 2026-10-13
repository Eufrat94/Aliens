# Spec 02 — Players, turns, starting cards and movement

## Goal
2–5 players take turns on one screen (hot-seat). Each player has a hand of the 4 basic cards. On their turn a player gets **3 actions**. Playing a card uses 1 action and puts the card face-up in their **played area**. **Basic Move** actually moves the player's token. The other 3 basic cards can be played but do nothing yet. **Recall** (1 action) takes all played cards back into the hand.

Builds on Spec 01. Do **not** change `BoardData`'s tiles or connections.

---

## Rules implemented in this spec
1. At game start, choose 2–5 players. Everyone starts on **Village market** with the same 4 cards in hand: Basic Move, Basic Search, Basic Interact, Basic Fight. No gold, no health.
2. Player 1 goes first, then 2, 3… and back to 1.
3. Each turn the player has **3 actions**.
4. **Playing a card** costs 1 action. The card leaves the hand and goes face-up into that player's played area.
5. **Basic Move:** move to a neighboring tile connected by a **normal (brown)** path only.
6. **Basic Search / Basic Interact / Basic Fight:** placeholders. Playing them costs 1 action and moves the card to the played area, but has no other effect yet.
7. **Recall:** costs 1 action. Takes **all** cards from the played area back into the hand. Not allowed if the played area is empty.
8. If the hand is empty, the only possible action is Recall.
9. **End turn:** the player can end their turn at any time. Unused actions are lost. Ending the turn is free.

## Assumptions (flagged)
- **A1.** Ending the turn is **manual**. When actions reach 0 the turn does not end on its own; the player clicks End turn. (Easy to change later.)
- **A2.** Players can end their turn early and lose unused actions.
- **A3.** Several players can stand on the same tile.
- **A4.** Played areas are **public**: everyone can see what everyone else has played. Hands are **private**: only the current player sees their own hand.
- **A5.** The 3 placeholder cards can still be played, so the play → played area → recall cycle can be tested with all 4 cards.
- **A6.** A hand is stored as a list of card ids (e.g. `"basic_move"`). Good enough for now.

---

## Files

New:
```
res://
├── data/
│   └── card_data.gd            # card definitions
├── game/
│   └── game_state.gd           # all game rules and state, no UI code
├── scenes/
│   ├── setup/
│   │   ├── setup_screen.tscn   # choose number of players
│   │   └── setup_screen.gd
│   └── ui/
│       ├── card_view.tscn      # one card on screen
│       ├── card_view.gd
│       ├── hud.tscn            # hand, played area, buttons, info panel
│       ├── hud.gd
│       ├── pass_screen.tscn    # "pass the device" curtain
│       └── pass_screen.gd
```
Changed: `main.tscn` / `main.gd`, `board.tscn` / `board.gd`, `tile.gd`.

**Important split:** all rules live in `game_state.gd`. UI scripts only display state and call `GameState` functions. UI must never change player position, hand or actions directly.

---

## 1. `card_data.gd`
`class_name CardData`, extends `RefCounted`, constants and static functions only.

```gdscript
enum ActionType { MOVE, SEARCH, INTERACT, FIGHT }
```

A constant dictionary of card definitions keyed by card id:

| id | name | action | text on card | extra fields |
|---|---|---|---|---|
| `basic_move` | Basic Move | MOVE | Move 1 tile along a normal path. | `move_paths: [NORMAL]` |
| `basic_search` | Basic Search | SEARCH | Draw 1 card here. (Not active yet) | — |
| `basic_interact` | Basic Interact | INTERACT | Use one action at this location. (Not active yet) | — |
| `basic_fight` | Basic Fight | FIGHT | Attack with strength 1. (Not active yet) | — |

`move_paths` is a list of `BoardData.PathType` values the card is allowed to use. Later cards (e.g. Machete) will add `JUNGLE` here.

Static functions:
- `get_card(id: String) -> Dictionary`
- `action_name(action: ActionType) -> String` → `"Move"`, `"Search"`, `"Interact"`, `"Fight"`
- `starting_hand() -> Array[String]` → the 4 basic card ids, in the order above.

---

## 2. `game_state.gd`
`class_name GameState`, extends `RefCounted`.

### Constants
- `ACTIONS_PER_TURN = 3`
- `START_TILE = "village_market"`
- Player colors, in order: red `#E74C3C`, blue `#3498DB`, yellow `#F1C40F`, green `#2ECC71`, orange `#E67E22`.

### Player data
Each player is a dictionary:
`{ "index": int (0-based), "name": "Player 1", "color": Color, "tile": String, "hand": Array[String], "played": Array[String] }`

### State
`players: Array`, `current_index: int`, `actions_left: int`.

### Signal
`state_changed` — emitted after **every** change, so the UI can redraw.

### Functions
- `start_game(player_count: int)` — 2–5 players, all on `START_TILE`, each with `CardData.starting_hand()`, empty played area. `current_index = 0`, `actions_left = 3`.
- `current_player() -> Dictionary`
- `can_play_card(hand_index: int) -> bool` — true if `actions_left > 0` and the index is valid.
- `get_move_destinations(hand_index: int) -> Array[String]` — for a MOVE card: neighbors of the player's tile (from `BoardData.get_neighbors`) whose path type is in the card's `move_paths`. Empty array for non-move cards.
- `play_move_card(hand_index: int, destination: String) -> bool` — checks the card is MOVE, `can_play_card` is true, and the destination is in `get_move_destinations`. If OK: move the player, move the card from hand to played, `actions_left -= 1`, return true.
- `play_placeholder_card(hand_index: int) -> bool` — for SEARCH/INTERACT/FIGHT cards: move card to played, `actions_left -= 1`.
- `can_recall() -> bool` — `actions_left > 0` and played area not empty.
- `recall() -> bool` — move all played cards back into the hand (keep their order), `actions_left -= 1`.
- `end_turn()` — next player (wrapping around), `actions_left = 3`.

Every successful action prints one line to Output, for example:
- `Player 1 played Basic Move: Village market -> Lake (normal)`
- `Player 1 played Basic Search (no effect yet)`
- `Player 1 recalled 3 cards`
- `Player 1 ended turn with 1 action unused`
- `--- Player 2's turn ---`

Every refused action prints why, e.g. `Refused: no actions left`.

---

## 3. Screens and flow
1. Game starts on the **setup screen**: title "Aliens — new game", text "How many players?", and buttons **2, 3, 4, 5**.
2. Clicking a number calls `start_game(n)`, hides the setup screen and shows the board + HUD, with the **pass screen** on top for Player 1.
3. **Pass screen:** a full-window, fully opaque dark overlay (`#1E1E2A`) that hides everything. Big text in the player's color: "Player 2's turn". Smaller text: "Pass the device to Player 2, then click anywhere to start." Clicking anywhere hides it.
4. The pass screen appears at the start of **every** turn, including the very first one.

---

## 4. Layout (window stays 1600×900)
Rearrange the main scene into three regions:

| region | position | contents |
|---|---|---|
| Board | top-left, about x 0–1000, y 0–640 | the Spec 01 board, scaled down (about 0.75×) so all tiles and both plane curves fit; legend may move or shrink to fit |
| Info panel | right side, about x 1020–1590, y 10–640 | turn and player info (section 6) |
| Hand area | bottom strip, about y 650–890, full width | hand, played area, buttons (section 5) |

Exact numbers are flexible; the rule is **nothing overlaps and everything is visible**.

---

## 5. Hand area (bottom strip) — current player only
- **Hand:** label "Your hand", then the current player's hand cards as `card_view` instances in a row.
- **Played area:** label "Played", then the current player's played cards, in the same style but slightly faded (60% opacity) and not clickable.
- **Buttons** on the right: **Recall (1 action)** and **End turn**.
  - Recall is disabled when `can_recall()` is false.
  - End turn is always enabled.

### `card_view`
- `Panel` about 140×190, white background, dark border 3 px, corner radius 10.
- Shows: card **name** (bold, top), action type (e.g. "MOVE") in a colored strip, and the card **text** (small, word-wrapped).
- Action strip colors: Move brown `#8B5A2B`, Search teal `#16A085`, Interact purple `#8E44AD`, Fight dark red `#C0392B`.
- Emits `card_clicked(hand_index)` when a playable hand card is clicked.
- When no actions are left, hand cards look disabled (greyed) and clicking does nothing.

---

## 6. Info panel (right side)
- Big: "Player 2's turn" in that player's color.
- "Actions left: 2 / 3"
- A small instruction line that changes with what you're doing (see section 7), e.g. "Choose a card to play."
- **Players** list, one block per player:
  - name in their color, with "(current)" next to the current player;
  - "On: Lake";
  - "Hand: 3 cards" (count only, never names, because hands are secret);
  - "Played: Basic Move, Basic Search" (names, because played cards are public), or "Played: —".

---

## 7. Playing cards — interaction
**Move card:**
1. Click Basic Move in the hand. The card is highlighted (raised 15 px and/or a thick yellow border).
2. Instruction line: "Click a highlighted tile to move there. Right-click or Esc to cancel."
3. Every tile in `get_move_destinations` gets a thick yellow `#F1C40F` border.
4. Click a highlighted tile → `play_move_card`. Clicking a non-highlighted tile does nothing.
5. Right-click anywhere or press Esc → cancel; nothing is spent.
6. If there are no destinations (not possible yet, but will be later), show "No reachable tiles with this card" and don't select it.

**Search / Interact / Fight card:** a single click plays it immediately with `play_placeholder_card`.

**Recall button:** calls `recall()`.

**End turn button:** cancels any half-finished selection, calls `end_turn()`, then shows the pass screen for the next player.

---

## 8. Player tokens on the board
- Each player is a filled circle, radius about 18 px (before board scaling), in their color, with a black 2 px outline and the player number in white in the middle.
- Tokens on the same tile are spread out in a row near the bottom of the tile so they don't overlap (up to 5 must fit).
- The current player's token has an extra white ring around it.
- Tokens update whenever `state_changed` fires.

---

## Out of scope (do NOT build yet)
Real Search/Interact/Fight effects, location decks, any card other than the 4 basics, jungle/river/plane movement, gold, purple, aliens, enemies, markets, the Oracle, win conditions, saving/loading, art, sound, animations.

---

## How to test (human, in Godot)
1. **F5.** The setup screen appears. No red errors in the Debugger.
2. Click **3**. A dark pass screen says "Player 1's turn". Click it. The board appears with **3 tokens** (red 1, blue 2, yellow 3) on Village market. Red has the white ring.
3. The bottom shows 4 cards in "Your hand", an empty "Played" area, and the Recall button is **disabled**. The info panel says "Actions left: 3 / 3".
4. Click **Basic Move**. Exactly **4 tiles** light up yellow: Junkyard, Arena, Bandit camp, Lake. Press **Esc**: highlights disappear, actions still 3.
5. Click Basic Move again, then click **Lake**. The red token moves to Lake. Actions left: 2. Basic Move is now in "Played".
6. Try to move again: there's no Move card in your hand, so you can't. Click **Basic Search**. It moves to Played. Actions left: 1.
7. Click **Recall**. Both cards go back to the hand. Actions left: 0. Cards look greyed out and can't be clicked.
8. Click **End turn**. The pass screen says "Player 2's turn" in blue. Click it. The hand shows Player 2's 4 cards, and the info panel shows "Player 1 — On: Lake — Hand: 4 cards — Played: —".
9. As Player 2: play Basic Fight, Basic Interact, Basic Search (3 actions). Click End turn. As Player 3, check the info panel: Player 2 shows "Hand: 1 card" and "Played: Basic Fight, Basic Interact, Basic Search".
10. Go around to Player 2 again. They have 1 card in hand and 3 played. Play the last card, so the hand is **empty**: only Recall and End turn work. Recall: all 4 back in hand.
11. From Lake (Player 1): Basic Move should highlight **Village market and Spaceship only**. Not Archeology site, Bandit camp or Crystal mount (those are river/plane).
12. The Output panel shows one line for every action, as in section 2.
13. Restart (F5) and try **5 players**: all 5 tokens fit on Village market without overlapping.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 02: players, turns, starting cards and movement"
git push
```

## What to report back
- Which test steps passed or failed (just the numbers is fine).
- A screenshot during a turn.
- Any red error text from the Debugger.
- How it **felt**: is 3 actions per turn nice? Is the recall rhythm annoying or interesting?
