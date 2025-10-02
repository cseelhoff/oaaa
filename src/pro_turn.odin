package oaaa

import "core:fmt"
import "core:math/rand"

/*
Pro AI Turn Implementation

This file implements a TripleA-style Pro AI turn structure designed for fast MCTS rollouts.
The Pro AI makes quick, reasonable decisions to reach terminal states faster than random play.

Turn Phases (matching TripleA structure):
1. Purchase Phase - Decide what units to buy
2. Combat Move Phase - Move units to attack territories
3. Combat Phase - Resolve all battles
4. Non-Combat Move Phase - Move remaining units to safe positions
5. Place Units Phase - Place newly purchased units
6. End Turn Phase - Collect income and advance to next player

Key Differences from play_full_turn:
- Makes strategic decisions rather than enumerating all possibilities
- Focuses on quick evaluation and good-enough moves
- Designed for rollout speed, not exhaustive search
*/

// Main Pro AI turn function - called during MCTS rollouts when use_pro_ai_rollout flag is set
play_full_proai_turn :: proc(gc: ^Game_Cache) -> (ok: bool) {
	debug_checks(gc)
	
	// Phase 1: Purchase Phase
	// Pro AI decides what units to purchase based on strategic needs
	proai_purchase_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 2: Combat Move Phase
	// Move air units, naval units, and ground units into combat positions
	proai_combat_move_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 3: Combat Phase
	// Resolve all sea and land battles
	proai_combat_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 4: Non-Combat Move Phase
	// Move remaining units to defensive/strategic positions
	proai_noncombat_move_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 5: Place Units Phase
	// Place purchased units at factories
	proai_place_units_phase(gc) or_return
	debug_checks(gc)
	
	// Phase 6: End Turn Phase
	// Clean up, collect income, rotate to next player
	rotate_turns(gc)
	debug_checks(gc)
	
	return true
}

// Test Pro AI for a single turn with debug output
test_proai_single_turn :: proc(gs: ^Game_State) -> bool {
	fmt.println("\n=== Testing Pro AI Single Turn ===")
	fmt.println("Current Player:", gs.cur_player)
	fmt.println("Player Money:", gs.money[gs.cur_player])
	
	gc: Game_Cache
	load_cache_from_state(&gc, gs)
	gc.answers_remaining = 65000
	gc.seed = u16(rand.int_max(RANDOM_MAX))
	
	fmt.println("\n--- Starting Pro AI Turn ---")
	debug_checks(&gc)
	
	// Run a single Pro AI turn
	if !play_full_proai_turn(&gc) {
		fmt.eprintln("Pro AI turn failed!")
		return false
	}
	
	fmt.println("\n--- Pro AI Turn Complete ---")
	fmt.println("New Current Player:", gc.cur_player)
	fmt.println("Score:", evaluate_cache(&gc))
	
	// Save the state back
	gs^ = gc.state
	
	return true
}

/*
Phase 1: Purchase Phase

Pro AI strategic purchasing decisions are implemented in pro_purchase.odin
This includes:
- Evaluating current board state
- Determining strategic priorities (offense vs defense)
- Purchasing units that best serve immediate needs
- Considering factory placement if economically viable
*/
// proai_purchase_phase is implemented in pro_purchase.odin

/*
Phase 2: Combat Move Phase

Pro AI combat movement strategy is implemented in pro_combat_move.odin
This includes:
- Identifying vulnerable enemy territories
- Calculating attack odds for potential battles
- Moving fighters and bombers to support key attacks
- Positioning naval units for amphibious assaults
- Moving ground units to maximize attack power
- Loading transports with invasion forces
*/
// proai_combat_move_phase is implemented in pro_combat_move.odin

