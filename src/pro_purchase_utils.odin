package oaaa
import sa "core:container/small_array"
import "core:fmt"
import "core:slice"

find_purchase_territories_triplea :: proc(
	gc: ^Game_Cache,
	player: Player_ID,
) -> map[Land_ID]Pro_Purchase_Territory {
    if ODIN_DEBUG {
        fmt.println("Find all purchase territories")
    }
	territories := make(map[Land_ID]Pro_Purchase_Territory)
	for factory_loc in sa.slice(&gc.factory_locations[player]) {
		territories[factory_loc] = Pro_Purchase_Territory {
			territory             = factory_loc,
			can_place_land        = true,
			unit_production       = gc.factory_prod[factory_loc],
			can_place_territories = {factory_loc},
		}
	}
	return territories
}
