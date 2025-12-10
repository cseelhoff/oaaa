package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"

/*
=============================================================================
Pro Land Value Calculation

Maps to Java ProTerritoryValueUtils.java (721 lines)
Calculates strategic value of territories for attack and defense prioritization.

=============================================================================
JAVA ProTerritoryValueUtils.java STRUCTURE (721 lines)
=============================================================================

findTerritoryValues() - Main entry (lines 40-180) - [PARTIAL]
├── LOOP: for each territory
│   ├── Calculate production value - [IMPLEMENTED]
│   ├── Calculate neighbor bonus - [IMPLEMENTED]
│   ├── [MISSING] Enemy factory/capital distance bonus (lines 80-120)
│   └── [MISSING] Sea zone accessibility bonus (lines 125-150)

findSeaValue() - Sea zone valuation (lines 182-280) - [PARTIAL]
├── LOOP: for each sea zone
│   ├── Adjacent land value sum - [IMPLEMENTED]
│   ├── [MISSING] Transport route value (lines 210-250)
│   └── [MISSING] Naval choke point bonus (lines 255-275)

findLandValue() - Land territory valuation (lines 282-400) - [PARTIAL]
├── LOOP: for each land territory
│   └── BFS from production centers - [IMPLEMENTED simplified]

[MISSING] findAttackValue() (lines 402-520)
├── Calculate value of attacking a territory
├── Consider TUV swing, production gain
└── Factor in post-conquest defensibility

[MISSING] findDefenseValue() (lines 522-640)
├── Calculate defensive priority
├── Consider capital proximity
└── Factor in factory presence

[MISSING] findUnitValue() (lines 642-721)
├── Unit-specific value multipliers
└── Used for TUV calculations

=============================================================================
TODO REVIEW: Missing from ProTerritoryValueUtils.java:

1. findAttackValue() - NOT IMPLEMENTED
   - Territory attack prioritization formula
   - Critical for attack sequencing

2. findDefenseValue() - NOT IMPLEMENTED
   - Defense priority calculation
   - Used in non-combat move decisions

3. Sea zone transport route value - NOT IMPLEMENTED
   - Value of sea zones for transport paths

4. Multi-hop value propagation - PARTIAL
   - Java uses BFS with decay, Odin simplified
=============================================================================
*/

MAX_LAND_MASS_SIZE :: 49

// VAL-003/VAL-004: Production value calc + Neighbor bonus calc (inline helper)
get_pro_value :: #force_inline proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	production := gc.factory_prod[territory]
	return(
		math.sqrt(f64(production) + math.sqrt(f64(production))) *
		32 *
		(1.0 + f64(mm.l2l_1away_via_land[territory].len)) /
		f64(MAX_LAND_TO_LAND_CONNECTIONS) \
	)
}

// =============================================================================
// VAL-001/VAL-002: Main Entry Point - findTerritoryValues
// =============================================================================
// Maps to Java ProTerritoryValueUtils.findTerritoryValues()
// Calculates values for all territories in the territories_to_check set

find_territory_values :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	territories_that_cant_be_held: Land_Bitset,
	territories_to_attack: Land_Bitset,
	land_territories_to_check: Land_Bitset,
	sea_territories_to_check: Sea_Bitset,
) -> (land_values: [Land_ID]f64, sea_values: [Sea_ID]f64) {
	// Get enemy capitals and factories map first
	enemy_capitals_and_factories_map := find_enemy_capitals_and_factories_value(
		gc,
		player,
		territories_that_cant_be_held,
		territories_to_attack,
	)
	defer delete(enemy_capitals_and_factories_map)

	// Calculate land territory values first
	for t in land_territories_to_check {
		land_values[t] = find_land_value(
			gc,
			t,
			player,
			enemy_capitals_and_factories_map,
			territories_that_cant_be_held,
			territories_to_attack,
		)
	}

	// Calculate sea territory values (depends on land values)
	for s in sea_territories_to_check {
		sea_values[s] = find_water_value(
			gc,
			s,
			player,
			enemy_capitals_and_factories_map,
			territories_that_cant_be_held,
			territories_to_attack,
			land_values,
		)
	}

	return land_values, sea_values
}

