package oaaa

/*
Pro AI Predicate Matching Utilities

TODO REVIEW: Java ProMatches.java contains 50+ predicate methods that this file should implement.

CRITICAL MISSING METHODS (all from ProMatches.java):

Territory Predicates:
- territoryHasInfraFactoryAndIsNotConqueredOwnedLand(player)
- territoryHasInfraFactoryAndIsOwnedLand(player)
- territoryHasInfraFactoryAndIsOwnedLandAdjacentToSea(player)
- territoryHasNonMobileInfraFactory()
- territoryHasInfraFactory()
- territoryCanMoveSeaUnits(player, isCombatMove)
- territoryCanMoveSeaUnitsThrough(player, isCombatMove)
- territoryCanMoveAirUnitsThrough(player, isCombatMove, isBlitzing)
- territoryCanPotentiallyMoveSeaUnits(player, isCombatMove)
- territoryCanMoveLandUnits(player, isCombatMove)
- territoryCanMoveLandUnitsThrough(player, isCombatMove, attackingUnit, territories)
- territoryCanMoveSeaUnitsAndNotInList(player, isCombatMove, notTerritories)
- territoryCanMoveSeaUnitsAndNotInList(player, isCombatMove)
- territoryHasOnlyIgnoredUnits(player)
- territoryIsEnemyNotNeutral(player)
- territoryHasEnemyNotOwnedUnits(player)
- territoryHasNoEnemyUnits(player)
- territoryHasNoEnemyUnitsOrCleared(player, clearedTerritories)
- territoryHasPotentialBomber(player)
- territoryCanBeBombed(player, alliedAa)

Unit Predicates:
- unitIsOwnedTransport(player)
- unitIsOwnedTransportableUnit(player)
- unitIsOwnedCombatTransportableUnit(player)
- unitIsOwnedTransportableUnitAndCanBeLoaded(player, ...)
- unitIsOwnedAndOnOwnedLandOrOwnedSea(player)
- unitIsOwnedNotLand(player)
- unitIsEnemyAnd(predicate)
- unitIsEnemyAndNotAa(player)
- unitIsEnemyAndNotInfa(player)
- unitHasSubBattleAbilities()
- unitCanBeMovedAndIsOwned(player)
- unitCanBeMovedAndIsOwnedLand(player, isCombatMove)
- unitCanBeMovedAndIsOwnedSea(player, isCombatMove)
- unitCanBeMovedAndIsOwnedAir(player, isCombatMove)
- unitIsOwnedNotLandAndNotInfrastructureAndCanMove(player, isCombatMove)
- unitIsOwnedCarrier(player)
- unitIsAlliedNotOwned(player)
- unitCanLandOnCarrier(player)
- unitIsOwnedFighterOnCarrier(player)
- unitHasLessMovementThan(minMovement)

These predicates are used extensively throughout the Java Pro AI for filtering units
and territories during combat/non-combat moves, purchasing, and strategic decisions.

Many of these predicates are currently implemented inline in other Odin files
(e.g., checking gc.owner, mm.team, etc.), but having centralized functions would
improve code consistency and maintainability.
*/

import "core:slice"
import sa "core:container/small_array"

// ===== Territory Geometry Predicates =====
// These predicates classify territories based on map geometry (land/sea adjacency).

// MATCH-001: is_island checks if a land territory is coastal but has no land neighbors.
// Islands are important for stranded unit detection - units here can only leave by transport.
// Examples: UK islands, Pacific islands, Madagascar
is_island :: proc(land: Land_ID) -> bool {
	has_sea := sa.len(mm.l2s_1away_via_land[land]) > 0
	has_land := sa.len(mm.l2l_1away_via_land[land]) > 0
	return has_sea && !has_land
}

// MATCH-002: has_land_neighbors checks if a territory has any adjacent land territories.
// Territories without land neighbors require amphibious transport to reinforce.
has_land_neighbors :: proc(land: Land_ID) -> bool {
	return sa.len(mm.l2l_1away_via_land[land]) > 0
}

// MATCH-003: get_land_neighbor_count returns the number of adjacent land territories.
// Used for evaluating territory connectivity and strategic importance.
get_land_neighbor_count :: proc(land: Land_ID) -> int {
	return sa.len(mm.l2l_1away_via_land[land])
}

