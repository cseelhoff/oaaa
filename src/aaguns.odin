package oaaa
import sa "core:container/small_array"
import "core:fmt"

move_aa_guns :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
    AI NOTE: AA Gun Movement Timing
    AA guns move AFTER all combat is resolved:
    1. Sea battles finish
    2. Transports unload
    3. Land battles resolve
    4. THEN AA guns move
    
    This timing means:
    - AA guns are purely defensive
    - They can't participate in attacks
    - They must wait for territory to be secured
    - They can only move into friendly territory
    
    Movement States:
    - Start as AAGUN_1_MOVES (ready to move)
    - Change to AAGUN_0_MOVES (done moving)
    - This prevents multiple moves per turn
    
    Monte Carlo Search Optimization:
    The rejected_moves_from variable (better name: rejected_moves_from) tracks which 
    moves the player has explicitly chosen not to make. This prevents the 
    search from:
    1. Re-offering moves the player rejected
    2. Exploring duplicate paths to identical states
    3. Wasting time on known-undesirable moves
    
    This significantly speeds up Monte Carlo tree convergence by pruning
    redundant decision paths early.
    */
	gc.clear_history_needed = false
    gc.current_active_unit = .AAGUN_1_MOVES
	for src_land in Land_ID {
		if gc.active_armies[src_land][.AAGUN_1_MOVES] == 0 do continue
		valid_army_destinations := mm.l2l_1away_via_land_bitset[src_land] & gc.friendly_owner// All adjacent lands
        gc.current_territory = to_air(src_land)
		for gc.active_armies[src_land][.AAGUN_1_MOVES] > 0 {
            //todo: optimize. instead of resetting, check unit count and update smallest_allowable_action
            reset_valid_actions(gc)
            add_lands_to_valid_actions(
                gc,
                valid_army_destinations,
                gc.active_armies[src_land][.AAGUN_1_MOVES],
            )                
			dst_action := get_action_input(gc) or_return
			if skip_army(gc, dst_action) do continue
			move_single_army_land(gc, dst_action, .AAGUN_0_MOVES)
		}
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}