build_map_production_value :: proc(gc: ^Game_Cache) {
	for land in Land_ID {
		if gc.factory_prod[land] == 0 do continue
		gc.pro_value[land] = get_pro_value(gc, land)
	}
	for land in Land_ID {
		land_mass_multiplier := f64(mm.land_mass_size[land]) / f64(MAX_LAND_MASS_SIZE)
		for valuable_land in Land_ID {
			if land == valuable_land do continue
			gc.pro_value[land] = max(
				gc.pro_value[land],
				land_mass_multiplier *
				gc.pro_value[valuable_land] /
				math.pow(2, f64(mm.air_distances[to_air(land)][to_air(valuable_land)])),
			)
		}
	}
}

find_enemy_capitals_and_factories_value :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	territoriesThatCantBeHeld: Land_Bitset,
	territoriesToAttack: Land_Bitset,
) -> map[Land_ID]f64 {
	enemy_capitals_and_factories :=
		gc.has_factory & (territoriesThatCantBeHeld | ~gc.friendly_owner)
	numPotentialEnemyTerritories := card(~gc.friendly_owner)
	if (card(enemy_capitals_and_factories) * 2 >= numPotentialEnemyTerritories) {
		enemy_capitals_and_factories = {}
	}
	for enemy in sa.slice(&mm.enemies[player]) {
		enemy_capitals_and_factories += {mm.capital[enemy]}
	}
	enemy_capitals_and_factories = enemy_capitals_and_factories & ~territoriesToAttack

	// Find value for each enemy capital and factory
	enemy_capitals_and_factories_map := make(map[Land_ID]f64)
	for t in enemy_capitals_and_factories {
		// Get factory production if factory
		factory_production := gc.factory_prod[t]

		// Get player production if capital
		player_production: f64 = 0
		for p in Player_ID {
			if mm.capital[p] == t {
				player_production = f64(mm.value[t])
			}
		}

		value :=
			math.sqrt_f64(f64(factory_production) + math.sqrt_f64(player_production)) *
			32 *
			f64(mm.land_mass_size[t]) /
			f64(MAX_LAND_MASS_SIZE)
		enemy_capitals_and_factories_map[t] = value
	}

	return enemy_capitals_and_factories_map
}


// VAL-012/VAL-013: findLandValue() - Land territory valuation with BFS from production centers
find_land_value :: proc(
	gc: ^Game_Cache,
	t: Land_ID, // proData: ^ProData,
	player: Player_ID,
	enemy_capitals_and_factories_map: map[Land_ID]f64,
	territories_that_cant_be_held: Land_Bitset,
	territories_to_attack: Land_Bitset,
) -> f64 {
	if t in territories_that_cant_be_held {
		return 0.0
	}

	// Determine value based on enemy factory land distance
	values: [dynamic]f64 = {}
	// data = proData.getData()
	nearby_enemy_capitals_and_factories := find_nearby_enemy_capitals_and_factories(
		t,
		enemy_capitals_and_factories_map,
	)

	for enemy_capital_or_factory in nearby_enemy_capitals_and_factories {
		// distance: int = get_land_distance(data.getMap(), t, enemy_capital_or_factory)
		distance := mm.land_distances[t][enemy_capital_or_factory]
		if (distance > 0) {
			append(
				&values,
				enemy_capitals_and_factories_map[enemy_capital_or_factory] /
				math.pow(2, f64(distance)),
			)
		}
	}
	// VAL-013: Sort values in descending order before applying cumulative decay
	// This ensures the highest-value factories contribute most
	slice.reverse_sort(values[:])
	capital_or_factory_value: f64 = 0
	for i in 0 ..< len(values) {
		capital_or_factory_value += values[i] / math.pow(2.0, f64(i)) // Decrease each additional factory value by half
	}

	// Determine value based on nearby territory production
	nearby_enemy_value: f64 = 0
	nearby_territories: Land_Bitset = mm.l2l_2away_via_land_bitset[t]
	// nearby_enemy_territories: [dynamic]Land_ID = CollectionUtils.getMatches(
	// 	nearby_territories,
	// 	ProMatches.territoryIsEnemyOrCantBeHeld(player, territories_that_cant_be_held),
	// )
	nearby_enemy_territories :=
		nearby_territories &
		(territories_that_cant_be_held | ~gc.friendly_owner) &
		~territories_to_attack

	for nearby_enemy_territory in nearby_enemy_territories {
		distance := mm.land_distances[t][nearby_enemy_territory]
		if distance > 0 {
			value: f64 = 0
			
			// VAL-012: Check if neutral land - use attack value calculation
			if is_neutral_land(gc, nearby_enemy_territory) {
				// Neutral territories use attack value / 3 (per Java)
				value = find_territory_attack_value(gc, nearby_enemy_territory, player) / 3.0
			} else if nearby_enemy_territory in gc.friendly_owner {
				// Allied territory that can't be held
				value = f64(gc.factory_prod[nearby_enemy_territory])
				neighbors := mm.l2l_1away_via_land_bitset[nearby_enemy_territory]
				enemy_neighbors := neighbors & ~gc.friendly_owner
				if enemy_neighbors == {} {
					value *= 0.1 // reduce value for can't hold amphib allied territories
				}
			} else {
				// Enemy territory - use production value
				value = f64(mm.value[nearby_enemy_territory])
			}
			
			if value > 0 {
				nearby_enemy_value += (value / math.pow(2, f64(distance)))
			}
		}
	}

	value: f64 =
		nearby_enemy_value * f64(mm.land_mass_size[t]) / f64(MAX_LAND_MASS_SIZE) +
		capital_or_factory_value
	if gc.factory_prod[t] > 0 {
		value *= 1.1 // prefer territories with factories
	}
	
	// VAL-006: Sea zone accessibility bonus
	// Coastal territories are worth more for transport loading/unloading
	if sa.len(mm.l2s_1away_via_land[t]) > 0 {
		value *= 1.15 // 15% bonus for coastal territories
	}

	return value
}

