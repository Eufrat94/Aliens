# Spec 14 — Materials, the Workshop and inventions

## Goal
1. The 4 old resources are replaced by **6 materials**: Copper Wire, Battery, Rope, Scrap Plate, Cog, Relic Crystal.
2. The **Arena becomes the Workshop**.
3. A public row of **3 blueprints** shows what can be built. Players **build** inventions by paying materials at the Workshop.
4. The **6 inventions** (Workshop-only gear) get their effects.

Builds on Spec 13.

---

## Decisions from the designer
- 6 materials; **every deck has 1 of each** for now. Materials still sell for 1 gold.
- 3 blueprints are face up from the start. When one is built, the next is drawn from the **invention deck**.
- Built inventions go **straight into the builder's gear slots** (choose one to replace if full).
- Inventions are new cards, only available at the Workshop.

## Assumptions (flagged)
- **A1. Many builds per visit (designer's decision):** like the market, one Workshop visit (Interact) costs **1 AP in total**, however many inventions are built. Leaving without building costs nothing.
- **A2.** Paid materials go to the **discard pile** (so Disko can grab them).
- **A3.** An **"any material"** slot is paid with a material of the builder's choice.
- **A4. Pedal Cart (designer's decision):** only at the **start of the turn**. The free Move is available until the player does anything else that turn (any action, card, gear or alien use, market or Workshop visit). After that, it's gone for this turn.
- **A5. Brass Binoculars:** the drawing player shows **every card drawn from a deck** (all cards from one action are shown together). Not for Disko (that's the discard pile, already public).
- **A6. Strongbox** blocks Pucky and Magnet. It does **not** block looking (Pikupiku, Truth Lantern) or Nerfoil discards.
- **A7. Echo Antenna** triggers once per active alien use (a Mimix use counts once).
- **A8.** Aether Still and Truth Lantern are gear, not aliens: Stopots doesn't block them, and they don't give purple to players on your tile.
- **A9.** When the invention deck is empty, an emptied row slot shows "No more inventions".

---

## 1. Materials (`card_data.gd`, `deck_data.gd`)
- **Remove** `scrap_metal`, `relic_shard`, `river_pearl`. **Keep** `copper_wire`. **Add** `battery`, `rope`, `scrap_plate`, `cog`, `relic_crystal`. All are kind RESOURCE.
- Card label shows **"MATERIAL"** (gold strip, as before). Text: *"Material. Build inventions at the Workshop, or sell for 1 gold."*
- `random_starting_hand()` gives **2 random materials**.
- Each deck: same item counts as now, plus **1 of each material** (6), plus aliens as before. The old resource cards are gone from all decks.
- Everything that checks "is a resource" (Ancient Trowel, market selling, unplayable cards) works with materials.

## 2. The Workshop tile
- Rename the **Arena** tile to **Workshop**: id `workshop`, name "Workshop", type label "workshop". **Update every reference** to `arena` (board data, connections, Claw tables, debug, tests).
- Connections don't change: Workshop↔Village (normal), Workshop↔Archeology site (jungle), Workshop↔Crystal mount (jungle).
- `has_interaction("workshop")` → true.

## 3. Inventions (`card_data.gd`)
Kind **GEAR**, with `invention: true` and `recipe: Array[String]` (material ids, `"any"` for a free slot). They are **never** in location decks or market offers.

| id | name | recipe | mode | text |
|---|---|---|---|---|
| `echo_antenna` | Echo Antenna | copper_wire, battery, relic_crystal | passive | Whenever another player uses an alien ability, you gain 1 purple. |
| `brass_binoculars` | Brass Binoculars | relic_crystal, any | passive | Whenever another player on your tile draws a card from a deck, they must show it to you. |
| `pedal_cart` | Pedal Cart | cog, cog, rope | passive | At the start of your turn, you may Move once for free (before doing anything else). |
| `strongbox` | Strongbox | scrap_plate, scrap_plate, battery | passive | Other players can't take cards from your hand. |
| `aether_still` | Aether Still | copper_wire, battery, rope | active | Use (1 action, once per turn): pay 2 gold, gain 1 purple. |
| `truth_lantern` | Truth Lantern | relic_crystal, copper_wire, rope | active | Use (1 action, once per turn): a player on your tile shows you 1 card from their hand. If they have an alien in hand, they must show an alien; otherwise any card they choose. |

Invention cards show their **recipe** as a row of small material labels (e.g. "Cog · Cog · Rope") above the effect text. Use a distinct strip color: **teal-blue `#1F7A8C`**, label "INVENTION".

## 4. Blueprint row (`game_state.gd`)
- `invention_deck: Array[String]` — the 6 inventions, shuffled at game start.
- `blueprint_row: Array[String]` — 3 slots, filled from the deck at game start. `""` = empty.
- `can_build(slot) / build_reason(slot)`: the player is on the Workshop, has ≥1 AP, the slot isn't empty, and their hand contains the recipe's materials (`"any"` = any one extra material).
- `build(slot, any_choice := "")`: remove the materials from hand → discard pile; the invention goes into the player's gear (replace flow if 4 slots are full, the replaced gear → discard); refill the slot from `invention_deck`. **No AP per build.**
- `workshop_finish()`: if at least one invention was built during this visit, spend **1 AP** (like `market_finish`). Otherwise nothing is spent.
- `can_build` needs ≥1 AP only for the **first** build of a visit; further builds in the same visit are always allowed if the materials are there.
- Log (public): `Player 1 built Pedal Cart at the Workshop (Cog, Cog, Rope)`.
- Run the usual checks after building (win, Shadow, Skrim, Nerfoil irrelevant here).

## 5. UI
### Blueprint row on the board
- Show the 3 blueprints as **mini cards** in a small labeled group **"Workshop"**, placed in a free spot of the board region **near the Workshop tile**, without covering tiles. Moving the legend or the discard pile to make room is fine.
- Hover shows the large preview with recipe and effect. The row is public and always visible.

### Workshop panel (Interact at the Workshop)
- Like the market panel: title "Workshop", the 3 blueprints as full cards, each with a **"Build"** button.
- Under each blueprint, show the recipe with a ✓ or ✗ per material, based on the player's hand. These update live after each build (a new blueprint may appear in the slot and can be built in the same visit).
- Build disabled with a reason ("Missing: Cog, Rope", "No actions left").
- For an `"any"` slot: after clicking Build, a small popup lets the player pick which material to pay.
- If gear is full: the existing replace-a-slot flow.
- Bottom button: **"Done (1 action)"** after at least one build, otherwise **"Leave"** (nothing spent). Esc/right-click = same.

## 6. Invention effects
### Echo Antenna
After any active alien use by **another** player (incl. via Mimix, once), the Antenna's owner gains 1 purple. Log: `Player 2 gained 1 purple (Echo Antenna)`.

### Brass Binoculars
- When a player **other than the owner**, standing on the owner's tile, draws card(s) from a deck (Search, ability cards, Metal Detector, Grappling Claw…), the owner must see those cards.
- The owner isn't the current player, so use the **hand-off screen**: "Player 3, take the device." → private popup showing the drawn card(s) → "Pass the device back to Player 1."
- All cards from one action are shown together in one hand-off.
- Public log: `Player 3 saw Player 1's draw (Brass Binoculars)`.

### Pedal Cart
- At the start of the owner's turn (after the pass screen and start-of-turn triggers like Junk Radio), a **free Move** is available: 1 step along the owner's normal move paths, costing 0 AP.
- The Move button shows **"Move (free)"** while it's available, with tooltip "Pedal Cart: free move at the start of your turn".
- It is lost as soon as the player does **anything else** (any AP-spending action, playing a card, using gear or an alien, opening and using the market or Workshop). Ending the turn also ends it.
- Reset each turn.

### Strongbox
The owner's hand can't be targeted by **Pucky**, and the owner is **skipped by Magnet**. Reasons in target popups: "Protected by Strongbox".

### Aether Still
Active gear: 1 AP, once per turn, needs ≥ 2 gold: −2 gold, +1 purple. (Shadow check runs after gold changes.)

### Truth Lantern
- Active gear: 1 AP, once per turn. Needs another player **on your tile** with ≥1 card in hand. If several, pick one in a popup.
- **Hand-off screen** for the target: "Player 3, take the device. Player 1 used Truth Lantern: show 1 card." The popup shows their hand; if they have **any alien** in hand, **only aliens** are selectable, otherwise any card. They pick one.
- Pass back to the user → **private popup** shows the chosen card.
- Public log: `Player 1 used Truth Lantern on Player 3` (never the card).

## 7. Debug helpers
- `DEBUG_START_MATERIALS: int = 0` — extra random materials in every starting hand.
- `DEBUG_PLAYER_GEAR: Dictionary` — player index → list of gear ids put directly into their gear slots at start (may include inventions; those are then removed from the invention deck).

---

## Out of scope
More inventions, set collection (pairs), the Sacred altar, Bandit camp, enemies, event cards.

---

## How to test (human, in Godot)
1. **F5**: starting hands have 2 **materials** (gold strip, "MATERIAL"). No Scrap Metal, Relic Shard or River Pearl anywhere.
2. The Arena is now **Workshop**. The **blueprint row** shows 3 inventions near it; hover shows recipe and effect.
3. With `DEBUG_START_MATERIALS = 10`, walk to the Workshop, Interact: the panel shows ✓/✗ per material. Build one: materials gone (discard pile +), invention in your gear, a **new blueprint** fills the slot, log line written. Build a **second** one in the same visit, then Done: only **1 AP** spent in total. Opening and leaving without building costs nothing.
4. Build **Brass Binoculars**: pick the material for the "any" slot.
5. **Pedal Cart**: at the start of your turn the Move button says "Move (free)". Moving costs 0 AP; the next Move costs 1. Next turn, do something else first (e.g. Search): the free Move is gone for that turn.
6. **Aether Still**: −2 gold, +1 purple, once per turn.
7. **Strongbox** on P2: P1's Pucky can't target P2; P1's Magnet skips P2.
8. **Echo Antenna** on P2: P1 uses an active alien anywhere → P2 +1 purple.
9. **Brass Binoculars** on P2, P1 on the same tile searches → hand-off to P2, P2 sees the card, pass back.
10. **Truth Lantern**: P1 and P2 on the same tile, P2 holds an alien → P2 can only pick an alien; P1 then sees it privately. Without aliens, P2 can pick any card.
11. Build all 6: the empty slots show "No more inventions".
12. Market and decks never offer inventions.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 14: materials, Workshop and inventions"
git push
```

## What to report back
Which steps passed, any errors, and whether building feels worth the trip.
