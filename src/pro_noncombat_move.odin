package oaaa

/*
Pro AI Non-Combat Move Phase Implementation

This file implements non-combat movement logic following TripleA's ProNonCombatMoveAi.java.
The Pro AI moves units to defensive positions, lands planes safely, and repositions forces
for future attacks.

Key Responsibilities:
- Find territories that need defense
- Move units to best defensive positions
- Land fighters and bombers safely
- Move transports to loading positions
- Consolidate forces for future attacks
- Ensure capital remains defended

Algorithm Overview (from ProNonCombatMoveAi.java):
1. Find units that can't move and infrastructure units
2. Move one defender to land territories bordering enemy
3. Determine max enemy attackers and if territories can be held
4. Prioritize territories to defend
5. Move units to defend territories
6. Move units to best value territories (sea, land, air)
7. Move infrastructure units (AA guns, factories if mobile)
8. Execute non-combat moves
*/

import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"

// Main non-combat move phase entry point
proai_noncombat_move_phase :: proc(gc: ^Game_Cache) -> (ok: bool) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Starting non-combat move phase")
	}

	pro_data := pro_data_init(gc)

	// Step 1: Find territories that need defense
	defense_targets := find_noncombat_defense_targets(gc, &pro_data)
	defer pro_noncombat_move_cleanup(&defense_targets)

	when ODIN_DEBUG {
		if len(defense_targets) == 0 {
			fmt.println("[PRO-AI] No territories need defense")
		} else {
			fmt.printf("[PRO-AI] Found %d territories needing defense:\n", len(defense_targets))
			for target in defense_targets {
				fmt.printf(
					"  - %s: defense=%.1f vs threat=%.1f (gap=%.1f, factory=%v, capital=%v)\n",
					mm.land_name[target.territory],
					target.current_defense,
					target.enemy_threat,
					target.defense_needed,
					target.has_factory,
					target.is_capital,
				)
			}
		}
	}

	// if len(defense_targets) == 0 {
	// 	return true
	// }

	// Step 2: Prioritize defense targets by strategic value
	prioritize_defense_targets(&defense_targets, gc, &pro_data)
	
	fmt.println("[PRO-AI] Prioritized defense targets:")
	for target in defense_targets {
		fmt.printf("  - %s: priority=%.1f, defense_needed=%.1f\n",
			target.territory, target.priority, target.defense_needed)
	}

	// Step 3: Move units to defend priority territories
	move_units_to_defense(&defense_targets, gc, &pro_data)

	// Step 4: Land fighters in safe territories
	land_fighters_noncombat(gc, &pro_data)

	// Step 5: Land bombers in safe territories
	land_bombers_noncombat(gc, &pro_data)

	// Step 6: Move remaining sea units to safe positions
	move_sea_units_noncombat(gc, &pro_data)

	// Step 7: Move remaining land units to consolidate
	move_land_units_noncombat(gc, &pro_data)
	debug_checks(gc)
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Completed non-combat move phase")
	}

	return true
}

// Defense_Target represents a territory that needs defensive units
Defense_Target :: struct {
	territory:       Land_ID,
	enemy_threat:    f64, // Enemy attack strength
	current_defense: f64, // Current defensive strength
	defense_needed:  f64, // Additional defense needed
	strategic_value: f64, // Strategic importance (factory, capital, etc)
	priority:        f64, // Overall priority for defense
	is_capital:      bool,
	has_factory:     bool,
}

// Find territories that need defensive reinforcement
find_noncombat_defense_targets :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) -> [dynamic]Defense_Target {
	targets := make([dynamic]Defense_Target)

	when ODIN_DEBUG {
		fmt.println("  [NONCOMBAT] Scanning all friendly territories for defense needs...")
	}

	// Check all friendly territories
	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}

		// Calculate enemy threat
		enemy_threat := calculate_enemy_threat(gc, to_air(land_id), pro_data)

		// Calculate current defense
		current_defense := calculate_current_defense(gc, to_air(land_id))

		// Calculate strategic value
		territory_value := calculate_territory_value(gc, land_id)
		is_capital := is_player_capital(gc, land_id, gc.cur_player)
		has_factory := gc.factory_prod[land_id] > 0

		strategic_value := territory_value
		if is_capital {
			strategic_value *= 10.0
		}
		if has_factory {
			strategic_value *= 3.0
		}

		// Check if this territory needs defense:
		// 1. Has enemy threat AND insufficient defense
		// 2. OR is strategically important (factory/capital) with no units
		needs_defense := false
		defense_gap := 0.0

		if enemy_threat > 0 {
			// Under threat - check if we have enough defense
			if current_defense < enemy_threat * 1.2 {
				needs_defense = true
				defense_gap = enemy_threat * 1.2 - current_defense
			}
		}

		// CRITICAL FIX: Also defend strategically important empty territories
		// This handles the case where all units moved out during combat phase
		if current_defense < 4.0 && (has_factory || is_capital || territory_value >= 3) {
			// Weak or empty strategic territory - check if enemy could attack next turn
			if has_enemy_neighbors(gc, land_id) {
				needs_defense = true
				// Assume minimum threat for weak strategic territories
				defense_gap = max(8.0 - current_defense, enemy_threat * 1.2 - current_defense)

				when ODIN_DEBUG {
					fmt.printf(
						"    [DEFENSE] %v is WEAK (cur_def=%.1f) with strategic value (factory=%v, capital=%v, value=%.1f, has_enemy_neighbors=true)\n",
						land_id,
						current_defense,
						has_factory,
						is_capital,
						territory_value,
					)
				}
			}
		}

		if !needs_defense {
			continue
		}

		target := Defense_Target {
			territory       = land_id,
			enemy_threat    = max(enemy_threat, 4.0), // Minimum assumed threat
			current_defense = current_defense,
			defense_needed  = defense_gap,
			strategic_value = strategic_value,
			is_capital      = is_capital,
			has_factory     = has_factory,
		}

		append(&targets, target)
	}

	return targets
}

// Check if territory has enemy neighbors (territories with enemy units)
has_enemy_neighbors :: proc(gc: ^Game_Cache, land_id: Land_ID) -> bool {
	my_team := mm.team[gc.cur_player]

	for adj in sa.slice(&mm.l2l_1away_via_land[land_id]) {
		if mm.team[gc.owner[adj]] != my_team {
			// Enemy or neutral territory adjacent
			return true
		}
	}

	return false
}

