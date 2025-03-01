# Axis and Allies written in Odin

Game Overview:
This is an implementation of Axis & Allies Second Edition, a turn-based strategy game.
The game features two teams (Allies and Axis) with 5 players:
- Allies: Russia (RUS), England (ENG), United States (USA)
- Axis: Germany (GER), Japan (JAP)

Turn Structure:
1. Air Phase:
   - Move unmoved fighters (for carrier landing options)
   - Move unmoved bombers
2. Naval Phase:
   - Move combat ships
   - Stage transports (pre-positioning)
3. Land Phase:
   - Move armies (including loading onto transports)
   - Move transports
   - Resolve sea battles
   - Unload transports
   - Resolve land battles
4. Cleanup Phase:
   - Move AA guns
   - Land remaining fighters
   - Land remaining bombers
   - Buy units
   - Buy factory
   - Reset units
   - Collect money
   - Rotate turns

Movement System:
1. Movement States:
   - UNMOVED: Unit has not been offered movement this turn
   - X_MOVES: Unit has X moves remaining (0, 1, or 2)
   - UNLOADED: (Transport specific) Declined to unload cargo
   - BOMBARDED: (Battleships/Cruisers) Used bombardment ability

2. Transport System:
   Capacity: 5 spaces total
   Unit Space Requirements:
   - Infantry (INF): 2 spaces
   - Artillery (ARTY): 3 spaces
   - Tank (TANK): 3 spaces
   - AA Gun: 6 spaces (exceeds capacity)

   Valid Configurations:
   - TRANS_EMPTY: No cargo
   - TRANS_1I: 1 Infantry
   - TRANS_1A: 1 Artillery
   - TRANS_1T: 1 Tank
   - TRANS_1I_1A: 1 Infantry + 1 Artillery
   - TRANS_1I_1A: 1 Infantry + 1 Tank
   - TRANS_2I: 2 Infantry

3. Transport Movement Sequence:
   a. Pre-staging Phase:
      - Transport starts as UNMOVED
      - Can move 0-2 spaces to position for loading
      - State changes to X_MOVES based on movement
      - Declining pre-stage sets to 2_MOVES
   b. Loading Phase:
      - Land units can load onto pre-staged transports
      - Loading allowed regardless of transport's moves
   c. Transport Movement Phase:
      - Transport moves with cargo
   d. Unloading Phase:
      - Transport unloads or declines (becomes UNLOADED)
      - No further movement or loading after unloading

Map Structure:
1. Movement Connections:
   - Land-to-Land (l2l): Direct land connections
   - Sea-to-Sea (s2s): Direct sea connections
   - Land-to-Sea (l2s): Where units can load/unload from transports
   - Air-to-Air (a2a): Air movement possibilities (X = 1-6)

2. Canals:
   - Connect specific sea zones
   - Require control of both connecting territories
   - Status tracked in canals_open bitset

State Management:
1. Game_State:
   - Core game state for save/load
   - Minimal required information

2. Game_Cache:
   - Derived data rebuilt from Game_State
   - Updated partially during turn rotation
   - No duplicate data with Game_State

3. Unit Tracking:
   - Active units: Belong to current player, includes movement state
   - Idle units: All other players' units, no movement tracking needed

Combat System:
1. Naval Combat:
   - Transports are vulnerable and have no combat power
   - Must be protected by combat ships

2. Bombardment:
   - Battleships and Cruisers: one bombardment per turn
   - State tracked via _BOMBARDED suffix

3. AA Defense:
   - Roll before regular combat
   - 1 die per plane (max 3 dice per AA gun)

AI Implementation:
- Uses Monte Carlo Tree Search (MCTS)
- Evaluates possible game states
- Provides move recommendations
- Performance optimized through Game_Cache structure