find_nearby_enemy_capitals_and_factories :: proc(
	t: Land_ID,
	enemy_capitals_and_factories: map[Land_ID]f64,
) -> [dynamic]Land_ID {
	result: [dynamic]Land_ID = {}
	for enemy_capital_or_factory in enemy_capitals_and_factories {
		if mm.land_distances[t][enemy_capital_or_factory] > 0 {
			append(&result, enemy_capital_or_factory)
		}
	}
	return result
}

// =============================================================================
// VAL-005/VAL-007/VAL-008: Sea Zone Value Calculation
// =============================================================================
// Maps to Java ProTerritoryValueUtils.findWaterValue()
// Calculates value of sea zones based on nearby land and transport routes

find_water_value :: proc(
	gc: ^Game_Cache,
	s: Sea_ID,
	player: Player_ID,
	enemy_capitals_and_factories_map: map[Land_ID]f64,
	territories_that_cant_be_held: Land_Bitset,
	territories_to_attack: Land_Bitset,
	land_values: [Land_ID]f64,
) -> f64 {
	canal_state := transmute(u8)gc.canals_open
	
	if !has_sea_neighbors(gc, s) {
		return 0.0
	}
	
	// Find nearby enemy capitals/factories reachable by sea
	capital_or_factory_value: f64 = 0
	values: [dynamic]f64 = {}
	defer delete(values)
	
	for enemy_capital_or_factory, factory_value in enemy_capitals_and_factories_map {
		// Check if reachable via sea routes (simplified: use air distance as proxy)
		sea_distance := get_sea_distance_to_land(gc, s, enemy_capital_or_factory)
		if sea_distance > 0 && sea_distance <= 6 {
			append(&values, factory_value / math.pow(2, f64(sea_distance)))
		}
	}
	
	// Sort and accumulate with decay
	slice.reverse_sort(values[:])
	for i in 0 ..< len(values) {
		capital_or_factory_value += values[i] / math.pow(2.0, f64(i))
	}
	
	// VAL-007: Determine value based on nearby land territories
	nearby_land_value: f64 = 0
	
	// Check adjacent land territories (distance 1)
	for land in sa.slice(&mm.s2l_1away_via_sea[s]) {
		land_value := land_values[land]
		
		// Add production value for enemy territories
		if land in (territories_that_cant_be_held | ~gc.friendly_owner) && land not_in territories_to_attack {
			nearby_land_value += f64(mm.value[land])
		}
		
		// Add propagated land value
		nearby_land_value += land_value
	}
	
	// VAL-008: Check nearby sea zones for transport routes (distance 2-3)
	for adj_sea in mm.s2s_1away_via_sea[canal_state][s] {
		for land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
			land_value := land_values[land]
			nearby_land_value += land_value / 2.0  // Decay by distance
		}
	}
	
	return capital_or_factory_value / 100 + nearby_land_value / 10
}