// MATCH-004: get_sea_neighbor_count returns the number of adjacent sea zones.
// Coastal territories with more sea access have more transport options.
get_sea_neighbor_count :: proc(land: Land_ID) -> int {
	return sa.len(mm.l2s_1away_via_land[land])
}

// ===== Player Relationship Predicates =====
// These predicates determine relationships between players.

// MATCH-005: are_enemies checks if two players are on opposing teams.
// Uses the team lookup table from map data.
are_enemies :: proc(player1: Player_ID, player2: Player_ID) -> bool {
	return mm.team[player1] != mm.team[player2]
}

// MATCH-006: are_allies checks if two players are on the same team (including self).
// Note: A player is allied with themselves.
are_allies :: proc(player1: Player_ID, player2: Player_ID) -> bool {
	return mm.team[player1] == mm.team[player2]
}

// MATCH-007: is_enemy_of_current checks if a player is an enemy of the current player.
// Convenience wrapper for use in iteration loops.
is_enemy_of_current :: proc(gc: ^Game_Cache, player: Player_ID) -> bool {
	return mm.team[player] != mm.team[gc.cur_player]
}

// MATCH-008: is_ally_of_current checks if a player is allied with the current player.
// Includes the current player themselves.
is_ally_of_current :: proc(gc: ^Game_Cache, player: Player_ID) -> bool {
	return mm.team[player] == mm.team[gc.cur_player]
}

// ===== Territory Ownership Predicates =====
// These predicates check territory ownership status.

// MATCH-009: is_owned_by_current checks if territory is owned by current player.
is_owned_by_current :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return gc.owner[land] == gc.cur_player
}

// MATCH-010: is_owned_by_ally checks if territory is owned by an allied player (not self).
// Useful for identifying friendly reinforcement opportunities.
is_owned_by_ally :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	owner := gc.owner[land]
	return owner != gc.cur_player && mm.team[owner] == mm.team[gc.cur_player]
}

// MATCH-011: is_friendly_territory checks if territory is owned by current player or ally.
is_friendly_territory :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return mm.team[gc.owner[land]] == mm.team[gc.cur_player]
}

// MATCH-015: is_enemy_territory checks if territory is owned by an enemy player.
// Complement to is_friendly_territory for attack target identification.
is_enemy_territory :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return mm.team[gc.owner[land]] != mm.team[gc.cur_player]
}

// ===== Sea Zone Geometry Predicates =====
// These predicates analyze sea zone connectivity.

// MATCH-012: get_adjacent_land_count returns number of land territories touching a sea zone.
// Sea zones with more land connections have more strategic value for transport operations.
get_adjacent_land_count :: proc(sea: Sea_ID) -> int {
	return sa.len(mm.s2l_1away_via_sea[sea])
}

// MATCH-013: get_adjacent_sea_count returns number of sea zones connected to this one.
// Higher connectivity means more naval movement options.
get_adjacent_sea_count :: proc(sea: Sea_ID) -> int {
	// Note: This depends on canal state, so we count potential connections
	count := 0
	for other_sea in Sea_ID {
		if other_sea != sea {
			// Check both open and closed canal states for max connectivity
			if other_sea in mm.s2s_1away_via_sea[0][sea] || other_sea in mm.s2s_1away_via_sea[1][sea] {
				count += 1
			}
		}
	}
	return count
}

// MATCH-014: is_canal_sea checks if a sea zone's connectivity depends on canal status.
// Canal-dependent sea zones are strategically important chokepoints.
is_canal_sea :: proc(sea: Sea_ID) -> bool {
	// Compare adjacency with canals open vs closed
	return mm.s2s_1away_via_sea[0][sea] != mm.s2s_1away_via_sea[1][sea]
}

// ===== Territory Infrastructure Predicates =====
// These predicates check for factories, AA guns, and other infrastructure.

// MATCH-016: has_factory checks if territory has a factory (production capacity > 0).
// Factories are high-value targets and defensive priorities.
has_factory :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return gc.factory_prod[land] > 0
}

// MATCH-017: has_aa_gun checks if territory has at least one AA gun.
// AA guns provide defense against strategic bombing and air attacks.
has_aa_gun :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	for player in Player_ID {
		if gc.idle_armies[land][player][.AAGUN] > 0 {
			return true
		}
	}
	return false
}