/*
Phase 3: Combat Phase

Resolve all battles:
- Sea battles (can affect amphibious assaults)
- Land battles (territorial control)
- Pro AI makes tactical combat decisions (retreat vs fight)

NOTE: Tactical combat resolution (retreat vs fight decisions) will NOT be implemented
for quite some time. This phase uses standard OAAA combat resolution.

Reasoning: Tactical combat decisions during battle are complex and require:
1. Monte Carlo simulation of battle outcomes with retreat at various points
2. Analysis of unit preservation vs territory capture trade-offs
3. Prediction of enemy counter-attacks after retreat
4. Integration with overall strategy (when to trade units, when to preserve)

For MCTS rollouts, standard combat resolution (fight to the end) is sufficient
and much faster. The strategic value comes from good attack/defense positioning,
not from retreat micro-decisions.

Future Enhancement: Could add simple retreat logic like:
- Retreat if battle odds drop below 30%
- Retreat if losing expensive units (tanks, bombers) with poor odds
- Never retreat from capital or critical territories
*/
proai_combat_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// Use standard OAAA combat resolution
	// No special Pro AI tactical decisions (stubbed for future)
	
	// Resolve sea battles first (affects transports)
	resolve_sea_battles(gc) or_return
	
	// Unload surviving transports
	unload_transports(gc) or_return
	
	// Resolve land battles
	resolve_land_battles(gc) or_return
	
	return true
}

/*
Phase 4: Non-Combat Move Phase

Pro AI non-combat movement strategy is implemented in pro_noncombat_move.odin
This includes:
- Moving air units to safe landing zones
- Repositioning naval units for defense/next turn
- Moving ground units to defensive positions
- Consolidating forces in key territories
- Moving AA guns to important locations
*/
// proai_noncombat_move_phase is implemented in pro_noncombat_move.odin

/*
Phase 5: Place Units Phase

Pro AI unit placement strategy is implemented in pro_place.odin
This includes:
- Place units purchased during purchase phase
- Prioritize threatened territories needing defense
- Place defenders at capital and factories first
- Place remaining units at strategic locations
- Respect factory production capacity limits
*/
// proai_place_units_phase is implemented in pro_place.odin

/*
Phase 6: End Turn Phase

Clean up and prepare for next player:
- Repair damaged battleships
- Collect income
- Rotate to next player
*/
proai_end_turn_phase :: proc(gc: ^Game_Cache) {
	reset_units_fully(gc)
	collect_money(gc)
	rotate_turns(gc)
}

// ===== Combat Move Phase Helper Functions =====

proai_move_air_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart fighter/bomber combat positioning
	// Strategy: Move air to territories where they tip the battle odds favorably
	
	// Stub: For now, skip air combat moves for rapid rollout
	return true
}

proai_move_ships_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
	Naval Combat Movement Strategy (based on ship.odin move_combat_ships):
	
	1. Attack weak enemy naval forces (no destroyers, just transports)
	2. Clear sea zones blocking amphibious assaults
	3. Position destroyers to detect enemy subs
	4. Protect our transports with combat ships
	5. Control strategic sea zones (near enemy coasts)
	
	Ship Movement Rules (from ship.odin):
	- All combat ships have 2 moves (Unmoved_Blockade_Ships)
	- Ships automatically mark seas for combat when entering enemy zones
	- Submarines can move through enemy blockades unless destroyers present
	- Other ships blocked by enemy blockade (destroyer/carrier/cruiser/battleship)
	
	For MCTS rollouts, we use simplified heuristics:
	- Attack if we outnumber enemy (quick power comparison)
	- Don't expose transports unnecessarily
	- Maintain sea control near our territories
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Naval combat movement phase (simplified)")
	}
	
	// Find target enemy sea zones to attack
	for sea in Sea_ID {
		// Skip if no enemy units
		if gc.team_sea_units[sea][mm.enemy_team[gc.cur_player]] == 0 {
			continue
		}
		
		// Skip if we don't have ships nearby
		if !has_friendly_ships_adjacent(gc, sea) {
			continue
		}
		
		// Simple heuristic: Only attack if enemy has no blockade ships
		// (just transports or subs without destroyer protection)
		if gc.enemy_blockade_total[sea] == 0 ||
		   (gc.enemy_subs_total[sea] > 0 && gc.enemy_destroyer_total[sea] == 0) {
			// Worthwhile target - clear it out
			when ODIN_DEBUG {
				fmt.printf("[PRO-AI] Would attack weak enemy fleet at sea %v\n", sea)
			}
			// Actual movement would use pro_move_execute.odin execute_sea_move
			// For now, just note the opportunity
		}
	}
	
	// For rapid MCTS rollouts, we skip detailed naval combat for now
	// Naval battles are secondary to land control in most scenarios
	// Future: Implement targeted naval attacks using execute_sea_move
	
	return true
}

