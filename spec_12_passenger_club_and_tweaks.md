# Spec 12 — Passenger Club Membership Card, starting purple, resource price

## Goal
1. **Passenger Club Membership Card** gets its effect: when a player leaves your tile, you may pay 1 gold to move with them.
2. Every player starts with **1 purple** (was 0).
3. Resources sell for **1 gold** at the market (was 3).

Builds on Spec 11.

---

## 1. Starting purple
- `STARTING_PURPLE = 1` in `game_state.gd`. Every player starts with 1 purple.
- If `DEBUG_START_PURPLE` is above 0, it overrides this value (for testing).

## 2. Resource sell price
- `MARKET_SELL_PRICE = 1`. The market panel's sell buttons say **"Sell — 1 gold"**. Buying stays at 2 gold.

## 3. Passenger Club Membership Card

### Rules (decided)
- **Trigger:** a player **leaves a tile by their own choice** (Move, Scrap Hoverboard, Patchwork Glider, Wingo, the Gloop **user**). **Not** when they are moved by someone else (Wush, the Gloop **target**).
- **Who can follow:** every **other** player standing on the tile being left who has the card **in their gear** and **at least 1 gold**.
- **Choice:** each such player decides whether to follow. Following costs **1 gold**, paid to the bank, and **no action points**.
- **Destination:** the follower ends up on the **same tile** where the moving player's move **ends**, whatever paths were used (jungle, river, plane, Wingo's flight). For the Hoverboard, that's the final tile, not the tile in between.
- **No limit:** it can trigger every time someone leaves your tile, as long as you have gold.
- **Muddk:** following counts as the follower **leaving by their own choice**, so a Muddk toll applies to them too, if they're leaving a Muddk owner's tile (and the owner isn't them).

### Assumptions (flagged)
- **A1.** Followers are asked one at a time, in turn order starting after the current player.
- **A2.** A follower's movement does **not** trigger other Passenger Club cards (no chains).
- **A3.** The **Map** doesn't trigger for followers (it's not their turn, so a private peek would need extra hand-offs). Entering the Village **does** refresh their market offer.
- **A4.** The follow decision is public (gear is public), but it's made on the **hand-off screen** so the follower doesn't see the current player's hand.

### Flow
1. The current player's move finishes (including their own Map popup, Muddk toll, etc.).
2. For each eligible follower (A1): use the **hand-off screen** from Spec 11:
   - "Player 3, take the device." + "Player 1 is leaving Lake for Spaceship."
   - Popup (no hand shown): **"Follow for 1 gold?"** with **Follow** and **Stay** buttons.
   - "Pass the device back to Player 1."
3. If they follow: pay 1 gold (and any Muddk toll), move their token. Log: `Player 3 followed Player 1 to Spaceship (Passenger Club, -1 gold)`. If they stay, log nothing.
4. Continue the current player's turn.

### Card text
Remove "(Effect coming soon)". The text stays: *"When a player moves away from your tile, you may pay 1 gold to move with them."*

---

## Out of scope
Anything else.

---

## How to test (human, in Godot)
1. **F5**: every player starts with **1 purple** and 5 gold.
2. Sell a resource at the market: **+1 gold**.
3. Give Player 2 a Passenger Club card in gear (`DEBUG_GIVE_ALL_ITEMS`, then put it down). Put P1 and P2 on the same tile. P1 moves away → hand-off screen for P2 → **Follow** → P2 is on P1's new tile, P2's gold −1, the log shows it.
4. Same again, but P2 picks **Stay**: P2 stays, nothing is paid.
5. P2 with **0 gold**: no hand-off screen, P1 just moves.
6. P1 uses a **Scrap Hoverboard** (2 steps) → P2 can follow and ends on the **final** tile.
7. P1 uses **Wingo** → P2 can follow to that tile.
8. P1 gets moved by **Wush** (from P3): P2 is **not** asked.
9. Follower leaving a **Muddk** tile: pays 1 gold for the card and 1 gold toll.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 12: Passenger Club card, starting purple, resource price"
git push
```