// Calculate enemy threat to a territory
calculate_enemy_threat :: proc(gc: ^Game_Cache, air_id: Air_ID, pro_data: ^Pro_Data) -> f64 {
	threat := 0.0
	if (is_air_land(air_id)) {
		territory := to_land(air_id)
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
				threat += f64(count) * get_army_threat_value(army_type)
			}

			// Check for enemy air units
			for plane_type in Idle_Plane {
				count := gc.idle_land_planes[territory][player][plane_type]
				threat += f64(count) * get_plane_threat_value(plane_type)
			}
		}
	} else {
		//TODO sea units
	}

	return threat
}

// Get threat value for army types
get_army_threat_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF:
		return 1.0
	case .ARTY:
		return 2.0
	case .TANK:
		return 3.0
	case .AAGUN:
		return 0.5
	case:
		return 1.0
	}
}

// Get threat value for plane types
get_plane_threat_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER:
		return 3.0
	case .BOMBER:
		return 4.0
	case:
		return 2.0
	}
}

// Calculate current defensive strength
calculate_current_defense :: proc(gc: ^Game_Cache, air_id: Air_ID) -> f64 {
	defense := 0.0
	if (is_air_land(air_id)) {
		territory := to_land(air_id)
		// Count friendly units
		for army_type in Idle_Army {
			count := gc.idle_armies[territory][gc.cur_player][army_type]
			defense += f64(count) * get_army_defense_value(army_type)
		}

		for plane_type in Idle_Plane {
			count := gc.idle_land_planes[territory][gc.cur_player][plane_type]
			defense += f64(count) * get_plane_defense_value(plane_type)
		}
	} else {
		// TODO sea units
	}
	return defense
}

// Get defense value for army types
get_army_defense_value :: proc(army_type: Idle_Army) -> f64 {
	switch army_type {
	case .INF:
		return INFANTRY_DEFENSE
	case .ARTY:
		return ARTILLERY_DEFENSE
	case .TANK:
		return TANK_DEFENSE
	case .AAGUN:
		return 0.5
	case:
		return 1.0
	}
}

// Get defense value for plane types
get_plane_defense_value :: proc(plane_type: Idle_Plane) -> f64 {
	switch plane_type {
	case .FIGHTER:
		return 4.0
	case .BOMBER:
		return 1.0
	case:
		return 2.0
	}
}

// Check if territory is a player's capital
is_player_capital :: proc(gc: ^Game_Cache, territory: Land_ID, player: Player_ID) -> bool {
	capital_maybe := get_capital_territory(player)
	if capital_maybe == nil {
		return false
	}
	return capital_maybe.? == territory
}

// Prioritize defense targets by strategic importance
prioritize_defense_targets :: proc(
	targets: ^[dynamic]Defense_Target,
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) {
	/*
	From ProNonCombatMoveAi.java prioritizeDefendOptions (lines 520-645):
	
	Calculates territory value using:
	territoryValue = unitOwnerMultiplier * 
	                 (2.0 * production + 10.0 * isFactory + 0.5 * cantMoveUnitValue + 0.5 * neighborValue) *
	                 (1 + 10.0 * isMyCapital) *
	                 (1 + 4.0 * isEnemyCapital)
	
	Then FILTERS territories removing those with:
	- isNotFactoryAndHasNoEnemyNeighbors (THIS IS KEY!)
	- Other conditions (can't hold, should hold, etc.)
	*/

	
	my_team := mm.team[gc.cur_player]
	
	// Calculate priority for each target using TripleA's formula
	for &target in targets {
		land_id := target.territory
		
		// Determine production value
		production := f64(gc.factory_prod[land_id])
		
		// Determine if it has a factory
		is_factory := target.has_factory ? 1.0 : 0.0
		
		// Determine if it is my capital
		is_my_capital := target.is_capital ? 1.0 : 0.0
		
		// Determine if it is enemy capital
		is_enemy_capital := 0.0
		for player in Player_ID {
			if mm.team[player] == my_team do continue
			if is_player_capital(gc, land_id, player) {
				is_enemy_capital = 1.0
				break
			}
		}
		
		// Calculate neighbor value (sum of adjacent territory production)
		neighbor_value := 0.0
		for neighbor in sa.slice(&mm.l2l_1away_via_land[land_id]) {
			neighbor_production := f64(gc.factory_prod[neighbor])
			if mm.team[gc.owner[neighbor]] == my_team {
				// Allied territories count at 10%
				neighbor_value += neighbor_production * 0.1
			} else {
				// Enemy/neutral territories count at 100%
				neighbor_value += neighbor_production
			}
		}
		
		// Determine defending unit value (cant move units)
		cant_move_unit_value := target.current_defense
		
		// Calculate territory value using TripleA formula
		territory_value := (2.0 * production + 
			10.0 * is_factory + 
			0.5 * cant_move_unit_value + 
			0.5 * neighbor_value) *
			(1.0 + 10.0 * is_my_capital) *
			(1.0 * 4.0 * is_enemy_capital)
		
		target.priority = territory_value
		target.strategic_value = territory_value
	}

	// CRITICAL: Filter out territories that shouldn't be defended
	// This is what makes Germany (capital) get removed, allowing Poland to be chosen!
	filtered := make([dynamic]Defense_Target, 0, len(targets))
	defer delete(filtered)
	
	for target in targets {
		land_id := target.territory
		has_factory := target.has_factory
		has_enemy_neighbors := has_enemy_neighbors(gc, land_id)
		is_capital := target.is_capital
		
		// Remove if: not a factory AND no enemy neighbors (matches isNotFactoryAndHasNoEnemyNeighbors)
		is_not_factory_and_has_no_enemy_neighbors := !has_factory && !has_enemy_neighbors
		
		if is_not_factory_and_has_no_enemy_neighbors && !is_capital {
			when ODIN_DEBUG {
				fmt.printf(
					"  [FILTER] Removing %v (value=%.2f): not factory, no enemy neighbors\n",
					mm.land_name[land_id], target.priority,
				)
			}
			continue
		}
		
		append(&filtered, target)
	}

	// fmt.println("---[PRO-AI] Prioritized defense targets:")
	// for target in filtered {
	// 	fmt.printf("  - %s: priority=%.1f, defense_needed=%.1f\n",
	// 		target.territory, target.priority, target.defense_needed)
	// }

	// targets^ = filtered

	//clear targets and reappend from filtered list
	clear(targets)
	for target in filtered {
		append(targets, target)
	}

	// Sort by priority (highest first)
	slice.sort_by(targets[:], proc(a, b: Defense_Target) -> bool {
		return a.priority > b.priority
	})

	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Prioritized defense targets (after filtering):")
		for target, i in targets {
			if i >= 10 {break} 	// Show top 10
			fmt.printf(
				"  %d. %v: value=%.1f, factory=%v, capital=%v, enemyNeighbors=%v\n",
				i + 1,
				mm.land_name[target.territory],
				target.priority,
				target.has_factory,
				target.is_capital,
				has_enemy_neighbors(gc, target.territory),
			)
		}
	}
}