// MATCH-018: is_coastal checks if land territory borders any sea zone.
// Coastal territories can be loaded from/unloaded to via transports.
is_coastal :: proc(land: Land_ID) -> bool {
	return sa.len(mm.l2s_1away_via_land[land]) > 0
}

// MATCH-019: can_produce_at checks if player can produce units at territory.
// Requires: owned factory, not conquered this turn (factory_prod > 0 implies not conquered).
can_produce_at :: proc(gc: ^Game_Cache, land: Land_ID, player: Player_ID) -> bool {
	return gc.owner[land] == player && gc.factory_prod[land] > 0
}

// MATCH-020: get_production_value returns IPC value of territory.
// This is the base production value from the map, not factory capacity.
get_production_value :: proc(land: Land_ID) -> u8 {
	return mm.value[land]
}

// ===== Neighbor Analysis Predicates =====
// These predicates analyze neighboring territories for strategic assessment.

// MATCH-021: has_enemy_neighbors checks if any adjacent land is enemy-owned.
// Territories with enemy neighbors are on the front line and need defense.
has_enemy_neighbors :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	cur_team := mm.team[gc.cur_player]
	for neighbor in sa.slice(&mm.l2l_1away_via_land[land]) {
		if mm.team[gc.owner[neighbor]] != cur_team {
			return true
		}
	}
	return false
}

// MATCH-022: has_allied_neighbors checks if any adjacent land is owned by ally (not self).
// Useful for finding reinforcement routes and coordination opportunities.
has_allied_neighbors :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	cur_team := mm.team[gc.cur_player]
	for neighbor in sa.slice(&mm.l2l_1away_via_land[land]) {
		owner := gc.owner[neighbor]
		if owner != gc.cur_player && mm.team[owner] == cur_team {
			return true
		}
	}
	return false
}

// ===== Unit Counting Predicates =====
// These predicates count units at locations for strength assessment.

// MATCH-023: count_enemy_units_at returns total enemy army units at a land territory.
// Counts all unit types (inf, arty, tank, aa) for all enemy players.
count_enemy_units_at :: proc(gc: ^Game_Cache, land: Land_ID) -> int {
	cur_team := mm.team[gc.cur_player]
	count := 0
	for player in Player_ID {
		if mm.team[player] != cur_team {
			for army in Idle_Army {
				count += int(gc.idle_armies[land][player][army])
			}
		}
	}
	return count
}

// MATCH-024: count_allied_units_at returns total allied army units at a land territory.
// Counts all unit types for current player and allies.
count_allied_units_at :: proc(gc: ^Game_Cache, land: Land_ID) -> int {
	cur_team := mm.team[gc.cur_player]
	count := 0
	for player in Player_ID {
		if mm.team[player] == cur_team {
			for army in Idle_Army {
				count += int(gc.idle_armies[land][player][army])
			}
		}
	}
	return count
}

// MATCH-025: is_capital checks if territory is any player's capital.
// Capitals have special significance for victory conditions and income capture.
is_capital :: proc(land: Land_ID) -> bool {
	for player in Player_ID {
		if mm.capital[player] == land {
			return true
		}
	}
	return false
}

// ===== Enemy Presence Predicates =====
// These predicates check for enemy units at various locations.

// MATCH-026: has_enemy_land_units checks if land territory has any enemy ground forces.
// Uses team_land_units for efficient O(1) lookup.
has_enemy_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	enemy_team := mm.enemy_team[gc.cur_player]
	return gc.team_land_units[land][enemy_team] > 0
}

// MATCH-027: has_allied_land_units checks if land territory has any allied ground forces.
// Includes current player's units.
has_allied_land_units :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	return gc.team_land_units[land][my_team] > 0
}

// MATCH-028: has_enemy_sea_units checks if sea zone has any enemy naval forces.
// Uses team_sea_units for efficient O(1) lookup.
has_enemy_sea_units :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	enemy_team := mm.enemy_team[gc.cur_player]
	return gc.team_sea_units[sea][enemy_team] > 0
}

// MATCH-029: has_allied_sea_units checks if sea zone has any allied naval forces.
// Includes current player's units.
has_allied_sea_units :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	return gc.team_sea_units[sea][my_team] > 0
}

