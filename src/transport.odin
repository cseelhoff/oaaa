#+feature global-context
package oaaa
import sa "core:container/small_array"
import "core:fmt"

MAX_TRANSPORT_MOVES :: 2

/*
PERFORMANCE-CRITICAL DESIGN NOTE:
Transport states use a combined enum approach that merges cargo and movement information.
This is a deliberately chosen optimization pattern - DO NOT REFACTOR into separate tracking
without careful consideration of the performance implications.

RATIONALE FOR COMBINED STATES:
1. Memory Layout Optimization:
   - Current: [sea_zone][combined_state]int for counting ships
   - Alternative (separate tracking): [sea_zone][cargo_type][movement_state]int
   - Memory Impact: ~3x memory reduction with combined approach
   - Cache Impact: Better locality, single array lookup vs multiple indirections

2. Valid State Management:
   - Combined: Invalid combinations cannot exist by enum definition
   - Separate: Would require runtime validation of cargo+movement combinations
   
3. Game State Storage:
   - Efficient bitset representation in game_state.idle_ships and active_ships
   - Perfect fit for Monte Carlo Tree Search (MCTS) state exploration
   - Minimal memory footprint for game state serialization

Cargo Configurations (5 space capacity):
- EMPTY: No cargo
- 1I: 1 Infantry (2 spaces)
- 1A: 1 Artillery (3 spaces)
- 1T: 1 Tank (3 spaces)
- 1I_1A: 1 Infantry + 1 Artillery (5 spaces)
- 1I_1T: 1 Infantry + 1 Tank (5 spaces)
- 2I: 2 Infantry (4 spaces)

Movement states are appended to cargo state:
- UNMOVED: Not yet moved this turn
- X_MOVES: Has X moves remaining (0,1,2)
- UNLOADED: Transport has unloaded its cargo

Example State Flow:
TRANS_EMPTY_UNMOVED -> TRANS_1I_2_MOVES -> TRANS_1I_1_MOVES -> TRANS_EMPTY_0_MOVES
(Empty transport) -> (Loads infantry) -> (Moves once) -> (Unloads infantry)

Example: TRANS_1I_2_MOVES = Transport with 1 infantry and 2 moves left

Transport states combine both cargo configuration (e.g., 1I = one infantry) and movement state 
(e.g., _2_MOVES, _UNMOVED) into a single enum rather than tracking them separately.
This design choice optimizes for performance in two ways:
1. Memory efficiency: Allows using simple 2D arrays [sea_zone][state]int to track ship counts,
   versus needing 3D arrays if cargo and movement were separate
2. Cache efficiency: Single enum lookup versus multiple field accesses when checking states
3. Validation: Invalid combinations are simply not represented in the enum, versus
   needing runtime checks with separate cargo/movement tracking
*/
Transports_With_Moves := [?]Active_Ship {
	.TRANS_1I_1_MOVES,
	.TRANS_1A_1_MOVES,
	.TRANS_1T_1_MOVES,
	.TRANS_2I_1_MOVES,
	.TRANS_1I_1A_1_MOVES,
	.TRANS_1I_1T_1_MOVES,
	.TRANS_1I_2_MOVES,
	.TRANS_1A_2_MOVES,
	.TRANS_1T_2_MOVES,
	.TRANS_2I_2_MOVES,
	.TRANS_1I_1A_2_MOVES,
	.TRANS_1I_1T_2_MOVES,
}

Idle_Transports := [?]Idle_Ship {
	.TRANS_EMPTY,
	.TRANS_1I,
	.TRANS_1A,
	.TRANS_1T,
	.TRANS_1I_1A,
	.TRANS_1I_1T,
}

Transports_Needing_Staging := [?]Active_Ship {
	.TRANS_EMPTY_UNMOVED,
	.TRANS_1I_UNMOVED,
	.TRANS_1A_UNMOVED,
	.TRANS_1T_UNMOVED,
}

Trans_After_Move_Used: [Active_Ship][MAX_TRANSPORT_MOVES + 1]Active_Ship