// Move units to defend priority territories
move_units_to_defense :: proc(
	targets: ^[dynamic]Defense_Target,
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) {
	/*
	Move units to defensive positions:
	1. Initialize moved units tracker
	2. For each high-priority target needing defense
	3. Find nearby units that can reach
	4. Move units until defense requirement met
	*/

	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)

	// For each high priority target, find nearby units that can move there
	for &target in targets {
		if target.defense_needed <= 0 {
			continue
		}

		// Find units that can reach this territory
		units_moved := move_nearby_units_to_defense(
			gc,
			target.territory,
			target.defense_needed,
			&moved,
		)

		when ODIN_DEBUG {
			if units_moved > 0 {
				fmt.printf(
					"[PRO-AI] Moved %d units to defend territory %v\n",
					units_moved,
					target.territory,
				)
			}
		}
	}
}

// Move nearby units to defend a territory
move_nearby_units_to_defense :: proc(
	gc: ^Game_Cache,
	territory: Land_ID,
	defense_needed: f64,
	moved: ^Moved_Units,
) -> int {
	/*
	Find and move units to defend a territory:
	1. Check adjacent territories for friendly units
	2. Prioritize: Infantry < Artillery < Tanks
	3. Move units until defense requirement met
	4. Use map graph for adjacency checking
	*/

	units_moved := 0
	defense_provided := f64(0)

	// Check all adjacent land territories
	fmt.println("territory: ", territory)
	fmt.println("to_int: ", int(territory))
	for adjacent in sa.slice(&mm.l2l_1away_via_land[territory]) {
		if gc.owner[adjacent] != gc.cur_player do continue
		if adjacent == territory do continue

		// Try to move infantry first (most expendable)
		// inf_available := get_available_unit_count(gc, adjacent, .INF, moved)
		inf_available := gc.active_armies[adjacent][.INF_1_MOVES]
		if inf_available > 0 && defense_provided < defense_needed {
			inf_to_move := min(inf_available, u8((defense_needed - defense_provided) / 2) + 1)

			success := execute_land_move(gc, adjacent, territory, .INF_1_MOVES, inf_to_move, moved)
			if success {
				units_moved += int(inf_to_move)
				defense_provided += f64(inf_to_move) * 2.0 // Infantry has 2 defense
			}
		}

		// Try artillery if still need defense
		if defense_provided < defense_needed {
			// arty_available := get_available_unit_count(gc, adjacent, .ARTY, moved)
			arty_available := gc.active_armies[adjacent][.ARTY_1_MOVES]
			if arty_available > 0 {
				arty_to_move := min(
					arty_available,
					u8((defense_needed - defense_provided) / 2) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .ARTY_1_MOVES, arty_to_move, moved)
				if success {
					units_moved += int(arty_to_move)
					defense_provided += f64(arty_to_move) * 2.0 // Artillery has 2 defense
				}
			}
		}

		// Try tanks if still need defense
		if defense_provided < defense_needed {
			// tank_available := get_available_unit_count(gc, adjacent, .TANK, moved)
			tank_available := gc.active_armies[adjacent][.TANK_1_MOVES]
			if tank_available > 0 {
				tank_to_move := min(
					tank_available,
					u8((defense_needed - defense_provided) / 3) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .TANK_1_MOVES, tank_to_move, moved)
				if success {
					units_moved += int(tank_to_move)
					defense_provided += f64(tank_to_move) * 3.0 // Tanks have 3 defense
				}
			}
			tank_available = gc.active_armies[adjacent][.TANK_2_MOVES]
			if tank_available > 0 {
				tank_to_move := min(
					tank_available,
					u8((defense_needed - defense_provided) / 3) + 1,
				)

				success := execute_land_move(gc, adjacent, territory, .TANK_2_MOVES, tank_to_move, moved)
				if success {
					units_moved += int(tank_to_move)
					defense_provided += f64(tank_to_move) * 3.0 // Tanks have 3 defense
				}
			}
		}

		// Stop if we've met defense requirement
		if defense_provided >= defense_needed {
			break
		}
	}

	// Check territories 2 moves away (tanks only - they have 2 movement)
	if defense_provided < defense_needed {
		for land_2_away in mm.l2l_2away_via_land_bitset[territory] {
			for midland in mm.l2l_2away_via_midland_bitset[territory][land_2_away] {
				if mm.team[gc.owner[midland]] != mm.team[gc.cur_player] do continue

				// Only tanks can move 2 spaces
				tank_available := get_available_unit_count(gc, land_2_away, .TANK, moved)
				if tank_available > 0 {
					tank_to_move := min(
						tank_available,
						u8((defense_needed - defense_provided) / 3) + 1,
					)

					// Note: Direct 2-move not supported by execute_land_move yet
					// Would need intermediate territory calculation
					// For now, skip 2-move tank movements

					success := execute_land_move(
						gc,
						land_2_away,
						territory,
						.TANK_2_MOVES,
						tank_to_move,
						moved,
					)
					if success {
						units_moved += int(tank_to_move)
						defense_provided += f64(tank_to_move) * 3.0
					}

					// if defense_provided >= defense_needed {
					// 	break
					// }
				}
			}

		}
	}

	return units_moved
}

// ============================================================================
// AIR UNIT LANDING LOGIC
// ============================================================================

// Air_Landing_Option represents a potential landing location for an air unit
Air_Landing_Option :: struct {
	territory:                Air_ID, // Where the plane could land
	is_water:                 bool, // Is this a carrier landing?
	carrier_id:               Maybe(u32), // Which carrier (if water landing)
	air_value:                f64, // Strategic value of landing here
	safety_score:             f64, // How safe is this location
	can_hold:                 bool, // Can territory be held
	has_factory:              bool, // Territory has factory
	is_capital:               bool, // Territory is capital
	is_allied:                bool, // Territory is allied (not owned)

	// Attack potential from this location
	num_sea_attack_options:   int,
	num_land_attack_options:  int,
	num_enemy_attack_options: int,
	num_nearby_enemies:       int,

	// Safety metrics
	enemy_threat:             f64,
	current_defense:          f64,
	win_percentage:           f64,
	tuv_swing:                f64,
	cant_hold_without_allies: bool,
}

// Air_Unit_To_Land represents a plane that needs to find a landing spot
Air_Unit_To_Land :: struct {
	plane_type:        Idle_Plane, // FIGHTER or BOMBER
	active_plane_type: Active_Plane,
	current_location:  Land_ID, // Where it is now
	movement_range:    int, // How far it can move
	options:           [dynamic]Air_Landing_Option, // Possible landing spots
}

