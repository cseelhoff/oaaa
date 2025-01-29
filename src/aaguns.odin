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
    - Start as AAGUN_UNMOVED (ready to move)
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
	for src_land in Land_ID {
		if gc.active_armies[src_land][.AAGUN_UNMOVED] == 0 do continue
		gc.valid_actions = {to_action(src_land)}
		gc.valid_actions += to_action_bitset(
			mm.l2l_1away_via_land_bitset[src_land] &  // All adjacent lands
			gc.friendly_owner &                        // Only friendly territory
			~to_land_bitset(gc.rejected_moves_from[to_air(src_land)]), // Remove rejected moves
		)
		for gc.active_armies[src_land][.AAGUN_UNMOVED] > 0 {
			dst_air := get_move_input(
				gc,
				fmt.tprint(Active_Army.AAGUN_UNMOVED),
				to_air(src_land),
			) or_return
			dst_land := to_land(dst_air)
			if skip_army(gc, src_land, dst_land, .AAGUN_UNMOVED) do continue
			move_single_army_land(
				gc,
				src_land,
				dst_land,
				.AAGUN_UNMOVED,
				.AAGUN_0_MOVES,
			)
		}
	}
	if gc.clear_history_needed do clear_move_history(gc)
	return true
}
