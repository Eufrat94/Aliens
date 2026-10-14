# Spec 05 — Starting gold and the Village market

## Goal
1. Every player starts with **5 gold**.
2. The **Village market** becomes the first real Interact location: players can **buy** item cards and **sell** resources there.
3. Talk (and any future INTERACT card) can only be played where there is something to interact with.

Builds on Spec 04. Keep the rule: **all rules live in `game_state.gd`**, UI only displays and calls functions.

---

## Rules implemented in this spec

### R1 — Starting gold
Each player starts with **5 gold** (purple still 0).

### R2 — Interact only where there's something to do
- An INTERACT card can only be played on a tile with an interaction.
- For now the only one is the **Village market**.
- Elsewhere the card is greyed out, and its `play_reason` is `"Nothing to interact with here"`.

### R3 — The market offer
- Each player has their own **market offer** of **3 random item cards**.
- A new offer is generated **every time that player enters the Village**, i.e. ends a move there.
- Players start the game in the Village, so each player gets an offer at game start.
- The offer **stays the same** while the player remains in the Village, even across turns.
- A bought card leaves the offer; its slot stays **empty** until the player leaves and enters again.
- Passing through the Village with the Scrap Hoverboard (not stopping) does **not** count as entering.

### R4 — Visiting the market (1 action)
Playing Talk (or any INTERACT card) in the Village opens the **market panel**. In one visit the player may:
- **sell** any number of resource cards from their hand, **3 gold each**;
- **buy** any number of cards from their offer, **2 gold each**, if they have enough gold.

Selling and buying can be mixed in any order during the visit; gold updates immediately.

- The whole visit costs **1 action**, however much is bought and sold.
- The INTERACT card goes to the played area as usual.
- If the player closes the market **without buying or selling anything**, the visit is cancelled: no action is spent and the card stays in hand.

---

## Assumptions (flagged)
- **A1. What the market sells:** random picks from the **15 item cards** (the same list as the debug hand: all ACTION and GEAR items). Unlimited supply, not taken from the location decks. Duplicates in one offer are allowed. No resources, no basic cards.
- **A2.** One market visit allows **both** selling and buying.
- **A3.** Sell price is a flat **3 gold** for every resource. The `sell_value` field from Spec 03 is ignored for now (keep it in the data).
- **A4.** Buying and selling are **public**: the log shows which cards were bought and sold. The offer itself is only shown to the visiting player.
- **A5.** `DEBUG_GIVE_ALL_ITEMS` is switched to **false** now, so the market matters. Players start with the 4 basic cards again.
- **A6. Balance note, not a change:** a resource sells for 3 and a card costs 2, so every resource found pays for a card with change left over. Worth watching in playtests.

---

## 1. Data changes
- `game_state.gd`:
  - `STARTING_GOLD = 5`
  - `MARKET_OFFER_SIZE = 3`
  - `MARKET_BUY_PRICE = 2`
  - `MARKET_SELL_PRICE = 3`
  - `DEBUG_GIVE_ALL_ITEMS = false`
- `card_data.gd`: add `market_pool() -> Array[String]` returning the 15 item card ids.
- `board_data.gd` (or a small new helper): `has_interaction(tile_id) -> bool`, true only for `village_market` for now. Don't change tiles or connections.

## 2. `game_state.gd` additions
- Each player gets `market_offer: Array` (3 entries; an empty slot is `""`).
- `refresh_market_offer(player)` — 3 random picks from `CardData.market_pool()`.
- Call it at game start for every player, and whenever a player **ends a move** on `village_market` coming from another tile.
- `can_play_card` for INTERACT cards: false unless `has_interaction(current tile)`.
- Market visit functions (names are suggestions):
  - `market_sell(resource_hand_index) -> bool` — must be a RESOURCE card; removes it from hand, `+3 gold`.
  - `market_buy(offer_slot) -> bool` — slot must not be empty, player must have ≥ 2 gold; `-2 gold`, card goes to the hand, slot becomes `""`.
  - `market_finish(interact_hand_index)` — if at least one buy or sell happened during this visit: move the INTERACT card to the played area and spend **1 action**. Otherwise do nothing (cancelled).
- Opening the market is only allowed if `can_play_card` is true for that INTERACT card (so it needs an action left).

## 3. Market panel (UI)
A new scene `res://scenes/ui/market_panel.tscn` / `.gd`, shown centered over the board, styled like the private popup.

- **Title:** "Village market" and the player's gold: **"Gold: 5"** (updates live).
- **Buy row:** the 3 offer cards as card views, each with a **"Buy — 2 gold"** button below it.
  - Disabled if the player has less than 2 gold.
  - An empty slot shows a faint outline with "Sold".
- **Sell row:** every resource card in the player's hand, each with a **"Sell — 3 gold"** button. If there are none: "No resources to sell."
- **Done** button at the bottom. Its text is **"Done (1 action)"** once something was bought or sold, otherwise **"Leave"**.
- Esc or right-click works the same as Done/Leave.
- While the panel is open, nothing else can be clicked.

## 4. Info panel and log
- Players' **Gold** in the info panel now starts at 5 and updates after every buy and sell.
- Public log, one line per visit, written when the visit finishes, e.g.:
  - `Player 1 at the market: sold 2 resources (+6), bought Map, Reed Raft (-4)`
  - `Player 1 at the market: bought Metal Detector (-2)`
- Output panel prints the same line, plus `[secret]` lines for the offer contents when `DEBUG_SHOW_SECRETS` is on.

---

## Out of scope (do NOT build yet)
Bandit camp market, Passenger Club Membership trigger, other Village helpers (healer etc.), aliens, enemies, purple pool, the Oracle, win conditions, layout redesign.

---

## How to test (human, in Godot)
1. **F5**, 2 players. Each player starts with **4 basic cards** (debug hand is off) and the info panel shows **Gold: 5** for both.
2. In the Village, click **Talk**: the market panel opens with **3 cards** and "Gold: 5". The sell row says "No resources to sell."
3. Click **Leave** without buying: no action spent, Talk still in hand, actions still 3/3.
4. Open the market again, buy **2 cards**: gold goes 5 → 3 → 1, the bought slots show "Sold", the third Buy button is **disabled** (only 1 gold). Click **Done (1 action)**: actions 2/3, Talk is in Played, the 2 cards are in hand. The log shows the purchase.
5. Walk to **Junkyard**: Talk is greyed out; hover says "Nothing to interact with here".
6. Search until you have a **resource**, walk back to the Village (Rest when needed).
7. Back in the Village: the market shows a **new** set of 3 cards. Sell the resource: gold +3. Buy a card with that gold in the **same** visit. Done: still only **1 action** spent.
8. End turn and come back (as the same player) **without leaving** the Village: the offer is **the same** as before, with the "Sold" slots still empty.
9. Other player's turn: their market offer is **different** from the first player's (it's per player).
10. Stand on Lake and use the **Scrap Hoverboard** to go to Junkyard (passing through the Village without stopping). No new offer is made. Then walk from Junkyard into the Village normally: a fresh offer appears.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 05: starting gold and the Village market"
git push
```

## What to report back
- Which test steps passed or failed (numbers are enough).
- Any red error text from the Debugger.
- How the economy feels: is 5 starting gold, 2 to buy, 3 to sell too generous or too tight?