// Check if we have friendly combat ships adjacent to a sea zone
has_friendly_ships_adjacent :: proc(gc: ^Game_Cache, target_sea: Sea_ID) -> bool {
	canal_state := transmute(u8)gc.canals_open
	
	for adjacent_sea in mm.s2s_1away_via_sea[canal_state][target_sea] {
		// Check for combat ships (not transports)
		if gc.idle_ships[adjacent_sea][gc.cur_player][.SUB] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.DESTROYER] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.CRUISER] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.BATTLESHIP] > 0 do return true
		if gc.idle_ships[adjacent_sea][gc.cur_player][.BS_DAMAGED] > 0 do return true
	}
	
	return false
}

proai_load_transports_for_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart transport loading for amphibious assaults
	// Strategy: Load transports with units to capture valuable territories
	
	// Stub: For now, skip transport loading for rapid rollout
	return true
}

proai_move_ground_to_combat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart ground unit combat positioning
	// Strategy: Attack weak territories, consolidate forces for major attacks
	
	// Stub: For now, skip ground combat moves for rapid rollout
	return true
}

// ===== Non-Combat Move Phase Helper Functions =====

proai_land_fighters_safe :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart fighter landing
	// Strategy: Land on carriers or friendly territories with defensive value
	
	// Stub: Use existing landing logic for now
	land_remaining_fighters(gc) or_return
	return true
}

proai_land_bombers_safe :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart bomber landing
	// Strategy: Land in territories that provide good offensive reach for next turn
	
	// Stub: Use existing landing logic for now
	land_remaining_bombers(gc) or_return
	return true
}

proai_move_ships_noncombat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart non-combat naval movement
	// Strategy: Move ships to defensive positions or staging areas
	
	// Stub: For now, skip non-combat naval moves for rapid rollout
	return true
}

proai_move_ground_noncombat :: proc(gc: ^Game_Cache) -> (ok: bool) {
	// TODO: Implement smart non-combat ground movement
	// Strategy: Consolidate forces, reinforce threatened territories
	
	// Stub: For now, skip non-combat ground moves for rapid rollout
	return true
}

/*
Future Enhancement Notes:

The stub functions above should eventually implement Pro AI decision-making logic:

1. Territory Evaluation:
   - Calculate value of each territory (IPC value, strategic importance)
   - Assess threat level (enemy units nearby)
   - Determine control status (friendly, enemy, contested)

2. Attack Planning:
   - Calculate battle odds for potential attacks
   - Prioritize high-value, low-risk targets
   - Consider follow-up attacks and defensive needs

3. Defense Planning:
   - Identify threatened friendly territories
   - Calculate minimum defense needed
   - Move units to reinforce weak points

4. Unit Routing:
   - Use movement range efficiently
   - Prefer safe paths when possible
   - Consider unit types and their roles

5. Economic Considerations:
   - Balance offense vs defense spending
   - Prioritize unit types based on game situation
   - Consider long-term strategic value

The goal is to make decisions quickly (no exhaustive search) while still playing reasonably well,
allowing MCTS rollouts to reach terminal states faster than random play.
*/
