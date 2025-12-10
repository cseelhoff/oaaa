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