// MATCH-030: is_contested_sea checks if sea zone has both allied and enemy units.
// Contested zones may require combat resolution.
is_contested_sea :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	enemy_team := mm.enemy_team[gc.cur_player]
	return gc.team_sea_units[sea][my_team] > 0 && gc.team_sea_units[sea][enemy_team] > 0
}

// ===== Capital Utilities =====
// These predicates work with player capitals.

// MATCH-031: get_player_capital returns the capital territory for a player.
// Returns the capital Land_ID from map data.
get_player_capital :: proc(player: Player_ID) -> Land_ID {
	return mm.capital[player]
}

// MATCH-032: is_own_capital checks if territory is current player's capital.
is_own_capital :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return mm.capital[gc.cur_player] == land
}

// MATCH-033: owns_capital checks if player currently owns their capital.
// Important for income collection and surrender conditions.
owns_capital :: proc(gc: ^Game_Cache, player: Player_ID) -> bool {
	return gc.owner[mm.capital[player]] == player
}

// ===== Distance Utilities =====
// These helpers provide distance-related information.

// MATCH-034: get_enemy_distance_to_land returns minimum distance from any enemy land to target.
// Returns 0 if enemy is at target, max_int if no path exists.
get_enemy_distance_to_land :: proc(gc: ^Game_Cache, target: Land_ID) -> int {
	cur_team := mm.team[gc.cur_player]
	min_dist := max(int)
	
	// Check each land territory for enemy ownership
	for land in Land_ID {
		if mm.team[gc.owner[land]] != cur_team {
			// This is enemy territory - calculate distance
			dist := get_land_distance(target, land)
			if dist < min_dist {
				min_dist = dist
			}
		}
	}
	return min_dist
}

// MATCH-035: get_land_distance returns BFS distance between two land territories.
// Returns max_int if no land path exists (islands).
get_land_distance :: proc(from: Land_ID, to: Land_ID) -> int {
	if from == to {
		return 0
	}
	
	// BFS through land connections
	visited: [Land_ID]bool
	queue: [128]Land_ID  // Fixed-size queue
	distances: [128]int
	front, back := 0, 0
	
	queue[back] = from
	distances[back] = 0
	back += 1
	visited[from] = true
	
	for front < back {
		current := queue[front]
		current_dist := distances[front]
		front += 1
		
		for neighbor in sa.slice(&mm.l2l_1away_via_land[current]) {
			if neighbor == to {
				return current_dist + 1
			}
			if !visited[neighbor] && back < 128 {
				visited[neighbor] = true
				queue[back] = neighbor
				distances[back] = current_dist + 1
				back += 1
			}
		}
	}
	
	return max(int)  // No path found
}

// ===== Neutral/Enemy Territory Predicates =====
// These predicates classify territory ownership states.

// MATCH-036: is_enemy_or_can_attack checks if territory is not friendly.
// Combines enemy check for attack targeting.
// Note: In A&A 1942 SE, all territories are player-owned (no neutral mechanic like newer games)
is_enemy_or_can_attack :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return mm.team[gc.owner[land]] != mm.team[gc.cur_player]
}

// MATCH-037: is_enemy_not_allied checks if territory is enemy-owned.
// For targeting player-owned enemy territories specifically.
is_enemy_not_allied :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return mm.team[gc.owner[land]] != mm.team[gc.cur_player]
}

// ===== Factory Predicates =====
// These predicates analyze factory status and bombing targets.

// MATCH-039: get_factory_capacity returns production capacity of territory.
// Returns 0 if no factory or factory is destroyed.
get_factory_capacity :: proc(gc: ^Game_Cache, land: Land_ID) -> u8 {
	return gc.factory_prod[land]
}

// MATCH-040: has_bombable_factory checks if territory can be strategically bombed.
// Territory must have factory and be enemy-owned.
has_bombable_factory :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	if gc.factory_prod[land] == 0 {
		return false
	}
	owner := gc.owner[land]
	return mm.team[owner] != mm.team[gc.cur_player]
}

// MATCH-041: is_factory_damaged checks if factory has any damage.
is_factory_damaged :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return gc.factory_dmg[land] > 0
}

