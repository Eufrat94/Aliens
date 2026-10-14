# Spec 09 — Free actions, gear, ability cards (drop the hand-builder)

## Goal
Rebuild the turn system around **free base actions**:
- **Move, Search, Interact, Fight** no longer need cards. Each costs **1 action point** (AP). Players have **3 AP per turn** to spend however they like.
- The basic cards (Walk, Rummage, Talk, Brawl), the **played area** and **Rest** are **removed**.
- Cards in hand are now **Gear**, **Ability cards** or **Resources** (aliens come later).
- Hands start with **2 random resources**.

This is a big rules change, but it **simplifies** a lot. The board, decks, market, popups, log and table layout from earlier specs stay.

Builds on Spec 08.

---

## Decisions from the designer
- Base actions are free (no card), 1 AP each, any combination (e.g. Move 3 times).
- **Gear:** costs 1 AP to put down from hand. Stays in front of the player. **Passive** (always on) or **active** (1 AP to use, **once per turn**). **4 gear slots**. Putting down gear with all slots full **discards** one of the old ones (player chooses).
- **Ability cards:** cost **1 AP**, do what the card says, then are **discarded**.
- **Resources:** can't be played. Sold at the market as before. (Set collection comes later.)
- **No hand limit.**
- **Starting hand:** 2 random resources. Starting gold stays 5.
- **Discarded cards** go to a shared **discard pile** that is not used for anything yet (later: digging through it).
- Card conversions: designer's choice, adjust after playtesting.

## Assumptions (flagged)
- **A1. Base Move** = 1 tile along a **normal** path, plus any extra path types granted by your gear (Machete → jungle, Raft → river).
- **A2. Base Search** = draw the top card of the deck on your tile. Needs a non-empty deck.
- **A3. Base Interact** = only on Village market (opens the market, as in Spec 05). 1 AP only if something was bought or sold.
- **A4. Base Fight** exists as a button but is always unavailable: "No enemies here" (no enemies yet).
- **A5.** Ability cards and active gear still have an **action tag** (Move/Search/…), so type rules keep working. E.g. Lucky Lure affects anything tagged Search that draws from the top.
- **A6.** Discarding gear from a slot is only possible when replacing it with new gear (no free "throw away" action yet).
- **A7.** Starting resources are generated (one of the 4 resource types at random, twice), **not** taken from the decks.

---

## 1. Card kinds (`card_data.gd`)

```gdscript
enum Kind { GEAR, ABILITY, RESOURCE }      # ALIEN will be added later
enum ActionType { NONE, MOVE, SEARCH, INTERACT, FIGHT }
```

Each card: `id`, `name`, `kind`, `action` (tag), `text`, and where relevant:
- GEAR: `gear_mode`: `"passive"` or `"active"`.
- Passive move gear: `grants_paths` (e.g. `[JUNGLE]`).
- RESOURCE: `sell_value` (kept, unused).

**Delete** `walk`, `rummage`, `talk`, `brawl` and `starting_hand()`. Replace with `random_starting_hand() -> Array[String]` (2 random resource ids).

### Gear — passive
| id | name | tag | text |
|---|---|---|---|
| `obsidian_machete` | Obsidian Machete | MOVE | Your Move action can also use jungle paths. (`grants_paths: [JUNGLE]`) |
| `reed_raft` | Reed Raft | MOVE | Your Move action can also use river paths. (`grants_paths: [RIVER]`) |
| `junk_radio` | Junk Radio | SEARCH | At the start of your turn, peek at the top card of any one deck. |
| `map` | Map | MOVE | When you move onto a tile with a deck, look at its top card. |
| `lucky_lure` | Lucky Lure | SEARCH | Once per turn, when you Search, you may draw from the bottom of the deck instead of the top. |
| `scholars_notebook` | Scholar's Notebook | SEARCH | At the end of your turn, look at the top 2 cards of the deck where you stand and put them back in any order. |
| `passenger_club_card` | Passenger Club Membership Card | MOVE | When a player moves away from your tile, you may pay 1 gold to move with them. *(Effect coming soon.)* |

### Gear — active (1 AP, once per turn)
| id | name | tag | text |
|---|---|---|---|
| `metal_detector` | Metal Detector | SEARCH | **Use (1 action, once per turn):** Draw 2 cards from the deck here. Keep 1, put the other on the bottom of the deck. |