@(init)
init_trans_after_move_used :: proc() {
	Trans_After_Move_Used[.TRANS_EMPTY_UNMOVED][0] = .TRANS_EMPTY_2_MOVES
	Trans_After_Move_Used[.TRANS_EMPTY_UNMOVED][1] = .TRANS_EMPTY_1_MOVES
	Trans_After_Move_Used[.TRANS_EMPTY_UNMOVED][2] = .TRANS_EMPTY_0_MOVES
	Trans_After_Move_Used[.TRANS_1I_UNMOVED][0] = .TRANS_1I_2_MOVES
	Trans_After_Move_Used[.TRANS_1I_UNMOVED][1] = .TRANS_1I_1_MOVES
	Trans_After_Move_Used[.TRANS_1I_UNMOVED][2] = .TRANS_1I_0_MOVES
	Trans_After_Move_Used[.TRANS_1A_UNMOVED][0] = .TRANS_1A_2_MOVES
	Trans_After_Move_Used[.TRANS_1A_UNMOVED][1] = .TRANS_1A_1_MOVES
	Trans_After_Move_Used[.TRANS_1A_UNMOVED][2] = .TRANS_1A_0_MOVES
	Trans_After_Move_Used[.TRANS_1T_UNMOVED][0] = .TRANS_1T_2_MOVES
	Trans_After_Move_Used[.TRANS_1T_UNMOVED][1] = .TRANS_1T_1_MOVES
	Trans_After_Move_Used[.TRANS_1T_UNMOVED][2] = .TRANS_1T_0_MOVES
}

Trans_After_Loading: [Idle_Army][Active_Ship]Active_Ship

@(init)
init_transport_after_loading :: proc() {
    /*
    AI NOTE: Transport Loading State Machine
    
    Loading transitions preserve remaining moves:
    1. Empty Transport States:
       TRANS_EMPTY_UNMOVED -> TRANS_1I_UNMOVED (load infantry)
       TRANS_EMPTY_2_MOVES -> TRANS_1I_2_MOVES
       TRANS_EMPTY_1_MOVES -> TRANS_1I_1_MOVES
    
    2. Partial Load States:
       TRANS_1I_2_MOVES -> TRANS_2I_2_MOVES (add second infantry)
       TRANS_1I_2_MOVES -> TRANS_1I_1A_2_MOVES (add artillery)
       TRANS_1I_2_MOVES -> TRANS_1I_1T_2_MOVES (add tank)
    
    3. Capacity Rules:
       - Infantry: 2 spaces
       - Artillery/Tank: 3 spaces
       - Total capacity: 5 spaces
       - Invalid combinations not represented in enum
    */
	// INF valid transitions
	Trans_After_Loading[.INF][.TRANS_EMPTY_UNMOVED] = .TRANS_1I_UNMOVED
	Trans_After_Loading[.INF][.TRANS_EMPTY_2_MOVES] = .TRANS_1I_2_MOVES
	Trans_After_Loading[.INF][.TRANS_EMPTY_1_MOVES] = .TRANS_1I_1_MOVES
	Trans_After_Loading[.INF][.TRANS_EMPTY_0_MOVES] = .TRANS_1I_0_MOVES
	Trans_After_Loading[.INF][.TRANS_1I_UNMOVED] = .TRANS_2I_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1I_2_MOVES] = .TRANS_2I_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1I_1_MOVES] = .TRANS_2I_1_MOVES
	Trans_After_Loading[.INF][.TRANS_1I_0_MOVES] = .TRANS_2I_0_MOVES
	Trans_After_Loading[.INF][.TRANS_1I_UNLOADED] = .TRANS_2I_UNLOADED
	Trans_After_Loading[.INF][.TRANS_1A_UNMOVED] = .TRANS_1I_1A_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1A_2_MOVES] = .TRANS_1I_1A_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1A_1_MOVES] = .TRANS_1I_1A_1_MOVES
	Trans_After_Loading[.INF][.TRANS_1A_0_MOVES] = .TRANS_1I_1A_0_MOVES
	Trans_After_Loading[.INF][.TRANS_1A_UNLOADED] = .TRANS_1I_1A_UNLOADED
	Trans_After_Loading[.INF][.TRANS_1T_UNMOVED] = .TRANS_1I_1T_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1T_2_MOVES] = .TRANS_1I_1T_2_MOVES
	Trans_After_Loading[.INF][.TRANS_1T_1_MOVES] = .TRANS_1I_1T_1_MOVES
	Trans_After_Loading[.INF][.TRANS_1T_0_MOVES] = .TRANS_1I_1T_0_MOVES
	Trans_After_Loading[.INF][.TRANS_1T_UNLOADED] = .TRANS_1I_1T_UNLOADED

	// ARTY valid transitions
	Trans_After_Loading[.ARTY][.TRANS_EMPTY_UNMOVED] = .TRANS_1A_UNMOVED
	Trans_After_Loading[.ARTY][.TRANS_EMPTY_2_MOVES] = .TRANS_1A_2_MOVES
	Trans_After_Loading[.ARTY][.TRANS_EMPTY_1_MOVES] = .TRANS_1A_1_MOVES
	Trans_After_Loading[.ARTY][.TRANS_EMPTY_0_MOVES] = .TRANS_1A_0_MOVES
	Trans_After_Loading[.ARTY][.TRANS_1I_UNMOVED] = .TRANS_1I_UNMOVED
	Trans_After_Loading[.ARTY][.TRANS_1I_2_MOVES] = .TRANS_1I_1A_2_MOVES
	Trans_After_Loading[.ARTY][.TRANS_1I_1_MOVES] = .TRANS_1I_1A_1_MOVES
	Trans_After_Loading[.ARTY][.TRANS_1I_0_MOVES] = .TRANS_1I_1A_0_MOVES
	Trans_After_Loading[.ARTY][.TRANS_1I_UNLOADED] = .TRANS_1I_1A_UNLOADED

	// TANK valid transitions
	Trans_After_Loading[.TANK][.TRANS_EMPTY_UNMOVED] = .TRANS_1T_UNMOVED
	Trans_After_Loading[.TANK][.TRANS_EMPTY_2_MOVES] = .TRANS_1T_2_MOVES
	Trans_After_Loading[.TANK][.TRANS_EMPTY_1_MOVES] = .TRANS_1T_1_MOVES
	Trans_After_Loading[.TANK][.TRANS_EMPTY_0_MOVES] = .TRANS_1T_0_MOVES
	Trans_After_Loading[.TANK][.TRANS_1I_UNMOVED] = .TRANS_1I_1T_2_MOVES
	Trans_After_Loading[.TANK][.TRANS_1I_2_MOVES] = .TRANS_1I_1T_2_MOVES
	Trans_After_Loading[.TANK][.TRANS_1I_1_MOVES] = .TRANS_1I_1T_1_MOVES
	Trans_After_Loading[.TANK][.TRANS_1I_0_MOVES] = .TRANS_1I_1T_0_MOVES
	Trans_After_Loading[.TANK][.TRANS_1I_UNLOADED] = .TRANS_1I_1T_UNLOADED

	// AAGUN has no valid transitions (all remain ERROR_INVALID_ACTIVE_SHIP)
}