// Land fighters in safe territories
land_fighters_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing fighters in safe territories")
	}

	// From ProNonCombatMoveAi.java moveUnitsToBestTerritories() - Air units section
	land_air_units_noncombat(gc, pro_data, .FIGHTER)
}

// Land bombers in safe territories
land_bombers_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Landing bombers in safe territories")
	}

	// From ProNonCombatMoveAi.java moveUnitsToBestTerritories() - Air units section
	land_air_units_noncombat(gc, pro_data, .BOMBER)
}

// Main air unit landing logic (handles both fighters and bombers)
land_air_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, plane_type: Idle_Plane) {
	/*
	From ProNonCombatMoveAi.java - moveUnitsToBestTerritories():
	
	ProLogger.info("Move air units");
	
	// Get list of territories that can't be held
	final List<Territory> territoriesThatCantBeHeld =
		moveMap.entrySet().stream()
			.filter(e -> !e.getValue().isCanHold())
			.map(Map.Entry::getKey)
			.collect(Collectors.toList());
	
	// Move air units to safe territory with most attack options
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		...
	}
	
	// Move air units to safest territory
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		...
	}
	*/

	// Step 1: Find all air units of this type that need landing
	when ODIN_DEBUG {
		fmt.printf("  [AIR] Find all air units of this type that need landing...\n")
	}
	air_units := find_air_units_needing_landing(gc, pro_data, plane_type)
	defer delete(air_units)

	if len(air_units) == 0 {
		return
	}

	when ODIN_DEBUG {
		fmt.printf("  [AIR] Found %d %v units needing landing\n", len(air_units), plane_type)
	}

	// Step 2: Find territories that can't be held (for attack value calculation)
	territories_cant_hold := find_territories_that_cant_be_held(gc, pro_data)
	defer delete(territories_cant_hold)

	// Step 3: For each air unit, find all valid landing options
	for &air_unit in air_units {
		find_air_landing_options(gc, pro_data, &air_unit, territories_cant_hold)
	}

	// Step 4: First pass - land in safe territories with most attack options
	land_air_units_to_best_attack_positions(gc, pro_data, &air_units)

	// Step 5: Second pass - land remaining units in safest available territory
	land_air_units_to_safest_territories(gc, pro_data, &air_units)

	// Step 6: Cleanup
	for air_unit in air_units {
		delete(air_unit.options)
	}
}

// Find all air units of a type that need landing
find_air_units_needing_landing :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	plane_type: Idle_Plane,
) -> [dynamic]Air_Unit_To_Land {
	units := make([dynamic]Air_Unit_To_Land)

	for plane in Unlanded_Fighters {

		// Check all territories for idle planes
		for land_id in Land_ID {
			count := gc.active_land_planes[land_id][plane]
			if count == 0 {
				continue
			}

			// Determine movement range
			movement_range := 4 // Fighters have 4 movement
			if plane_type == .BOMBER {
				movement_range = 6 // Bombers have 6 movement
			}

			// Create entries for each plane at this location
			for i in 0 ..< count {
				air_unit := Air_Unit_To_Land {
					plane_type        = plane_type,
					active_plane_type = plane,
					current_location  = land_id,
					movement_range    = movement_range,
					options           = make([dynamic]Air_Landing_Option),
				}
				append(&units, air_unit)
			}
		}
	}

	return units
}

// Find territories that can't be held
find_territories_that_cant_be_held :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
) -> [dynamic]Land_ID {
	/*
	From ProNonCombatMoveAi.java:
	
	// Get list of territories that can't be held
	final List<Territory> territoriesThatCantBeHeld =
		moveMap.entrySet().stream()
			.filter(e -> !e.getValue().isCanHold())
			.map(Map.Entry::getKey)
			.collect(Collectors.toList());
	*/

	cant_hold := make([dynamic]Land_ID)

	for land_id in Land_ID {
		if gc.owner[land_id] != gc.cur_player {
			continue
		}

		// Calculate if we can hold this territory
		enemy_threat := calculate_enemy_threat(gc, to_air(land_id), pro_data)
		current_defense := calculate_current_defense(gc, to_air(land_id))

		// Can't hold if enemy threat exceeds defense by significant margin
		if enemy_threat > current_defense * 1.5 {
			append(&cant_hold, land_id)
		}
	}

	return cant_hold
}


// Calculate if territory can be held with the air unit
calculate_can_hold_with_air_unit :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	territory: Air_ID,
	plane_type: Idle_Plane,
) -> bool {
	enemy_threat := calculate_enemy_threat(gc, territory, pro_data)
	current_defense := calculate_current_defense(gc, territory)

	// Add air unit defense value
	air_defense := get_plane_defense_value(plane_type)
	total_defense := current_defense + air_defense

	// Can hold if defense meets threshold
	return total_defense >= enemy_threat * 1.2
}

// Calculate battle results for air unit landing
calculate_air_landing_battle_results :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	option: ^Air_Landing_Option,
	plane_type: Idle_Plane,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Check to see if the territory is safe
	final Collection<Unit> defendingUnits = proTerritory.getAllDefenders();
	defendingUnits.add(u);
	proTerritory.setBattleResultIfNull(
		() -> calc.calculateBattleResults(proData, proTerritory, defendingUnits));
	final ProBattleResult result = proTerritory.getBattleResult();
	...
	if (result.getWinPercentage() >= proData.getMinWinPercentage()
		|| result.getTuvSwing() > 0) {
		proTerritory.setCanHold(false);
		continue;
	}
	
	// Determine if territory can be held with owned units
	final List<Unit> myDefenders =
		CollectionUtils.getMatches(defendingUnits, Matches.unitIsOwnedBy(player));
	final ProBattleResult result2 =
		calc.calculateBattleResults(proData, proTerritory, myDefenders);
	int cantHoldWithoutAllies = 0;
	if (result2.getWinPercentage() >= proData.getMinWinPercentage()
		|| result2.getTuvSwing() > 0) {
		cantHoldWithoutAllies = 1;
	}
	*/

	// Simplified battle calculation
	air_defense := get_plane_defense_value(plane_type)
	total_defense := option.current_defense + air_defense

	// Estimate win percentage based on defense vs threat ratio
	if option.enemy_threat == 0 {
		option.win_percentage = 100.0
		option.tuv_swing = 0.0
	} else {
		ratio := total_defense / option.enemy_threat
		option.win_percentage = min(100.0, ratio * 50.0)
		option.tuv_swing = total_defense - option.enemy_threat
	}

	// Check if can hold without allies
	my_defense := calculate_current_defense(gc, option.territory)
	my_defense_with_air := my_defense + air_defense

	if option.enemy_threat > 0 {
		my_ratio := my_defense_with_air / option.enemy_threat
		my_win_pct := min(100.0, my_ratio * 50.0)

		// Can't hold without allies if win % is too low
		if my_win_pct < 70.0 || my_defense_with_air < option.enemy_threat {
			option.cant_hold_without_allies = true
		}
	}
}