// MATCH-042: get_factory_damage returns current damage on factory.
get_factory_damage :: proc(gc: ^Game_Cache, land: Land_ID) -> u8 {
	return gc.factory_dmg[land]
}

// MATCH-043: can_build_units checks if player can build units at territory.
// Must own factory with remaining build capacity.
can_build_units :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	return gc.owner[land] == gc.cur_player && gc.builds_left[land] > 0
}

// MATCH-044: get_builds_left returns remaining production at territory.
get_builds_left :: proc(gc: ^Game_Cache, land: Land_ID) -> u8 {
	return gc.builds_left[land]
}

// ===== Sea Zone Factory Adjacency =====
// These predicates check factory-sea relationships.

// MATCH-045: is_adjacent_to_owned_factory checks if sea zone is next to owned factory.
// Important for naval production placement.
is_adjacent_to_owned_factory :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	for land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
		if gc.owner[land] == gc.cur_player && gc.factory_prod[land] > 0 {
			return true
		}
	}
	return false
}

// MATCH-046: is_adjacent_to_allied_factory checks if sea zone is next to any allied factory.
is_adjacent_to_allied_factory :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	for land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
		if mm.team[gc.owner[land]] == my_team && gc.factory_prod[land] > 0 {
			return true
		}
	}
	return false
}

// MATCH-046: is_adjacent_to_enemy_factory checks if sea zone is next to enemy factory.
is_adjacent_to_enemy_factory :: proc(gc: ^Game_Cache, sea: Sea_ID) -> bool {
	my_team := mm.team[gc.cur_player]
	for land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
		owner := gc.owner[land]
		if mm.team[owner] != my_team && gc.factory_prod[land] > 0 {
			return true
		}
	}
	return false
}

// ===== Naval Unit Counting =====
// These helpers count specific ship types at sea zones.
// Note: count_transports_at_sea is defined in pro_noncombat_move.odin

// MATCH-047: count_empty_transports_at_sea returns empty transports at sea zone.
count_empty_transports_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	return int(gc.idle_ships[sea][player][.TRANS_EMPTY])
}

// MATCH-048: count_loaded_transports_at_sea returns loaded transports at sea zone.
count_loaded_transports_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	count := 0
	count += int(gc.idle_ships[sea][player][.TRANS_1I])
	count += int(gc.idle_ships[sea][player][.TRANS_1A])
	count += int(gc.idle_ships[sea][player][.TRANS_1T])
	count += int(gc.idle_ships[sea][player][.TRANS_2I])
	count += int(gc.idle_ships[sea][player][.TRANS_1I_1A])
	count += int(gc.idle_ships[sea][player][.TRANS_1I_1T])
	return count
}

// MATCH-049: count_combat_ships_at_sea returns warships (not transports) at sea zone.
count_combat_ships_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	count := 0
	count += int(gc.idle_ships[sea][player][.SUB])
	count += int(gc.idle_ships[sea][player][.DESTROYER])
	count += int(gc.idle_ships[sea][player][.CARRIER])
	count += int(gc.idle_ships[sea][player][.CRUISER])
	count += int(gc.idle_ships[sea][player][.BATTLESHIP])
	count += int(gc.idle_ships[sea][player][.BS_DAMAGED])
	return count
}

// MATCH-050: has_destroyer checks if player has destroyer at sea zone.
// Destroyers are essential for attacking submarines.
has_destroyer :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	return gc.idle_ships[sea][player][.DESTROYER] > 0
}

// MATCH-051: has_carrier checks if player has carrier at sea zone.
has_carrier :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	return gc.idle_ships[sea][player][.CARRIER] > 0
}

// MATCH-052: has_submarine checks if player has submarine at sea zone.
has_submarine :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	return gc.idle_ships[sea][player][.SUB] > 0
}

// MATCH-053: count_carriers_at_sea returns carrier count at sea zone.
count_carriers_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	return int(gc.idle_ships[sea][player][.CARRIER])
}

// MATCH-054: get_carrier_capacity returns total fighter capacity at sea zone.
// Each carrier holds 2 fighters.
get_carrier_capacity :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	return int(gc.idle_ships[sea][player][.CARRIER]) * 2
}

// ===== Bombardment Predicates =====
// These predicates check for shore bombardment capability.

