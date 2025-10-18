package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

populate_enemy_attack_options :: proc(
	gc: ^Game_Cache,
	cleared_territories: Land_Bitset,
	territories_to_check: Land_Bitset,
	enemy_attack_options: ^Pro_Other_Move_Options,
) {
	find_enemy_attack_options(
		gc,
		gc.cur_player,
		cleared_territories,
		territories_to_check,
		enemy_attack_options,
	)
}

find_enemy_attack_options :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
	cleared_territories: Land_Bitset,
	territories_to_check: Land_Bitset,
	enemy_attack_options: ^Pro_Other_Move_Options,
) {
	enemy_attack_maps: [Player_ID]map[Air_ID]Pro_Territory = {}
	allied_territories: Land_Bitset = {}
	enemy_territories: Land_Bitset = cleared_territories

	// Loop through each enemy to determine the maximum number of enemy units that can attack each
	// territory
	for enemy_player in sa.slice(&mm.enemies[gc.cur_player]) {
		enemy_unit_territories_land := gc.has_enemy_units
		enemy_unit_territories_sea := gc.has_enemy_ships
		attack_map := map[Air_ID]Pro_Territory{}
		enemy_attack_maps[enemy_player] = attack_map
		find_attack_options(
			gc,
			enemy_player,
			enemy_unit_territories_land,
			enemy_unit_territories_sea,
			attack_map,
			territories_to_check,
		)
		for air_id in attack_map {
			if !is_land(air_id) do continue
			allied_territories += {to_land(air_id)}
		}
		// allied_territories += air_bitset_to_land_bitset(attack_map)
		enemy_territories -= allied_territories
	}
	set_max_move_map(gc, enemy_attack_options, &enemy_attack_maps, player, true)
	set_move_maps(gc, enemy_attack_options, &enemy_attack_maps)
}

set_max_move_map :: proc(
	gc: ^Game_Cache,
	enemy_attack_options: ^Pro_Other_Move_Options,
	enemy_attack_maps: ^[Player_ID]map[Air_ID]Pro_Territory,
	player: Player_ID,
	is_attacker: bool,
) {
	//   private static Map<Territory, ProTerritory> newMaxMoveMap(
	//       final List<Map<Territory, ProTerritory>> moveMaps,
	//       final GamePlayer player,
	//       final boolean isAttacker) {

	//     final Map<Territory, ProTerritory> result = new HashMap<>();
	//     final List<GamePlayer> players = ProUtils.getOtherPlayersInTurnOrder(player);
	//     for (final Map<Territory, ProTerritory> moveMap : moveMaps) {
	//       for (final Territory t : moveMap.keySet()) {
	//         final ProTerritory proTerritory = moveMap.get(t);
	//         // Get current player
	//         final Set<Unit> currentUnits = new HashSet<>(proTerritory.getMaxUnits());
	//         currentUnits.addAll(proTerritory.getMaxAmphibUnits());
	//         if (currentUnits.isEmpty()) {
	//           continue;
	//         }
	//         final GamePlayer movePlayer = CollectionUtils.getAny(currentUnits).getOwner();
	//         // Skip if checking allied moves and their turn doesn't come before territory owner's
	//         if (player.isAllied(movePlayer)
	//             && !ProUtils.isPlayersTurnFirst(players, movePlayer, t.getOwner())) {
	//           continue;
	//         }

	//         // Add to max move map if its empty or its strength is greater than existing
	//         if (!result.containsKey(t)) {
	//           result.put(t, proTerritory);
	//         } else {
	//           final ProTerritory proResult = result.get(t);
	//           final Set<Unit> maxUnits = new HashSet<>(proResult.getMaxUnits());
	//           maxUnits.addAll(proResult.getMaxAmphibUnits());
	//           double maxStrength = 0;
	//           if (!maxUnits.isEmpty()) {
	//             maxStrength = ProBattleUtils.estimateStrength(t, maxUnits, List.of(), isAttacker);
	//           }
	//           final double currentStrength =
	//               ProBattleUtils.estimateStrength(t, currentUnits, List.of(), isAttacker);
	//           final boolean currentHasLandUnits = currentUnits.stream().anyMatch(Matches.unitIsLand());
	//           final boolean maxHasLandUnits = maxUnits.stream().anyMatch(Matches.unitIsLand());
	//           if ((currentHasLandUnits
	//                   && ((!maxHasLandUnits && !t.isWater()) || currentStrength > maxStrength))
	//               || ((!maxHasLandUnits || t.isWater()) && currentStrength > maxStrength)) {
	//             result.put(t, proTerritory);
	//           }
	//         }
	//       }
	//     }
	//     return result;
}

set_move_maps :: proc(
	gc: ^Game_Cache,
	enemy_attack_options: ^Pro_Other_Move_Options,
	enemy_attack_maps: ^[Player_ID]map[Air_ID]Pro_Territory,
) {
	// private static Map<Territory, List<ProTerritory>> newMoveMaps(
	//       final List<Map<Territory, ProTerritory>> moveMapList) {
	//     final Map<Territory, List<ProTerritory>> result = new HashMap<>();
	//     for (final Map<Territory, ProTerritory> moveMap : moveMapList) {
	//       for (final Territory t : moveMap.keySet()) {
	//         result.computeIfAbsent(t, key -> new ArrayList<>()).add(moveMap.get(t));
	//       }
	//     }
	//     return result;
	//   }
}

find_attack_options :: proc(
	gc: ^Game_Cache,
	enemy_player: Player_ID,
	enemy_unit_territories_land: Land_Bitset,
	enemy_unit_territories_sea: Sea_Bitset,
	attack_map: map[Air_ID]Pro_Territory,
	territories_to_check: Land_Bitset,
) {
	land_routes_map: map[Land_ID]Land_Bitset = {}
	territories_that_cant_be_held: Land_Bitset = territories_to_check
	find_naval_move_options(
		gc,
		enemy_player,
		enemy_unit_territories_sea,
		attack_map,
		territories_that_cant_be_held,
	)
	find_land_move_options(
		gc,
		enemy_player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_air_move_options(
		gc,
		enemy_player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_amphib_move_options(
		gc,
		enemy_player,
		enemy_unit_territories_land,
		land_routes_map,
		attack_map,
		territories_that_cant_be_held,
	)
	find_bombard_options(
		gc,
		enemy_player,
		enemy_unit_territories_sea,
		attack_map,
		territories_that_cant_be_held,
	)
}

find_naval_move_options :: proc(gc: ^Game_Cache,
	enemy_player: Player_ID,
	enemy_unit_territories_sea: Sea_Bitset,
	attack_map: map[Air_ID]Pro_Territory,
	territories_that_cant_be_held: Land_Bitset,
) -> (ok: bool) {
	// Implementation goes here
	return true
}