// Helper: Check if sea zone has water neighbors
has_sea_neighbors :: proc(gc: ^Game_Cache, s: Sea_ID) -> bool {
	canal_state := transmute(u8)gc.canals_open
	return card(mm.s2s_1away_via_sea[canal_state][s]) > 0
}

// Helper: Get approximate sea distance from sea zone to land territory
get_sea_distance_to_land :: proc(gc: ^Game_Cache, s: Sea_ID, land: Land_ID) -> int {
	canal_state := transmute(u8)gc.canals_open
	
	// Check if land is adjacent to this sea zone
	for adj_land in sa.slice(&mm.s2l_1away_via_sea[s]) {
		if adj_land == land {
			return 1
		}
	}
	
	// Check distance 2 (through adjacent sea zones)
	for adj_sea in mm.s2s_1away_via_sea[canal_state][s] {
		for adj_land in sa.slice(&mm.s2l_1away_via_sea[adj_sea]) {
			if adj_land == land {
				return 2
			}
		}
	}
	
	// Check distance 3
	for adj_sea in mm.s2s_1away_via_sea[canal_state][s] {
		for adj_sea2 in mm.s2s_1away_via_sea[canal_state][adj_sea] {
			for adj_land in sa.slice(&mm.s2l_1away_via_sea[adj_sea2]) {
				if adj_land == land {
					return 3
				}
			}
		}
	}
	
	return 0  // Not reachable in 3 moves
}

// =============================================================================
// VAL-009: Territory Attack Value (Simple)
// =============================================================================
// Maps to Java ProTerritoryValueUtils.findTerritoryAttackValue()
// Simplified version used for neutral territory evaluation

find_territory_attack_value :: proc(gc: ^Game_Cache, t: Land_ID, player: Player_ID) -> f64 {
	// Check if enemy factory
	is_enemy_factory := gc.factory_prod[t] > 0 && mm.team[gc.owner[t]] != mm.team[player]
	factory_multiplier := 1 + (1 if is_enemy_factory else 0)
	
	value := 3.0 * f64(mm.value[t]) * f64(factory_multiplier)
	
	// For neutral land, estimate TUV swing based on defender strength
	if is_neutral_land(gc, t) {
		strength := calculate_land_defense_strength(gc, t)
		// Estimate TUV swing as number of casualties * min cost per hit point
		tuv_swing := -(strength / 8.0) * f64(get_min_cost_per_hit_point())
		value += tuv_swing
	}
	
	return value
}

// =============================================================================
// VAL-014 to VAL-017: Attack Value Calculation
// =============================================================================

// VAL-014: findAttackValue() - Evaluates territories from offensive perspective
// Returns how valuable it is to capture an enemy territory
find_attack_value :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	pro_data: ^Pro_Data,
) -> f64 {
	/*
	From Java ProTerritoryValueUtils.findAttackValue():
	
	VAL-015: Iterate enemy territories calculating attack priority
	VAL-016: TUV swing calc - expected TUV gain from attack
	VAL-017: Post-conquest defensibility - can we hold after capture?
	
	Attack value formula:
	- Base production value (IPC income)
	- TUV swing bonus (enemy losses > our losses)
	- Defensibility bonus (can we hold it?)
	- Capital bonus (very high for enemy capitals)
	- Factory bonus (enemy factories are valuable)
	*/
	
	value: f64 = 0.0
	
	// Base: IPC production value
	value += f64(mm.value[territory]) * 2.0
	
	// Factory bonus: enemy factories are high priority
	if gc.factory_prod[territory] > 0 {
		value += f64(gc.factory_prod[territory]) * 5.0
	}
	
	// Capital bonus: enemy capitals are very high priority
	for player in Player_ID {
		if mm.capital[player] == territory && mm.team[player] != mm.team[gc.cur_player] {
			value += 50.0  // Very high bonus for enemy capital
		}
	}
	
	// VAL-016: TUV swing estimate (simplified)
	// Estimate based on defender strength vs attacker capability
	enemy_defense := calculate_land_defense_strength(gc, territory)
	if enemy_defense > 0 {
		// Lower defense = easier to capture = higher value
		value += 10.0 / (1.0 + enemy_defense/10.0)
	} else {
		// Undefended territory is very valuable to take
		value += 20.0
	}
	
	// VAL-017: Post-conquest defensibility
	// Check if we can hold it after capture
	can_hold_multiplier := 1.0
	enemy_threat := estimate_enemy_counterattack_strength(gc, territory)
	if enemy_threat > 20 {
		can_hold_multiplier = 0.5  // Hard to hold, reduce value
	} else if enemy_threat > 10 {
		can_hold_multiplier = 0.75
	}
	value *= can_hold_multiplier
	
	return value
}

