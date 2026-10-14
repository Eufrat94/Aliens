# Spec 10b — Visible discard pile

One small change: the discard pile's top card becomes public.

---

## Discard pile top card is visible
The discard pile is **face up**, like on a real table: everyone can see the **top card** (the most recently discarded one). Only the top card is visible; the rest of the pile stays hidden.

- Next to the "Discard: N" counter, show the **top card** as a small mini card (same style as mini cards in seats). If the pile is empty, show a faint empty outline with "Empty".
- Hovering it shows the large preview, like any card.
- Since the log line is thin, it's fine to move the discard pile to a better free spot (for example a corner of the board region, near the legend), as long as nothing overlaps and it's clearly labeled **"Discard (N)"**.
- Add a helper in `game_state.gd`: `discard_top() -> String` (returns `""` if empty).

---

## How to test (human, in Godot)
1. Play an ability card: it appears face up on the discard pile, and the counter goes up.
2. Discard another card (another ability card, or replace a gear): the new card is now on top.
3. Hover the top card: the big preview shows.
4. On the next player's turn, the top card is still visible (it's public).

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 10b: visible discard pile"
git push
```
