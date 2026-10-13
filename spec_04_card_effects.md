# Spec 04 — Card effects, private peeks and a compact public log

## Goal
Every item card from Spec 03 gets its real effect (except Passenger Club Membership Card, which waits for gold). Cards that let you look at hidden cards use a **private popup**. Public events go into a **compact one-line log**. Resources in the decks are reduced.

Builds on Spec 03. Keep the rule: **all rules live in `game_state.gd`**, UI only displays and calls functions.

---

## Decisions from the designer
- **Grappling Claw** reaches tiles that are **grid-adjacent** (directly up, down, left or right in the 3×3 grid), no matter what paths connect them.
- **Lucky Lure + Metal Detector:** both cards are drawn from the bottom; the rejected one goes back to the bottom.
- **Public log** must be small. Screen space is precious.
- **Resources reduced by 2** in every deck (section 1).

## Assumptions (flagged)
- **A1. Scrap Hoverboard:** instead of moving step by step, all tiles reachable in **1 or 2 steps along normal paths** are highlighted at once, and the player clicks the destination. Simpler to use; the tile you pass through doesn't matter yet.
- **A2. Map** triggers only on the tile where a move **ends**, and only for the Map's owner on their own moves.
- **A3.** A player **can't equip two copies of the same gear.**
- **A4.** All gear effects are **free** (no action cost) and happen automatically when triggered. Optional ones offer a "Skip" button.
- **A5. Lucky Lure** asks "top or bottom?" only for Search cards that draw from the top. If the player picks top, the Lure is not used up for the turn.
- **A6. Alien Tracker** checks for aliens, but aliens don't exist yet, so it will never give purple in this spec. That's expected.
- **A7. Debug starting hand:** to make testing possible without hunting for cards, a debug switch gives every player **one copy of every item card** at the start (in addition to the 4 basic cards, and not taken from the decks). On by default for this spec.

---

## 1. `deck_data.gd` — new numbers
Every deck now has **12 cards**.

| tile | contents | total |
|---|---|---|
| `junkyard` | metal_detector ×2, scrap_hoverboard ×2, grappling_claw ×2, junk_radio ×2, alien_tracker ×2, scrap_metal ×**2** | 12 |
| `archeology_site` | obsidian_machete ×2, ancient_trowel ×2, scholars_notebook ×2, map ×2, relic_shard ×**4** | 12 |
| `lake` | reed_raft ×2, fishing_net ×2, lucky_lure ×2, river_pearl ×**6** | 12 |
| `spaceship` | patchwork_glider ×2, cargo_manifest ×2, passenger_club_card ×2, copper_wire ×**6** | 12 |

---

## 2. Move card effects

| card | effect |
|---|---|
| Walk | 1 tile, normal paths. (unchanged) |
| Obsidian Machete | 1 tile, `move_paths: [NORMAL, JUNGLE]` |
| Reed Raft | 1 tile, `move_paths: [NORMAL, RIVER]` |
| Patchwork Glider | 1 tile, `move_paths: [NORMAL, JUNGLE, RIVER, PLANE]` |
| Scrap Hoverboard | Any tile reachable in **1 or 2 steps** along normal paths (not the starting tile). See A1. |

- `get_move_destinations` must handle the Hoverboard (add a card field like `move_steps: 2`; default 1).
- Highlighting and clicking work exactly as in Spec 02.

---

## 3. Search card effects
"Draw" always means: take the card into the player's hand, secretly.

| card | effect |
|---|---|
| Rummage | Draw the top card. (unchanged) |
| Metal Detector | Draw the top 2 cards. Private popup: player clicks the one to **keep**; the other goes to the **bottom** of the deck. If only 1 card is left, just draw it. |
| Grappling Claw | Player chooses a **grid-adjacent** tile that has a non-empty deck (those tiles are highlighted in yellow, like movement). Draw its top card. The player does **not** move. |
| Alien Tracker | Private popup shows the top 3 cards (or fewer) of the deck here. Nothing is drawn; order is unchanged. If any of them is an alien, the player gains **1 purple** (public). |
| Ancient Trowel | Draw the top card. If it's a resource: it is **revealed** (public log), then draw 1 more card (secret, no further chain). |
| Fishing Net | Draw the **bottom** card. |
| Cargo Manifest | Draw the top card, then private popup shows the **next** top card (it stays in the deck). |

### Search rules
- Normal Search cards need a non-empty deck **here** (Spec 03 rule).
- **Grappling Claw is the exception:** it's playable if at least one grid-adjacent tile has a non-empty deck. Its `play_reason` when not playable: `"No deck next to you"`.
- Add a helper `is_alien(card_id) -> bool` in `CardData`. It returns false for every card for now; aliens are added in a later spec.

### Lucky Lure (gear)
- When the owner plays Rummage, Metal Detector, Grappling Claw, Ancient Trowel or Cargo Manifest, and the Lure has **not been used this turn**, a private popup asks: **"Lucky Lure: draw from the Top or the Bottom?"**
- If **Bottom**: every card that search draws comes from the bottom instead of the top. For Cargo Manifest the peeked "next" card is also from the bottom. For Metal Detector the rejected card still goes to the bottom. Mark the Lure as used for this turn.
- If **Top**: normal search; the Lure stays available.
- Resets at the start of each of the owner's turns.

---

## 4. Other gear effects

