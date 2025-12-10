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