// VAL-016 Helper: Calculate defense strength of a territory
calculate_land_defense_strength :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	strength: f64 = 0.0
	owner := gc.owner[territory]
	
	// Count defending units
	strength += f64(gc.idle_armies[territory][owner][.INF]) * 2.0    // Infantry defense = 2
	strength += f64(gc.idle_armies[territory][owner][.ARTY]) * 2.0   // Artillery defense = 2
	strength += f64(gc.idle_armies[territory][owner][.TANK]) * 3.0   // Tank defense = 3
	strength += f64(gc.idle_armies[territory][owner][.AAGUN]) * 0.0  // AA guns don't defend
	
	// Count defending planes
	strength += f64(gc.idle_land_planes[territory][owner][.FIGHTER]) * 4.0  // Fighter defense = 4
	strength += f64(gc.idle_land_planes[territory][owner][.BOMBER]) * 1.0   // Bomber defense = 1
	
	return strength
}

// VAL-017 Helper: Estimate enemy counter-attack strength
estimate_enemy_counterattack_strength :: proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	strength: f64 = 0.0
	
	// Check adjacent territories for enemy forces
	for adj in sa.slice(&mm.l2l_1away_via_land[territory]) {
		owner := gc.owner[adj]
		if mm.team[owner] == mm.team[gc.cur_player] {
			continue  // Skip friendly
		}
		
		// Add enemy units that could counter-attack
		strength += f64(gc.idle_armies[adj][owner][.INF]) * 1.0    // Infantry attack = 1
		strength += f64(gc.idle_armies[adj][owner][.ARTY]) * 2.0   // Artillery attack = 2
		strength += f64(gc.idle_armies[adj][owner][.TANK]) * 3.0   // Tank attack = 3
		strength += f64(gc.idle_land_planes[adj][owner][.FIGHTER]) * 3.0
		strength += f64(gc.idle_land_planes[adj][owner][.BOMBER]) * 4.0
	}
	
	return strength
}

// =============================================================================
// VAL-018 to VAL-021: Defense Value Calculation  
// =============================================================================

// VAL-018: findDefenseValue() - Evaluates territories from defensive perspective
// Returns how important it is to hold a friendly territory
find_defense_value :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	pro_data: ^Pro_Data,
) -> f64 {
	/*
	From Java ProTerritoryValueUtils.findDefenseValue():
	
	VAL-019: Iterate friendly territories calculating defense priority
	VAL-020: Capital proximity - closer to capital = more critical
	VAL-021: Factory presence - factories must be defended
	
	Defense value formula:
	- Base production value (IPC loss if captured)
	- Capital bonus (capital is critical)
	- Factory bonus (don't lose production)
	- Capital proximity bonus (buffer zones matter)
	*/
	
	value: f64 = 0.0
	
	// Base: IPC production value
	value += f64(mm.value[territory]) * 2.0
	
	// VAL-021: Factory bonus
	if gc.factory_prod[territory] > 0 {
		value += f64(gc.factory_prod[territory]) * 10.0  // Very high - don't lose factories
	}
	
	// Capital check - is this our capital?
	capital := mm.capital[gc.cur_player]
	if territory == capital {
		value += 100.0  // Capital is critical - must defend
	}
	
	// VAL-020: Capital proximity
	// Territories closer to capital are buffer zones - defend them
	distance_to_capital := mm.land_distances[territory][capital]
	if distance_to_capital > 0 && distance_to_capital <= 3 {
		value += 20.0 / f64(distance_to_capital)  // Closer = more valuable
	}
	
	// Bonus for territories bordering enemy (front line defense)
	for adj in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if mm.team[gc.owner[adj]] != mm.team[gc.cur_player] {
			value += 5.0  // Front line territories need defense
			break
		}
	}
	
	return value
}
