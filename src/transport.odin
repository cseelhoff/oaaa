#+feature global-context
package oaaa
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
   - Efficient bitset representation in game_state.roster_ships and active_ships
   - Perfect fit for Monte Carlo Tree Search (MCTS) state exploration
   - Minimal memory footprint for game state serialization

Cargo Configurations (5 space capacity):
- EMPTY: No cargo
- Infantry: 1 Infantry (2 spaces)
- Artillery: 1 Artillery (3 spaces)
- Tank: 1 Tank (3 spaces)
- Infantry_Artillery: 1 Infantry + 1 Artillery (5 spaces)
- Infantry_Tank: 1 Infantry + 1 Tank (5 spaces)
- Infantry_Infantry: 2 Infantry (4 spaces)

Movement states are appended to cargo state:
- UNMOVED: Not yet moved this turn
- X_Moves: Has X moves remaining (0,1,2)
- UNLOADED: Transport has unloaded its cargo

Example State Flow:
Transport_Empty_Unmoved -> Transport_Infantry_2_Moves -> Transport_Infantry_1_Moves -> Transport_Empty_0_Moves
(Empty transport) -> (Loads infantry) -> (Moves once) -> (Unloads infantry)

Example: Transport_Infantry_2_Moves = Transport with 1 infantry and 2 moves left

Transport states combine both cargo configuration (e.g., Infantry = one infantry) and movement state 
(e.g., _2_Moves, _Unmoved) into a single enum rather than tracking them separately.
This design choice optimizes for performance in two ways:
1. Memory efficiency: Allows using simple 2D arrays [sea_zone][state]int to track ship counts,
   versus needing 3D arrays if cargo and movement were separate
2. Cache efficiency: Single enum lookup versus multiple field accesses when checking states
3. Validation: Invalid combinations are simply not represented in the enum, versus
   needing runtime checks with separate cargo/movement tracking
*/
transports_with_moves := [?]Active_Ship {
	.Transport_Infantry_1_Moves,
	.Transport_Artillery_1_Moves,
	.Transport_Tank_1_Moves,
	.Transport_Infantry_Infantry_1_Moves,
	.Transport_Infantry_Artillery_1_Moves,
	.Transport_Infantry_Tank_1_Moves,
	.Transport_Infantry_2_Moves,
	.Transport_Artillery_2_Moves,
	.Transport_Tank_2_Moves,
	.Transport_Infantry_Infantry_2_Moves,
	.Transport_Infantry_Artillery_2_Moves,
	.Transport_Infantry_Tank_2_Moves,
}

roster_transports := [?]Roster_Ship {
	.Transport_Empty,
	.Transport_Infantry,
	.Transport_Artillery,
	.Transport_Tank,
	.Transport_Infantry_Artillery,
	.Transport_Infantry_Tank,
}

transports_needing_staging := [?]Active_Ship {
	.Transport_Empty_Unmoved,
	.Transport_Infantry_Unmoved,
	.Transport_Artillery_Unmoved,
	.Transport_Tank_Unmoved,
}

transport_after_move_used: [Active_Ship][MAX_TRANSPORT_MOVES + 1]Active_Ship

@(init)
init_transport_after_move_used :: proc() {
	transport_after_move_used[.Transport_Empty_Unmoved][0] = .Transport_Empty_2_Moves
	transport_after_move_used[.Transport_Empty_Unmoved][1] = .Transport_Empty_1_Moves
	transport_after_move_used[.Transport_Empty_Unmoved][2] = .Transport_Empty_0_Moves
	transport_after_move_used[.Transport_Infantry_Unmoved][0] = .Transport_Infantry_2_Moves
	transport_after_move_used[.Transport_Infantry_Unmoved][1] = .Transport_Infantry_1_Moves
	transport_after_move_used[.Transport_Infantry_Unmoved][2] = .Transport_Infantry_0_Moves
	transport_after_move_used[.Transport_Artillery_Unmoved][0] = .Transport_Artillery_2_Moves
	transport_after_move_used[.Transport_Artillery_Unmoved][1] = .Transport_Artillery_1_Moves
	transport_after_move_used[.Transport_Artillery_Unmoved][2] = .Transport_Artillery_0_Moves
	transport_after_move_used[.Transport_Tank_Unmoved][0] = .Transport_Tank_2_Moves
	transport_after_move_used[.Transport_Tank_Unmoved][1] = .Transport_Tank_1_Moves
	transport_after_move_used[.Transport_Tank_Unmoved][2] = .Transport_Tank_0_Moves
}