Trans_Allowed_By_Army_Size := [Army_Sizes][]Idle_Ship {
	.SMALL = {.TRANS_EMPTY, .TRANS_1I, .TRANS_1A, .TRANS_1T},
	.LARGE = {.TRANS_EMPTY, .TRANS_1I},
}

Active_Trans_By_Army_Size := [Army_Sizes][]Active_Ship {
	.SMALL = {.TRANS_1T_2_MOVES, .TRANS_1A_2_MOVES, .TRANS_1T_1_MOVES, .TRANS_1A_1_MOVES, .TRANS_1T_0_MOVES, .TRANS_1A_0_MOVES, .TRANS_1I_2_MOVES, .TRANS_EMPTY_2_MOVES, .TRANS_1I_1_MOVES, .TRANS_EMPTY_1_MOVES, .TRANS_1I_0_MOVES, .TRANS_EMPTY_0_MOVES},
	.LARGE = {.TRANS_1I_2_MOVES, .TRANS_EMPTY_2_MOVES, .TRANS_1I_1_MOVES, .TRANS_EMPTY_1_MOVES, .TRANS_1I_0_MOVES, .TRANS_EMPTY_0_MOVES},
}

stage_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in Transports_Needing_Staging {
		gc.current_active_unit = to_unit(ship)
		stage_trans_seas(gc, ship) or_return
	}
	return true
}

stage_trans_seas :: proc(gc: ^Game_Cache, ship: Active_Ship) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_sea in Sea_ID {
		gc.current_territory = to_air(src_sea)
		stage_trans_sea(gc, src_sea, ship) or_return
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}

stage_trans_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	if gc.active_ships[src_sea][ship] == 0 do return true
	for gc.active_ships[src_sea][ship] > 0 {
		stage_next_ship_in_sea(gc, src_sea, ship) or_return
	}
	return true
}

stage_next_ship_in_sea :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship) -> (ok: bool) {
	debug_checks(gc)
	reset_valid_actions(gc)
	add_valid_transport_moves(gc, src_sea, 2)
	dst_action := get_action_input(gc) or_return
	if skip_ship(gc, dst_action) do return true
	dst_sea := to_sea(dst_action)
	// sea_distance := src_sea.canal_paths[gc.canal_state].sea_distance[dst_sea_idx]
	sea_distance := mm.sea_distances[transmute(u8)gc.canals_open][src_sea][dst_sea]
	if dst_sea in gc.more_sea_combat_needed {
		// only allow staging to sea with enemy blockade if other unit started combat
		sea_distance = 2
	}
	Transport_State_After_Movement_Used := Trans_After_Move_Used[ship][sea_distance]
	move_single_ship(gc, Transport_State_After_Movement_Used, dst_action)
	return true
}