// MATCH-055: has_bombard_ships checks if player has cruisers or battleships at sea zone.
// These ships can provide shore bombardment for amphibious assaults.
has_bombard_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> bool {
	return gc.idle_ships[sea][player][.CRUISER] > 0 ||
	       gc.idle_ships[sea][player][.BATTLESHIP] > 0 ||
	       gc.idle_ships[sea][player][.BS_DAMAGED] > 0
}

// MATCH-056: count_bombard_ships returns total bombardment-capable ships.
count_bombard_ships :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	count := 0
	count += int(gc.idle_ships[sea][player][.CRUISER])
	count += int(gc.idle_ships[sea][player][.BATTLESHIP])
	count += int(gc.idle_ships[sea][player][.BS_DAMAGED])
	return count
}

// MATCH-057: get_bombard_power returns total bombardment attack power at sea zone.
// Cruiser=3, Battleship=4
get_bombard_power :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	power := 0
	power += int(gc.idle_ships[sea][player][.CRUISER]) * 3     // Cruiser attack 3
	power += int(gc.idle_ships[sea][player][.BATTLESHIP]) * 4  // Battleship attack 4
	power += int(gc.idle_ships[sea][player][.BS_DAMAGED]) * 4  // Damaged BB still attack 4
	return power
}

// ===== Air Unit Predicates =====
// These predicates work with air units.

// MATCH-058: count_fighters_at_land returns fighters at land territory for player.
count_fighters_at_land :: proc(gc: ^Game_Cache, land: Land_ID, player: Player_ID) -> int {
	return int(gc.idle_land_planes[land][player][.FIGHTER])
}

// MATCH-059: count_bombers_at_land returns bombers at land territory for player.
count_bombers_at_land :: proc(gc: ^Game_Cache, land: Land_ID, player: Player_ID) -> int {
	return int(gc.idle_land_planes[land][player][.BOMBER])
}

// MATCH-060: count_fighters_at_sea returns fighters at sea zone for player.
count_fighters_at_sea :: proc(gc: ^Game_Cache, sea: Sea_ID, player: Player_ID) -> int {
	return int(gc.idle_sea_planes[sea][player][.FIGHTER])
}

// MATCH-061: has_enemy_fighters_in_range checks if enemy fighters can reach land territory.
// Uses cached bitset to check territories within fighter range (4 moves).
has_enemy_fighters_in_range :: proc(gc: ^Game_Cache, target: Land_ID) -> bool {
	enemy_team := mm.enemy_team[gc.cur_player]
	target_air := to_air(target)
	
	// Check all land territories for enemy fighters within range
	for land in Land_ID {
		air_id := to_air(land)
		// Check if this air territory can reach target in 4 moves
		if target_air in mm.a2a_within_4_moves[air_id] {
			for player in Player_ID {
				if mm.team[player] == enemy_team {
					if gc.idle_land_planes[land][player][.FIGHTER] > 0 {
						return true
					}
				}
			}
		}
	}
	// Also check sea-based fighters on carriers
	for sea in Sea_ID {
		air_id := to_air_from_sea(sea)
		if target_air in mm.a2a_within_4_moves[air_id] {
			for player in Player_ID {
				if mm.team[player] == enemy_team {
					if gc.idle_sea_planes[sea][player][.FIGHTER] > 0 {
						return true
					}
				}
			}
		}
	}
	return false
}

// ===== Territory Value Helpers =====
// These helpers provide territory value information.

// MATCH-062: get_territory_value returns base IPC value of territory.
get_territory_value :: proc(land: Land_ID) -> int {
	return int(mm.value[land])
}

// MATCH-063: get_total_adjacent_land_value returns sum of IPC values of adjacent lands.
get_total_adjacent_land_value :: proc(land: Land_ID) -> int {
	total := 0
	for neighbor in sa.slice(&mm.l2l_1away_via_land[land]) {
		total += int(mm.value[neighbor])
	}
	return total
}

// MATCH-064: get_total_adjacent_sea_land_value returns sum of land values touching a sea zone.
get_total_adjacent_sea_land_value :: proc(sea: Sea_ID) -> int {
	total := 0
	for land in sa.slice(&mm.s2l_1away_via_sea[sea]) {
		total += int(mm.value[land])
	}
	return total
}