transport_after_loading: [Roster_Army][Active_Ship]Active_Ship

@(init)
init_transport_after_loading :: proc() {
    /*
    AI NOTE: Transport Loading State Machine
    
    Loading transitions preserve remaining moves:
    1. Empty Transport States:
       Transport_Empty_Unmoved -> Transport_Infantry_Unmoved (load infantry)
       Transport_Empty_2_Moves -> Transport_Infantry_2_Moves
       Transport_Empty_1_Moves -> Transport_Infantry_1_Moves
    
    2. Partial Load States:
       Transport_Infantry_2_Moves -> Transport_Infantry_Infantry_2_Moves (add second infantry)
       Transport_Infantry_2_Moves -> Transport_Infantry_Artillery_2_Moves (add artillery)
       Transport_Infantry_2_Moves -> Transport_Infantry_Tank_2_Moves (add tank)
    
    3. Capacity Rules:
       - Infantry: 2 spaces
       - Artillery/Tank: 3 spaces
       - Total capacity: 5 spaces
       - Invalid combinations not represented in enum
    */
	// Infantry valid transitions
	transport_after_loading[.Infantry][.Transport_Empty_Unmoved] = .Transport_Infantry_Unmoved
	transport_after_loading[.Infantry][.Transport_Empty_2_Moves] = .Transport_Infantry_2_Moves
	transport_after_loading[.Infantry][.Transport_Empty_1_Moves] = .Transport_Infantry_1_Moves
	transport_after_loading[.Infantry][.Transport_Empty_0_Moves] = .Transport_Infantry_0_Moves
	transport_after_loading[.Infantry][.Transport_Infantry_Unmoved] = .Transport_Infantry_Infantry_2_Moves
	transport_after_loading[.Infantry][.Transport_Infantry_2_Moves] = .Transport_Infantry_Infantry_2_Moves
	transport_after_loading[.Infantry][.Transport_Infantry_1_Moves] = .Transport_Infantry_Infantry_1_Moves
	transport_after_loading[.Infantry][.Transport_Infantry_0_Moves] = .Transport_Infantry_Infantry_0_Moves
	transport_after_loading[.Infantry][.Transport_Infantry_Unloaded] = .Transport_Infantry_Infantry_Unloaded
	transport_after_loading[.Infantry][.Transport_Artillery_Unmoved] = .Transport_Infantry_Artillery_2_Moves
	transport_after_loading[.Infantry][.Transport_Artillery_2_Moves] = .Transport_Infantry_Artillery_2_Moves
	transport_after_loading[.Infantry][.Transport_Artillery_1_Moves] = .Transport_Infantry_Artillery_1_Moves
	transport_after_loading[.Infantry][.Transport_Artillery_0_Moves] = .Transport_Infantry_Artillery_0_Moves
	transport_after_loading[.Infantry][.Transport_Artillery_Unloaded] = .Transport_Infantry_Artillery_Unloaded
	transport_after_loading[.Infantry][.Transport_Tank_Unmoved] = .Transport_Infantry_Tank_2_Moves
	transport_after_loading[.Infantry][.Transport_Tank_2_Moves] = .Transport_Infantry_Tank_2_Moves
	transport_after_loading[.Infantry][.Transport_Tank_1_Moves] = .Transport_Infantry_Tank_1_Moves
	transport_after_loading[.Infantry][.Transport_Tank_0_Moves] = .Transport_Infantry_Tank_0_Moves
	transport_after_loading[.Infantry][.Transport_Tank_Unloaded] = .Transport_Infantry_Tank_Unloaded

	// Artillery valid transitions
	transport_after_loading[.Artillery][.Transport_Empty_Unmoved] = .Transport_Artillery_Unmoved
	transport_after_loading[.Artillery][.Transport_Empty_2_Moves] = .Transport_Artillery_2_Moves
	transport_after_loading[.Artillery][.Transport_Empty_1_Moves] = .Transport_Artillery_1_Moves
	transport_after_loading[.Artillery][.Transport_Empty_0_Moves] = .Transport_Artillery_0_Moves
	transport_after_loading[.Artillery][.Transport_Infantry_Unmoved] = .Transport_Infantry_Unmoved
	transport_after_loading[.Artillery][.Transport_Infantry_2_Moves] = .Transport_Infantry_Artillery_2_Moves
	transport_after_loading[.Artillery][.Transport_Infantry_1_Moves] = .Transport_Infantry_Artillery_1_Moves
	transport_after_loading[.Artillery][.Transport_Infantry_0_Moves] = .Transport_Infantry_Artillery_0_Moves
	transport_after_loading[.Artillery][.Transport_Infantry_Unloaded] = .Transport_Infantry_Artillery_Unloaded

	// Tank valid transitions
	transport_after_loading[.Tank][.Transport_Empty_Unmoved] = .Transport_Tank_Unmoved
	transport_after_loading[.Tank][.Transport_Empty_2_Moves] = .Transport_Tank_2_Moves
	transport_after_loading[.Tank][.Transport_Empty_1_Moves] = .Transport_Tank_1_Moves
	transport_after_loading[.Tank][.Transport_Empty_0_Moves] = .Transport_Tank_0_Moves
	transport_after_loading[.Tank][.Transport_Infantry_Unmoved] = .Transport_Infantry_Tank_2_Moves
	transport_after_loading[.Tank][.Transport_Infantry_2_Moves] = .Transport_Infantry_Tank_2_Moves
	transport_after_loading[.Tank][.Transport_Infantry_1_Moves] = .Transport_Infantry_Tank_1_Moves
	transport_after_loading[.Tank][.Transport_Infantry_0_Moves] = .Transport_Infantry_Tank_0_Moves
	transport_after_loading[.Tank][.Transport_Infantry_Unloaded] = .Transport_Infantry_Tank_Unloaded

	// AAGun has no valid transitions (all remain ERROR_INVALID_ACTIVE_SHIP)
}

