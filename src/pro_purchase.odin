package oaaa

/*
Pro AI Purchase Phase Implementation

Modeled after TripleA's ProPurchaseAi.java

Main algorithm flow (from TripleA):
1. Repair damaged factories (critical first step)
2. Find all territories that need defense
3. Purchase defenders for threatened territories
4. Calculate strategic value for all territories
5. Purchase AA guns for high-value territories
6. Purchase land units for offense
7. Purchase naval defenders if needed
8. Consider factory placement
9. Purchase sea/amphibious units
10. Use remaining PUs on high-value units

Key simplifications for OAAA:
- Simplified bidding (not needed for MCTS rollouts)
- Focus on speed over perfection
*/

import "core:fmt"
import "core:math"
import sa "core:container/small_array"

// Main purchase function called from pro_turn.odin
proai_purchase_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	if gc.money[gc.cur_player] == 0 {
		return true
	}
	
	// Step 0: Repair damaged factories FIRST (following TripleA logic)
	// This is critical - damaged factories reduce production capacity
	repair_factories(gc)
	
	// Find territories that can place units (have factories)
	purchase_territories := find_purchase_territories(gc)
	if len(purchase_territories) == 0 {
		return true  // No factories to place at
	}
	
	// Step 1: Identify territories that need defense
	territories_needing_defense := find_territories_needing_defense(gc)
	
	// Step 2: Purchase defenders for threatened territories
	purchase_defenders(gc, territories_needing_defense, purchase_territories)
	
	// Step 3: Purchase offensive land units
	purchase_land_units(gc, purchase_territories)
	
	// Step 4: Consider factory placement (if enough money)
	consider_factory_purchase(gc)
	
	// Step 5: Purchase naval/air units if money remains
	purchase_sea_and_air_units(gc, purchase_territories)
	
	// Step 6: Spend remaining money on most cost-effective units
	spend_remaining_money(gc, purchase_territories)
	
	return true
}

// Repair damaged factories (following TripleA's ProPurchaseAi.repair logic)
// Factories can be damaged by strategic bombing, reducing production capacity
// Pro AI prioritizes repairing high-production factories first
repair_factories :: proc(gc: ^Game_Cache) {
	if gc.money[gc.cur_player] == 0 do return
	
	// Define factory info struct
	Factory_Info :: struct {
		location: Land_ID,
		damage: u8,
		production: u8,
	}
	
	// Find all damaged factories we own
	damaged_factories := make([dynamic]Factory_Info, context.temp_allocator)
	
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		damage := gc.factory_dmg[factory_loc]
		if damage > 0 && gc.owner[factory_loc] == gc.cur_player {
			production := gc.factory_prod[factory_loc]
			append(&damaged_factories, Factory_Info{location = factory_loc, damage = damage, production = production})
		}
	}
	
	if len(damaged_factories) == 0 do return
	
	// Sort by production value (repair high-production factories first)
	// This matches TripleA's prioritization logic
	// For now, iterate in order (proper sorting would be done here)
	
	// Repair factories in priority order
	for factory in damaged_factories {
		if gc.money[gc.cur_player] == 0 do break
		
		// Calculate how much we can afford to repair
		damage := factory.damage
		money_available := gc.money[gc.cur_player]
		
		// Repair as much as we can afford
		repair_amount := min(damage, money_available)
		
		if repair_amount > 0 {
			// Deduct money and reduce damage
			gc.money[gc.cur_player] -= repair_amount
			gc.factory_dmg[factory.location] -= repair_amount
			
			// Note: In TripleA, repair costs are 1 IPC per damage point
			// This matches OAAA's system where repair_cost is calculated as damage
		}
	}
}

// Find all territories where we have factories (can place units)
find_purchase_territories :: proc(gc: ^Game_Cache) -> []Land_ID {
	territories := make([dynamic]Land_ID, context.temp_allocator)
	
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		// Make sure we own this factory
		if gc.owner[factory_loc] == gc.cur_player {
			append(&territories, factory_loc)
		}
	}
	
	return territories[:]
}

// Territory defense assessment
Territory_Defense_Need :: struct {
	territory: Land_ID,
	defense_value: f64,
	enemy_threat_power: f64,
	current_defense_power: f64,
	is_capital: bool,
	has_factory: bool,
}