### Ability cards (1 AP, then discarded)
| id | name | tag | text |
|---|---|---|---|
| `scrap_hoverboard` | Scrap Hoverboard | MOVE | Move up to 2 tiles, using any paths your Move action can use. |
| `patchwork_glider` | Patchwork Glider | MOVE | Move 1 tile along any path, including plane routes. |
| `grappling_claw` | Grappling Claw | SEARCH | Draw the top card of the deck on a grid-adjacent tile, without moving. |
| `ancient_trowel` | Ancient Trowel | SEARCH | Draw 2 cards from the deck here. If either is a resource, reveal it and draw 1 more (max 1 extra). |
| `fishing_net` | Fishing Net | SEARCH | Draw the bottom 2 cards of the deck here. |
| `cargo_manifest` | Cargo Manifest | SEARCH | Draw 1 card from the deck here, then look at the next 2 and put them back in any order. |
| `alien_tracker` | Alien Tracker | SEARCH | Look at the top 3 cards of **any** deck and put them back in the same order. If you saw an alien, gain 1 purple. |

### Resources
Unchanged: Scrap Metal, Relic Shard, River Pearl, Copper Wire.

Hologram Decoy stays out of the game for now.

## 2. Decks (`deck_data.gd`)
Same contents and counts as Spec 04 (12 cards each). Only the card definitions change.

## 3. Market
Unchanged from Spec 05, except:
- It's opened with the **Interact** action (no card).
- `market_pool()` = all GEAR and ABILITY cards from section 1 (no resources).

---

## 4. `game_state.gd`

### Remove
`played` arrays, `rest()`, `can_rest()`, `recall()`, basic-card logic, the empty-hand rule, `play_placeholder_card`.

### Player data
`{ index, name, color, tile, hand: Array[String], gear: Array[String] (max 4), gear_used_this_turn: Array[String], gold: 5, purple: 0, market_offer, lure_used_this_turn: bool }`

### Shared state
`players`, `current_index`, `actions_left`, `decks`, **`discard: Array[String]`**.

### Constants
`ACTIONS_PER_TURN = 3`, `GEAR_SLOTS = 4`, `STARTING_GOLD = 5`, `STARTING_RESOURCES = 2`. Keep `DEBUG_SHOW_SECRETS`. Keep `DEBUG_GIVE_ALL_ITEMS` (false by default) but make it give one of every GEAR and ABILITY card.

### Base actions
- `move_paths(player) -> Array` — `[NORMAL]` plus all `grants_paths` from equipped gear.
- `get_move_destinations()` — neighbors reachable with `move_paths`.
- `can_move()`, `do_move(destination)` — 1 AP.
- `can_search() / search_reason()`, `do_search()` — 1 AP, draw top card (Lucky Lure may ask top/bottom).
- `can_interact() / interact_reason()` — only on Village market. Market functions from Spec 05 stay; finishing a visit with at least one buy/sell costs 1 AP.
- `can_fight()` — always false for now, reason `"No enemies here"`.

### Cards
- `can_play_card(hand_index) / play_reason(hand_index)` — RESOURCE: `"Resources can't be played"`. GEAR/ABILITY need ≥ 1 AP plus card-specific conditions (e.g. a deck here for Trowel, Net, Manifest; an adjacent deck for Claw).
- `play_gear(hand_index, replace_slot := -1)` — 1 AP. With 4 equipped, `replace_slot` is required; the replaced gear goes to `discard`.
- `play_ability(hand_index, ...)` — 1 AP, apply effect, card goes to `discard`.
- `can_use_gear(slot) / use_gear(slot)` — active gear only, 1 AP, once per turn per gear (track in `gear_used_this_turn`).
- A player can't put down a second copy of a gear they already have equipped (Spec 04 rule).

### Gear triggers
- **Start of turn** (after the pass screen): Junk Radio popup.
- **After any move** ending on a deck tile (base Move or ability card): Map popup.
- **When Searching** (base Search or Search-tagged card drawing from the top): Lucky Lure top/bottom popup, once per turn.
- **On End turn**, before the pass screen: Scholar's Notebook popup if standing on a non-empty deck.
- Reset `gear_used_this_turn` and `lure_used_this_turn` at the start of each turn.

### Turn
`end_turn()` → Scholar's Notebook trigger if any → next player, `actions_left = 3` → pass screen → start-of-turn triggers.

### Log lines (public)
- `Player 1 moved Village market → Lake`
- `Player 1 searched Lake`
- `Player 1 played Grappling Claw (from Junkyard)`
- `Player 1 put down Reed Raft`, or `Player 1 put down Map (discarded Junk Radio)`
- `Player 1 used Metal Detector`
- Market lines as in Spec 05. End turn as before.

