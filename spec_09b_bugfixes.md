# Spec 09b — Bugfixes after Spec 09

Fix these three bugs. No new features, no rule changes.

---

## Bug 1 — Current player's cards visible on the pass screen
**What happens:** after clicking End turn, the "pass the device" screen appears, but some of the previous player's cards are still visible on it.

**Expected:** the pass screen hides **everything**. Nobody can see any hand during it.

**Fix:**
- Before the pass screen is shown, **clear the bottom seat's hand display** (and hide the hover preview and any popup).
- Only fill in the next player's hand **after** the pass screen is clicked away.
- Make sure the pass screen is on the **topmost layer** (see the layer order in Bug 2), fully opaque, and covers the whole window.

## Bug 2 — Hover preview appears behind small cards
**What happens:** hovering a card shows the large preview, but other cards are drawn on top of it.

**Expected:** the preview is always in front of everything except the pass screen.

**Fix:** use explicit `CanvasLayer`s so the drawing order is guaranteed, instead of relying on node order or `z_index`:

| layer | contents |
|---|---|
| 0 | board, seats, hand, log (normal game) |
| 10 | private popups, market panel |
| 20 | hover preview |
| 30 | pass screen |

- The hover preview must also hide whenever the pass screen or a popup opens.
- Check that no card or seat element uses a `z_index` or `top_level` setting that lets it escape its layer.

## Bug 3 — All actions greyed out with actions left
**What happens:** Player 1 is on **Junkyard** (deck has 10 cards) with **1 / 3** actions left. Move, Search, Interact and Fight are **all** greyed out, and the hand can't be used. The last log line is `Player 1 used Map`, so it probably happened right after the **Map** popup closed.

**Expected:** Move (to Archeology site or Village market) and Search should be available. Interact and Fight greyed out is correct.

**Likely cause:** some "busy / popup open / waiting for a choice" state is not reset after the Map popup (or another gear trigger) closes, so the UI keeps everything disabled.

**Fix:**
- Find where the UI decides that actions are blocked, and make sure **every** popup and trigger (Map, Junk Radio, Lucky Lure, Scholar's Notebook, Metal Detector, Alien Tracker, Cargo Manifest, market) resets that state when it closes, **including** when it closes via Esc, right-click or Skip.
- After any popup closes, refresh the action buttons.
- Add a check: if the player has actions left but no popup is open, the action buttons must reflect `can_move()` / `can_search()` / etc., never a stale "busy" state.
- Print a warning to Output if the UI thinks a popup is open but none is visible. That helps catch this kind of bug in the future.

---

## How to test (human, in Godot)
1. End a turn with cards in hand: the pass screen shows **no cards at all**. After clicking it, the next player's hand appears.
2. Hover a card in your hand, a gear card, and a mini card in an opponent strip: the big preview is **in front** of everything.
3. Put down a **Map**, then move onto a search tile. The Map popup shows the top card. Close it. **Move and Search are still available** if you have actions left.
4. Repeat step 3 with the other popups: Junk Radio (start of turn), Lucky Lure (Search), Metal Detector (Use), Alien Tracker, Cargo Manifest, and the market (open and Leave). After each one closes, the action buttons work.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 09b: bugfixes"
git push
```
