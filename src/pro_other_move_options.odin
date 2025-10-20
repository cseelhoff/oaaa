package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

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
