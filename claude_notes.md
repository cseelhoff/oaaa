# Claude's Notes on OAAA Project Architecture

## Key Learnings from Failed Experiment

### Game State Architecture

**Critical Understanding:**
- `idle_armies`, `idle_ships`, `idle_planes`: Track ALL players' units in ALL locations `[Location][Player][UnitType]u8`
- `active_armies`, `active_ships`, `active_planes`: Track ONLY current player's movable units `[Location][UnitState]u8`
- `current_territory` and `current_active_unit`: These are **transient internal state** used during turn processing, NOT permanent markers of actions taken

### The Active Units Pattern

When a player's turn starts (in `rotate_turns`):
```odin
for land in Land_ID {
    idle_armies := &gc.idle_armies[land][gc.cur_player]
    gc.active_armies[land][.INF_1_MOVES] = idle_armies[.INF]
    gc.active_armies[land][.ARTY_1_MOVES] = idle_armies[.ARTY]
    gc.active_armies[land][.TANK_2_MOVES] = idle_armies[.TANK]
    gc.active_armies[land][.AAGUN_1_MOVES] = idle_armies[.AAGUN]
    // Similar for planes and ships
}
```

**Why this matters:** When `get_possible_actions` or `apply_action` loads a mid-game state, the active units arrays must be explicitly initialized from idle units for the current player, or you'll get stale data from previous states.

### Game Flow

1. `rotate_turns` is called at the **END** of `play_full_turn`, not the start
2. It advances `cur_player` to next player
3. It clears and repopulates `active_*` arrays for the NEW current player
4. When MCTS loads a state, there's no guarantee active arrays are properly set

### MCTS Architecture Issues Discovered

**Problem:** MCTSNode stores `src_air` and `unit` fields, but these were being populated from Game_State's `current_territory` and `current_active_unit` which are:
- Transient values used during turn processing
- Not reliable indicators of what action was actually taken
- Often contain stale data from previous action processing

**Action Structure:**
- Actions are simple enums: `Anhwei_Action`, `Alaska_Action_32`, etc.
- Action names indicate DESTINATION or PURCHASE, not source
- Actions with suffixes (_32, _16, _8, _4, _2, none) represent different contexts
- There's no way to reconstruct the source territory from an action alone

### Functions That Need Active Units Initialization

When loading a Game_State for processing, these functions MUST initialize active units:

1. **`get_possible_actions`** (lines 432-520 in engine.odin)
   - Purpose: Collect all valid actions for current player
   - Must initialize: active_armies, active_ships, active_planes from idle_* arrays
   
2. **`apply_action`** (lines 489-509 in engine.odin)  
   - Purpose: Apply one action and advance game state
   - Must initialize: active_armies, active_ships, active_planes from idle_* arrays

3. **`random_play_until_terminal`** (lines 382-412 in engine.odin)
   - Uses `answers_remaining = 0` for random rollouts
   - Active units initialized through normal game flow

### What Went Wrong in the Experiment

1. Initially didn't recognize active units need initialization when loading states
2. Tried to capture src_air/unit BEFORE applying action (wrong - they were stale)
3. Tried to use post-action state (wrong - already moved to next territory)
4. Finally realized: `current_territory` and `current_active_unit` are unreliable for this purpose
5. Correct solution: Don't try to display source territories - just show action names

### Correct Approach

**For MCTS Display:**
- Show action name (e.g., "Anhwei_Action") 
- Show player whose turn it is
- Show visits and average value
- Don't try to show source territories or unit types - they can't be reliably determined

**For State Management:**
- Always initialize active_* arrays when loading a Game_State for processing
- Copy initialization pattern from `rotate_turns` (lines 270-310 in engine.odin)
- Clear active arrays first, then populate from idle arrays for current player only

### Other Architecture Notes

**PRO-AI System:**
- Filters invalid/bad actions during tree expansion and rollouts
- Uses `use_pro_ai` flag for tree expansion filtering
- Uses `use_pro_ai_rollout` flag for rollout filtering  
- Stored in Game_State, copied to Game_Cache during processing

**State Caching:**
- Every 50th node stores full Game_State for faster reconstruction
- Reduces replay overhead from ~40x to ~1x for deep nodes
- Controlled by `CACHE_INTERVAL` constant

**Early Termination:**
- Detects 3:1 advantage ratios (material, economic, territorial)
- Implemented in early_termination.odin
- Used during training to speed up obvious wins

**Debug System:**
- `GLOBAL_TICK` counter tracks total operations
- `ACTUALLY_PRINT` flag controls output
- `debug_checks` function validates state consistency
- Threshold at 100000000000 enables debug output

### AlphaZero Integration

The project is designed for AlphaZero training:
- `alpha_game.odin` provides Python FFI interface
- 13,712 feature vector representing game state
- Sequential action model (not batched parallel moves)
- Complete turn simulation for NN training

### Testing Commands

```powershell
# Quick test with PRO-AI, no rollouts
.\build\oaaa.exe 2001 true false

# Full test with rollouts
.\build\oaaa.exe 2001 true true

# Build optimized
odin build src -out:build/oaaa.exe -o:aggressive -no-bounds-check -disable-assert -collection:src=src
```

## What NOT to Do

❌ Don't trust `current_territory` / `current_active_unit` for anything except current processing context
❌ Don't try to reconstruct action sources from post-action state
❌ Don't modify `rotate_turns` - it's called at END of turn for a reason
❌ Don't forget to initialize active_* arrays when loading states
❌ Don't use `save_json` on Game_State (u128 bitsets not supported by JSON marshaler)

## What TO Do

✅ Initialize active_* arrays in any function that loads and processes a Game_State
✅ Use action names directly for MCTS display
✅ Trust idle_* arrays as source of truth for unit locations
✅ Follow the pattern in `rotate_turns` for active unit initialization
✅ Use PRO-AI flags to control filtering during expansion vs rollouts
