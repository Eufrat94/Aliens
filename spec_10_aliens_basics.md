# Spec 10 — Aliens: cards, hiding, alien area, Crystal mount, win condition

## Goal
1. Add the **16 alien cards**. At game start **15** are shuffled into the location decks; **1 is secretly left out**.
2. Aliens can be **played** (1 AP) into a separate **alien area** that doesn't count toward the 4 gear slots.
3. Playing an alien adds **1 purple** to the **Crystal mount pool**. Players collect the pool there with **Interact**.
4. **Win:** the first player who owns **5 aliens** (hand + alien area combined) wins.
5. **SKRIM** is announced to everyone whenever someone gains it.
6. Each player has a private **alien checklist** for deduction.

Alien **abilities** are **not** implemented in this spec (that's Spec 11). Played aliens just sit in the alien area.

Builds on Spec 09b.

---

## Design rule (important for all future specs)
This digital version simulates a **physical board game**. The game must **never** reveal hidden information that players couldn't learn at a real table. Secret things (the missing alien, deck contents, hands) are only shown through cards, players, or debug output.

## Assumptions (flagged)
- **A1. Distribution:** the 15 aliens are shuffled and dealt round-robin into the 4 decks, starting from a random deck, so decks get 4, 4, 4 and 3 aliens. Then each deck is shuffled. Decks become 15–16 cards.
- **A2.** Aliens are **not** sold at the market and never appear in market offers.
- **A3.** The alien area has **no limit**.
- **A4.** The win check happens **immediately** whenever any player's alien count changes. The game ends at once.
- **A5.** The checklist is **manual**: players tick it themselves.
- **A6.** Crystal mount Interact takes the **whole pool** for 1 AP. Not allowed when the pool is 0.

---

## 1. `card_data.gd`
Add `Kind.ALIEN`. Each alien has `alien_mode`: `"active"`, `"passive"` or `"unplayable"`. Store the text now; the effects come in Spec 11.

| id | name | mode | text |
|---|---|---|---|
| `wingo` | Wingo | active | Pay 1 purple: move to any tile. |
| `magnet` | Magnet | active | Each other player on your tile gives you 1 card of their choice from their hand. |
| `disko` | Disko | active | Take the top card of the discard pile into your hand. |
| `mani` | Mani | active | Pay 1 purple: gain 5 gold. |
| `ugg` | Ugg | active | Pay 3 purple: discard any alien on the table. |
| `wush` | Wush | active | Move another player to a tile directly next to theirs (up, down, left or right). |
| `shadow` | Shadow | active | Every other player gives you 1 gold. If you have 9 or more gold, discard Shadow. |
| `stopots` | Stopots | passive | Other players on your tile can't use alien abilities. |
| `pucky` | Pucky | active | Take a random card from any player's hand, then discard 1 card from your hand. |
| `muddk` | Muddk | passive | Players leaving your tile must pay you 1 gold, if they have any. Being pushed doesn't count. |
| `nerfoil` | Nerfoil | passive | Other players have a hand limit of 7. If they would gain a card at 7, they first discard 1. |
| `skrim` | Skrim | unplayable | Can't be played. Whenever anyone gains this card, everyone is told. |
| `pikupiku` | Pikupiku | active | Pay 1 purple: look at the hand of a player on your tile. |
| `quizazz` | Quizazz | active | Pick a player. They reveal to everyone whether they have an alien in hand. Yes: you gain 1 purple. No: you gain 1 gold. |
| `mimix` | Mimix | active | Discard a card from your hand: use the active ability of any alien on the table, paying its costs. |
| `gloop` | Gloop | active | Give 1 purple to another player, then swap positions with them. |

Every active alien also shows a second small line: *"Active: 1 action, once per turn. Other players on your tile gain 1 purple."*

Until Spec 11, alien cards show *"Ability coming soon"* in small grey text.

Helpers:
- `is_alien(id)` now returns true for these 16.
- `all_alien_ids() -> Array[String]`.

## 2. Setup (`game_state.gd`)
- `missing_alien: String` — at game start, pick 1 of the 16 at random. Keep it out of all decks.
- Deal the other 15 into the decks (A1), then shuffle each deck.
- Print `[secret] Missing alien: Gloop` only when `DEBUG_SHOW_SECRETS` is true.
- `crystal_pool: int = 0`.
- Each player gets `aliens: Array[String]` (their alien area) and `checklist: Dictionary` (alien id → bool, all false).
- New debug constant `DEBUG_START_ALIENS = 0`: when above 0, each player starts with that many random aliens in hand (taken from the decks, so the total stays correct). Used for testing the win.

## 3. Playing an alien
- `can_play_card` for ALIEN: needs 1 AP; `"unplayable"` aliens (Skrim) can never be played, reason `"Skrim can't be played"`.
- `play_alien(hand_index)`: 1 AP, card moves from hand to `aliens`, `crystal_pool += 1`.
- Log (public): `Player 1 played alien Wingo (+1 purple to Crystal mount)`.

## 4. Crystal mount
- `has_interaction("crystal_mount")` → true.
- **Interact** at Crystal mount: if `crystal_pool > 0`, player gains all of it, pool becomes 0, 1 AP. Otherwise disabled with reason `"The pool is empty"`.
- Log: `Player 2 collected 3 purple at Crystal mount`.
- The Crystal mount **tile** shows **"Pool: N"** (big enough to read), updated live.

## 5. Win condition
- `alien_count(player) = aliens in hand + aliens in alien area`.
- After **any** change to hands or alien areas, check every player. If someone has **5 or more**, the game ends.
- **Win screen** (full screen, layer above everything): "Player 3 wins!" in their color, the names of their aliens, then **"The missing alien was: Gloop"**, and a **New game** button that returns to the setup screen.

## 6. SKRIM announcement
- Whenever Skrim enters any player's hand (search, any card effect, debug start), show a big public banner over the board: **"SKRIM!"** with "Player 2 has Skrim", which stays until clicked. Add a log line.
- From then on, that player's seat shows a small **"SKRIM"** badge (public knowledge), until Skrim leaves their hand.

## 7. Alien checklist (private)
- A small **"Aliens"** button in the bottom seat header.
- Opens a popup (layer 10) listing all **16 aliens** in two columns, each with a checkbox and its name. Hovering a name shows the card preview.
- Ticks are saved **per player** and only visible on that player's own turn.
- No automatic ticking. The pass screen hides it, like everything else.

## 8. UI: alien areas
- **Bottom seat:** add an **"Aliens (N)"** group after Gear, showing played aliens as mini cards (overlap if needed, no scrolling).
- **Opponent strips:** add an **"Aliens (N)"** group after Gear, same style. Played aliens are public.
- **Alien card visuals:** strip color purple `#8E44AD`, label **"ALIEN"**, and a second line "Active", "Passive" or "Can't be played".
- In the current player's hand, aliens look like normal hand cards with the purple strip. Skrim is greyed out (unplayable).

---

## Out of scope
Alien abilities (Spec 11), purple for players sharing a tile (Spec 11), Bandit camp, Sacred altar guess, enemies, set collection.

---

## How to test (human, in Godot)
1. **F5**, 2 players. Output shows `[secret] Missing alien: …`. Deck counts are now **15–16**.
2. Search until you find an **alien** (or set `DEBUG_START_ALIENS = 2`). It has a purple strip and "Ability coming soon".
3. Play it: 1 AP. It moves to your **Aliens** area, visible on your opponent's strip next turn. The Crystal mount tile shows **Pool: 1**.
4. Move to **Crystal mount** (you need a Machete, Glider, or debug items). Interact: you gain the pool, the tile shows **Pool: 0**, Interact is now disabled.
5. Open the **Aliens** checklist, tick two names, end the turn. The other player's checklist is **empty**. On your next turn your ticks are still there.
6. Set `DEBUG_START_ALIENS = 4`, start a game, and find/draw one more alien: the **win screen** appears immediately, showing the winner and **the missing alien**. New game works.
7. Get **Skrim** (debug: keep restarting with `DEBUG_START_ALIENS = 4` until someone has it, or search): a **SKRIM!** banner appears, the seat shows a SKRIM badge, and Skrim can't be played.
8. The market never offers aliens.
9. The pass screen still hides everything, including the checklist and the alien hand cards.

When everything passes, in the Cursor terminal:
```powershell
git add .
git commit -m "Spec 10: aliens basics, Crystal mount, win condition"
git push
```

## What to report back
Which steps passed, any errors, and how it feels to find an alien.
