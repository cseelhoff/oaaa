package oaaa

import "core:fmt"
import "core:math"
import "core:slice"

// Find all valid landing options for an air unit
find_air_landing_options :: proc(
	gc: ^Game_Cache,
	pro_data: ^Pro_Data,
	air_unit: ^Air_Unit_To_Land,
	territories_cant_hold: [dynamic]Land_ID,
) {
	/*
	From ProNonCombatMoveAi.java:
	
	for (final Territory t : unitMoveMap.get(u)) {
		final ProTerritory proTerritory = moveMap.get(t);
		if (!proTerritory.isCanHold()) {
			continue;
		}
		if (t.isWater()
			&& !ProTransportUtils.validateCarrierCapacity(
				player, t, proTerritory.getAllDefendersForCarrierCalcs(data, player), u)) {
			ProLogger.trace(t + " already at MAX carrier capacity");
			continue;
		}
		...
	}
	*/
	valid_landings :Air_Bitset= {}
	territory := air_unit.current_location
	air_location := to_air(territory)

	// Handle fighters
	if air_unit.active_plane_type == .FIGHTER_1_MOVES {
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		valid_landings = gc.can_fighter_land_here & mm.a2a_within_1_moves[air_location]
	} else if air_unit.active_plane_type == .FIGHTER_2_MOVES {
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		valid_landings = gc.can_fighter_land_here & mm.a2a_within_2_moves[air_location]
	} else if air_unit.active_plane_type == .FIGHTER_3_MOVES {
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		valid_landings = gc.can_fighter_land_here & mm.a2a_within_3_moves[air_location]
	} else if air_unit.active_plane_type == .FIGHTER_4_MOVES {
		if !gc.is_fighter_cache_current do refresh_can_fighter_land_here(gc)
		valid_landings = gc.can_fighter_land_here & mm.a2a_within_4_moves[air_location]
	// Handle bombers
	} else if air_unit.active_plane_type == .BOMBER_1_MOVES {
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		valid_landings = to_air_bitset(gc.can_bomber_land_here) & mm.a2a_within_1_moves[air_location]
	} else if air_unit.active_plane_type == .BOMBER_2_MOVES {
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		valid_landings = to_air_bitset(gc.can_bomber_land_here) & mm.a2a_within_2_moves[air_location]
	} else if air_unit.active_plane_type == .BOMBER_3_MOVES {
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		valid_landings = to_air_bitset(gc.can_bomber_land_here) & mm.a2a_within_3_moves[air_location]
	} else if air_unit.active_plane_type == .BOMBER_4_MOVES {
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		valid_landings = to_air_bitset(gc.can_bomber_land_here) & mm.a2a_within_4_moves[air_location]
	} else if air_unit.active_plane_type == .BOMBER_5_MOVES {
		if !gc.is_bomber_cache_current do refresh_can_bomber_land_here(gc)
		valid_landings = to_air_bitset(gc.can_bomber_land_here) & mm.a2a_within_5_moves[air_location]
	}
    sa_valid_landings: Air_ID_Array = {}
    get_airs(valid_landings, &sa_valid_landings)
	for air_id in sa_valid_landings[:] {
		option := Air_Landing_Option{
			territory = air_id,
			is_water = false,
		}
        if(is_air_land(air_id)) {
            dest_land := to_land(air_id)
            is_allied := gc.owner[dest_land] != gc.cur_player
            option.is_allied = is_allied
            if is_allied {
                has_factory := gc.factory_prod[dest_land] > 0
                if !has_factory {
                    continue
                }
            } else {
                option.has_factory = gc.factory_prod[dest_land] > 0
            }
            // Calculate if territory can be held
            option.can_hold = calculate_can_hold_with_air_unit(gc, pro_data, air_id, air_unit.plane_type)
            
            // Calculate safety metrics
            option.enemy_threat = calculate_enemy_threat(gc, air_id, pro_data)
            option.current_defense = calculate_current_defense(gc, air_id)
            
            // Calculate battle results
            calculate_air_landing_battle_results(gc, pro_data, &option, air_unit.plane_type)
            
            // Calculate attack potential from this location
            calculate_air_attack_potential(gc, pro_data, &option, air_unit, territories_cant_hold)
            
            // Calculate overall air value
            calculate_air_value(&option)

            option.is_capital = mm.capital[gc.owner[territory]] == territory
            append(&air_unit.options, option)
        } else {
            // TODO carrier land
        }
	}
	
}