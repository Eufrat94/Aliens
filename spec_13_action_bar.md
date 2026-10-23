# Spec 13 — Action bar under the board

## Goal
Move the **4 action buttons** (Move, Search, Interact, Fight) and the **End turn** button into one horizontal bar in the **center of the bottom seat's header row**, directly under the board. Less mouse travel, cleaner look.

Layout only. No rule changes. Builds on Spec 12.

---

## 1. New position
In the current player's (bottom) seat **header row**:

```
[Player 1's turn ●●● 3/3 (5)(1)  message…]   [Move][Search][Interact][Fight]   ( End turn )   [Aliens]
```

- The four action buttons sit **side by side** in one row, **centered horizontally** under the board (roughly x 650–1110 at 1920 width).
- Each action button: about **110×40**, same style as now (enabled / disabled with tooltip reasons, unchanged).
- **End turn** sits right after them, with a gap of about **50 px**, so it's clearly separate. Give it a **pill shape** (fully rounded ends), a bit larger than an action button (about 150×44), with a 2 px border in the current player's color, so it stands out.
- The **Aliens** checklist button stays at the far right of the header.

## 2. Freed space
- **Remove** the old 2×2 action button block from the left of the card row.
- The **hand** now starts at the **left edge** of the card row and gets that extra width.
- Gear and Aliens groups stay on the right of the card row.

## 3. Header row text
- The left part of the header (name, pips, gold, purple) stays as it is.
- The **instruction/message line** must not overlap the buttons. If it's too long for the space left of the action bar, cut it with "…" and show the full text as a tooltip. (Alternatively it may move to a small line under the name, if that fits better.)

## 4. Everything else unchanged
All behaviour stays: disabled states and reasons, Move highlighting, Esc/right-click cancel, popups, hand-off screens, pass screen.

---

## How to test (human, in Godot)
1. **F5**: the 4 action buttons are in one row in the middle of the bottom bar, directly under the board, with a pill-shaped **End turn** right after them.
2. The old 2×2 button block on the left is gone, and the hand starts at the left edge.
3. All buttons still work and show their disabled reasons on hover (e.g. Search in the Village: "No deck here").
4. A long instruction message (e.g. during Move: "Click a highlighted tile…") doesn't overlap the buttons.
5. Nothing overlaps at 1920×1080, and with 2, 3 and 4 players.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 13: action bar under the board"
git push
```
