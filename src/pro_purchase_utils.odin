package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

// =============================================================================
// PUR-025/039/054: Randomized Purchase Selection
// =============================================================================
// Java's randomizePurchaseOption() selects from available options with probability
// proportional to their efficiency. This adds variety to AI purchases.

// Weighted random selection of land units for purchase
// Returns nil if no valid options or total efficiency is 0
randomize_land_purchase :: proc(gc: ^Game_Cache, efficiencies: [Idle_Army]f64, budget: u8) -> Maybe(Idle_Army) {
	// Calculate total efficiency of affordable options
	total_efficiency := f64(0)
	for army in Idle_Army {
		cost := COST_IDLE_ARMY[army]
		if cost <= budget && efficiencies[army] > 0 {
			total_efficiency += efficiencies[army]
		}
	}
	
	if total_efficiency <= 0 do return nil
	
	// Generate random number from 0 to total_efficiency
	random_value := f64(RANDOM_NUMBERS[gc.seed % RANDOM_MAX]) / f64(65535) * total_efficiency
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	
	// Select option based on cumulative probability
	cumulative := f64(0)
	for army in Idle_Army {
		cost := COST_IDLE_ARMY[army]
		if cost <= budget && efficiencies[army] > 0 {
			cumulative += efficiencies[army]
			if random_value <= cumulative {
				return army
			}
		}
	}
	
	// Fallback: return first affordable option
	for army in Idle_Army {
		cost := COST_IDLE_ARMY[army]
		if cost <= budget && efficiencies[army] > 0 {
			return army
		}
	}
	
	return nil
}

// Weighted random selection of ships for purchase
// Returns nil if no valid options or total efficiency is 0
randomize_ship_purchase :: proc(gc: ^Game_Cache, efficiencies: [Idle_Ship]f64, budget: u8) -> Maybe(Idle_Ship) {
	// Calculate total efficiency of affordable options
	total_efficiency := f64(0)
	for ship in Idle_Ship {
		cost := COST_IDLE_SHIP[ship]
		if cost <= budget && efficiencies[ship] > 0 {
			total_efficiency += efficiencies[ship]
		}
	}
	
	if total_efficiency <= 0 do return nil
	
	// Generate random number from 0 to total_efficiency
	random_value := f64(RANDOM_NUMBERS[gc.seed % RANDOM_MAX]) / f64(65535) * total_efficiency
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	
	// Select option based on cumulative probability
	cumulative := f64(0)
	for ship in Idle_Ship {
		cost := COST_IDLE_SHIP[ship]
		if cost <= budget && efficiencies[ship] > 0 {
			cumulative += efficiencies[ship]
			if random_value <= cumulative {
				return ship
			}
		}
	}
	
	// Fallback: return first affordable option
	for ship in Idle_Ship {
		cost := COST_IDLE_SHIP[ship]
		if cost <= budget && efficiencies[ship] > 0 {
			return ship
		}
	}
	
	return nil
}

// Weighted random selection of planes for purchase
randomize_plane_purchase :: proc(gc: ^Game_Cache, efficiencies: [Idle_Plane]f64, budget: u8) -> Maybe(Idle_Plane) {
	// Calculate total efficiency of affordable options
	total_efficiency := f64(0)
	for plane in Idle_Plane {
		cost := COST_IDLE_PLANE[plane]
		if cost <= budget && efficiencies[plane] > 0 {
			total_efficiency += efficiencies[plane]
		}
	}
	
	if total_efficiency <= 0 do return nil
	
	// Generate random number from 0 to total_efficiency
	random_value := f64(RANDOM_NUMBERS[gc.seed % RANDOM_MAX]) / f64(65535) * total_efficiency
	gc.seed = (gc.seed + 1) % RANDOM_MAX
	
	// Select option based on cumulative probability
	cumulative := f64(0)
	for plane in Idle_Plane {
		cost := COST_IDLE_PLANE[plane]
		if cost <= budget && efficiencies[plane] > 0 {
			cumulative += efficiencies[plane]
			if random_value <= cumulative {
				return plane
			}
		}
	}
	
	// Fallback: return first affordable option
	for plane in Idle_Plane {
		cost := COST_IDLE_PLANE[plane]
		if cost <= budget && efficiencies[plane] > 0 {
			return plane
		}
	}
	
	return nil
}

find_purchase_territories_triplea :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
) -> map[Land_ID]Pro_Purchase_Territory {
    if ODIN_DEBUG {
        fmt.println("Find all purchase territories")
    }
	territories := make(map[Land_ID]Pro_Purchase_Territory)
	for factory_loc in sa.slice(&gc.factory_locations[player]) {
		territories[factory_loc] = Pro_Purchase_Territory {
			territory             = factory_loc,
			can_place_land        = true,
			unit_production       = gc.factory_prod[factory_loc],
			can_place_territories = {factory_loc},
		}
	}
	return territories
}