// Calculate attack potential from landing location
calculate_air_attack_potential :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	option: ^Air_Landing_Option,
	air_unit: ^Air_Unit_To_Land,
	territories_cant_hold: [dynamic]Land_ID,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Find number of potential attack options next turn
	final int range = u.getMaxMovementAllowed();
	final Predicate<Territory> canMoveAirUnits =
		ProMatches.territoryCanMoveAirUnits(data, player, true);
	final Set<Territory> possibleAttackTerritories =
		data.getMap().getNeighbors(t, range / 2, canMoveAirUnits);
	final int numEnemyAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			ProMatches.territoryIsEnemyNotPassiveNeutralLand(player));
	final int numLandAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			ProMatches.territoryIsEnemyOrCantBeHeldAndIsAdjacentToMyLandUnits(
				player, territoriesThatCantBeHeld));
	final int numSeaAttackTerritories =
		CollectionUtils.countMatches(
			possibleAttackTerritories,
			Matches.territoryHasEnemySeaUnits(player)
				.and(
					Matches.territoryHasUnitsThatMatch(
						Matches.unitHasSubBattleAbilities().negate())));
	final Set<Territory> possibleMoveTerritories =
		data.getMap()
			.getNeighbors(t, range, ProMatches.territoryCanMoveAirUnits(data, player, true));
	final int numNearbyEnemyTerritories =
		CollectionUtils.countMatches(
			possibleMoveTerritories, ProMatches.territoryIsEnemyNotPassiveNeutralLand(player));
	*/

	// Calculate attack range (half of movement for next turn planning)
	attack_range := air_unit.movement_range / 2
	full_range := air_unit.movement_range

	my_team := mm.team[gc.cur_player]

	// Count enemy territories within attack range
	// TODO: Use proper map graph for neighbor calculation
	// For now, use simplified adjacency

	num_enemy := 0
	num_land_attack := 0
	num_sea_attack := 0
	num_nearby := 0

	for land_id in Land_ID {
		owner := gc.owner[land_id]

		// Check if enemy territory
		if mm.team[owner] != mm.team[gc.cur_player] {
			// TODO: Calculate actual distance with map graph
			// For now, count all enemy territories
			num_enemy += 1

			// Check if it's a land attack target
			// (enemy or can't be held and adjacent to our units)
			is_cant_hold := false
			for cant_hold in territories_cant_hold {
				if cant_hold == land_id {
					is_cant_hold = true
					break
				}
			}

			if is_cant_hold {
				num_land_attack += 1
			}
		}
	}

	// Count sea attack options
	// TODO: Check sea zones for enemy ships

	option.num_enemy_attack_options = num_enemy
	option.num_land_attack_options = num_land_attack
	option.num_sea_attack_options = num_sea_attack
	option.num_nearby_enemies = num_nearby
}

// Calculate overall air value for landing location
calculate_air_value :: proc(option: ^Air_Landing_Option) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Check if number of attack territories and value are max
	final int isntFactory = ProMatches.territoryHasInfraFactoryAndIsLand().test(t) ? 0 : 1;
	final int hasOwnedCarrier =
		proTerritory.getAllDefenders().stream().anyMatch(ProMatches.unitIsOwnedCarrier(player))
			? 1
			: 0;
	final double airValue =
		(200.0 * numSeaAttackTerritories
				+ 100.0 * numLandAttackTerritories
				+ 10.0 * numEnemyAttackTerritories
				+ numNearbyEnemyTerritories)
			/ (1 + cantHoldWithoutAllies)
			/ (1 + (double) cantHoldWithoutAllies * isntFactory)
			* (1 + hasOwnedCarrier);
	*/

	isnt_factory := option.has_factory ? 0.0 : 1.0
	has_owned_carrier := 0.0 // TODO: Detect carriers
	cant_hold_allies := option.cant_hold_without_allies ? 1.0 : 0.0

	option.air_value =
		(200.0 * f64(option.num_sea_attack_options) +
			100.0 * f64(option.num_land_attack_options) +
			10.0 * f64(option.num_enemy_attack_options) +
			f64(option.num_nearby_enemies)) /
		(1.0 + cant_hold_allies) /
		(1.0 + cant_hold_allies * isnt_factory) *
		(1.0 + has_owned_carrier)

	// Calculate safety score
	if option.enemy_threat > 0 {
		option.safety_score = option.current_defense / option.enemy_threat
	} else {
		option.safety_score = 100.0
	}
}

// Land air units to best attack positions (first pass)
land_air_units_to_best_attack_positions :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	air_units: ^[dynamic]Air_Unit_To_Land,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Move air units to safe territory with most attack options
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		double maxAirValue = 0;
		Territory maxTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			...
			if (airValue > maxAirValue) {
				maxAirValue = airValue;
				maxTerritory = t;
			}
		}
		if (maxTerritory != null) {
			...
			moveMap.get(maxTerritory).addUnit(u);
			...
			it.remove();
		}
	}
	*/

	moved := make([dynamic]int)
	defer delete(moved)

	for air_unit, idx in air_units {
		max_air_value := 0.0
		best_option_idx := -1

		// Find option with highest air value that can be held
		for option, i in air_unit.options {
			if !option.can_hold {
				continue
			}

			if option.air_value > max_air_value {
				max_air_value = option.air_value
				best_option_idx = i
			}
		}

		if best_option_idx >= 0 {
			best := air_unit.options[best_option_idx]

			when ODIN_DEBUG {
				fmt.printf(
					"  [AIR] %v landing at %v (airValue=%.1f, seaAttacks=%d, landAttacks=%d)\n",
					air_unit.plane_type,
					best.territory,
					best.air_value,
					best.num_sea_attack_options,
					best.num_land_attack_options,
				)
			}
			gc.current_territory = to_air(air_unit.current_location)
			gc.current_active_unit = to_unit(air_unit.active_plane_type)
			move_fighter_from_land_to_land(gc, to_action(best.territory))
			// TODO: Execute the actual move
			// For now, just mark as moved
			append(&moved, idx)
		}
	}

	// Remove moved units (in reverse to preserve indices)
	for i := len(moved) - 1; i >= 0; i -= 1 {
		idx := moved[i]
		ordered_remove(air_units, idx)
	}
}