// Find territories that need additional defense
find_territories_needing_defense :: proc(gc: ^Game_Cache) -> []Territory_Defense_Need {
	needs := make([dynamic]Territory_Defense_Need, context.temp_allocator)
	
	for territory in Land_ID {
		// Only consider territories we own
		if gc.owner[territory] != gc.cur_player do continue
		
		// Count our defenders
		our_inf := gc.idle_armies[territory][gc.cur_player][.INF]
		our_art := gc.idle_armies[territory][gc.cur_player][.ARTY]
		our_tanks := gc.idle_armies[territory][gc.cur_player][.TANK]
		our_aa := gc.idle_armies[territory][gc.cur_player][.AAGUN]
		our_fighters := gc.idle_land_planes[territory][gc.cur_player][.FIGHTER]
		our_bombers := gc.idle_land_planes[territory][gc.cur_player][.BOMBER]
		
		// Calculate our defense power
		defense_power := estimate_defense_power(gc, our_inf, our_art, our_tanks, our_aa, our_fighters, our_bombers)
		
		// Estimate enemy threat (simplified - would need map graph for real calculation)
		// For now, assume moderate threat if we have < 3 defenders
		total_defenders := our_inf + our_art + our_tanks + our_fighters + our_bombers
		enemy_threat := f64(0)
		if total_defenders < 3 {
			enemy_threat = 10.0  // Moderate threat
		}
		
		// Only add if there's a threat and we need more defense
		if enemy_threat > defense_power * 1.5 {
			is_capital := is_our_capital(gc, territory)
			has_factory := has_factory_at(gc, territory)
			
			// Calculate defense value (higher = more important to defend)
			value := calculate_defense_value(gc, territory, is_capital, has_factory, defense_power)
			
			if value > 0 {
				need := Territory_Defense_Need{
					territory = territory,
					defense_value = value,
					enemy_threat_power = enemy_threat,
					current_defense_power = defense_power,
					is_capital = is_capital,
					has_factory = has_factory,
				}
				append(&needs, need)
			}
		}
	}
	
	return needs[:]
}

// Calculate how important it is to defend this territory
calculate_defense_value :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	is_capital: bool,
	has_factory: bool,
	current_defense: f64,
) -> f64 {
	value := f64(0)
	
	// Base value from territory importance
	value += calculate_territory_value(gc, territory)
	
	// Capital is extremely important
	if is_capital {
		value *= 10.0
	}
	
	// Factory territories are very important
	if has_factory {
		value *= 4.0
	}
	
	// Lower current defense = higher urgency
	if current_defense < 5.0 {
		value *= 2.0
	}
	
	return value
}

// Check if this is our capital
is_our_capital :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	capital, ok := get_capital_territory(gc.cur_player).?
	if !ok do return false
	return capital == territory
}

// Check if we have a factory at this territory
has_factory_at :: proc(gc: ^Game_Cache, territory: Land_ID) -> bool {
	for factory_loc in sa.slice(&gc.factory_locations[gc.cur_player]) {
		if factory_loc == territory do return true
	}
	return false
}

// Purchase defensive units for threatened territories
purchase_defenders :: proc(
	gc: ^Game_Cache,
	needs: []Territory_Defense_Need,
	factories: []Land_ID,
) {
	if len(needs) == 0 do return
	if gc.money[gc.cur_player] == 0 do return
	
	// Sort by defense value (highest first)
	// For now, iterate through as-is (proper sorting would be done here)
	
	for need in needs {
		// Try to purchase defenders for this territory
		// Priority: Infantry (cheap, good defense)
		
		// Find nearest factory that can produce for this territory
		factory := find_nearest_factory(gc, need.territory, factories)
		if factory == nil do continue
		
		// Calculate how many defenders we need
		defense_gap := need.enemy_threat_power - need.current_defense_power
		if defense_gap <= 0 do continue
		
		// Buy infantry until we close the gap or run out of money
		// Infantry: 3 IPCs, defense 2
		inf_needed := int(defense_gap / 2.0) + 1
		
		for i := 0; i < inf_needed; i += 1 {
			if gc.money[gc.cur_player] >= 3 {
				// Purchase infantry
				if try_buy_unit(gc, .BUY_INF_ACTION) {
					// Success - unit will be placed at factory location
				} else {
					break
				}
			} else {
				break
			}
		}
	}
}

// Find nearest factory to a territory (simplified - returns first factory)
find_nearest_factory :: proc(gc: ^Game_Cache, territory: Land_ID, factories: []Land_ID) -> Maybe(Land_ID) {
	if len(factories) == 0 do return nil
	// Simplified: just return first factory
	// Full implementation would use map graph to find closest
	return factories[0]
}

// Purchase offensive land units
purchase_land_units :: proc(gc: ^Game_Cache, factories: []Land_ID) {
	if gc.money[gc.cur_player] == 0 do return
	if len(factories) == 0 do return
	
	// Pro AI offensive unit purchase strategy (from TripleA):
	// - Mix of infantry, artillery, and tanks
	// - Prefer tanks if we have money (high attack power, mobility)
	// - Buy artillery to support infantry
	// - Always buy some infantry (cheap, essential)
	
	money := int(gc.money[gc.cur_player])
	
	// Strategy: 1 tank per 2 infantry, 1 artillery per 3 infantry
	// This gives a balanced offensive force
	
	tanks_to_buy := money / 24  // Each "stack" = 2 inf (6) + 1 art (4) + 1 tank (6) = 16 IPCs
	if tanks_to_buy > 0 {
		// Buy tanks
		for i := 0; i < tanks_to_buy && gc.money[gc.cur_player] >= 6; i += 1 {
			try_buy_unit(gc, .BUY_TANK_ACTION)
		}
	}
	
	// Buy artillery (support for infantry)
	arty_to_buy := money / 12  // Artillery pairs well with inf
	for i := 0; i < arty_to_buy && gc.money[gc.cur_player] >= 4; i += 1 {
		try_buy_unit(gc, .BUY_ARTY_ACTION)
	}
	
	// Spend remaining on infantry
	for gc.money[gc.cur_player] >= 3 {
		if !try_buy_unit(gc, .BUY_INF_ACTION) do break
	}
}

