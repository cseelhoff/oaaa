# oaaa

A faithful Odin port of TripleA's *Axis & Allies* (Second Edition) engine, plus a reinforcement-learning project (`rl-agent/`) that learns to play it. This glossary fixes the canonical word for each core domain concept across both the engine and the RL stack. Implementation details, types, and APIs do not belong here — only the shared vocabulary.

## Language

### Sides and decision-makers

**Nation**:
One of the 5 active countries that take turns in the game, plus 1 **Phantom Nation** (Italy) that exists in the data model but never takes a Turn. Each Nation belongs to exactly one Team. Spelled out in prose, identifiers, and enum values — the legacy 3-letter forms (`Rus`, `Ger`, `Eng`, `Jap`) in `Player_ID` are slated for rename to `Nation_ID` with these canonical values:

| Canonical | Enum value | Capital Land | Team | Active? | Banned aliases |
|---|---|---|---|---|---|
| Russia | `.Russia` | `.Russia` | Allies | yes | Rus, USSR, Soviet, Soviet_Union |
| Germany | `.Germany` | `.Germany` | Axis | yes | Ger, Reich, Nazi |
| United Kingdom | `.United_Kingdom` | `.United_Kingdom` | Allies | yes | Eng, England, Britain, Great_Britain, British, British_Empire, UK |
| Japan | `.Japan` | `.Japan` | Axis | yes | Jap, Imperial_Japan, Empire_of_Japan |
| USA | `.USA` | `.Eastern_United_States` | Allies | yes | US, America, United_States, American, Americans |
| Italy | `.Italy` | (none) | Axis | **no (Phantom)** | Ita, Italian, Italians, Kingdom_of_Italy |

USA is kept as an acronym (one capital block, parallel to `AAGun`); all other Nations spell out the country name. `Player_ID` is the legacy type name and is itself slated for rename (`Player_ID` → `Nation_ID`).
_Avoid_: power, player, country, faction

**Phantom Nation**:
A Nation that occupies a slot in `Nation_ID` and in the per-Nation arrays (`gc.money`, `gc.income`, etc.) but never has its Turn driven by a Player and never executes Purchase / Combat / Place. **Italy** is the only Phantom Nation. Its slot exists specifically so the Turn order alternates strictly between Allies and Axis Teams — see Round entry. This is an **RL observability invariant**: a learning policy embedded in a fixed observation tensor relies on "the next Nation is always on the opposing Team" being true unconditionally; without Italy, USA → Russia would break that pattern (both Allies). The engine could otherwise omit Italy, but the RL stack requires the slot.

A Phantom Nation: owns no Lands by default, has zero Income, has no Capital, never takes a Turn, never holds Active Units. The 6th slot in `gc.money: [6]u8` and the 6th `Player_ID` enum value (currently `.ITA` or equivalent legacy short form) are the implementation. Rename: any `.ITA` legacy form → `.Italy`.
_Avoid_: dummy nation, placeholder nation, ITA, inactive nation, dead nation

**Team**:
One of the 2 sides; Allies (Russia, United Kingdom, USA) and Axis (Germany, Japan). The win condition, shared reward, and ownership of units/territories are all Team-level. Within a Team the constituent Nations take turns.
_Avoid_: side, alliance
_Members_: Allies, Axis

**Player**:
The agent driving a Team for a game — a human, a Pro AI instance, or an RL policy. There are always exactly two Players per game, one per Team; the relationship is 1-to-1 by construction. `Player` is an off-board, RL-stack concept and should not appear in the engine (`src/`), which knows only about Nations and Teams.
_Avoid_: agent, controller, bot, seat

### Map

**Region**:
Any single space on the map — a Land or a Sea. Aircraft move over Regions, so any space a plane can occupy is a Region. The engine's `Air_ID` is the legacy index type for this concept and is slated for rename. The name "Air" is misleading in a wargame context (it reads as aerospace, not "any space a plane can occupy"); the canonical noun is **Region**. Legacy `Air_*` identifiers slated for rename:

| Current | Rename to |
|---|---|
| `Air_ID` | `Region_ID` |
| `Air_Bitset` | `Region_Bitset` |
| `Air_States` | `Region_States` |
| `air_to_land`, `land_to_air`, `sea_to_air`, `action_to_air` | `region_to_land`, `land_to_region`, `sea_to_region`, `action_to_region` |
| `to_air`, `to_air_bitset`, `get_airs` | `to_region`, `to_region_bitset`, `get_regions` |
| `is_air_land` | `region_is_land` (subject-first; pairs with future `region_is_sea`) |
| `gc.air_has_enemies` | `gc.region_has_enemies` |
| loop vars `air`, `src_air`, `dst_air` | `region`, `src_region`, `dst_region` |
| `air_positions`, `air_bitset`, `valid_air_moves_bitset` | `region_positions`, `region_bitset`, `valid_region_moves_bitset` |

**Region naming convention**: no single-letter loop variables (`l`, `s`, `a`) for Regions or sub-Regions in new code — always `land`, `sea`, `region`, with `src_` / `dst_` prefixes for source/destination. No `_idx` suffix when the value is a typed enum (`mid_idx: Land_ID` → `mid_land: Land_ID`). The plain word "air" is reserved for actual aerospace concepts (Fighter/Bomber operations) and must not be used as a synonym for Region.
_Avoid_: territory, node, tile, zone, locale, map node, air (as a synonym for Region)

**Land**:
A Region that is land. Owned by a Nation, holds armies/planes/factories, and contributes IPC income to its owner's Team.
_Avoid_: land territory, territory, region (when Sea is in scope), province

**Sea**:
A Region that is water. Unowned; holds ships and planes; some Seas are convoy zones that contribute IPC.
_Avoid_: sea zone, water, ocean, naval zone, region (when Land is in scope)

**Canal**:
A fixed structural connection between two specific Seas via two specific banking Lands. A Canal is *passable* for a Team when that Team owns both of its banking Lands; otherwise ships (and carrier-borne planes) cannot transit between the connected Seas in a single move. The game has exactly two: Suez (Egypt/Trans-Jordan banking Sea 17 ↔ Sea 34) and Panama (Central America banking Sea 18 ↔ Sea 19). Defined as `Canal { lands: [2]Land_ID, seas: [2]Sea_ID }`.
_Avoid_: strait, chokepoint, passage, lock

### Movement

**Move**:
The atomic step of a Unit changing position from one Region to an Adjacent Region. One Move costs one point of the Unit's Movement Allowance. A Unit with Movement Allowance N may chain up to N Moves in a Turn (subject to combat-vs-noncombat rules). "Move" is the noun and the verb; never use "step", "hop", or "tile-move".
_Avoid_: step, hop, tile-move, tick

**Distance**:
The minimal number of Moves needed to go from a source Region to a destination Region, measured in the appropriate medium. Always unsigned and minimal — never path length or Euclidean. Three media, three distance relations:

| Medium | Table | Indexed by |
|---|---|---|
| Land path (armies) | `mm.land_distance[Land_ID][Land_ID]` | `[src][dst]` |
| Sea path (ships) | `mm.sea_distance[Canal_States][Sea_ID][Sea_ID]` | `[canal_state][src][dst]` |
| Air path (planes) | `mm.air_distance[Region_ID][Region_ID]` | `[src][dst]` |

Sea Distance is parameterized by `Canal_States` because Canal passability mutates the sea graph. Air Distance is the cross-medium one — planes ignore Land/Sea boundaries.
_Avoid_: range, hops, cost, weight, length

**Adjacent**:
"At Distance 1." Two Regions are Adjacent if a Unit of the appropriate medium can move from one to the other in a single Move. Adjacency is a per-medium relation:

| Relation | Table | Meaning |
|---|---|---|
| Land ↔ Land | `mm.lands_within_1_move[Land_ID]` | Lands reachable from this Land in 1 land-Move |
| Sea ↔ Sea | `mm.seas_within_1_move[Canal_States][Sea_ID]` | Seas reachable from this Sea in 1 sea-Move (canal-state-dependent) |
| Land → Sea (coastal) | `mm.coastal_seas[Land_ID]` | Seas touching this Land's coast |
| Sea → Land (coastal) | `mm.coastal_lands[Sea_ID]` | Lands touching this Sea |
| Region ↔ Region (air) | `mm.regions_within_1_air_move[Region_ID]` | Regions reachable from this Region in 1 air-Move |

