package oaaa

/*
Pro AI Place Units Phase Implementation

This file implements unit placement logic following TripleA's ProPurchaseAi.place().
The Pro AI places purchased units at factories to maximize defensive and offensive value.

Key Responsibilities:
- Place units purchased during purchase phase
- Prioritize threatened territories
- Place defenders first at critical locations
- Place remaining units at strategic positions
- Handle factory production capacity limits

Algorithm Overview (from ProPurchaseAi.java place() method):
1. Place all units calculated during purchase phase (land first, then sea)
2. If any units remain unplaced:
   a. Find all territories where units can be placed
   b. Determine enemy threats to each placement location
   c. Prioritize land territories needing defense
   d. Place defenders at threatened territories
   e. Prioritize sea territories needing defense
   f. Place naval defenders
   g. Calculate strategic value for remaining territories
   h. Place remaining units at highest value locations

Placement Priority:
- Capital defense (highest)
- Factory defense
- Threatened border territories
- High production value territories
- Strategic staging areas
*/

import "core:fmt"
import "core:slice"
import sa "core:container/small_array"

// Main place units phase entry point
proai_place_units_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Starting place units phase")
	}
	
	// Step 1: Place units at factories based on purchase phase decisions
	// This uses the placement plan from pro_purchase.odin
	place_purchased_units(gc) or_return
	
	// Step 2: If any units remain unplaced (shouldn't happen normally)
	// Place them at best available locations
	place_remaining_units(gc) or_return
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Completed place units phase")
	}
	
	return true
}

// Place units that were purchased during purchase phase
place_purchased_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
	Java Original (ProPurchaseAi.java lines 461-503):
	This places all units calculated during purchase phase.
	Land units are placed first, then sea units to reduce failed placements.
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Placing purchased units at factories")
		
		// Show factory locations and their remaining production capacity
		factory_count := 0
		for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
			if gc.owner[factory_loc] == gc.cur_player {
				fmt.printf("  Factory at %v: %d production capacity, %d units to place\n",
					factory_loc, gc.factory_prod[factory_loc], gc.builds_left[factory_loc])
				factory_count += 1
			}
		}
		
		if factory_count == 0 {
			fmt.println("  No factories available for placement")
		}
	}
	
	// Place land units first (reduces failed placements)
	// This consumes g_purchased_units and places into idle_armies
	place_units_triplea(gc)
	
	// Place factories purchased during purchase phase
	// This consumes g_purchased_factories and places into factory arrays
	place_factory_triplea(gc)
	
	return true
}

