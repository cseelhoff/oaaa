package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"

MAX_LAND_MASS_SIZE :: 49


// get_pro_value :: #force_inline proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
// 	production := gc.factory_prod[territory]
// 	return(
// 		math.sqrt(f64(production) + math.sqrt(f64(production))) *
// 		32 *
// 		(1.0 + f64(mm.l2l_1away_via_land[territory].len)) /
// 		f64(MAX_LAND_TO_LAND_CONNECTIONS) \
// 	)
// }

// build_map_production_value :: proc(gc: ^Game_Cache) {
// 	for land in Land_ID {
// 		if gc.factory_prod[land] == 0 do continue
// 		gc.pro_value[land] = get_pro_value(gc, land)
// 	}
// 	for land in Land_ID {
// 		land_mass_multiplier := f64(mm.land_mass_size[land]) / f64(MAX_LAND_MASS_SIZE)
// 		for valuable_land in Land_ID {
// 			if land == valuable_land do continue
// 			gc.pro_value[land] = max(
// 				gc.pro_value[land],
// 				land_mass_multiplier *
// 				gc.pro_value[valuable_land] /
// 				math.pow(2, f64(mm.air_distances[to_air(land)][to_air(valuable_land)])),
// 			)
// 		}
// 	}
// }

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
	enemy_capitals_and_factories_map: map[Land_ID]f64 = map[Land_ID]f64{}
	for t in enemy_capitals_and_factories_map {
		// Get factory production if factory
		factory_production := gc.factory_prod[t]

		// Get player production if capital
		player_production :f64= 0
		for player in Player_ID {
			if mm.capital[player] == t {
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
	// slice.reverse_sort(values[:])
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
			value := f64(gc.factory_prod[nearby_enemy_territory])
			if nearby_enemy_territory in gc.friendly_owner {
				neighbors := mm.l2l_1away_via_land_bitset[nearby_enemy_territory]
				enemy_neighbors := neighbors & ~gc.friendly_owner
				if enemy_neighbors == {} {
					value *= 0.1 // reduce value for can't hold amphib allied territories
				}
			}
			if (value > 0) {
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