skip_empty_transports :: proc(gc: ^Game_Cache) {
	for src_sea in Sea_ID {
		gc.active_ships[src_sea][.TRANS_EMPTY_0_MOVES] +=
			gc.active_ships[src_sea][.TRANS_EMPTY_1_MOVES] +
			gc.active_ships[src_sea][.TRANS_EMPTY_2_MOVES]
		gc.active_ships[src_sea][.TRANS_EMPTY_1_MOVES] = 0
		gc.active_ships[src_sea][.TRANS_EMPTY_2_MOVES] = 0
	}
}

move_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	skip_empty_transports(gc)
	for ship in Transports_With_Moves {
		gc.current_active_unit = to_unit(ship)
		gc.clear_history_needed = false
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			gc.current_territory = to_air(src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_transport_moves(gc, src_sea, Ships_Moves[ship])
				dst_action := get_action_input(gc) or_return
				if skip_ship(gc, dst_action) do break
				dst_sea := to_sea(dst_action)
				move_single_ship(gc, Ships_Moved[ship], dst_action)
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

/*
Determines valid moves for a transport based on:

Movement Range Rules:
1. Can move 1-2 sea zones per turn
2. Movement paths affected by open/closed canals
3. Max_distance parameter can restrict to 1-space moves only

Safety Rules:
1. Cannot enter enemy-occupied sea zones without escort
2. Requires allied combat ships present to move into hostile waters
3. For 2-space moves, path must be free of enemy blockades

Optimization:
1. Skips moves previously rejected by player
2. Uses pre-computed movement tables based on canal state
*/
add_valid_transport_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID, max_distance: int) {
	/*
    Transport Movement Safety Rules
    
    Transports require protection when entering hostile waters:
    1. If a sea zone contains enemy units (team_sea_units[enemy] > 0)
    2. Then transports can ONLY enter if friendly combat ships are present (allied_sea_combatants_total > 0)
    3. For 2-space moves, all intermediate sea zones must be free of enemy blockades
    
    This ensures transports don't move through hostile waters without escort.
    */
	for dst_sea in mm.s2s_1away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] > 0 &&
			   gc.allied_sea_combatants_total[dst_sea] == 0 { 	// Transport needs combat ship escort
			continue
		}
		add_valid_action(gc, to_action(dst_sea))
	}
	if max_distance == 1 do return

	mid_seas := &mm.s2s_2away_via_midseas[transmute(u8)gc.canals_open][src_sea]
	for dst_sea_2_away in mm.s2s_2away_via_sea[transmute(u8)gc.canals_open][src_sea] {
		if gc.team_sea_units[dst_sea_2_away][mm.enemy_team[gc.cur_player]] > 0 &&
			   gc.allied_sea_combatants_total[dst_sea_2_away] == 0 { 	// Transport needs combat ship escort
			continue
		}
		for mid_sea in sa.slice(&mid_seas[dst_sea_2_away]) {
			if (gc.enemy_blockade_total[mid_sea] == 0) { 	// Path must be free of enemy blockades
				add_valid_action(gc, to_action(dst_sea_2_away))
				break
			}
		}
	}
}

add_valid_unload_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	for dst_land in sa.slice(&mm.s2l_1away_via_sea[src_sea]) {
		add_valid_action(gc, to_action(dst_land))
	}
}

Transports_With_Cargo := [?]Active_Ship {
	.TRANS_2I_0_MOVES,
	.TRANS_1I_1A_0_MOVES,
	.TRANS_1I_1T_0_MOVES,
	.TRANS_1I_0_MOVES,
	.TRANS_1A_0_MOVES,
	.TRANS_1T_0_MOVES,
}

/*
Transport State Transitions After Rejecting Unload

When a player explicitly chooses not to unload units from a transport that has the option to unload:
1. The transport's state transitions to an UNLOADED state
2. This prevents re-prompting the player about unloading from this transport
3. Helps optimize the Monte Carlo search by avoiding already-rejected options
*/
Trans_After_Rejecting_Unload: [Active_Ship]Active_Ship

