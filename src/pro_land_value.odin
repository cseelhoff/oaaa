package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"

get_pro_value :: #force_inline proc(gc: ^Game_Cache, territory: Land_ID) -> f64 {
	production := gc.factory_prod[territory]
	return(
		math.sqrt(f64(production) + math.sqrt(f64(production))) *
		32 *
		(1.0 + f64(mm.l2l_1away_via_land[territory].len)) /
		f64(MAX_LAND_TO_LAND_CONNECTIONS) \
	)
}

build_map_production_value :: proc(gc: ^Game_Cache) {
	for land in Land_ID {
		if gc.factory_prod[land] == 0 do continue
		gc.pro_value[land] = get_pro_value(gc, land)
	}
	for land in Land_ID {
		land_mass_multiplier :=
			(1.0 + f64(mm.l2l_1away_via_land[land].len)) / f64(MAX_LAND_TO_LAND_CONNECTIONS)
		for valuable_land in Land_ID {
			if land == valuable_land do continue
			gc.pro_value[land] = max(
				gc.pro_value[land],
				land_mass_multiplier *
				gc.pro_value[valuable_land] /
				math.pow(2, f64(mm.air_distances[land_to_air(land)][land_to_air(valuable_land)])),
			)
		}
	}
}