Secret lines (drawn card names, peeks) only with `DEBUG_SHOW_SECRETS`.

---

## 5. UI

### Bottom seat (current player)
- **Header row:** "Player 1's turn" · action pips + "2 / 3" · gold · purple · instruction line · **End turn** at the far right. **Remove the Rest button.**
- **Action bar** (left side of the card row): four big buttons stacked or in a 2×2 grid: **Move · Search · Interact · Fight**. Disabled when not possible, with the reason as a tooltip ("No deck here", "Nothing to interact with here", "No enemies here", "No actions left").
- **Hand:** full cards, overlapping when needed (Spec 08 rule). Resources look greyed out (unplayable).
- **Gear (x/4):** 4 slots. An **active** gear shows a small **"Use (1)"** button on it; after use it shows **"Used"** until next turn.
- **Remove the Played area.**

### Interactions
- **Move button** → reachable tiles highlighted → click one (Esc/right-click cancels, nothing spent).
- **Shortcut:** during your turn, when nothing else is selected, clicking a tile that is **directly connected** to yours (one step away, using your allowed paths) moves you there (1 AP). This is always **exactly one step**. Clicking a tile that is 2 or more steps away does **nothing**: the game must never plan a route or move several steps automatically. To travel further, the player clicks one tile at a time.
- **Search button** → draws immediately (or Lucky Lure popup first).
- **Interact button** → opens the market.
- **Clicking a gear card in hand** → put it down (choose a slot to replace if full).
- **Clicking an ability card** → play it (tile targets get highlighted where needed, e.g. Claw, Hoverboard, Glider; Alien Tracker shows a deck choice popup).

### Opponent strips
- **Remove** the Played section.
- Show: header (name, gold, purple, "On: …"), hand **card backs** + count, **Gear (x/4)** with mini cards. Use the freed space to make the gear mini cards a bit bigger.

### Card visuals
- Strip color and label by kind:
  - GEAR passive: slate `#5D6D7E`, label "GEAR"
  - GEAR active: slate `#5D6D7E`, label "GEAR · ACTIVE"
  - ABILITY: orange `#E67E22`, label "ABILITY"
  - RESOURCE: gold `#D4AC0D`, label "RESOURCE"
- Small grey line under the label shows the action tag, e.g. "Move" or "Search" (not for resources).

### Discard pile
A small text **"Discard: N"** at the right end of the log line, next to History. No other use yet.

---

## Out of scope
Aliens, win conditions, enemies, Fight, set collection, blueprints, Passenger Club trigger, Hologram Decoy, digging through the discard pile, the Bandit camp, Crystal mount, Oracle.

---

## How to test (human, in Godot)
1. **F5**, 4 players. Each player's hand has exactly **2 resources** (and nothing else). Gold 5, purple 0. No Walk/Rummage/Talk/Brawl, no Rest button, no Played area.
2. In the Village: **Search** is disabled ("No deck here"), **Fight** disabled ("No enemies here"), **Interact** works (market).
3. Click **Move**, pick Lake: 1 AP spent. **Search** at Lake: a card is drawn, deck count goes down. **Search** again: works again (no card needed). Actions 0/3.
4. Next turn: **Move** three times in a row (e.g. Village → Lake → Spaceship → Lake). Allowed.
5. Clicking a reachable tile directly (without pressing Move) also moves you.
6. Buy a **Reed Raft** at the market (or turn on `DEBUG_GIVE_ALL_ITEMS`). Put it down: 1 AP, it appears in Gear. Now **Move** from Lake also highlights Archeology site and Bandit camp (rivers).
7. Put down **Metal Detector**: on a deck tile it shows **Use (1)**. Use it: popup to keep 1 of 2, 1 AP. It then shows **Used** and can't be used again this turn. Next turn it's available again.
8. Play an **ability card** (e.g. Fishing Net at a deck): 1 AP, effect happens, the card leaves your hand and **Discard** goes up by 1.
9. Fill all **4 gear slots**, then put down a 5th gear: choose a slot; the replaced gear is gone (Discard +1), still 1 AP.
10. Opponent strips show hand backs and gear only, no Played.
11. Junk Radio (start of turn), Map (after moving onto a deck), Lucky Lure (on Search), Scholar's Notebook (when clicking End turn on a deck tile) all still trigger.
12. Market: sells only gear and ability cards; selling resources still gives 3 gold.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 09: free actions, gear, ability cards"
git push
```

## What to report back
- Which test steps passed or failed.
- Any red error text from the Debugger.
- How the turn **feels** now compared to before.