The `coastal_*` pair encodes amphibious adjacency: a Transport in `sea` can load/unload at any Land in `mm.coastal_lands[sea]`, and a Land unit at `land` can board at any Sea in `mm.coastal_seas[land]`.
_Avoid_: neighbor, next-to, 1-away, via_land suffix, via_sea suffix

**Within N Moves**:
The set of Regions reachable in at most N Moves from a given Region, in a given medium. Per-medium, per-N bitsets, precomputed for the maximum Movement Allowance of any Unit in that medium:

| Medium | Table family | N values | Notes |
|---|---|---|---|
| Land | `mm.lands_within_N_moves[Land_ID]` | N ∈ {1, 2} | Tank has Movement Allowance 2 |
| Sea | `mm.seas_within_N_moves[Canal_States][Sea_ID]` | N ∈ {1, 2} | All ships have Movement Allowance ≤ 2; canal-state-dependent |
| Air | `mm.regions_within_N_air_moves[Region_ID]` | N ∈ {1, …, 6} | Bomber has Movement Allowance 6; **air-path only — does not guarantee a Land or Sea unit can follow that path** |

English-grammar singular/plural: `lands_within_1_move` (singular), `lands_within_2_moves` (plural for N ≥ 2). Same rule for `seas_within_*` and `regions_within_*_air_move(s)`.

The air-path qualifier on the Region family is load-bearing: `regions_within_3_air_moves[Berlin]` includes Sea Regions a Bomber can fly over, but tells you nothing about whether a Tank or a Battleship can reach them.
_Avoid_: reachable, in_range, in_reach, hops

**Movement Allowance**:
The maximum number of Moves a Unit may make in a single Turn, fixed by its Unit Type:

| Unit Type | Movement Allowance |
|---|---|
| Infantry, Artillery, AAGun, Factory | 1 (Factory: 0, immobile) |
| Tank | 2 |
| Fighter | 4 |
| Bomber | 6 |
| Transport, Submarine, Destroyer, Cruiser, Battleship, Carrier | 2 |

The remaining-Moves count carried by Active State (e.g. `Tank_1_Moves` meaning "a Tank with 1 Move left") is a runtime residual, not the Allowance. Movement Allowance is a constant per Unit Type; remaining Moves is per Unit per Turn.
_Avoid_: range, speed, mobility, movement points, MP, moves_left (as a field name for the constant)

**Movement vocabulary boundary rules**:
- "Range" is banned as a domain term entirely — too overloaded (artillery range, attack range, weapon range, programming "range"). Use Distance, Movement Allowance, or Within N Moves instead.
- "Move" is always the atomic Region-to-Region step. A Unit's whole Turn-worth of motion is its **Movement** (the sequence of Moves), not "a move".
- Adjacency table renames (slated):

| Current | Rename to |
|---|---|
| `mm.l2l_1away_via_land`, `mm.l2l_1away_via_land_bitset` | `mm.lands_within_1_move` |
| `mm.l2l_2away_via_land_bitset` | `mm.lands_within_2_moves` |
| `mm.l2l_2away_via_midland_bitset[src][dst]` | `mm.lands_between[src][dst]` (intermediate Lands on 2-Move paths) |
| `mm.s2s_1away_via_sea[canal_state]` | `mm.seas_within_1_move[canal_state]` |
| `mm.s2s_2away_via_sea[canal_state]` | `mm.seas_within_2_moves[canal_state]` |
| `mm.l2s_1away_via_land`, `mm.l2s_1away_via_land_bitset` | `mm.coastal_seas` |
| `mm.s2l_1away_via_sea` | `mm.coastal_lands` |
| `mm.a2a_within_N_moves` (N=1..6) | `mm.regions_within_N_air_moves` |
| `mm.land_distances` | `mm.land_distance` |
| `mm.sea_distances` | `mm.sea_distance` |
| `mm.air_distances` | `mm.air_distance` |

`_distances` → `_distance` (singular) because the table indexed by `[A][B]` returns a single number, not a collection. The `_within_N_moves` family stays plural-when-N≥2 because the table value *is* a set of Regions.

### Units

**Unit**:
A single individual game piece — one infantryman, one tank, one fighter, one battleship, one transport, one AAGun, and so on. The atomic thing that occupies a Region, belongs to a Nation, and takes orders. The current `idle_armies[…]` etc. counts in the engine are counts of Units, not of armies in the English sense.
_Avoid_: piece, model, token, army (in the "one soldier" sense)

