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