| gear | trigger | effect |
|---|---|---|
| Junk Radio | Start of the owner's turn, right after the pass screen is clicked away | Private popup: "Junk Radio: peek at which deck?" with a button per non-empty deck and **Skip**. Then shows that deck's top card. |
| Scholar's Notebook | The owner Rests while standing on a tile with a non-empty deck | Private popup shows the top 2 cards (or 1). Buttons: **Swap order** and **Done**. The new order is saved. |
| Map | The owner finishes a move on a tile with a non-empty deck | Private popup: "Map: the top card of the Lake deck is…" |
| Passenger Club Membership Card | — | No effect yet. Keep the "Effect coming soon" line on this card only. |

Remove the "Effect coming soon" line from every other card.

---

## 5. Private popup (new reusable scene)
`res://scenes/ui/private_popup.tscn` / `.gd`
- A centered panel over the board (not full-screen), dark background `#1E1E2A` at ~95% opacity, rounded corners.
- Shows: a **title** (e.g. "Metal Detector"), a short **message**, **0–3 card views** in a row, and **1–3 buttons**.
- Cards in the popup can be clickable (Metal Detector "choose one to keep").
- While a popup is open, everything else is blocked (no other clicks).
- It must never appear while the pass screen is showing.

---

## 6. Compact public log
- **One line** only, about 28 px tall, placed between the board and the hand area (or wherever it takes the least space without overlapping).
- Shows only the **most recent** public event, in small text, e.g. `Player 1 revealed Relic Shard (Ancient Trowel)`.
- A small **History** button at the end of the line opens an overlay with the **full** list of public events (newest at the top, scrollable) and a **Close** button.

### What goes in the public log
- Moves: `Player 1 moved Village market → Lake (Reed Raft)`
- Searches: `Player 1 searched Junkyard (Metal Detector)` — the **card used** is public, the **cards drawn** are not.
- Grappling Claw: `Player 1 grabbed from Spaceship (Grappling Claw)`
- Trowel reveal: `Player 1 revealed Relic Shard (Ancient Trowel)`
- Purple gain: `Player 1 gained 1 purple (Alien Tracker)`
- Equip, Rest, End turn (as in Spec 03).
- Gear triggers, without secrets: `Player 2 used Junk Radio`

### Never in the public log
Names of drawn cards (except the Trowel reveal), anything seen in a private popup.

The Output panel keeps printing everything as before, including `[secret]` lines when `DEBUG_SHOW_SECRETS` is on.

---

## 7. Debug starting hand
- New constant in `game_state.gd`: `DEBUG_GIVE_ALL_ITEMS = true`.
- When true, each player's starting hand is the 4 basic cards **plus one of each item card** (all ACTION and GEAR items from section 2–4, including Passenger Club card), not taken from the decks.
- When false, the hand is just the 4 basic cards.

---

## Out of scope (do NOT build yet)
Aliens, enemies, gold income or spending, selling resources, markets, Passenger Club trigger, Hologram Decoy, Talk/Brawl effects, Crystal mount, Oracle, win conditions, a general layout redesign.

---

## How to test (human, in Godot)
Start with **2 players**. Thanks to the debug hand, everyone has every item.

**Movement**
1. From Village, **Obsidian Machete** highlights the same 4 tiles as Walk (no jungle from Village). Walk to Junkyard first, then Machete highlights **Sacred altar** too.
2. **Reed Raft** from Lake highlights Village, Spaceship, Archeology site and Bandit camp (normal + river).
3. **Patchwork Glider** from Lake also highlights **Crystal mount** (plane).
4. **Scrap Hoverboard** from Village highlights 4 tiles at 1 step plus Archeology site and Spaceship at 2 steps.

**Search**
5. At Junkyard, **Metal Detector**: a popup shows 2 cards, click one; you keep it and Junkyard's deck count goes down by **1**.
6. At Village, **Grappling Claw** highlights Junkyard and Lake (grid-adjacent decks). Pick one: you draw from it and stay in the Village.
7. **Alien Tracker** at a deck: shows up to 3 cards, deck count **doesn't change**, no purple (no aliens yet).
8. **Ancient Trowel** at Archeology site: if you draw a Relic Shard, the log line shows the reveal and you get a second card.
9. **Fishing Net** draws a different card than the top (check with Alien Tracker or the `[secret]` lines in Output).
10. **Cargo Manifest**: you draw, then a popup shows the next card.

**Gear** (equip each one first, 1 action each)
11. **Lucky Lure**: next Rummage asks Top/Bottom. Pick Bottom; the following search that turn doesn't ask again. Next turn it asks again.
12. **Junk Radio**: at the start of your next turn, after the pass screen, a popup lets you pick a deck to peek at.
13. **Map**: move onto a search tile; a popup shows its top card.
14. **Scholar's Notebook**: Rest on a search tile; a popup shows the top 2 cards with **Swap order**. Swap, then check with Alien Tracker that the order changed.
15. Try to equip a second Junk Radio (if you found one): it should be refused.

**Log and screen**
16. The log is **one line**. **History** opens the full list. No drawn card names appear there, except the Trowel reveal.
17. Each deck shows **"Deck: 12"** at the start of a game.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 04: card effects, private peeks, compact log"
git push
```

## What to report back
- Which test steps passed or failed (numbers are enough).
- Any red error text from the Debugger.
- Which cards feel **strong**, **weak**, or **fun**.
- A screenshot of the full screen during a turn, so we can plan a layout cleanup.