// ===== Movement Validation Helpers =====
// These predicates help with movement validation.

// MATCH-065: can_land_move_through checks if land unit can move through territory.
// Must be friendly (owned by self or ally) or empty enemy.
can_land_move_through :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	owner := gc.owner[land]
	if mm.team[owner] == mm.team[gc.cur_player] {
		return true  // Friendly territory
	}
	// Enemy territory - can only move through if empty (blitz)
	return gc.team_land_units[land][mm.enemy_team[gc.cur_player]] == 0
}

// MATCH-066: can_sea_move_through checks if sea unit can move through sea zone.
// Can move through if no enemy combat ships (subs can sneak).
can_sea_move_through :: proc(gc: ^Game_Cache, sea: Sea_ID, has_destroyer: bool) -> bool {
	enemy_team := mm.enemy_team[gc.cur_player]
	enemy_units := gc.team_sea_units[sea][enemy_team]
	if enemy_units == 0 {
		return true
	}
	// If we have destroyer, enemy subs don't block
	// For simplicity, if any enemy units, consider blocked (conservative)
	return false
}

// MATCH-067: is_blitzable checks if territory can be blitzed through.
// Must be enemy with no units and have tank or mech to blitz.
is_blitzable :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	owner := gc.owner[land]
	// Can't blitz friendly territory
	if mm.team[owner] == mm.team[gc.cur_player] {
		return false
	}
	// Enemy territory - blitzable if no units
	return gc.team_land_units[land][mm.enemy_team[gc.cur_player]] == 0
}

// ===== Combat Helpers =====
// These predicates help with combat decisions.

// MATCH-068: has_aa_threat checks if territory has AA guns that threaten air.
has_aa_threat :: proc(gc: ^Game_Cache, land: Land_ID) -> bool {
	// AA guns belong to the territory owner's team
	owner := gc.owner[land]
	if mm.team[owner] == mm.team[gc.cur_player] {
		return false  // Friendly AA doesn't shoot our planes
	}
	return has_aa_gun(gc, land)
}

// MATCH-069: count_aa_guns_at returns number of AA guns at territory.
count_aa_guns_at :: proc(gc: ^Game_Cache, land: Land_ID) -> int {
	count := 0
	for player in Player_ID {
		count += int(gc.idle_armies[land][player][.AAGUN])
	}
	return count
}

// MATCH-070: get_defense_power_at_land returns total defense power at territory.
// Sums defense values of all defending units.
get_defense_power_at_land :: proc(gc: ^Game_Cache, land: Land_ID) -> int {
	power := 0
	owner := gc.owner[land]
	owner_team := mm.team[owner]
	
	// Count army defense
	for player in Player_ID {
		if mm.team[player] == owner_team {
			power += int(gc.idle_armies[land][player][.INF]) * 2   // Infantry defense 2
			power += int(gc.idle_armies[land][player][.ARTY]) * 2  // Artillery defense 2
			power += int(gc.idle_armies[land][player][.TANK]) * 3  // Tank defense 3
		}
	}
	
	// Count air defense (fighters and bombers on land)
	for player in Player_ID {
		if mm.team[player] == owner_team {
			power += int(gc.idle_land_planes[land][player][.FIGHTER]) * 4  // Fighter defense 4
			power += int(gc.idle_land_planes[land][player][.BOMBER]) * 1   // Bomber defense 1
		}
	}
	
	return power
}

// MATCH-071: get_attack_power_at_land returns total attack power at territory.
// Sums attack values of all units that could attack from this territory.
get_attack_power_at_land :: proc(gc: ^Game_Cache, land: Land_ID, player: Player_ID) -> int {
	power := 0
	
	// Count army attack
	power += int(gc.idle_armies[land][player][.INF]) * 1   // Infantry attack 1
	power += int(gc.idle_armies[land][player][.ARTY]) * 2  // Artillery attack 2
	power += int(gc.idle_armies[land][player][.TANK]) * 3  // Tank attack 3
	
	// Count air attack (fighters and bombers on land)
	power += int(gc.idle_land_planes[land][player][.FIGHTER]) * 3  // Fighter attack 3
	power += int(gc.idle_land_planes[land][player][.BOMBER]) * 4   // Bomber attack 4
	
	return power
}

