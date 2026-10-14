# Spec 07 — Table layout v2: four equal corner seats, fixed positions, max 4 players

## Goal
Replace the Spec 06 layout with a simpler one that's easier to read while testing:
1. The game supports **2–4 players** (no more 5).
2. **Four equal player areas** in the four **corners** of the screen, **including the current player**.
3. Seats are **fixed**: each player stays in the same corner all game (no rotating).
4. The current player's area is **highlighted** and shows their hand.
5. The **board** gets the full screen height in the middle, so it's as big as possible.

Layout only. **No rule changes**, except the player limit and one card text fix.

Builds on Spec 06.

---

## Decisions from the designer
- Readability for one person playing all seats matters more than imitating a real table.
- Max 4 players.

## Assumptions (flagged)
- **A1. Fixed seats by player number**, clockwise: **Player 1 bottom-left, Player 2 top-left, Player 3 top-right, Player 4 bottom-right.** With 2 or 3 players, the unused corners stay empty.
- **A2.** The current player's hand is shown **inside their own corner**. Other corners show only the **backs** of their cards (count visible, contents secret).
- **A3.** The pass screen between turns stays exactly as it is.

---

## 1. Screen regions (at 1920×1080)

```
┌──────────┬────────────────────────┬──────────┐
│ PLAYER 2 │                        │ PLAYER 3 │
│          │                        │          │
├──────────┤         BOARD          ├──────────┤
│ PLAYER 1 │                        │ PLAYER 4 │
│          ├────────────────────────┤          │
│          │        log line        │          │
└──────────┴────────────────────────┴──────────┘
```

| region | approx. position |
|---|---|
| Top-left seat (P2) | x 0–400, y 0–540 |
| Bottom-left seat (P1) | x 0–400, y 540–1080 |
| Top-right seat (P3) | x 1520–1920, y 0–540 |
| Bottom-right seat (P4) | x 1520–1920, y 540–1080 |
| Board | x 400–1520, y 0–1040 |
| Log line | x 400–1520, y 1040–1080 |

- All four seats are **the same size** (about 392×532 with small margins).
- **Remove** the full-width bottom seat from Spec 06 and the seat-rotation logic.
- Exact numbers are flexible. Rules: nothing overlaps, all four seats equal, board as large as possible.

## 2. Board fills its region
- Scale the board to fill the board region as much as possible (keeping proportions), **including both plane curves and labels**, centered.
- If the plane curves limit the size, the curve bulge may be reduced a little, as long as the Sacred altar ↔ Spaceship curve doesn't pass behind Bandit camp.
- Tile text (name, type, "Deck: N") and tokens must be **clearly readable**: increase font and token sizes to match the bigger board.
- The legend stays small, in a free corner of the board region.
- Private popups and the market panel appear centered over the **board region**. The pass screen still covers the **whole** screen.

## 3. Setup screen
Buttons **2, 3, 4** only. Remove the 5 button. `start_game` must refuse more than 4 players.

## 4. Player seat (one scene for all four corners)
Every seat uses the **same scene and same layout**, top to bottom:

1. **Header row:** player name (in their color) · gold token · purple token · **"On: Lake"** (small, grey).
2. **Turn row:** only filled in for the current player: **3 action pips** + "2 / 3" + the instruction/message line (e.g. "You found: Map"). For other players this row is empty but keeps its height, so all seats stay aligned.
3. **Hand:**
   - **Current player:** their hand cards, about **110×150**, in one row that **scrolls sideways** when there are more than fit. All existing click interactions work here.
   - **Other players:** small **card backs** (about 50×70, dark with a light border), one per card, overlapping if needed to fit, plus the number, e.g. **"5 cards"**.
4. **Played:** mini cards (about 72×100) in one row, scrolling sideways if needed. "—" if empty.
5. **Gear (x/3):** 3 slots of mini card size. Empty slots shown as faint outlines.
6. **Buttons row:** **Rest (1 action)** and **End turn**, shown only in the current player's seat.

### Current player highlight
- Current seat: **6 px border** in the player's color, a slightly lighter background (`#3A3A52`), and a small **"YOUR TURN"** tag in the header.
- Other seats: **2 px border** in the player's color, normal background (`#2B2B3A`).

### Mini cards and hover
- Mini cards keep the colored strip and the card name (readable without hovering).
- The hover preview from Spec 06 still works on every card, including mini cards and the current player's hand.

## 5. Card text fix
In `card_data.gd`, Talk's text becomes: **"Use one action at this location (e.g. the market)."** Brawl keeps "(Not active yet)".

---

## Out of scope
Rule changes (other than the 4-player limit), new cards, art, animations.

---

## How to test (human, in Godot)
1. **F5**: the setup screen offers only **2, 3, 4**.
2. Start **4 players**: P1 bottom-left, P2 top-left, P3 top-right, P4 bottom-right. All four seats are **the same size**. The board fills the middle from top to almost bottom, with the log line underneath.
3. Player 1's seat is **highlighted** (thick border, "YOUR TURN"), shows their **4 cards face up**, action pips, Rest and End turn. The other three seats show **4 card backs** each.
4. End turn: the highlight moves to **Player 2 (top-left)**; nobody changes corners. Player 1's seat now shows card backs.
5. Play several cards as one player: the Played row fills and scrolls sideways instead of overflowing. Equip a gear: it appears in the Gear row and is visible after the turn passes.
6. Gold and purple tokens update after buying at the market.
7. Tile names, deck counts and tokens are easy to read. Both plane curves are fully visible. Nothing overlaps.
8. Start a **2-player** game: only bottom-left and top-left seats are used; the right corners are empty.
9. Popups and the market panel appear over the board; the pass screen covers everything.
10. Talk no longer says "(Not active yet)".
11. Everything else still works: moving, searching, market, gear swap, popups, History, hover previews.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 07: four equal corner seats, max 4 players"
git push
```

## What to report back
A screenshot with 4 players after a few rounds, and how it feels to follow the game.
