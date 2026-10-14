# Spec 08 — Table layout v3: seats around the table, no scrolling

## Goal
Replace the Spec 07 corner layout with a layout that imitates a real table:
- The **current player** sits at the **bottom** in a wide, low strip.
- The other players sit **left, top and right** of the board, each in a strip along that edge.
- **Left and right strips are rotated sideways**, so their cards face their own edge of the table, like at a real table.
- The **top strip stays upright** (not upside down), for readability.
- **No scrolling anywhere.** When cards don't fit, they **overlap** like a fanned hand.

Layout only. **No rule changes.** Max 4 players stays.

Builds on Spec 07.

---

## Decisions from the designer
- Table feel is wanted. Sideways side seats are acceptable; the top seat must not be upside down.
- If sideways seats turn out hard to read, switch them to upright **without a new spec** (see the switch in section 4).
- No scrolling.

## Assumptions (flagged)
- **A1. Seats rotate every turn again:** whoever's turn it is always sits at the bottom. The other players keep their clockwise order: the **next** player on the **left**, then **top**, then **right**.
- **A2.** With 2 players the opponent sits at the **top**. With 3 players: **left** and **right**.
- **A3.** The hover preview of any card is always shown **upright**, also for cards in rotated seats.

---

## 1. Screen regions (at 1920×1080)

```
┌──────┬──────────────────────────────────────┬──────┐
│      │              TOP SEAT                │      │
│      ├──────────────────────────────────────┤      │
│ LEFT │                                      │RIGHT │
│ SEAT │               BOARD                  │ SEAT │
│(side-│                                      │(side-│
│ ways)├──────────────────────────────────────┤ ways)│
│      │              log line                │      │
├──────┴──────────────────────────────────────┴──────┤
│              BOTTOM SEAT (current player)          │
└────────────────────────────────────────────────────┘
```

| region | approx. position |
|---|---|
| Left seat | x 0–170, y 0–830 |
| Right seat | x 1750–1920, y 0–830 |
| Top seat | x 170–1750, y 0–170 |
| Board | x 170–1750, y 170–795 |
| Log line | x 170–1750, y 795–830 |
| Bottom seat | x 0–1920, y 830–1080 |

- Exact numbers are flexible. Rules: nothing overlaps, the board is as large as possible, and **the three opponent seats have the same depth** (about 170 px).
- Remove the Spec 07 corner seats. Keep `start_game` limited to 2–4 players.

## 2. Board
- Scale the board to fill its region as well as possible, including both plane curves and labels.
- The board region is now **wide and not very tall**. To use the width, it's allowed to make the tiles **wider** and the **horizontal gaps** bigger, so the board stretches sideways instead of leaving empty space. Keep the vertical layout readable.
- Tile text and tokens stay clearly readable. Legend small, in a free corner.
- Private popups and the market panel appear centered over the board. The pass screen still covers the whole screen.

## 3. Opponent strip (one scene, used for left, top and right)
Build it as a **horizontal strip**: long side = length of its region, short side = 170 px. Contents, left to right in one row under a header line:

- **Header line:** name (player color) · gold token · purple token · "On: Lake" (small, grey).
- **Hand:** card backs (about 56×80), one per card, plus the count, e.g. "5 cards".
- **Played:** mini cards (about 86×120) with the colored strip and the card name.
- **Gear (x/3):** 3 slots, mini card size, empty slots as faint outlines.

Thin border (2 px) in the player's color, background `#2B2B3A`.

## 4. Rotation of the side seats
- The **top** strip is placed normally (not rotated).
- The **left** strip is the same strip rotated **+90°** (clockwise), so its **header and card bottoms face the left screen edge**, where that player "sits".
- The **right** strip is rotated **−90°**, so it faces the right screen edge.
- Clicking and hovering must still work on rotated cards (Godot handles input on rotated Controls; make sure the pivot and position are set so the strip exactly fills its region).

### Switch
Add a constant `ROTATE_SIDE_SEATS = true` (in the HUD or a small `ui_config.gd`).
- **true:** left and right strips are rotated as above.
- **false:** left and right seats are **upright**, laid out top to bottom instead: header, then hand backs, then Played (mini cards wrapping into rows), then Gear. Still no scrolling (overlap if needed).

## 5. Bottom seat (current player)
Full width, about 250 px tall, **6 px border** in the player's color, background `#3A3A52`.

- **Header row:** "Player 1's turn" in the player's color · 3 action pips + "2 / 3" · gold token · purple token · instruction/message line · at the far right **Rest (1 action)** and **End turn**.
- **Card row**, left to right:
  1. **Hand:** full cards about 130×180. Takes most of the width.
  2. **Played:** mini cards (86×120), faded as before.
  3. **Gear (x/3):** 3 slots, mini card size.
- All existing interactions keep working (playing cards, highlights, cancel, gear swap, market, popups, History).

## 6. No scrolling: overlap instead
Applies to **every** row of cards (hand, played, gear, card backs), in every seat:
- Cards keep their normal size.
- If a row has more cards than fit side by side, the spacing between them shrinks so they **overlap**, like a fanned hand. Later cards lie on top of earlier ones.
- Each card's **name stays visible** in the uncovered part where possible (the strip and name are at the top of the card, so overlap sideways from the left).
- Hovering a card lifts it a little (raised 10 px) and shows the large upright preview.
- Remove all `ScrollContainer`s from the seats.

## 7. Hover preview
Unchanged from Spec 06, except it must always appear **upright**, fully on screen, even when the hovered card is in a rotated seat.

---

## Out of scope
Rule changes, new cards, art, animations.

---

## How to test (human, in Godot)
1. **F5**, **4 players**: Player 1 at the bottom, Player 2 on the left (rotated sideways, facing the left edge), Player 3 at the top (upright), Player 4 on the right (rotated, facing the right edge).
2. End turn: Player 2 is now at the bottom, P3 left, P4 top, **P1 right**.
3. **2 players**: the opponent is at the top. **3 players**: opponents left and right.
4. The board is bigger and wider than before, fills the middle, and both plane curves are visible. Nothing overlaps.
5. Give one player a big hand (buy several cards at the market, ~10 cards): the hand **overlaps** like a fan, **no scrollbar**, and every card can still be hovered and clicked.
6. Play many cards so a Played row gets crowded: it overlaps, no scrollbar.
7. Hover a mini card in the **left** and **right** seats: the big preview appears upright.
8. Set `ROTATE_SIDE_SEATS = false`, run again: side seats are upright and still readable, no scrolling.
9. Everything else still works: moving, searching, market, gear swap, popups, History.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 08: table layout v3"
git push
```

## What to report back
A screenshot with 4 players after a few rounds, and whether the sideways seats are readable enough.