// Place any remaining unplaced units
place_remaining_units :: proc(gc: ^Game_Cache) -> (ok: bool) {
	/*
	Java Original (ProPurchaseAi.java lines 505-574):
	This handles remaining units that weren't placed during purchase phase.
	Examples: WW2v3 China units, units from special rules, etc.
	
	Steps:
	1. Check if any units remain to be placed
	2. Find all place territories
	3. Populate enemy attack options
	4. Find defenders in place territories
	5. Prioritize land territories needing defense and place defenders
	6. Prioritize sea territories needing defense and place defenders
	7. Find strategic values for territories
	8. Prioritize all place territories
	9. Place regular (non-construction) units first
	10. Place construction units (factories) second
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Checking for remaining unplaced units")
	}
	
	// In OAAA, units are typically all placed during the purchase phase
	// This section would handle special cases like:
	// - Units from bid phase
	// - Units from special game rules
	// - Factory construction units
	
	// For now, this is a placeholder for future implementation
	// The Java code has extensive logic here for:
	// - findDefendersInPlaceTerritories()
	// - prioritizeTerritoriesToDefend() for land and sea
	// - placeDefenders() for threatened territories
	// - Finding strategic values
	// - placeUnits() for non-construction units
	// - placeUnits() for construction units (factories)
	
	when ODIN_DEBUG {
		fmt.println("  ✓ No remaining units to place (placeholder implementation)")
	}
	
	return true
}

// Placement_Option represents a location where units can be placed
Placement_Option :: struct {
	territory: Land_ID,
	factory_location: Land_ID,   // Factory producing the units
	production_remaining: u8,      // Units that can still be placed
	enemy_threat: f64,             // Threat to this territory
	strategic_value: f64,          // Strategic importance
	priority: f64,                 // Overall placement priority
	is_capital: bool,
	has_factory: bool,
}

// Find all territories where units can be placed
find_placement_options :: proc(gc: ^Game_Cache) -> [dynamic]Placement_Option {
	options := make([dynamic]Placement_Option)
	
	// For each factory owned by current player
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if gc.owner[factory_loc] != gc.cur_player {
			continue
		}
		
		// Check remaining production capacity
		production_remaining := gc.builds_left[factory_loc]
		if production_remaining == 0 {
			continue
		}
		
		// Create placement option
		enemy_threat := calculate_placement_threat(gc, factory_loc)
		strategic_value := calculate_territory_value(gc, factory_loc)
		is_capital := is_player_capital(gc, factory_loc, gc.cur_player)
		has_factory := true
		
		option := Placement_Option{
			territory = factory_loc,
			factory_location = factory_loc,
			production_remaining = production_remaining,
			enemy_threat = enemy_threat,
			strategic_value = strategic_value,
			is_capital = is_capital,
			has_factory = has_factory,
		}
		
		append(&options, option)
	}
	
	return options
}

// Calculate threat to a placement territory
calculate_placement_threat :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	threat := 0.0
	
	// Count enemy units in adjacent territories
	// Simplified - would use map graph for proper adjacency
	for player in Player_ID {
		if player == gc.cur_player {
			continue
		}
		if mm.team[player] == mm.team[gc.cur_player] {
			continue
		}
		
		// Check for enemy land units
		for army_type in Idle_Army {
			count := gc.idle_armies[territory][player][army_type]
			threat += f64(count) * get_army_placement_threat(army_type)
		}
		
		// Check for enemy air units
		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[territory][player][plane_type]
			threat += f64(count) * get_plane_placement_threat(plane_type)
		}
	}
	
	return threat
}

// Get threat value for army types in placement
get_army_placement_threat :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF: return 1.0
	case .ARTY: return 2.0
	case .TANK: return 3.0
	case .AAGUN: return 0.5
	case: return 1.0
	}
}

// Get threat value for plane types in placement
get_plane_placement_threat :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER: return 3.0
	case .BOMBER: return 4.0
	case: return 2.0
	}
}

// Prioritize placement options by threat and strategic value
prioritize_placement_options :: proc(options: ^[dynamic]Placement_Option) {
	// Calculate priority for each option
	for &option in options {
		// Priority = threat + strategic value
		// Higher threat = higher priority for defense
		// Higher strategic value = higher priority for important territories
		option.priority = option.enemy_threat + option.strategic_value
		
		// Extra priority for capital
		if option.is_capital {
			option.priority *= 10.0
		}
		
		// Extra priority for factories
		if option.has_factory {
			option.priority *= 2.0
		}
	}
	
	// Sort by priority (highest first)
	slice.sort_by(options[:], proc(a, b: Placement_Option) -> bool {
		return a.priority > b.priority
	})
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized placement options:")
		for option, i in options {
			if i >= 5 { break } // Only show top 5
			fmt.printf("  %d. Territory %v: priority=%.1f, threat=%.1f, value=%.1f\n",
				i+1, option.territory, option.priority, option.enemy_threat, option.strategic_value)
		}
	}
}

// Place defenders at threatened territories
place_defenders_at_threatened :: proc(gc: ^Game_Cache, options: ^[dynamic]Placement_Option) -> int {
	units_placed := 0
	
	// For each threatened territory
	for &option in options {
		if option.enemy_threat <= 0 {
			continue // Not threatened
		}
		
		if option.production_remaining == 0 {
			continue // No production left
		}
		
		// Place defensive units here
		// Simplified - would integrate with actual placement system
		// In full implementation:
		// 1. Determine best defensive units to place
		// 2. Place up to production_remaining units
		// 3. Update game state
		
		when ODIN_DEBUG {
			fmt.printf("[PRO-AI] Would place defenders at threatened territory %v\n", option.territory)
		}
		
		units_placed += 1
	}
	
	return units_placed
}

// Place units at strategic locations
place_units_at_strategic_locations :: proc(gc: ^Game_Cache, options: ^[dynamic]Placement_Option) -> int {
	units_placed := 0
	
	// For each strategic location with production remaining
	for &option in options {
		if option.production_remaining == 0 {
			continue
		}
		
		// Place offensive or strategic units
		// Simplified - would integrate with actual placement system
		// In full implementation:
		// 1. Determine best unit mix for location
		// 2. Consider future attack opportunities
		// 3. Place up to production_remaining units
		// 4. Update game state
		
		when ODIN_DEBUG {
			fmt.printf("[PRO-AI] Would place strategic units at %v\n", option.territory)
		}
		
		units_placed += 1
	}
	
	return units_placed
}

// Helper: Check if territory has remaining production
has_production_remaining :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	return gc.builds_left[territory] > 0
}

// Helper: Get available production at territory
get_available_production :: proc(gc: ^Game_Cache, territory: Land_ID) -> u8 {
	return gc.builds_left[territory]
}

// Helper: Place specific units at a territory
place_units_at_territory :: proc(gc: ^Game_Cache, territory: Land_ID, unit_count: u8) -> bool {
	// Check if we have production
	if gc.builds_left[territory] < unit_count {
		return false
	}
	
	// In full implementation, would:
	// 1. Select unit types to place
	// 2. Add to idle_armies arrays
	// 3. Deduct from money
	// 4. Update builds_left
	
	return true
}

// Cleanup
pro_place_cleanup :: proc(options: ^[dynamic]Placement_Option) {
	delete(options^)
}