// Land air units to safest territories (fallback pass)
land_air_units_to_safest_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	air_units: ^[dynamic]Air_Unit_To_Land,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	// Move air units to safest territory
	for (final Iterator<Unit> it = unitMoveMap.keySet().iterator(); it.hasNext(); ) {
		final Unit u = it.next();
		if (Matches.unitIsNotAir().test(u)) {
			continue;
		}
		double minStrengthDifference = Double.POSITIVE_INFINITY;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			...
			final double strengthDifference =
				ProBattleUtils.estimateStrengthDifference(t, attackers, defenders);
			...
			if (strengthDifference < minStrengthDifference) {
				minStrengthDifference = strengthDifference;
				minTerritory = t;
			}
		}
		if (minTerritory != null) {
			...
			moveMap.get(minTerritory).addUnit(u);
			it.remove();
		}
	}
	*/

	for air_unit in air_units {
		min_strength_diff := math.F64_MAX
		best_option_idx := -1

		// Find safest option (best strength difference)
		for option, i in air_unit.options {
			// Calculate strength difference
			strength_diff :=
				option.enemy_threat -
				(option.current_defense + get_plane_defense_value(air_unit.plane_type))

			if strength_diff < min_strength_diff {
				min_strength_diff = strength_diff
				best_option_idx = i
			}
		}

		if best_option_idx >= 0 {
			best := air_unit.options[best_option_idx]

			when ODIN_DEBUG {
				fmt.printf(
					"  [AIR] %v landing at SAFE %v (strengthDiff=%.1f)\n",
					air_unit.plane_type,
					best.territory,
					min_strength_diff,
				)
			}

			// TODO: Execute the actual move
		}
	}
}

// Move sea units to safe positions
move_sea_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving sea units to safe positions")
	}

	// For each sea zone with friendly ships:
	// 1. Calculate if zone is safe from enemy attack
	// 2. If unsafe, move to safer adjacent zone
	// 3. If safe, consider moving to better strategic position

	// Priority considerations:
	// - Protect transports
	// - Position carriers for fighter landing
	// - Stage for future amphibious assaults
	// - Blockade enemy territories

	// Placeholder - simplified implementation
	for sea_id in Sea_ID {
		// Check if we have ships here
		has_ships := false
		for ship_type in Idle_Ship {
			if gc.idle_ships[sea_id][gc.cur_player][ship_type] > 0 {
				has_ships = true
				break
			}
		}

		if !has_ships {
			continue
		}

		// Calculate if this zone is safe
		// Would check for enemy attackers
		// If unsafe, would move to adjacent safer zone
	}
}

// Move land units to consolidate positions
move_land_units_noncombat :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data) {
	/*
	From ProNonCombatMoveAi.java (lines 1842-1989):
	
	Three-pass algorithm:
	1. Move land units to territory with highest value and highest transport capacity
	2. Move land units towards nearest factory that is adjacent to the sea
	3. Move any remaining land units to safest territory (fallback)
	
	NOTE: Uses gc.pro_value which is calculated by build_map_production_value() during
	game cache initialization. This matches TripleA's ProTerritoryValueUtils.findTerritoryValues.
	*/
	
	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving land units to consolidate")
	}

	// Initialize movement tracker
	moved := init_moved_units()
	defer cleanup_moved_units(&moved)

	// PASS 1: Move to high-value territories with transport capacity
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 1: Move to high-value territories near transports")
	}
	
	move_land_to_high_value_territories(gc, pro_data, &moved)
	debug_checks(gc)

	// PASS 2: Move towards coastal factories
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 2: Move towards coastal factories")
	}
	
	move_land_towards_coastal_factories(gc, pro_data, &moved)

	// PASS 3: Move remaining units to safest territory
	when ODIN_DEBUG {
		fmt.println("  [LAND] Pass 3: Move remaining units to safety")
	}
	
	move_land_to_safest_territories(gc, pro_data, &moved)
}

// PASS 1: Move land units to high-value territories with transport capacity
move_land_to_high_value_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1842-1904):
	
	// Move land units to territory with highest value and highest transport capacity
	// TODO: consider if territory ends up being safe
	final Predicate<Territory> canMoveSeaUnits = ProMatches.territoryCanMoveSeaUnits(player, true);
	final List<Unit> addedUnits = new ArrayList<>();
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		Territory maxValueTerritory = null;
		double maxValue = 0;
		int maxNeedAmphibUnitValue = Integer.MIN_VALUE;
		for (final Territory t : unitMoveMap.get(u)) {
			final ProTerritory proTerritory = moveMap.get(t);
			if (proTerritory.isCanHold() && proTerritory.getValue() >= maxValue) {
				// Find transport capacity of neighboring (distance 1) transports
				final Set<Territory> seaNeighbors = data.getMap().getNeighbors(t, canMoveSeaUnits);
				int transportCapacity1 = 0;
				for (Unit tr : ProTransportUtils.getTransports(player, moveMap, seaNeighbors)) {
					transportCapacity1 += tr.getUnitAttachment().getTransportCapacity();
				}
				
				// Find transport capacity of nearby (distance 2) transports
				final Set<Territory> nearbySeaTerritories =
					data.getMap().getNeighbors(t, 2, canMoveSeaUnits);
				nearbySeaTerritories.removeAll(seaNeighbors);
				int transportCapacity2 = 0;
				for (Unit tr : ProTransportUtils.getTransports(player, moveMap, nearbySeaTerritories)) {
					transportCapacity2 += tr.getUnitAttachment().getTransportCapacity();
				}
				final List<Unit> unitsToTransport =
					CollectionUtils.getMatches(
						proTerritory.getAllDefenders(), ProMatches.unitIsOwnedTransportableUnit(player));
				
				// Find transport cost of potential amphib units
				int transportCost = 0;
				for (final Unit unit : unitsToTransport) {
					transportCost += unit.getUnitAttachment().getTransportCost();
				}
				
				// Find territory that needs amphib units the most
				int hasFactory = 0;
				if (ProMatches.territoryHasInfraFactoryAndIsOwnedLandAdjacentToSea(player).test(t)) {
					hasFactory = 1;
				}
				final int neededNeighborTransportValue = Math.max(0, transportCapacity1 - transportCost);
				final int neededNearbyTransportValue =
					Math.max(0, transportCapacity1 + transportCapacity2 - transportCost);
				final int needAmphibUnitValue =
					1000 * neededNeighborTransportValue
						+ 100 * neededNearbyTransportValue
						+ (1 + 10 * hasFactory) * data.getMap().getNeighbors(t, canMoveSeaUnits).size();
				if (proTerritory.getValue() > maxValue || needAmphibUnitValue > maxNeedAmphibUnitValue) {
					maxValue = proTerritory.getValue();
					maxNeedAmphibUnitValue = needAmphibUnitValue;
					maxValueTerritory = t;
				}
			}
		}
		if (maxValueTerritory != null) {
			ProLogger.trace(
				String.format(
					"%s moved to %s with value=%s, needAmphibUnitValue=%s",
					u, maxValueTerritory, maxValue, maxNeedAmphibUnitValue));
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(maxValueTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	my_team := mm.team[gc.cur_player]
	
	// For each unit type at this location
	for army in Unmoved_Armies {
		// For each land territory with our units
		for src_land in Land_ID {
			// if gc.owner[src_land] != gc.cur_player {
			// 	continue
			// }

			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			
			// Find best destination considering value and transport capacity
			best_territory:= src_land
			best_value := 0.0
			best_amphib_value := 0.0
			
			// Check all territories this unit can reach
			//if army == .TANK_2_MOVES do add_valid_army_moves_2(gc)

			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				if !can_hold_destination(gc, pro_data, dst_land) {					
					when ODIN_DEBUG {
						fmt.printf("Cannot hold destination: %v\n", dst_land)
					}
					continue
				}
				// Calculate transport capacity (amphib potential)
				amphib_value := calculate_amphib_value(gc, dst_land)
				
				// Choose if better than current best
				if gc.pro_value[dst_land] > best_value || amphib_value > best_amphib_value {
					best_value = gc.pro_value[dst_land]
					best_amphib_value = amphib_value
					best_territory = dst_land
				}
			}

			//TODO add tanks with 2 moves


			//todo game_cache bitset for is_boat_available large, small
			// for dst_sea in sa.slice(&mm.l2s_1away_via_land[src_land]) {
			// 	idle_ships := &gc.idle_ships[dst_sea][gc.cur_player]
			// 	transport_available := false
			// 	for transport in Trans_Allowed_By_Army_Size[Army_Size[army]] {
			// 		if idle_ships[transport] > 0 {
			// 			transport_available = true
			// 			break
			// 		}
			// 	}
			// 	if !transport_available {
			// 		continue
			// 	}
			// }
			
			// Move unit to best destination
			if best_value > 0 {
				if best_territory != src_land {
					// success := execute_land_move(gc, src_land, best_land, army_type, 1, moved)
					gc.current_territory = to_air(src_land)
					gc.current_active_unit = to_unit(army)
					dst_action := to_action(best_territory)
					debug_checks(gc)
					next_state := blitz_checks(gc, dst_action)
					move_single_army_land(gc, dst_action, next_state)
					when ODIN_DEBUG {
						fmt.printf(
							"    Moved %v from %v to %v (value: %.1f, amphib: %.1f)\n",
							army, src_land, best_territory, best_value, best_amphib_value,
						)
					}
					debug_checks(gc)
				}
			}
		}
	}
}