transport_allowed_by_army_size := [Army_Sizes][]Roster_Ship {
	.SMALL = {.Transport_Empty, .Transport_Infantry, .Transport_Artillery, .Transport_Tank},
	.LARGE = {.Transport_Empty, .Transport_Infantry},
}

active_transport_by_army_size := [Army_Sizes][]Active_Ship {
	.SMALL = {.Transport_Tank_2_Moves, .Transport_Artillery_2_Moves, .Transport_Tank_1_Moves, .Transport_Artillery_1_Moves, .Transport_Tank_0_Moves, .Transport_Artillery_0_Moves, .Transport_Infantry_2_Moves, .Transport_Empty_2_Moves, .Transport_Infantry_1_Moves, .Transport_Empty_1_Moves, .Transport_Infantry_0_Moves, .Transport_Empty_0_Moves},
	.LARGE = {.Transport_Infantry_2_Moves, .Transport_Empty_2_Moves, .Transport_Infantry_1_Moves, .Transport_Empty_1_Moves, .Transport_Infantry_0_Moves, .Transport_Empty_0_Moves},
}

stage_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	for ship in transports_needing_staging {
		gc.current_active_unit = to_unit(ship)
		stage_trans_seas(gc, ship) or_return
	}
	return true
}

stage_trans_seas :: proc(gc: ^Game_Cache, ship: Active_Ship) -> (ok: bool) {
	gc.clear_history_needed = false
	for src_sea in Sea_ID {
		gc.current_territory = to_region(src_sea)
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
	sea_distance := mm.sea_distance[transmute(u8)gc.canals_open][src_sea][dst_sea]
	if dst_sea in gc.more_sea_battles_needed {
		// only allow staging to sea with enemy blockade if other unit started combat
		sea_distance = 2
	}
	Transport_State_After_Movement_Used := transport_after_move_used[ship][sea_distance]
	move_single_ship(gc, Transport_State_After_Movement_Used, dst_action)
	return true
}

skip_empty_transports :: proc(gc: ^Game_Cache) {
	for src_sea in Sea_ID {
		gc.active_ships[src_sea][.Transport_Empty_0_Moves] +=
			gc.active_ships[src_sea][.Transport_Empty_1_Moves] +
			gc.active_ships[src_sea][.Transport_Empty_2_Moves]
		gc.active_ships[src_sea][.Transport_Empty_1_Moves] = 0
		gc.active_ships[src_sea][.Transport_Empty_2_Moves] = 0
	}
}

move_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
	skip_empty_transports(gc)
	for ship in transports_with_moves {
		gc.current_active_unit = to_unit(ship)
		gc.clear_history_needed = false
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			gc.current_territory = to_region(src_sea)
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_transport_moves(gc, src_sea, ships_moves[ship])
				dst_action := get_action_input(gc) or_return
				if skip_ship(gc, dst_action) do break
				dst_sea := to_sea(dst_action)
				move_single_ship(gc, ships_moved[ship], dst_action)
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
2. Requires friendly combat ships present to move into hostile waters
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
    2. Then transports can ONLY enter if friendly combat ships are present (friendly_sea_combatants_total > 0)
    3. For 2-space moves, all intermediate sea zones must be free of enemy blockades
    
    This ensures transports don't move through hostile waters without escort.
    */
	for dst_sea in mm.seas_within_1_move[transmute(u8)gc.canals_open][src_sea] {
		if gc.team_sea_units[dst_sea][mm.enemy_team[gc.acting_nation]] > 0 &&
			   gc.friendly_sea_combatants_total[dst_sea] == 0 { 	// Transport needs combat ship escort
			continue
		}
		add_valid_action(gc, to_action(dst_sea))
	}
	if max_distance == 1 do return

	mid_seas := &mm.seas_between[transmute(u8)gc.canals_open][src_sea]
	for dst_sea_2_away in mm.seas_within_2_moves[transmute(u8)gc.canals_open][src_sea] {
		if gc.team_sea_units[dst_sea_2_away][mm.enemy_team[gc.acting_nation]] > 0 &&
			   gc.friendly_sea_combatants_total[dst_sea_2_away] == 0 { 	// Transport needs combat ship escort
			continue
		}
		for mid_sea in mid_seas[dst_sea_2_away] {
			if (gc.enemy_blockade_total[mid_sea] == 0) { 	// Path must be free of enemy blockades
				add_valid_action(gc, to_action(dst_sea_2_away))
				break
			}
		}
	}
}

add_valid_unload_moves :: proc(gc: ^Game_Cache, src_sea: Sea_ID) {
	for dst_land in mm.coastal_lands[src_sea] {
		add_valid_action(gc, to_action(dst_land))
	}
}

transports_with_cargo := [?]Active_Ship {
	.Transport_Infantry_Infantry_0_Moves,
	.Transport_Infantry_Artillery_0_Moves,
	.Transport_Infantry_Tank_0_Moves,
	.Transport_Infantry_0_Moves,
	.Transport_Artillery_0_Moves,
	.Transport_Tank_0_Moves,
}

/*
Transport State Transitions After Rejecting Unload

When a player explicitly chooses not to unload units from a transport that has the option to unload:
1. The transport's state transitions to an UNLOADED state
2. This prevents re-prompting the player about unloading from this transport
3. Helps optimize the Monte Carlo search by avoiding already-rejected options
*/
transport_after_rejecting_unload: [Active_Ship]Active_Ship

@(init)
init_transport_after_rejecting_unload :: proc() {
	transport_after_rejecting_unload[.Transport_Infantry_0_Moves] = .Transport_Infantry_Unloaded
	transport_after_rejecting_unload[.Transport_Artillery_0_Moves] = .Transport_Artillery_Unloaded
	transport_after_rejecting_unload[.Transport_Tank_0_Moves] = .Transport_Tank_Unloaded
	transport_after_rejecting_unload[.Transport_Infantry_Infantry_0_Moves] = .Transport_Infantry_Infantry_Unloaded
	transport_after_rejecting_unload[.Transport_Infantry_Artillery_0_Moves] = .Transport_Infantry_Artillery_Unloaded
	transport_after_rejecting_unload[.Transport_Infantry_Tank_0_Moves] = .Transport_Infantry_Tank_Unloaded
}

unload_transports :: proc(gc: ^Game_Cache) -> (ok: bool) {
    /*
    AI NOTE: Transport Unloading System
    
    Unloading has several key rules:
    1. Can only unload when transport has 0 moves left
       - Prevents unload-move-unload exploitation
       - Forces commitment to unload location
    
    2. Must unload to adjacent land territory
       - Uses coastal_lands connections
       - Territory must be friendly or empty
    
    3. Rejection Handling:
       - If player chooses not to unload
       - Transport marked as UNLOADED
       - Prevents re-prompting about same unload
       - Helps Monte Carlo search efficiency
    */
	for ship in transports_with_cargo {
		//todo bug feature: allow to specify specific cargo to unload
		for src_sea in Sea_ID {
			if gc.active_ships[src_sea][ship] == 0 do continue
			for gc.active_ships[src_sea][ship] > 0 {
				reset_valid_actions(gc)
				add_valid_unload_moves(gc, src_sea)
				dst_action := get_action_input(gc) or_return
				if dst_action == .Skip_Action {
					gc.active_ships[src_sea][transport_after_rejecting_unload[ship]] +=
						gc.active_ships[src_sea][ship]
					gc.active_ships[src_sea][ship] = 0
					continue
				}
				unload_unit(gc, to_land(dst_action), ship)
				replace_ship(gc, src_sea, ship, transport_after_unload[ship])
			}
		}
		if gc.clear_history_needed do clear_move_history(gc)
	}
	return true
}

transport_unload_unit: [Active_Ship]Active_Army
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
	transport_unload_unit[.Transport_Infantry_0_Moves] = .Infantry_0_Moves
	transport_unload_unit[.Transport_Artillery_0_Moves] = .Artillery_0_Moves
	transport_unload_unit[.Transport_Tank_0_Moves] = .Tank_0_Moves
	transport_unload_unit[.Transport_Infantry_Infantry_0_Moves] = .Infantry_0_Moves
	transport_unload_unit[.Transport_Infantry_Artillery_0_Moves] = .Infantry_0_Moves
	transport_unload_unit[.Transport_Infantry_Tank_0_Moves] = .Infantry_0_Moves
}

