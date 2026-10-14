# Spec 06 — Table layout (visual overhaul, first version)

## Goal
Make the screen look like a **table**: the board in the **center**, the **current player** seated at the **bottom**, and every other player seated **around** the board. Everyone's **played cards**, **gear**, **gold** and **purple** are visible next to their seat. Use the **whole screen**.

This is a **layout-only** spec. **No game rules change.** `game_state.gd` should need no changes, except perhaps small read-only helper functions.

Builds on Spec 05.

---

## Assumptions (flagged)
- **A1. Resolution:** base size **1920×1080**, stretch mode `canvas_items`, aspect `keep`. The window starts **maximized**. **F11** toggles fullscreen.
- **A2. Seats rotate every turn.** Whoever's turn it is always sits at the bottom; the others keep their order around the table. This matches passing the device around.
- **A3. Clockwise order:** the **next** player in turn order sits to the **left** of the current player, then around the top, and the player who just had their turn sits on the **right**.
- **A4.** The right-side info panel from Spec 02 is **removed**. Everything it showed now lives in the seats.
- **A5.** Opponents' cards are shown as **mini cards**. Hovering any card (anywhere) shows a large preview so the text is readable.
- **A6.** No art or icons from files: shapes, colors and text only.

---

## 1. Screen regions (at 1920×1080)

```
┌─────────────┬────────────────────────────────┬─────────────┐
│             │          TOP SEAT(S)           │             │
│    LEFT     ├────────────────────────────────┤    RIGHT    │
│    SEAT     │                                │    SEAT     │
│             │             BOARD              │             │
│             │                                │             │
│             ├────────────────────────────────┤             │
│             │        log line + legend       │             │
├─────────────┴────────────────────────────────┴─────────────┤
│                 BOTTOM SEAT (current player)                │
└─────────────────────────────────────────────────────────────┘
```

| region | approx. position |
|---|---|
| Left seat | x 0–380, y 0–760 |
| Right seat | x 1540–1920, y 0–760 |
| Top seat(s) | x 380–1540, y 0–190 |
| Board | x 380–1540, y 190–720 (scale the board to fit, including both plane curves) |
| Log line | x 380–1540, y 725–760 |
| Bottom seat | x 0–1920, y 765–1080 |

Exact numbers are flexible. Rules: **nothing overlaps**, the **board is centered horizontally**, and it's **as large as possible** in its region.

- The **legend** becomes small and sits in a corner of the board region (e.g. bottom-left), so it doesn't steal space.
- Unused seat regions (fewer than 5 players) stay empty, with the background color.

---

## 2. Who sits where

Let `offset = (player_index - current_index + player_count) % player_count`. Offset 0 is the current player (bottom). The other offsets fill these seats in order:

| players in game | offset 1 | offset 2 | offset 3 | offset 4 |
|---|---|---|---|---|
| 2 | top | — | — | — |
| 3 | left | right | — | — |
| 4 | left | top | right | — |
| 5 | left | top-left | top-right | right |

- With 5 players the top region is split into two halves: **top-left** and **top-right**.
- Seats are rebuilt every time the turn changes.

---

## 3. Opponent seat panel (new scene)
`res://scenes/ui/player_seat.tscn` / `.gd`, used for every non-current player.

- Dark panel `#2B2B3A`, rounded corners, a **4 px border in the player's color**.
- **Header row:** player name in their color · **gold token** · **purple token** · **hand count**.
  - **Gold token:** a filled circle `#D4AC0D` (about 26 px) with the number in dark text inside.
  - **Purple token:** same, color `#8E44AD`, white number.
  - **Hand count:** a small card-back rectangle (dark with a light border) with the number inside, e.g. `5`. Only the count, never names.
- Small grey line: **"On: Lake"**.
- **Played:** label, then mini cards in a wrapping row (`HFlowContainer`). "—" if empty.
- **Gear:** label, then up to 3 mini cards. Empty slots shown as faint outlines.
- Must work both **tall and narrow** (left/right seats) and **wide and short** (top seats). Wrapping containers should handle both.
- If too many played cards to fit, the area scrolls instead of overflowing.

### Mini card
- About **72×100**. Colored strip at the top (same colors as full cards), card **name** in small text below. No rules text.
- Hover → large preview (section 5).

---

## 4. Bottom seat (current player)
Full width, height ~315, same dark panel with a border in the current player's color.

**Header row (left to right):**
- **"Player 1's turn"** in the player's color, large.
- **Actions:** 3 round pips, filled = available, hollow = used. Plus text "2 / 3".
- **Gold** and **purple** tokens (same as opponent seats, slightly larger).
- **Instruction / message line** (the "Choose a card…", "You found: …" text from earlier specs), small text.
- At the far right: **Rest (1 action)** and **End turn** buttons.

**Card row (below the header), three groups side by side:**
1. **Hand** — full-size card views (about 130×180). Scrolls sideways if there are too many. Takes the most space.
2. **Played** — full-size but faded, as before.
3. **Gear (x/3)** — 3 slots, as before.

All existing interactions (clicking cards, highlights, cancel with Esc/right-click, gear swap, market panel, private popups) must keep working exactly as before.

---

## 5. Card hover preview
- Hovering **any** card for ~0.3 s (hand, played, gear, mini cards, market panel, popups) shows a **large preview** of it (about 220×310) with full name, type strip and rules text.
- The preview appears next to the cursor and stays fully on screen.
- It disappears when the mouse leaves the card.
- It never blocks clicks.

---

## 6. Tokens on the board
Unchanged from earlier specs, but they must still be readable at the new board scale. Make them a bit bigger if needed.

---

## 7. Popups and panels
The pass screen, private popups and market panel stay as they are and appear **centered over the board region**. The pass screen still covers the **whole** screen.

---

## Out of scope (do NOT build yet)
New rules, new cards, card art, icons from files, animations, sound, themes, a main menu.

---

## How to test (human, in Godot)
1. **F5**: the window opens **maximized**, filling the screen. **F11** toggles fullscreen and back.
2. Start with **2 players**: board centered, Player 1 at the **bottom**, Player 2 at the **top**. Left and right regions are empty.
3. Restart with **3**: Player 2 on the **left**, Player 3 on the **right**.
4. Restart with **4**: P2 left, P3 top, P4 right.
5. Restart with **5**: P2 left, P3 top-left, P4 top-right, P5 right. Nothing overlaps; the board and both plane curves are fully visible.
6. In the 5-player game, end Player 1's turn. Now Player 2 is at the **bottom**, P3 left, P4 top-left, P5 top-right, and **P1 on the right**.
7. Play some cards and equip a gear as Player 2, end turn. In Player 3's view, Player 2's seat shows the **played mini cards** and the **gear**.
8. Gold and purple tokens show **5** and **0** for everyone. Buy something at the market: the gold token on your bottom seat drops, and on the next player's view your seat shows the new number.
9. Hand count on opponent seats matches their real number of cards (check by switching turns).
10. Hover a **mini card** on an opponent's seat: a large readable preview appears. It also works on cards in your hand and in the market panel.
11. Action pips: start full (3), empty one at a time as you act, refill next turn.
12. Every earlier interaction still works: moving, searching, the market, gear swap, popups, the History log.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 06: table layout"
git push
```

## What to report back
- A screenshot with **4 or 5 players** after a few rounds, so every seat has something in it.
- Anything that feels too small, too big, crowded or empty.
- Any red error text from the Debugger.