// PASS 2: Move land units towards coastal factories
move_land_towards_coastal_factories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1910-1944):
	
	// Move land units towards nearest factory that is adjacent to the sea
	final Collection<Territory> myFactoriesAdjacentToSea =
		CollectionUtils.getMatches(
			data.getMap().getTerritories(),
			ProMatches.territoryHasInfraFactoryAndIsOwnedLandAdjacentToSea(player));
	final Predicate<Territory> canMoveLandUnits =
		ProMatches.territoryCanMoveLandUnits(player, true);
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		int minDistance = Integer.MAX_VALUE;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			if (!moveMap.get(t).isCanHold()) {
				continue;
			}
			for (final Territory factory : myFactoriesAdjacentToSea) {
				int distance = data.getMap().getDistance(t, factory, canMoveLandUnits);
				if (distance < 0) {
					distance = 10 * data.getMap().getDistance(t, factory);
				}
				if (distance >= 0 && distance < minDistance) {
					minDistance = distance;
					minTerritory = t;
				}
			}
		}
		if (minTerritory != null) {
			ProLogger.trace(
				u.getType().getName()
					+ " moved towards closest factory adjacent to sea at "
					+ minTerritory.getName());
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(minTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	// Find all our coastal factories
	coastal_factories := make([dynamic]Land_ID)
	defer delete(coastal_factories)
	
	for land_id in sa.slice(&gc.factory_locations[gc.cur_player]) {
		// Adjacent to sea?
		if is_land_adjacent_to_sea(land_id) {
			append(&coastal_factories, land_id)
		}
	}
	
	if len(coastal_factories) == 0 {
		return
	}
	
	when ODIN_DEBUG {
		fmt.printf("    Found %d coastal factories\n", len(coastal_factories))
	}
	
	// For each unit type at this location
	for army in Unmoved_Armies {
		// For each land territory with our units
		for src_land in Land_ID {
			// if gc.owner[src_land] != gc.cur_player {
			// 	continue
			// }
			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			// Find nearest coastal factory
			min_distance := max(u8)
			best_territory:= src_land
			
			// max_moves := idle_army_to_max_moves(army_type)
			
			// Check all reachable territories

			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				
				// Skip if can't hold
				if !can_hold_destination(gc, pro_data, dst_land) {
					continue
				}
				
				// Calculate distance to nearest coastal factory
				for factory in coastal_factories {
					distance := mm.air_distances[to_air(src_land)][to_air(factory)]
					
					if distance >= 0 && distance < min_distance {
						min_distance = distance
						best_territory = dst_land
					}
				}
			}

			//TODO add tanks with 2 moves
			
			// Move towards coastal factory
			if best_territory != src_land {
				success := execute_land_move(gc, src_land, best_territory, army, 1, moved)
				when ODIN_DEBUG {
					if success {
						fmt.printf(
							"    Moved %v from %v to %v (distance to factory: %d)\n",
							army, src_land, best_territory, min_distance,
						)
					}
				}
			}
		}
	}
}