// Consider purchasing a factory if economically viable
consider_factory_purchase :: proc(gc: ^Game_Cache) {
	// Need at least 15 IPCs for factory
	if gc.money[gc.cur_player] < 15 do return
	
	// Only buy factory if we have good income
	if gc.income[gc.cur_player] < 20 do return
	
	// Try to buy factory using existing function
	// Note: buy_factory handles its own logic and user input
	// For Pro AI, we skip this for now (would need to implement auto-selection)
	// buy_factory(gc)
}

// Purchase naval and air units
purchase_sea_and_air_units :: proc(gc: ^Game_Cache, factories: []Land_ID) {
	if gc.money[gc.cur_player] == 0 do return
	
	// Pro AI naval purchase strategy:
	// - Buy transports if we need to move units overseas
	// - Buy destroyers/cruisers for naval defense
	// - Buy fighters (versatile, can defend both land and sea)
	
	// Check if we need transports (simplified logic)
	// Full implementation would check if enemies are only reachable by sea
	
	// Buy a fighter if we have money (good for both offense and defense)
	if gc.money[gc.cur_player] >= 10 {
		try_buy_unit(gc, .BUY_FIGHTER_ACTION)
	}
	
	// Buy a transport if we have sea production capability
	// (Simplified - would check for coastal factories)
	if gc.money[gc.cur_player] >= 7 {
		// Only buy if we have coastal access
		// For now, skip this (would need map graph integration)
	}
}

// Spend any remaining money on most cost-effective units
spend_remaining_money :: proc(gc: ^Game_Cache, factories: []Land_ID) {
	// Keep buying infantry with remaining money
	for gc.money[gc.cur_player] >= 3 {
		if !try_buy_unit(gc, .BUY_INF_ACTION) do break
	}
}

// Attempt to purchase a unit
try_buy_unit :: proc(gc: ^Game_Cache, action: Action_ID) -> bool {
	// Check if we can afford it
	cost := get_unit_cost(action)
	if gc.money[gc.cur_player] < cost do return false
	
	// Deduct money
	gc.money[gc.cur_player] -= cost
	
	// Add to purchase queue (will be placed in place phase)
	// For now, directly add to first factory (simplified)
	// Full implementation would track purchases separately and place later
	
	if len(gc.factory_locations[gc.cur_player].data) > 0 {
		factory := gc.factory_locations[gc.cur_player].data[0]
		
		// Add unit to factory location based on type
		#partial switch action {
		case .BUY_INF_ACTION:
			gc.idle_armies[factory][gc.cur_player][.INF] += 1
		case .BUY_ARTY_ACTION:
			gc.idle_armies[factory][gc.cur_player][.ARTY] += 1
		case .BUY_TANK_ACTION:
			gc.idle_armies[factory][gc.cur_player][.TANK] += 1
		case .BUY_AAGUN_ACTION:
			gc.idle_armies[factory][gc.cur_player][.AAGUN] += 1
		case .BUY_FIGHTER_ACTION:
			gc.idle_land_planes[factory][gc.cur_player][.FIGHTER] += 1
		case .BUY_BOMBER_ACTION:
			gc.idle_land_planes[factory][gc.cur_player][.BOMBER] += 1
		case .BUY_TRANS_ACTION, .BUY_SUB_ACTION, .BUY_DESTROYER_ACTION,
		     .BUY_CARRIER_ACTION, .BUY_CRUISER_ACTION, .BUY_BATTLESHIP_ACTION:
			// Naval units - would need sea placement logic
			// For now, skip (simplified)
			return false
		}
	}
	
	return true
}

// Get cost of a unit
get_unit_cost :: proc(action: Action_ID) -> u8 {
	#partial switch action {
	case .BUY_INF_ACTION: return 3
	case .BUY_ARTY_ACTION: return 4
	case .BUY_TANK_ACTION: return 6
	case .BUY_AAGUN_ACTION: return 5
	case .BUY_FIGHTER_ACTION: return 10
	case .BUY_BOMBER_ACTION: return 12
	case .BUY_TRANS_ACTION: return 7
	case .BUY_SUB_ACTION: return 6
	case .BUY_DESTROYER_ACTION: return 8
	case .BUY_CARRIER_ACTION: return 14
	case .BUY_CRUISER_ACTION: return 12
	case .BUY_BATTLESHIP_ACTION: return 20
	}
	return 0
}