**Unit Type**:
The kind of a Unit. One enum across the game, even though some Types only legally appear on Land and others only at Sea. Thirteen Types, with one canonical spelling each — used in prose, in identifiers, and in enum values. The legacy SCREAMING_SNAKE short forms (`INF`, `ARTY`, `AAGUN`, `SUB`, `TRANS`) and the ProAI parallel enum (`pro_combat_move.odin`'s `Infantry, Artillery, ...`) are slated for rename:

| Canonical | Enum value | Identifier stem | Banned aliases |
|---|---|---|---|
| Infantry | `.Infantry` | `infantry` | inf, foot, 1I (as Unit Type) |
| Artillery | `.Artillery` | `artillery` | arty, 1A (as Unit Type) |
| Tank | `.Tank` | `tank` | armor, 1T (as Unit Type) |
| AAGun | `.AAGun` | `aagun` | AA Gun, AA_Gun, aa_gun, anti-aircraft, aa, flak |
| Fighter | `.Fighter` | `fighter` | fig, fighter plane |
| Bomber | `.Bomber` | `bomber` | bmb, strategic bomber, heavy bomber |
| Transport | `.Transport` | `transport` | trans, transport ship, transport boat |
| Submarine | `.Submarine` | `submarine` | sub, u-boat |
| Destroyer | `.Destroyer` | `destroyer` | dd, destroyer escort |
| Cruiser | `.Cruiser` | `cruiser` | ca, heavy cruiser |
| Battleship | `.Battleship` | `battleship` | bb, capital ship |
| Carrier | `.Carrier` | `carrier` | cv, aircraft carrier, flat-top |
| Factory | `.Factory` | `factory` | industrial complex, IC, plant, production complex |

_Avoid_: unit class, unit kind, piece type

**Naming convention** (codebase-wide, applies to the rename pass):
Follow standard Odin style. Types and enum values are `Ada_Case` (e.g. `Game_State`, `Roster_Army.Infantry`). Procedures and variables are `snake_case` (e.g. `play_full_turn`, `acting_nation`). Package-level numeric constants are `SCREAMING_SNAKE_CASE` (e.g. `DICE_SIDES :: 6`, `INFANTRY_ATTACK_VALUE :: 1`, `MAX_COMBAT_ROUNDS :: 120`) — this is idiomatic Odin (matches `core:os` constants like `O_RDONLY`) and is *not* the same thing as the banned SCREAMING_SNAKE enum-value style. No SCREAMING_SNAKE *enum values* — anywhere. `AAGun` is treated as a single acronym-token (one capital block), not as two words, so it remains `AAGun` in Ada_Case and `aagun` in snake_case.
_Avoid_: ALL_CAPS enum values, ad-hoc abbreviations in new identifiers, parallel re-declared enums for the same concept

### Time

**Round**:
One full pass through all Nations in fixed order: Russia (Allies) → Germany (Axis) → United Kingdom (Allies) → Japan (Axis) → USA (Allies) → **Italy (Axis, Phantom — slot only, no Turn executed)** → back to Russia. The order is deliberately alternating-Team to support the RL observation invariant (see Phantom Nation). The A&A rulebook calls this a "game round" or "year".
_Avoid_: year, game round, cycle, volley (in this sense)

**Turn**:
One Nation's complete sequence of actions inside a Round. `play_full_turn(gc)` runs exactly one Turn.
_Avoid_: round (in this sense), nation turn

**Phase**:
A named sub-segment of a Turn. There are six, in this canonical order:

1. **Purchase** — the Acting Nation spends IPC from its Treasury on Units, queued onto its Purchased Units list. Repair of Damaged Factories is also paid for here (one IPC per damage point). No board mutations except Treasury and Purchased Units.
2. **Combat Move** — Active Units move into Regions containing enemy Units. Each enemy-occupied destination becomes a Battle staged for Phase 3. Air-Unit Combat Move also enforces fuel-return planning.
3. **Combat** — every staged Battle resolves to completion (or Retreat); Strategic Air Raids also resolve here as a sibling mechanic. Fully automated; no Player Plan accepted during this Phase.
4. **Non-Combat Move** — remaining Active Units move into Regions not containing enemies. Air Units must end on a Region that can refuel them.
5. **Place** — Purchased Units are committed to the board at owned Factories, capped per Factory by `builds_left[land] = factory_prod[land]` minus current-Place placements. Newly-captured Factories cannot Place this Turn.
6. **End Turn** — Battleships repaired, Income collected (= sum of owned Land Values, gated on Capital ownership), Active Units collapsed back to Roster, Acting Nation rotates.

The engine's internal step sequence (e.g. `stage_transports`, `resolve_land_battles`, `buy_units`, `collect_money`) is the *implementation* of these Phases, not additional Phases.

**Engine status (current `play_full_turn`)**: the engine currently does **not** run Purchase as a separate Phase — it fuses Purchase into the Place step (`buy_units` deducts IPC and places the Unit atomically, post-Combat). Likewise it fuses Repair into the same buy loop (`repair_cost := max(0, 1 + factory_dmg - builds_left)` in `purchase.odin:154`). Tracked as **EP-1** (Purchase fusion) and **EP-2** (Repair fusion) in the Known bugs subsection. The 6-Phase model above is the *intended* and canonical model; current code is a known partial implementation.
_Avoid_: step, stage, segment

**Volley**:
One simultaneous exchange of dice inside a single Battle: both sides roll, hits are tallied, casualties are taken. A Battle consists of one or more Volleys until one side is destroyed or retreats. The current code calls this a "combat round" — that usage conflicts with Round (the game pass) and is retired.
_Avoid_: combat round, round (in this sense), exchange, iteration, dice round

### Player decisions

**Plan**:
The complete submission a Player makes when prompted during a Phase — an ordered sequence of Sub-actions terminated by `FINALIZE`. The data shape of a Plan is uniform across Phases; what varies is the legal Sub-action set, which the engine reports per-state. (See `plan.md` §4.2 for the wire encoding.)
_Avoid_: macro action, meta action, move set, combined decision, macro choice, action bundle

**Sub-action**:
One atomic step inside a Plan — e.g. *buy 1 Infantry for this Factory*, *move N Units of one Type from Region A to Region B*, *place 2 Tanks at this Factory*, *FINALIZE*. The legal Sub-actions at any moment are a function of game state and current Phase; the engine is the ground truth via `ts_legal_subactions`.
_Avoid_: micro action, atomic action, primitive, step

### Combat resolution

The Combat Phase is fully automated — the Player submits no Plan during it. Three intra-Combat choices that would otherwise require a decision are instead resolved by Pro AI heuristics inside the engine and never surface to the Player.

**Boundary rule (Combat / Battle)**: "Combat" is reserved for the Phase names — **Combat** (the resolution Phase) and **Combat Move** (the movement Phase that precedes it). The multi-Volley engagement at one Region is always a **Battle**, never "combat", "fight", or "engagement". The Combat Phase resolves *two distinct mechanics*: Battles (multi-Volley engagements, can capture Land) and Strategic Air Raids (one-shot Bomber attacks on Factories, never capture Land — see below). They are siblings, not subtypes. Existing engine cache fields `gc.land_combat_started`, `gc.sea_combat_started`, `gc.more_land_combat_needed` are slated for rename to `*_battle_started` / `more_land_battles_needed` to match.

**Battle**:
One specific multi-Volley engagement at one specific Region between Attackers and Defenders. The Combat Phase resolves every Battle the Acting Nation started during Combat Move. A Battle ends when one side is destroyed or the Attacker retreats. The engine tracks Battles per-Region.
_Avoid_: fight, skirmish, engagement, encounter, fray, combat (when meaning the engagement rather than the Phase)

**Attacker**:
A Unit belonging to the Acting Nation that is participating in a Battle as a result of moving into the Battle's Region during Combat Move. Attackers roll first in each Volley.
_Avoid_: aggressor, invader, offensive unit, mover

**Defender**:
A Unit not belonging to the Acting Nation's Team that is present in a Battle's Region when the Battle resolves. Defenders roll second in each Volley. "Counter-attack" is not a domain term — only the Acting Nation initiates Battles, and an enemy "counter-attack" is just a Battle the enemy starts on their own Turn next Round.
_Avoid_: enemy unit (in this role context), garrison, holder, occupier, counter-attacker

**Attack Value / Defense Value**:
The per-Unit-Type integer that drives dice resolution. Each Unit contributes its Attack Value (when attacking) or Defense Value (when defending) to the dice pool for its side in a Volley. Constants per Unit Type:

| Unit Type | Attack | Defense | Notes |
|---|---|---|---|
| Infantry | 1 | 2 | Infantry paired with an Artillery attacks at 2 (Combined Arms — see below) |
| Artillery | 2 | 2 | Provides Combined Arms support to one Infantry per Artillery |
| Tank | 3 | 2 | |
| AAGun | — | — | Does not roll in regular Volleys; fires only in Tactical AA |
| Fighter | 3 | 4 | |
| Bomber | 4 | 1 | Bomber attacks at 4 in a Battle; rolls separately at much higher value in a Strategic Air Raid (Raid damage formula, not Attack Value) |
| Submarine | 2 | 1 | First Strike applies — see Combat resolution mechanics |
| Destroyer | 2 | 2 | Cancels enemy Submarine First Strike when present |
| Cruiser | 3 | 3 | May also bombard (Naval Bombardment) |
| Battleship | 4 | 4 | 2 HP — first Hit transitions to Damaged Active State; may also bombard |
| Carrier | 1 | 2 | |
| Transport | 0 | 0 | No combat value; destroyed last in Casualty Order |
| Factory | — | — | Immobile, never participates in a Battle's Volley; can be Damaged only by a Strategic Air Raid |

These map to existing engine constants: `INFANTRY_ATTACK`, `ARTILLERY_ATTACK`, `TANK_ATTACK`, `FIGHTER_ATTACK`, `BOMBER_ATTACK`, `DESTROYER_ATTACK`, `CARRIER_ATTACK`, `CRUISER_ATTACK`, `BATTLESHIP_ATTACK`, `SUB_ATTACK`, and the matching `*_DEFENSE` family. Slated rename: add the `_VALUE` suffix codebase-wide to disambiguate from non-domain "attack" senses — `SUB_ATTACK` → `SUB_ATTACK_VALUE :: 2`, `INFANTRY_DEFENSE` → `INFANTRY_DEFENSE_VALUE :: 2`, etc. (SCREAMING_SNAKE stays — these are package-level numeric constants, not enum values.)
_Avoid_: attack power, defense power, attack strength, firepower, attack rating, combat strength

**Combined Arms**:
The Infantry+Artillery support rule. For each Artillery on the attacking side, up to one Infantry on the same side attacks at value 2 instead of 1 for that Volley. Engine implements this by adding `INFANTRY_ATTACK * min(INF_count, ARTY_count)` as a second term in the attack-value sum (see `calculate_land_attack_value`). Combined Arms applies only on attack, not on defense, and only in Land Battles.
_Avoid_: artillery support, infantry boost, support fire (which means Naval Bombardment), pairing bonus

**Total Attack Value / Total Defense Value**:
The sum of contributing Units' Attack Values (or Defense Values) on one side in one Volley, including the Combined Arms bonus on the attacking Land side. This is the integer fed into `Roll`. Engine identifiers: `total_attack_value: int`, `total_defense_value: int`, `get_total_attack_value_sea`, `calculate_land_attack_value`, `calculate_land_defense_value`, `calculate_naval_defense_value`, `calculate_sub_defense_value`. The variable names *inside* those calculate-functions that currently capture the return value as `damage: int` (e.g. `damage += int(gc.idle_armies[land][player][.INF]) * INFANTRY_ATTACK`) are slated for rename — see boundary rule below.
_Avoid_: damage (as a synonym; see boundary rule), dice pool, attack pool, combat power

**Roll**:
The dice-resolution step that converts Total Attack Value into a Hit count. The engine uses **Low Luck** mode (deterministic whole-Hits plus a single capped probabilistic fractional Hit), not raw per-die rolling — see `calculate_attacker_hits_low_luck` and `calculate_defender_hits_low_luck`. Low Luck is the engine's chosen dice mode, not standard A&A rules.
_Avoid_: dice, dice roll, throw, RNG step

**Hit**:
A unit of injury produced by Roll. Both sides Roll simultaneously inside a Volley; the resulting `attacker_hits` and `defender_hits` integers are applied in the same Volley, before retreat is checked. A Hit *lands* on a Casualty unless absorbed as Damage (Battleship's first Hit, or any Hit on a Factory during a Strategic Air Raid). Engine identifiers: `attacker_hits: u8`, `defender_hits: u8`, `sub_attacker_hits`, `aa_defense_hits`, `bombing_damage_hits`.
_Avoid_: damage point, wound, success roll, success

**Casualty**:
A Unit destroyed (removed from the board) by a Hit through Casualty Selection. Each Hit produces exactly one Casualty unless absorbed by Damage. The verb is **destroyed**, never "killed" / "lost" / "eliminated" / "removed" in prose (engine code uses `remove_*` procs as the side-effect verb — those keep their name; only prose is constrained).
_Avoid_: kill, loss, death, eliminated unit, removed unit (in prose)

**Damage**:
Persistent injury *short of destruction*. A Damaged thing absorbs a Hit instead of becoming a Casualty. Only two species exist in A&A 2nd:

- **Battleship Damage**: A Battleship has 2 HP. The first Hit transitions a fresh Battleship to the `Battleship_Damaged` Active State (see Active State entry); the second Hit destroys it (Casualty). Repaired automatically at the end of the owner's Place Phase. Engine: `Battleship_Damaged_*` Active States, `BS_DAMAGED` legacy short form slated for rename.
- **Factory Damage**: `gc.factory_dmg[Land]` accumulates from Strategic Air Raids, caps at 2× the Factory's production value, and is subtracted from `builds_left` next Purchase Phase. Reduces production until repaired.

The word **Damage** never means "Total Attack Value" — see boundary rule.
_Avoid_: HP, hit points, wounds, durability, structural damage

**Boundary rule (Damage vs Total Attack Value)**: The word "Damage" is reserved for the two persistent-injury senses above (Battleship Damage and Factory Damage). The current `combat.odin` comments — e.g. `// 1. Base hits = damage / DICE_SIDES`, `// Example: 7 damage / 6 sides = 1 guaranteed hit`, and the return-name `damage: int` inside `calculate_land_attack_value` / `calculate_land_defense_value` / `calculate_naval_defense_value` / `calculate_sub_defense_value` / `get_total_attack_value_sea` — use "damage" to mean Total Attack Value, which collides. These are slated for rename:

| Current | Rename to |
|---|---|
| Comment "total damage" / "X damage" in `calculate_attacker_hits_low_luck` / `calculate_defender_hits_low_luck` | "total attack value" / "X attack value" |
| `damage: int` return name in `calculate_land_attack_value`, `calculate_land_defense_value` | `total_attack_value: int`, `total_defense_value: int` |
| `damage: int` return name in `calculate_naval_defense_value`, `calculate_sub_defense_value` | `total_defense_value: int` |
| `damage: int` return name in `get_total_attack_value_sea` | `total_attack_value: int` |
| `bombing_damage_hits` (inside `resolve_raid`) | `raid_hits` (these are Hits applied to the Factory as Factory Damage; the variable name conflates Hit and Damage) |
| `def_damage` local in `resolve_sea_battles` | `def_total_attack_value` (this local accumulates Total Attack Value for the defender side — naming is exactly inverted by the legacy "damage" shorthand) |

**First Strike**:
A Submarine's privilege of firing — and having its Hits applied — before the rest of a Sea Battle's Volley, so its targets do not get to return fire that Volley. Cancelled when the opposing side has a Destroyer in the same Sea (the Destroyer negates the Sub's surprise). Standard A&A rule: **both sides' Subs** get First Strike when their respective opposing side has no Destroyer.

**Engine status**: only the attacker's First Strike is implemented. `sub_attacker_hits` is computed from `count_allied_subs(sea) * SUB_ATTACK_VALUE` and applied before `def_damage` is rolled when `gc.enemy_destroyer_total[sea] == 0`. The defender's Sub return fire is folded into `def_damage` via `calculate_sub_defense_value` and resolved simultaneously with the rest of the Defender Volley — there is **no separate pre-emptive Defender Sub Volley**.

**Known bug (FS-1)**: Defender Subs should get their own First Strike Volley (with attacker Hits pre-removed before non-Sub attackers return fire) when the attacker has no Destroyer in the Sea. Currently they do not. Symmetric attacker/defender First Strike resolution is a planned fix; the current implementation under-models defender Sub power in destroyer-less Sea Battles.
_Avoid_: sneak attack, surprise attack, sub strike, sub sneak

**Submerge**:
A Submarine's per-Volley alternative to firing: it submerges and is neither targetable nor able to fire for that Volley. Available iff the *opposing* side has no Destroyer in the Sea. Symmetric: applies to both Acting Nation's Subs and Defender Subs based on whose opponent lacks a Destroyer. A Sub that Submerges does not fire that Volley, so Submerge and First Strike are mutually exclusive per Volley.

**Engine status**: Submerge is *intended* to be a per-Volley Player Decision (see **Submerge Decision**), but the current code force-defaults every eligible Sub to Submerge (`combat.odin` comment: "Subs ALWAYS submerge if they can"). The Submerge Decision API surface is not yet wired through. This is a partial implementation, not a misdesign — the decision exists in the model; the engine just doesn't currently *ask* the Player.
_Avoid_: dive, evade, escape, sub-submerge

**Naval Bombardment**:
A pre-Battle shore-fire mechanic: a Battleship or Cruiser at a Sea Adjacent to a Land where an amphibious Battle is about to occur fires one die into the Battle on the lead-in Volley, before regular attacker / defender fire. Hits count as Attacker hits for Casualty Selection. Each surface ship may bombard at most once per Turn — used ships transition into the `Bombarded` Active State and are barred from bombarding again. Bombardment is a *modifier* on a Battle, not a Battle of its own.
_Avoid_: shore bombardment, sea bombardment, support fire, shelling

**AA Fire**:
Defensive fire against attacking Air Units (Fighters, Bombers), resolved before the first Volley of the relevant engagement. Each AA shot rolls one die at the standard low-luck AA hit rate; hits remove planes via Casualty Selection, and removed planes do not get to fire in the engagement they were entering. Two sub-mechanics:

- **Tactical AA**: Mobile `.AAGun` Units defending a Land Battle. Fires once at the lead-in to the Battle, with one shot per attacking Air Unit, capped at 3 shots per defending AAGun. The AAGuns themselves never participate in the regular Volleys (they have no attack or defense value against ground Units in this engine).
- **Strategic AA**: A defending Factory's intrinsic anti-air, firing only during a Strategic Air Raid. One shot per raiding Bomber. Not tied to any AAGun Unit — it is a built-in Factory ability that activates only when the Factory's Land is being raided. Fighters are not legal Raiders, so Strategic AA never targets Fighters.

_Avoid_: anti-air, flak, AAGun fire (ambiguous — excludes Strategic AA), interception

**Strategic Air Raid**:
A standalone one-Volley mechanic distinct from Battle: one or more Bombers (no other Units) fly to an Enemy Factory's Land during Combat Move and, during the Combat Phase, are met by Strategic AA fire; surviving Bombers roll for Factory damage that accumulates in `factory_dmg[Land]` (capped at 2× the Factory's production value). A Strategic Air Raid:

- Has exactly one Volley. No "round 2".
- Has no Retreat mechanic — surviving Bombers automatically return home in the End-Turn landing pass.
- Does not capture the Land, has no Defenders other than Strategic AA, never involves Casualty Selection on the defender side (the Factory just accumulates damage).
- Cannot mix with a Land Battle on the same Land in the same Combat Phase — the engine routes a target Land to Raid resolution only when *every* Unit moved in is a Bomber.

Long form **Strategic Air Raid** in prose; short form **Raid** in identifier stems (`gc.more_raids_needed`, `proc resolve_raid`, `proc resolve_strategic_aa_fire`). The legacy term "Strategic Bombing Raid" / "SBR" is retired — Bombers carry out Raids, but the mechanic is named **Strategic Air Raid** to keep the "bomb-" stem reserved for Naval Bombardment and the Bomber Unit Type. `resolve_strategic_bombing_raid` is slated for rename to `resolve_raid`.
_Avoid_: Strategic Bombing Raid, SBR, bombing raid, strategic bombing, factory bombing, bombing mission

**Boundary rule (bomb-word family)**: The stem "bomb-" carries two distinct things, kept strictly separated:

- **Bombardment** = naval shore fire (Battleships and Cruisers only, into an amphibious Land Battle). Verb: *to bombard*. Active State suffix: `_Bombarded`.
- **Bomber** = the Air Unit Type with Movement Allowance 6. Verb: *the Bomber attacks* (in a Battle) or *the Bomber raids* (in a Strategic Air Raid).

"Bombing", "Bomb Raid", and "Strategic Bombing" are **not** domain terms. A Bomber participating in a regular Battle is an Attacker (same as any other Attacker); a Bomber attacking a Factory is a **Raider** participating in a **Strategic Air Raid**. The word "Raid" never combines with "bomb-" — it is **Strategic Air Raid**, not "Strategic Bombing Raid".

**Casualty Selection**:
When a side takes Hits in a Volley, the engine chooses which specific Units become Casualties. Handled by a fixed-priority walk through per-context **Casualty Order** arrays (`Attacker_Sea_Casualty_Order_1` … `_4`, `Defender_Land_Casualty_Order_1` … `_2`, `Air_Casualty_Order_Fighters`, `Air_Casualty_Order_Bombers`, `Defender_Sub_Casualty`). The arrays are numbered in priority order (Order_1 dies first), and within each priority group the engine processes the Acting Nation's own Units before its Allies' Units in the same Sea — that's why each tier exists as a separate slice rather than one merged list. Battleships absorb their first Hit as Damage instead of becoming a Casualty (`hit_my_battleship`, `hit_ally_battleship`, `hit_enemy_battleship`). The Player never makes Casualty Selection choices; it is not exposed via the Plan API.
_Avoid_: hit assignment, loss allocation, casualty roll, casualty pick

**Retreat**:
A Battle-ending action available to the Attacker after any Volley (except the lead-in Volley containing only Naval Bombardment / AA Fire / First Strike pre-rolls): all surviving attacking Units in this Battle leave the Battle's Region together and relocate to a single Adjacent Region that they could have legally moved *from* during this Turn's Combat Move (i.e. an adjacent Friendly-owned Region or an adjacent Region they used as their staging origin). The Battle ends immediately; the Land is not captured; defending Units remain in place. Retreat applies only to Battles, never to Strategic Air Raids (Raids have no Retreat — surviving Bombers always carry through and return home in End Turn).

Key constraints:
- All Attackers retreat to the **same** destination Region; no per-Unit choice.
- A Sea Battle Retreat destination must be a Sea; a Land Battle Retreat destination must be a Land (amphibious assaults retreat back to a Sea the Attackers came from).
- The Defender never Retreats. "Defensive retreat" is not a domain term.
- Naval Bombardment ships do not Retreat (they already returned to their bombardment Sea and are spent).

**Engine status**: not yet implemented as a Player Decision. The `build_sea_retreat_options` and `sea_retreat` procs exist in `resolve_sea_battles` and accept a Retreat destination via `get_action_input`, but the Player-side Retreat Decision plumbing is incomplete; current Pro AI also does not Retreat (see Retreat Decision and `PRO_AI_QUICK_REFERENCE.md`). Tracked as a feature TODO, not as a Known bug — the *mechanic* will work when wired up; nothing is computing the wrong answer right now.
_Avoid_: withdraw, fallback, disengage, fall back, pull back

**Retreat Decision**:
After a Volley, the Player chooses whether the Attackers of this Battle Retreat and, if so, to which Adjacent Region. One Retreat Decision per Battle per Volley boundary. Currently stubbed: the engine asks via `build_sea_retreat_options` / `load_dyn_arr_actions` but the Plan API surface and Pro AI heuristic are unfinished (see `PRO_AI_QUICK_REFERENCE.md`).
_Avoid_: withdraw, fallback, disengage

**Submerge Decision**:
Per Volley, per eligible Submarine (i.e. those whose opposing side has no Destroyer in the Sea), the Player chooses whether the Sub Submerges (skips firing this Volley, untargetable) or fires (rolls Sub Attack Value or Sub Defense Value, becomes targetable). **Status: partially implemented.** The decision is part of the rules model; the current engine short-circuits it by always Submerging when eligible (see Submerge entry). Plan API surface and Pro AI heuristic are stubbed.
_Avoid_: dive, escape, sub-submerge

**Combat-resolution rename table** (bomb-family, AA, and combat stats):

| Current | Rename to |
|---|---|
| `Bombard_Ships` | `bombardment_ships` |
| `Ship_After_Bombard` | `ship_after_bombardment` |
| `init_Ship_After_Bombard` | `init_ship_after_bombardment` |
| `BATTLESHIP_BOMBARDED`, `BS_DAMAGED_BOMBARDED`, `CRUISER_BOMBARDED` | `Battleship_Bombarded`, `Battleship_Damaged_Bombarded`, `Cruiser_Bombarded` |
| `gc.max_bombards[Land]` | `gc.max_bombardment_dice[Land]` |
| `mark_ships_ineligible_for_bombardment` | (already canonical — keep) |
| `resolve_strategic_bombing_raid` | `resolve_raid` |
| `resolve_tactical_aa_defense` | `resolve_tactical_aa_fire` |
| Strategic AA inline fire (inside `resolve_raid`) | `resolve_strategic_aa_fire` (extract if it grows) |
| `gc.more_land_combat_needed`, `gc.land_combat_started`, `gc.sea_combat_started` | `gc.more_land_battles_needed`, `gc.land_battle_started`, `gc.sea_battle_started` |
| (new) per-Land "Strategic Air Raid pending" tracking | `gc.more_raids_needed` (Land bitset) |
| `INFANTRY_ATTACK`, `ARTILLERY_ATTACK`, `TANK_ATTACK`, `FIGHTER_ATTACK`, `BOMBER_ATTACK`, `DESTROYER_ATTACK`, `CARRIER_ATTACK`, `CRUISER_ATTACK`, `BATTLESHIP_ATTACK`, `SUB_ATTACK` | append `_VALUE` suffix: `INFANTRY_ATTACK_VALUE`, …, `SUB_ATTACK_VALUE` |
| `INFANTRY_DEFENSE`, `ARTILLERY_DEFENSE`, `TANK_DEFENSE`, `FIGHTER_DEFENSE`, `BOMBER_DEFENSE`, `DESTROYER_DEFENSE`, `CARRIER_DEFENSE`, `CRUISER_DEFENSE`, `BATTLESHIP_DEFENSE`, `SUB_DEFENSE` | append `_VALUE` suffix: `INFANTRY_DEFENSE_VALUE`, …, `SUB_DEFENSE_VALUE` |
| `damage: int` return-name in `calculate_land_attack_value`, `calculate_land_defense_value`, `calculate_naval_defense_value`, `calculate_sub_defense_value`, `get_total_attack_value_sea` | `total_attack_value: int` or `total_defense_value: int` as appropriate |
| `def_damage` local in `resolve_sea_battles` | `def_total_attack_value` |
| `bombing_damage_hits` local in `resolve_raid` | `raid_hits` |
| `combat_rounds_counter` (global) | `volley_counter` |
| `MAX_COMBAT_ROUNDS :: 120` | `MAX_VOLLEYS_PER_BATTLE :: 120` |
| `LOW_LUCK_THRESHOLD :: 3` | (already canonical — keep) |
| `DICE_SIDES :: 6` | (already canonical — keep) |
| Comments "sneak attack" / "surprise attack" / "surprise attack advantage" in `combat.odin` (lines ~84, ~383, ~865) | "First Strike" |
| `enemy_subs_detected` local in `resolve_sea_battles` | `defender_subs_detected` |
| `count_allied_subs` | (already canonical — keep, but note return name `allied_subs` reads as attacker-side from caller context) |

**Known combat bugs (tracked here, not fixed in this rename pass):**

- **FS-1**: Defender Subs do not get a separate First Strike Volley when the attacker has no Destroyer (see First Strike entry).
- **FS-2**: Subs and Air Units can Hit each other freely; no Destroyer gating in dice-pool split or Casualty Selection (see Sub/Air Targeting entry).
- **EP-1 (Phase: Purchase fusion)**: Purchase is not a separate Phase in `play_full_turn`. `buy_units` deducts IPC and Places Units atomically, *after* Combat. Standard A&A and the canonical 6-Phase model require Purchase first, *before* Combat Move, with Purchased Units queued onto the Nation's Purchased Units list and Placed only during Phase 5. Future fix: extract a `resolve_purchase_phase` that runs at Turn start and writes to `purchased_units`; have `resolve_place_phase` (renamed from `buy_units`) consume that list.
- **EP-2 (Phase: Repair fusion)**: Repair is not its own first-class step. `purchase.odin:154` inlines a `repair_cost := max(0, 1 + factory_dmg - builds_left)` surcharge into the per-unit Place loop. Standard A&A repairs Factories as a separate Purchase-Phase expenditure (1 IPC per damage point, paid before any Unit is Purchased). Future fix lands together with EP-1: a Repair step at Purchase Phase start that decrements `factory_dmg` and debits Treasury.

FS-1 and FS-2 require restructuring `resolve_sea_battles` dice-pool and Casualty Selection plumbing; fix them together. EP-1 and EP-2 share the same refactor (extracting the Purchase Phase); also fix them together.

**Pro AI code is grandfathered.** Identifiers like `attack_power`, `defense_power`, `estimate_attack_power`, `estimate_defense_power` in `pro_data.odin` / `pro_combat_move.odin` / `pro_noncombat_move.odin` are known to use the wrong vocabulary; they will be replaced wholesale in the future data-oriented rewrite and are not part of this rename pass.

### Engine bookkeeping

**Acting Nation**:
The single Nation whose Turn is currently being played. The only Nation that can submit a Plan, mutate Active State, or appear as an Active Unit. The Acting Nation rotates at Turn end.
_Avoid_: current player, cur_player, mover, current nation, on-move, current power

**Roster**:
The canonical count store: for every Region × Nation × Unit Type, how many Units of that Type are in that Region belonging to that Nation. Tracks every Unit in the game at all times; does not track Active State or Cargo Loadout. Renames the current engine concept "Idle" (which misleadingly suggests "not in use" — the Roster is actually ground truth).
_Avoid_: idle, idle units, inventory, stockpile, ground truth (informal only)

**Active Unit**:
One of the Acting Nation's Units treated as an in-flight piece on the board, carrying its Active State (and, for Transports, its Cargo Loadout). Active Units exist only for the Acting Nation, only during their Turn. At Turn end, Active Units are collapsed back into the Roster and discarded.
_Avoid_: active, mover, mobile unit, live unit

**Active State**:
The transient within-Turn per-Unit tag attached to an Active Unit. Encoded as a suffix (and, for Battleship, an inner segment) on `Active_Unit` enum values. "Active" pairs with **Active Unit** — an Active Unit *has* an Active State. Five states exist; the first four are mutually exclusive, Damaged composes with the others as a middle segment:

| State | Canonical | Enum suffix | What it means |
|---|---|---|---|
| Has N moves remaining | **N Moves** | `_N_Moves` | The Unit still has N movement points this Turn (N is a literal count up to the Unit Type's max). |
| Not yet moved | **Unmoved** | `_Unmoved` | The Unit has not moved this Turn *and is distinct from its max-moves state* because it was placed mid-Turn (e.g. a Fighter placed on a just-built Carrier). Only Fighter, Bomber, and Transport use this. |
| Already unloaded | **Unloaded** | `_Unloaded` | Transport-only. The Transport delivered its Cargo Loadout to a Land this Turn and cannot move again. |
| Already bombarded | **Bombarded** | `_Bombarded` | Cruiser/Battleship-only. The warship fired its one shore-bombardment shot this Turn and cannot bombard again. |
| Damaged (Battleship) | **Damaged** | `_Damaged_` (middle segment) | Battleship-only. Took 1 hit but not killed; persists until repaired. Composes with the movement/bombarded suffix: `Battleship_Damaged_2_Moves`, `Battleship_Damaged_0_Moves`, `Battleship_Damaged_Bombarded`. Automatically repaired at the end of the owner's Place Phase — no Factory adjacency or repair-cost is required. |

For Transports, Active State is combined with Cargo Loadout in a single enumeration (Unit Type × Cargo Loadout × Active State). This is the idiomatic encoding given the GNN's fixed-size-vector input constraint — collapsing the triple into one flat enum lets the observation be a stable count store per Region.
_Avoid_: movement state, turn state, action state, activity, mode, flag

**Cargo Loadout**:
The specific combination of Units a Transport is currently carrying. Only Transports have a Cargo Loadout; it is part of the Transport's `Active_Unit` identity, not a separate set of Units in the Region. Exactly seven loadouts are legal in A&A 2nd edition (`Cargo_Loadout` enum), with one canonical name each:

| Canonical | Enum value | Letter-code (legacy, slated for rename) |
|---|---|---|
| Empty | `.Empty` | `EMPTY` |
| 1 Infantry | `.Infantry` | `1I` |
| 2 Infantry | `.Infantry_Infantry` | `2I` |
| 1 Artillery | `.Artillery` | `1A` |
| 1 Tank | `.Tank` | `1T` |
| 1 Infantry + 1 Artillery | `.Infantry_Artillery` | `1I_1A` |
| 1 Infantry + 1 Tank | `.Infantry_Tank` | `1I_1T` |

Forbidden loadouts: any combination not in this table — notably `2A`, `2T`, and `1A_1T` are illegal and must never appear in code, tests, or generated Plans. The phrase "Cargo" alone remains usable as a generic noun in prose ("the Transport's Cargo is 1 Infantry + 1 Tank") but the *named glossary concept* is **Cargo Loadout**.
_Avoid_: load, payload, contents, cargo manifest, cargo config, cargo state

### Ownership

**Boundary rule**: **Friendly / Enemy** are *perspective-relative* and shift with the Acting Nation. **Allies / Axis** are the two fixed Team names. They overlap only by coincidence — when the Acting Nation is on the Allies Team, "Friendly Nation" and "Allied Nation" name the same set; when the Acting Nation is on the Axis Team, "Friendly Nation" = Axis Nation, *not* Allied Nation. Never say "allied" to mean "Friendly".

**Owner**:
The Nation currently controlling a Land. Stored as `owner[Land]`. Determines Land Value income and Place eligibility. Sea has no Owner.
_Avoid_: controller, holder, ruler, occupant

**Original Owner**:
The Nation that owned a Land at the start of the game. Static (set once at init); used to resolve liberation — when a Friendly Nation captures a Land previously held by another Nation on the same Team, ownership returns to the Original Owner instead of the conqueror. Stored as `original_owner[Land]`.
_Avoid_: starting owner, founding owner, home nation, pre-war owner

**Capture**:
The event of a Land changing Owner as a result of a Battle. After a Land Battle resolves with only Friendly Units remaining in the Region, the Land is Captured and its new Owner is the Acting Nation — except in the Liberation case (see below). Triggers Capital-capture side effects when the Land is an Enemy's Capital (the captured Treasury transfers to the conqueror). Handled by `transfer_land_ownership` in `land.odin`.
_Avoid_: conquest, take, seize, occupy (as a verb meaning Capture), invade (as a verb meaning Capture)

**Liberation**:
The special-case rule for Capture: if the Captured Land's Original Owner is on the Acting Nation's Team (i.e. Friendly), Ownership returns to the Original Owner rather than to the Acting Nation. Example: if Germany has been holding a Land originally owned by the United Kingdom, and the USA captures it, the Land becomes UK-owned again (not USA-owned). No special bookkeeping fires — Liberation is just the branch in `transfer_land_ownership` that sets `new_owner = mm.original_owner[dst_land]`.
_Avoid_: return, restoration, freeing, recapture

**Friendly**:
Perspective-relative: on the Acting Nation's Team. A Friendly Nation is the Acting Nation itself or any other Nation on its Team. A Friendly Unit/Land is one belonging to a Friendly Nation. Always defined relative to the Acting Nation — when Germany is acting, Japan is Friendly to Germany. The engine bitset `gc.friendly_owner` is the set of Lands whose Owner is Friendly. Cache fields currently prefixed `allied_*` (e.g. `allied_carriers_total`) are slated for rename to `friendly_*` to match this convention and pair cleanly with the existing `enemy_*` siblings.
_Avoid_: allied (when meaning Friendly rather than the Allies Team), home, our, ours, same-side

**Enemy**:
Perspective-relative: on the opposite Team from the Acting Nation. An Enemy Nation is any Nation not on the Acting Nation's Team. An Enemy Unit/Land is one belonging to an Enemy Nation. Always defined relative to the Acting Nation — when Germany is acting, Russia, United Kingdom, and USA are all Enemy. Stored as cache fields prefixed `enemy_*` (e.g. `enemy_fighters_total`, `enemy_subs_total`).
_Avoid_: hostile, opponent (when meaning a Unit/Nation), foe, axis (when meaning Enemy rather than the Axis Team), allies (when meaning Enemy rather than the Allies Team)

**Neutral**:
*Not a domain concept in this engine.* `Player_ID` has exactly 5 values (Russia, Germany, United Kingdom, Japan, USA) and every Land has an Owner from this set at all times. References to "neutral territories" in `src/pro_combat_move.odin` are inherited from TripleA's Java code and do not correspond to any engine concept — they should be removed or restated in terms of Enemy ownership during the rename pass. Banned in new code, identifiers, comments, and the Plan API.
_Avoid_: neutral, unowned, no-owner, unaligned, non-aligned, neutral nation

**Capital**:
The single Land designated as a Nation's seat of government. Capturing a Nation's Capital transfers that Nation's entire Treasury to the conqueror. One per Nation, fixed at game init. Stored as `capital[Nation]`.
_Avoid_: home, headquarters, seat, capitol

**Factory**:
A Unit Type that, once Placed on a Land, lets the Land's Owner Place newly Purchased Units there each Turn. A Factory has Production Capacity, never moves, can be damaged by Strategic Bombing, and is captured along with its Land. The Factory has two representations in the engine — counted in the Roster as a Unit, and exposed via the Land properties `factory_prod[Land]` and `factory_dmg[Land]`. The cache `factory_locations[Nation]` is a non-persistent denormalized index for fast iteration during Place Phase, not a source of truth.
_Avoid_: factory unit, plant, IC, industrial complex, building

**Production Capacity**:
The maximum total IPC of Units a Factory can Place in one Place Phase, before subtracting Factory Damage. Equal to the Land Value of the hosting Land. Stored as `factory_prod[Land]`; reads `0` as the sentinel for "no Factory present".
_Avoid_: factory production, build limit, output, slots, capacity

**Factory Damage**:
Accumulated damage on a Factory, dealt by Strategic Bombing. Subtracted from Production Capacity to get this Turn's effective build limit. Can be reduced by repairs during the Purchase Phase. Stored as `factory_dmg[Land]`.
_Avoid_: factory hp, damage, wear, bomb damage

**Strategic Bombing**:
A special Battle variant where a Bomber raids an enemy Factory's Land instead of engaging combat Units, rolling dice to inflict Factory Damage. Handled by `resolve_strategic_bombing_raid` before any normal Land Battle at the same Land.
_Avoid_: bombing raid, SBR, factory bombing, industrial strike

### Engine architecture

**Game State**:
The minimal, fully-serializable description of a single moment in the game. The source of truth. If two Game States are equal, the games are identical. Contains the Roster, Treasury per Nation, Owner and Original Owner per Land, Capital assignments, Production Capacity and Factory Damage per Land, Acting Nation, Round, Phase, Purchased Units, and any in-flight Battle state. Excludes anything derivable. This is the data passed across the FFI to the RL stack.
_Avoid_: game, state, save state, position, snapshot

**Game Cache**:
A working copy of a Game State plus derived indexes, per-Turn projections (Active Units with Active State), and performance caches (`factory_locations`, `more_land_combat_needed`, `builds_left`, etc.). Mutated in place during a Turn. Not authoritative — the cache legitimately duplicates Game State data in a different shape for fast access, but anywhere the two disagree the Game State wins. Recomputed from a Game State on load.
_Avoid_: cache, working state, runtime state, scratch

**Observation**:
The Python-side view a Player's policy and value network consume. Constructed on demand from a Game State, with per-Nation feature rotation applied so the viewing Nation occupies a canonical "mover" slot. A `torch_geometric.data.HeteroData` graph plus a global feature vector. Observations live entirely in `rl-agent/`; the engine emits Game State and the RL stack builds the Observation. (See `docs/adr/0001-observation-built-on-rl-side.md`.)
_Avoid_: view, perspective, canonical state, network input

**Canonical Form**:
The convention that an Observation rotates per-Nation feature planes so plane 0 is always the viewing Nation, plane 1 the next opponent, and so on, while geography (Lands, Seas, edges) stays fixed. A property of how Observations are built; not a separate data structure.
_Avoid_: mover frame, rotated form, POV

### Outcome

**Victory**:
The single win condition: at the end of the Combat Phase, if the current Team owns at least 4 Capitals, that Team wins and the game ends. There are no draws, no round limits, no annihilation conditions, and no other terminal states — every game ends in Victory for exactly one Team. At Victory the engine reports `is_terminal == true`, `team_reward == +1` for the winning Team and `-1` for the losing Team.
_Avoid_: win, victory condition, game end, terminal, endgame

### Economy

**IPC**:
The currency unit of the game. 1 IPC pays for 1 IPC of Unit cost. Always abbreviated; treated as a mass noun ("Russia has 24 IPC", not "24 IPCs"). Never spelled out as "Industrial Production Certificate" in code or docs.
_Avoid_: money, cash, dollars, credits, gold, coin

**Income**:
The per-Turn currency intake event during End Turn (Phase 6): the Acting Nation receives IPC equal to the sum of Land Values for the Lands it owns, **gated on Capital ownership** — if the Acting Nation's Capital is not currently owned by that Nation, Income is $0 for this Turn. The *event*, not the cumulative pool. Engine: `collect_money :: proc(gc)` reads `gc.income[gc.cur_player]` (the cached Land-Value sum, maintained incrementally on every Land-Ownership change) and adds it to `gc.money[gc.cur_player]` only if `gc.owner[mm.capital[gc.cur_player]] == gc.cur_player`. Slated rename: `collect_money` → `collect_income`.
_Avoid_: money collection, payday, revenue, paycheck

**Treasury**:
The IPC a Nation has on hand at any moment. Increases by Income at End Turn; decreases when Units are Purchased or when Factory Repair is paid. Stored per-Nation, persists across Turns. The current engine field `gc.money[Nation_ID]: [6]u8` is the Treasury — 6 slots: 5 active Nations plus the Italy Phantom Nation slot (see Phantom Nation). The Phantom slot is initialized to 0 and never grows. Slated rename: `gc.money` → `gc.treasury`.
_Avoid_: money, funds, balance, wallet, bank, coffers

**Land Value**:
The recurring IPC contribution a single Land makes to its owner's Income, printed on the map. Does not include convoy contributions (those are properties of Seas).
_Avoid_: IPC value, income value, production value, territory value

**Purchased Units**:
Units that have been bought during a Purchase Phase but not yet Placed on the board. Live on a Nation between Purchase Phase and Place Phase; emptied during Place Phase as Units are committed to Factories. Stored per-Nation as `purchased_units` in the engine. *Currently unused as an intermediate list* — the engine's fused `buy_units` skips the queue and places atomically (see EP-1). The slot is reserved for the post-EP-1 split.
_Avoid_: order queue, force pool, build queue, production queue, pending placements, owed units

**Purchase Phase**:
Phase 1 of a Turn. The Acting Nation spends IPC from its Treasury on Units (queued onto the Purchased Units list) and on Factory Repair (paid as 1 IPC per Factory Damage point). No Units enter the board; no Units move; no Battles staged. Output: a decremented Treasury, a populated Purchased Units list, and reduced `factory_dmg[land]` on Repaired Factories. Engine status: **not separated from Place — see EP-1, EP-2**. Future proc: `resolve_purchase_phase`.
_Avoid_: buy phase, build phase, production phase, shopping phase

**Factory Build**:
The Purchase-Phase sub-action of buying a new Factory at $15 IPC on a Land you own that (a) has no existing Factory, (b) is not staged for Combat this Turn, and (c) is not your Capital itself (Capitals already have a Factory by convention). On commit, sets `factory_prod[land] = mm.value[land]` for that Land. There is currently no per-Turn cap on Factory Builds; a Nation with enough Treasury may Build multiple Factories on the same Turn. Engine proc: `buy_factory` (slated rename to `resolve_factory_build`). Constant: `FACTORY_COST :: 15`.
_Avoid_: build factory, construct factory, found factory, new factory build, IC purchase, IC build

**Place Phase**:
Phase 5 of a Turn. The Acting Nation commits Purchased Units to the board at owned Factories, subject to per-Factory caps (`builds_left[land]`, initialized at Turn rotation to `factory_prod[land]`). A Factory captured this Turn cannot Place: `builds_left` for that Land was reset to 0 by the previous owner's rotation and is not re-set until *this* Nation's next rotation. Sea Units may be Placed in any Sea Adjacent to an owned coastal Factory; Land Units are Placed on the Factory's Land. Engine proc: `buy_units` (slated rename to `resolve_place_phase`); currently performs the entire Purchase+Place fused operation (see EP-1).
_Avoid_: deployment, deploy phase, placement phase, drop phase, mobilize phase

**Repair**:
A Purchase-Phase sub-action: the Acting Nation pays IPC from its Treasury to reduce `factory_dmg[land]` on Damaged Factories it owns, at the rate of 1 IPC per damage point. A Factory at full Damage cap (2 × `factory_prod`) can be partially or fully repaired. Engine status: **currently fused into the Place loop as a per-unit surcharge** — see EP-2. Battleship repair is a separate mechanic (automatic, no IPC cost, at End Turn) and is **not** called Repair to avoid collision; see Battleship Damage in the Damage entry.
_Avoid_: fix, restore, rebuild, mend, factory repair surcharge

**Capital**:
The single Land for each active Nation that hosts its government and starts with a Factory. Lost when an enemy Acting Nation captures it via a winning Land Battle. While a Nation's Capital is held by an enemy, that Nation: collects $0 Income at End Turn (see Income entry), retains ownership of its non-Capital Lands, and may continue to take Turns (units still move, Factories still produce if `builds_left > 0`). Nations have exactly one Capital; recapturing your own Capital restores Income next End Turn. Phantom Nations have no Capital. Engine: `mm.capital[Nation]` returns the Capital Land.
_Avoid_: home, homeland, headquarters, HQ, seat, government

**Capital Capture**:
The game event triggered when an enemy Acting Nation wins a Land Battle for a Nation's Capital and gains Ownership of that Land. Two side effects beyond the standard Land-capture rules:

1. **Treasury transfer**: the captured Nation's entire Treasury (`gc.money[captured]`) transfers in full to the capturing Acting Nation (`gc.money[gc.cur_player] += gc.money[old_owner]; gc.money[old_owner] = 0`). The captured Nation's bank is emptied.
2. **Income suspension**: starting next End Turn, the captured Nation receives $0 Income (Income gate checks `owner[capital] == this_nation`). Recapture restores Income.

Team-level **Victory** is computed over Capitals owned across both Teams (4 Capitals = Victory); Capital Capture is therefore the only board event that can directly end the game. Engine: handled inline in `land.odin:capture_land`.
_Avoid_: capital fall, capital takeover, HQ capture, capital sack

### Example dialogue

A new contributor (Dev) is reading the engine for the first time and asks a maintainer (Domain) to walk through a turn.

> **Dev**: I see five "players" hard-coded. Are those the agents?
>
> **Domain**: No — those are **Nations**: Russia, Germany, United Kingdom, Japan, USA. They're the countries on the board. Nations are grouped into two **Teams** (Allies = Russia / United Kingdom / USA, Axis = Germany / Japan). In the RL framing there are exactly two **Players**, one per Team. A Player drives every Nation on its Team. So when it's Germany's turn, the Axis Player is acting *as* Germany.
>
> **Dev**: OK. And `gc.cur_player` is which of those?
>
> **Domain**: That's the **Acting Nation** — the one Nation whose Turn it is right now. The variable name is a wart we're renaming. One full pass through all five Nations (Russia → Germany → United Kingdom → Japan → USA) is a **Round**. One Nation's slice of that pass is a **Turn**.
>
> **Dev**: And inside a Turn?
>
> **Domain**: Six **Phases** in order: Purchase, Combat Move, Combat, Non-Combat Move, Place, End Turn. The Combat Phase resolves every battle the Acting Nation started; each battle is one or more **Volleys** — a Volley is one simultaneous dice exchange. Don't say "combat round"; that collides with Round-the-game-pass.
>
> **Dev**: Where does the agent actually make a decision?
>
> **Domain**: The agent submits a **Plan** — an ordered sequence of **Sub-actions** ending in `FINALIZE` — at three points per Turn: Purchase, Combat Move, and Non-Combat Move. Place and Combat resolution are mechanical. The legal Sub-action set at any moment comes from the engine, not the agent.
>
> **Dev**: Got it. Now — `idle_armies[Moscow][Russia][Inf] == 4`. There are four "idle" infantry in Moscow?
>
> **Domain**: There are four infantry, full stop. "Idle" is the wart name for the **Roster** — the canonical present-and-accounted-for count of Units of one Unit Type at one Region for one Nation. They're not idle in any English sense; they just haven't been spawned into the per-movement-state tracking enums yet this Turn. We're renaming those fields to `roster_*`.
>
> **Dev**: And **Active_Unit** with 73 values?
>
> **Domain**: That's the god-enum the GNN sees. It flattens Unit Type × Cargo Loadout × Active State into one fixed-size vector slot per Region. Don't try to split it; the observation needs a fixed shape.
>
> **Dev**: Moves. A fighter flying from Sea_17 to Sea_18 — does that pass through Suez?
>
> **Domain**: Sea_17 to Sea_18 is two **Seas**, both **Regions**. Suez is a **Canal** banking Sea_17 ↔ Sea_34, not Sea_18. Canals are only passable for ships and carrier-borne planes when the Acting Nation's Team owns both banking Lands — Suez needs Egypt *and* Trans-Jordan. Free-flying fighters and bombers don't care about Canals; they fly over Lands and Seas freely.
>
> **Dev**: Money. `gc.money[Russia]` is what Russia earns each turn?
>
> **Domain**: No — that's the **Treasury**, the IPC Russia has on hand right now. **Income** is the *event* at End Turn that adds IPC equal to the sum of **Land Values** of Russia's owned Lands. Don't conflate the three: IPC is the unit, Income is the event, Treasury is the pool.
