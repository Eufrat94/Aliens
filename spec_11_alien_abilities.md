# Spec 11 — Alien abilities

## Goal
Bring all 16 aliens to life. Active aliens get a **Use** button in the alien area; passive aliens work automatically. Using an active alien gives **1 purple to every other player on your tile**.

Builds on Spec 10b. Card texts from Spec 10 stay; remove the "Ability coming soon" line from all aliens.

---

## Design rules (reminder)
- The game never reveals hidden information a real table couldn't. (Quizazz is fine: at a real table the player would answer honestly; the game answers for them.)
- All aliens still count toward the 5-alien win, wherever they are (hand + alien area). **Check the win after every card movement**, including steals and gifts.

## Decisions from the designer (confirmed)
- **Shadow:** while Shadow is in its owner's alien area, whenever the owner's gold becomes **9 or more**, Shadow is discarded immediately.
- **Nerfoil:** when an affected player must discard, they choose on their own screen. If it's not their turn, use a hand-off screen (section 3).
- **Mimix** can copy any **active** alien on the table (any player's, including your own), never passives, never Mimix itself.
- **Stopots** blocks other players on its owner's tile from using active aliens, **including Mimix**.
- The **"+1 purple to others on your tile"** bonus applies to every active alien use, including through Mimix (once per use).

## Assumptions (flagged)
- **A1. Who gets the purple bonus:** every other player on the user's tile **at the moment the ability is used** (before any movement the ability causes).
- **A2. Costs** (1 AP, purple) are paid only when the player **confirms** the last choice. Cancelling (Esc / right-click / Cancel) during target selection costs nothing.
- **A3. Muddk counts only your own movement:** Move, Hoverboard, Glider, Wingo, and the Gloop **user**. It doesn't count for players moved by Wush or the target of a Gloop swap. For the Hoverboard, only leaving the **starting** tile counts.
- **A4.** Movement caused by aliens follows earlier rules: entering the Village refreshes that player's market offer; the **Map** triggers only for the player's **own** moves (Wingo, Gloop user), not when pushed.
- **A5. Wush and Gloop** can target any other player **anywhere** on the board.
- **A6.** When a card is given or stolen, the public log says that it happened, **not which card** (except Disko, whose card was already public).

---

## 1. Active alien framework (`game_state.gd`)
- Each player gets `aliens_used_this_turn: Array[String]` (reset at turn start).
- `can_use_alien(alien_area_index) -> bool` and `alien_use_reason(...) -> String`. Checks, with reasons:
  - card is an active alien;
  - `actions_left >= 1` → `"No actions left"`;
  - not used this turn → `"Already used this turn"`;
  - not blocked by Stopots (another player on your tile owns Stopots in their alien area) → `"Blocked by Stopots"`;
  - enough purple for its cost → `"Needs 1 purple"`;
  - at least one valid target exists → e.g. `"No other player here"`, `"Discard pile is empty"`, `"No aliens on the table"`.
- On confirmed use: pay 1 AP and costs, apply the effect, mark it used, then give **+1 purple to every other player who was on the user's tile at the start** (A1). Log it.
- After every effect: run the **win check**, the **Shadow check**, and the **Skrim announcement** if Skrim changed hands.

## 2. Each alien

| alien | cost | targets / flow | effect |
|---|---|---|---|
| **Wingo** | 1 purple | Highlight **every tile** except the current one; click one. | Move there. Muddk toll applies when leaving. Map triggers. |
| **Magnet** | — | Needs ≥1 other player **on your tile** with ≥1 card. | For each such player, in turn order: **hand-off screen** (section 3), they pick 1 card from their hand, it goes to the user's hand. |
| **Disko** | — | Needs a non-empty discard pile. | Top card of the discard pile goes to the user's hand. Log names the card. |
| **Mani** | 1 purple | — | +5 gold. |
| **Ugg** | 3 purple | Popup with every alien in **any** alien area (including your own), shown as cards with their owner's name; click one. | That alien goes to the discard pile. |
| **Wush** | — | Popup: pick another player. Then highlight the tiles **grid-adjacent** to **their** tile; click one. | Move that player there. No Muddk toll for them. |
| **Shadow** | — | Needs at least one other player with ≥1 gold. | Every other player with ≥1 gold gives the user 1 gold. Then the Shadow check. |
| **Pucky** | — | Popup: pick another player with ≥1 card in hand. | A **random** card from their hand goes to the user's hand (only the user sees which). Then the user picks 1 card from their own hand to discard (it may be the stolen one). |
| **Pikupiku** | 1 purple | Needs another player **on your tile** with ≥1 card. If several, pick one in a popup. | Private popup shows that player's whole hand (only the user sees it). |
| **Quizazz** | — | Popup: pick another player. | The game checks if that player has an alien **in hand** (not alien area). A big **public** banner: "Player 3 has an alien in hand: YES" or "…: NO". YES → user +1 purple, NO → user +1 gold. |
| **Mimix** | discard 1 card + the copied alien's cost | Step 1: pick a card from your hand to discard. Step 2: popup with every **active** alien on the table (any alien area, not Mimix), click one. Then follow that alien's flow. | Works exactly as if the user had used the copied alien. Counts as using **Mimix** (once per turn); the copied alien is **not** marked used. The purple bonus happens once. |
| **Gloop** | give 1 purple to the target | Popup: pick another player. | User gives that player 1 purple, then the two swap tiles. Muddk toll applies to the **user** if leaving a Muddk tile (A3). Map triggers for the user only. |

Mimix with no cards in hand → `"Need a card to discard"`. If there are no copyable aliens → `"No active aliens on the table"`.

## 3. Hand-off screen (new, reusable)
Used when **another** player must make a secret choice during someone's turn (Magnet, Nerfoil).
1. Full-screen pass screen: **"Player 3, take the device."** + reason (e.g. "Player 1 used Magnet: choose a card to give."). Click to continue.
2. A popup shows **only Player 3's hand**; they click a card. No other UI is usable.
3. Full-screen pass screen: **"Pass the device back to Player 1."** Click to continue.
4. Play continues on Player 1's turn.

Everything else is hidden during these screens, exactly like the normal pass screen (layer 30).

## 4. Passive aliens

### Stopots
See the framework check above. Only **other** players on the owner's tile are blocked; the owner isn't.

### Muddk
- Whenever a player **other than the owner** leaves the owner's tile by their own movement (A3), they pay the owner **1 gold** if they have any. If they have 0 gold, they move anyway and pay nothing.
- Log: `Player 2 paid 1 gold to Player 4 (Muddk)`.

### Nerfoil
- While Nerfoil is in its owner's alien area: whenever **another** player would gain a card while holding **7 or more** cards, they first **discard 1 card of their choice** (to the discard pile), then gain the new card.
- If that player is the current player, they choose in a normal popup. Otherwise use the hand-off screen.
- Applies to every way of gaining cards: Search, ability cards, Metal Detector, market (per card bought), Magnet, Pucky, Disko.
- Log: `Player 2 discarded a card (Nerfoil)`. The discarded card is visible on the discard pile anyway.

### Shadow check
While Shadow is in its owner's alien area: after **any** change to the owner's gold, if gold ≥ 9, Shadow goes to the discard pile. Log: `Player 1's Shadow left (9+ gold)`.

## 5. UI
- **Played active aliens** in the current player's alien area get a **"Use"** button, showing the cost: "Use (1)" or "Use (1 + 1 purple)". Disabled with the reason as a tooltip. After use: **"Used"** until next turn.
- Passive aliens show **"Passive"**, no button. Skrim stays unplayable.
- Tile and player choices reuse the existing highlight and popup systems. Every choice step has **Cancel** (or Esc / right-click).
- New public banners (Quizazz answer) reuse the Skrim banner style and close on click.

## 6. Debug helpers
- `DEBUG_PLAYER_ALIENS: Dictionary` — player index → list of alien ids placed **directly in that player's alien area** at game start (removed from the decks). Example: `{0: ["wingo", "mimix"], 1: ["stopots"]}`. Empty by default.
- `DEBUG_START_PURPLE: int = 0` — starting purple for every player.
- The missing alien must never be one of the debug aliens (pick it from the rest).

---

## Out of scope
Selling aliens at Bandit camp, the Sacred altar guess, enemies, Passenger Club trigger, set collection.

---

## How to test (human, in Godot)
Use `DEBUG_PLAYER_ALIENS` and `DEBUG_START_PURPLE = 5` (ask Cursor to set them for each test).

1. **Wingo** (P1): use it → every tile highlighted, pick Sacred altar → you're there, purple −1, AP −1. A second use the same turn is refused ("Already used this turn").
2. **Purple bonus:** P1 and P2 on the same tile, P1 uses any active alien → P2 gets +1 purple. P3 elsewhere gets nothing.
3. **Stopots** (P2) on P1's tile: P1's aliens show "Blocked by Stopots". P2 can still use their own aliens. When P1 moves away, P1 can use them again.
4. **Magnet:** P1 and P2 on the same tile. Use it → hand-off screen for P2, P2 picks a card, pass back → card in P1's hand.
5. **Disko:** discard something, use Disko → the top card goes to your hand.
6. **Mani:** purple −1, gold +5.
7. **Ugg:** P2 has a played alien → Ugg discards it (purple −3). P2's alien count drops.
8. **Wush:** push P3 to a grid-adjacent tile; no Muddk toll for P3.
9. **Shadow:** others pay 1 gold each. Then raise P1's gold to 9+ (e.g. Mani): Shadow is discarded automatically.
10. **Pucky:** steal from P2 (random), then discard 1 of your cards.
11. **Pikupiku:** on a tile with P2 → private popup with P2's hand; purple −1.
12. **Quizazz:** pick P2 → public YES/NO banner, correct reward.
13. **Mimix:** discard a card, copy another player's **Mani** → +5 gold, purple −1. Mimix shows Used; the original Mani isn't marked used.
14. **Gloop:** swap with P3 anywhere on the board; P3 gets 1 purple.
15. **Muddk** (P2): P1 leaves P2's tile → pays 1 gold. With 0 gold, P1 can still leave.
16. **Nerfoil** (P2): P1 with 7 cards searches → must discard 1 first.
17. **Win:** with 4 aliens, steal or receive a 5th via Pucky/Magnet/Disko → win screen appears immediately.
18. **Skrim:** steal Skrim with Pucky → SKRIM banner and the badge moves to the new owner.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 11: alien abilities"
git push
```

## What to report back
Which steps passed, any errors, and which aliens feel too strong, too weak, or most fun.