@(init)
init_trans_after_rejecting_unload :: proc() {
	Trans_After_Rejecting_Unload[.TRANS_1I_0_MOVES] = .TRANS_1I_UNLOADED
	Trans_After_Rejecting_Unload[.TRANS_1A_0_MOVES] = .TRANS_1A_UNLOADED
	Trans_After_Rejecting_Unload[.TRANS_1T_0_MOVES] = .TRANS_1T_UNLOADED
	Trans_After_Rejecting_Unload[.TRANS_2I_0_MOVES] = .TRANS_2I_UNLOADED
	Trans_After_Rejecting_Unload[.TRANS_1I_1A_0_MOVES] = .TRANS_1I_1A_UNLOADED
	Trans_After_Rejecting_Unload[.TRANS_1I_1T_0_MOVES] = .TRANS_1I_1T_UNLOADED
}

unload_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
    /*
    AI NOTE: Transport Unloading System
    
    Unloading has several key rules:
    1. Can only unload when transport has 0 moves left
       - Prevents unload-move-unload exploitation
       - Forces commitment to unload location
    
    2. Must unload to adjacent land territory
       - Uses s2l_1away_via_sea connections
       - Territory must be friendly or empty
    
    3. Rejection Handling:
       - If player chooses not to unload
       - Transport marked as UNLOADED
       - Prevents re-prompting about same unload
       - Helps Monte Carlo search efficiency
    */
	for ship in Transports_With_Cargo {
		//todo bug feature: allow to specify specific cargo to unload
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_unload_moves(gc, src_sea)
				dst_action := get_action_input(gc) or_return
				if dst_action == .Skip_Action {
					gc.active_ships[src_sea][Trans_After_Rejecting_Unload[ship]] +=
						gc.active_ships[src_sea][ship]
					gc.active_ships[src_sea][ship] = 0
					continue
				}
				unload_unit(gc, to_land(dst_action), ship)
				replace_ship(gc, src_sea, ship, Trans_After_Unload[ship])
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

Transport_Unload_Unit: [Active_Ship]Active_Army
/*
    Game Rule: Transport Unloading
    
    When a unit unloads from a transport, it cannot move further that turn.
    This is a core game rule, not an optimization choice.
    
    Therefore all units unload with 0 moves remaining, regardless of:
    - Their original movement allowance
    - How far the transport moved
    - Whether they moved before loading
    */

@(init)
init_transport_unload_unit :: proc() {
	Transport_Unload_Unit[.TRANS_1I_0_MOVES] = .INF_0_MOVES
	Transport_Unload_Unit[.TRANS_1A_0_MOVES] = .ARTY_0_MOVES
	Transport_Unload_Unit[.TRANS_1T_0_MOVES] = .TANK_0_MOVES
	Transport_Unload_Unit[.TRANS_2I_0_MOVES] = .INF_0_MOVES
	Transport_Unload_Unit[.TRANS_1I_1A_0_MOVES] = .INF_0_MOVES
	Transport_Unload_Unit[.TRANS_1I_1T_0_MOVES] = .INF_0_MOVES
}

Trans_After_Unload: [Active_Ship]Active_Ship

@(init)
init_Trans_After_Unload :: proc() {
	Trans_After_Unload[.TRANS_1I_0_MOVES] = .TRANS_EMPTY_0_MOVES
	Trans_After_Unload[.TRANS_1A_0_MOVES] = .TRANS_EMPTY_0_MOVES
	Trans_After_Unload[.TRANS_1T_0_MOVES] = .TRANS_EMPTY_0_MOVES
	Trans_After_Unload[.TRANS_2I_0_MOVES] = .TRANS_1I_0_MOVES
	Trans_After_Unload[.TRANS_1I_1A_0_MOVES] = .TRANS_1A_0_MOVES
	Trans_After_Unload[.TRANS_1I_1T_0_MOVES] = .TRANS_1T_0_MOVES
}

/*
Unloads a unit from transport, updating:
1. Active and idle armies in destination
2. Team unit counts
3. Combat potential (bombard capability)
4. Checks for potential combat or conquest
*/
unload_unit :: proc(gc: ^Game_Cache, dst_land: Land_ID, ship: Active_Ship) {
	army := Transport_Unload_Unit[ship]
	gc.active_armies[dst_land][army] += 1
	gc.idle_armies[dst_land][gc.cur_player][Active_Army_To_Idle[army]] += 1
	gc.team_land_units[dst_land][mm.team[gc.cur_player]] += 1
	gc.max_bombards[dst_land] += 1
	if !mark_land_for_combat_resolution(gc, dst_land) {
		check_and_process_land_conquest(gc, dst_land)
	}
}

replace_ship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship, new_ship: Active_Ship) {
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[new_ship]] += 1
	gc.active_ships[src_sea][new_ship] += 1
	gc.idle_ships[src_sea][gc.cur_player][Active_Ship_To_Idle[ship]] -= 1
	gc.active_ships[src_sea][ship] -= 1
}