transport_after_unload: [Active_Ship]Active_Ship

@(init)
init_transport_after_unload :: proc() {
	transport_after_unload[.Transport_Infantry_0_Moves] = .Transport_Empty_0_Moves
	transport_after_unload[.Transport_Artillery_0_Moves] = .Transport_Empty_0_Moves
	transport_after_unload[.Transport_Tank_0_Moves] = .Transport_Empty_0_Moves
	transport_after_unload[.Transport_Infantry_Infantry_0_Moves] = .Transport_Infantry_0_Moves
	transport_after_unload[.Transport_Infantry_Artillery_0_Moves] = .Transport_Artillery_0_Moves
	transport_after_unload[.Transport_Infantry_Tank_0_Moves] = .Transport_Tank_0_Moves
}

/*
Unloads a unit from transport, updating:
1. Active and idle armies in destination
2. Team unit counts
3. Combat potential (bombard capability)
4. Checks for potential combat or conquest
*/
unload_unit :: proc(gc: ^Game_Cache, dst_land: Land_ID, ship: Active_Ship) {
	army := transport_unload_unit[ship]
	gc.active_armies[dst_land][army] += 1
	gc.roster_armies[dst_land][gc.acting_nation][active_army_to_roster[army]] += 1
	gc.team_land_units[dst_land][mm.team[gc.acting_nation]] += 1
	gc.max_bombardment_dice[dst_land] += 1
	if !mark_land_for_combat_resolution(gc, dst_land) {
		check_and_process_land_conquest(gc, dst_land)
	}
}

replace_ship :: proc(gc: ^Game_Cache, src_sea: Sea_ID, ship: Active_Ship, new_ship: Active_Ship) {
	gc.roster_ships[src_sea][gc.acting_nation][active_ship_to_roster[new_ship]] += 1
	gc.active_ships[src_sea][new_ship] += 1
	gc.roster_ships[src_sea][gc.acting_nation][active_ship_to_roster[ship]] -= 1
	gc.active_ships[src_sea][ship] -= 1
}