// PASS 3: Move land units to safest territories (fallback)
move_land_to_safest_territories :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	moved: ^Moved_Units,
) {
	/*
	From ProNonCombatMoveAi.java (lines 1950-1989):
	
	// Move any remaining land units to safest territory (this is rarely used)
	for (final Unit u : unitMoveMap.keySet()) {
		if (!Matches.unitIsLand().test(u) || addedUnits.contains(u)) {
			continue;
		}
		
		// Get all units that have already moved
		final List<Unit> alreadyMovedUnits =
			moveMap.values().stream()
				.map(ProTerritory::getUnits)
				.flatMap(Collection::stream)
				.collect(Collectors.toList());
		
		// Find safest territory
		double minStrengthDifference = Double.POSITIVE_INFINITY;
		Territory minTerritory = null;
		for (final Territory t : unitMoveMap.get(u)) {
			final ProTerritory proTerritory = moveMap.get(t);
			final List<Unit> attackers = proTerritory.getMaxEnemyUnits();
			final List<Unit> defenders = proTerritory.getMaxDefenders();
			defenders.removeAll(alreadyMovedUnits);
			defenders.addAll(proTerritory.getUnits());
			final double strengthDifference =
				ProBattleUtils.estimateStrengthDifference(t, attackers, defenders);
			if (strengthDifference < minStrengthDifference) {
				minStrengthDifference = strengthDifference;
				minTerritory = t;
			}
		}
		if (minTerritory != null) {
			ProLogger.debug(
				u.getType().getName()
					+ " moved to safest territory at "
					+ minTerritory.getName()
					+ " with strengthDifference="
					+ minStrengthDifference);
			final List<Unit> unitsToAdd = ProTransportUtils.getUnitsToAdd(proData, u, moveMap);
			moveMap.get(minTerritory).addUnits(unitsToAdd);
			addedUnits.addAll(unitsToAdd);
		}
	}
	*/
	
	// For each land territory with our units
	// For each land territory with our units
	// For each unit type at this location
	for army in Unmoved_Armies {
		// For each land territory with our units
		for src_land in Land_ID {
			available := gc.active_armies[src_land][army]
			if available == 0 {
				continue
			}
			// Find safest reachable territory
			min_strength_diff := math.F64_MAX
			best_territory:= src_land	
			
			for dst_land in sa.slice(&mm.l2l_1away_via_land[src_land]) {
				
				// Calculate strength difference (attackers - defenders)
				enemy_threat := calculate_enemy_threat(gc, to_air(dst_land), pro_data)
				current_defense := calculate_current_defense(gc, to_air(dst_land))
				unit_defense := get_army_defense_value(Active_Army_To_Idle[army])
				
				strength_diff := enemy_threat - (current_defense + unit_defense)
				
				if strength_diff < min_strength_diff {
					min_strength_diff = strength_diff
					best_territory = dst_land
				}
			}
			
			// Move to safest territory
			if best_territory != src_land {
				success := execute_land_move(gc, src_land, best_territory, army, 1, moved)

				when ODIN_DEBUG {
					if success {
						fmt.printf(
							"    Moved %v from %v to %v (strength diff: %.1f)\n",
							army, src_land, best_territory, min_strength_diff,
						)
					}
				}
			}
		}
	}
}

// ============================================================================
// HELPER FUNCTIONS FOR LAND MOVEMENT
// ============================================================================

// Calculate amphib value - how useful is this territory for amphibious assaults
calculate_amphib_value :: proc(gc: ^Game_Cache, land: Land_ID) -> f64 {
	/*
	From Java:
	final int needAmphibUnitValue =
		1000 * neededNeighborTransportValue
			+ 100 * neededNearbyTransportValue
			+ (1 + 10 * hasFactory) * data.getMap().getNeighbors(t, canMoveSeaUnits).size();
	*/
	
	// Check if has factory
	has_factory := gc.factory_prod[land] > 0
	factory_multiplier := has_factory ? 10.0 : 1.0
	
	// Simplified: Just count adjacent seas weighted by factory presence
	// Full implementation would count transport capacity at those seas
	amphib_value := factory_multiplier * f64(mm.l2s_1away_via_land[land].len)
	
	// TODO: Count actual transports in adjacent/nearby seas
	// For now, use simplified calculation
	
	return amphib_value
}

// Check if land territory is adjacent to sea
is_land_adjacent_to_sea :: proc(land: Land_ID) -> bool {
	return sa.len(mm.l2s_1away_via_land[land]) > 0
}

// Calculate distance between two land territories
calculate_land_distance :: proc(gc: ^Game_Cache, from: Land_ID, to: Land_ID) -> i32 {
	/*
	Simplified distance calculation using BFS-style traversal
	
	In full implementation, would use:
	- mm.land_distances[from][to] if available
	- Or implement proper pathfinding considering team ownership
	
	For now, use approximation:
	- Adjacent = 1
	- 2-away = 2
	- Otherwise = high value
	*/
	
	if from == to {
		return 0
	}
	
	// Check if adjacent
	for adj in sa.slice(&mm.l2l_1away_via_land[from]) {
		if adj == to {
			return 1
		}
	}
	
	// Check if 2-away
	for land_2 in mm.l2l_2away_via_land_bitset[from] {
		if land_2 == to {
			return 2
		}
	}
	
	// Otherwise return high value (unreachable or far)
	return 10
}

// Check if destination can be held
can_hold_destination :: proc(gc: ^Game_Cache, pro_data: ^Pro_Data, land: Land_ID) -> bool {
	/*
	From Java:
	if (!moveMap.get(t).isCanHold()) {
		continue;
	}
	*/
	
	// Check if we own it or an ally owns it
	if mm.team[gc.owner[land]] != mm.team[gc.cur_player] {
		return false
	}
	
	// Calculate if we can hold it
	enemy_threat := calculate_enemy_threat(gc, to_air(land), pro_data)
	current_defense := calculate_current_defense(gc, to_air(land))
	
	// Can hold if defense is sufficient
	return current_defense >= enemy_threat * 0.8
}

// Helper: Move one unit to each territory bordering enemy
move_one_defender_to_border_territories :: proc(gc: ^Game_Cache) {
	// Find all friendly territories adjacent to enemy
	// For each, ensure at least one defender present
	// This prevents enemy from easily capturing undefended border territories

	when ODIN_DEBUG {
		fmt.println("[PRO-AI] Moving one defender to each border territory")
	}

	// Placeholder - simplified implementation
	// Would identify border territories and ensure minimal defense
}

// Helper: Check if territory can be held after reinforcement
can_hold_territory_after_reinforcement :: proc(
	gc: ^Game_Cache,
	territory: Air_ID,
	additional_defense: f64,
	pro_data: ^Pro_Data,
) -> bool {
	enemy_threat := calculate_enemy_threat(gc, territory, pro_data)
	current_defense := calculate_current_defense(gc, territory)
	total_defense := current_defense + additional_defense

	// Can hold if defense is 20% stronger than threat
	return total_defense >= enemy_threat * 1.2
}

// Helper: Find best territory to move a unit to
find_best_noncombat_move :: proc(
	gc: ^Game_Cache,
	from: Land_ID,
	unit_strength: f64,
) -> Maybe(Land_ID) {
	best_territory: Maybe(Land_ID) = nil
	best_value := 0.0

	// Check all territories unit can reach
	// Would use movement range and map graph
	// For now, simplified to adjacent territories

	// Evaluate each potential destination
	// Consider: strategic value, defensive need, safety

	return best_territory
}

// Cleanup
pro_noncombat_move_cleanup :: proc(targets: ^[dynamic]Defense_Target) {
	delete(targets^)
}
