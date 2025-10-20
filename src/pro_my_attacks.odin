package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:math"
import "core:slice"

generate_my_attack_options :: proc(gc: ^Game_Cache, my_territory_targets: ^[Air_ID]Territory_Target) {

	air_array: Air_ID_Array
	refresh_can_fighter_land_here(gc)
	refresh_can_bomber_land_here(gc)

	// Process fighters
	for src_land in Land_ID {
		gc.current_territory = to_air(src_land)
		if gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_fighter_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {
				// check if dst is land or sea
				if is_land(dst) {
					dst_land := to_land(dst)
					// there has to either be value in conquering the land or TUV swing
					if mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] ||
					   gc.team_land_units[dst_land][mm.enemy_team[gc.cur_player]] == 0 {
						continue
					}
					my_territory_targets[dst].Fighters +=
						gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
				} else {
					dst_sea := to_sea(dst)
					if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] == 0 {
						continue
					}
					my_territory_targets[dst].Fighters +=
						gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
				}
			}
		}
		if gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
			get_airs(get_valid_unmoved_bomber_moves(gc), &air_array)
			for dst in sa.slice(&air_array) {

				if is_land(dst) {
					dst_land := to_land(dst)
					if mm.team[gc.owner[dst_land]] == mm.team[gc.cur_player] ||
					   (gc.team_land_units[dst_land][mm.enemy_team[gc.cur_player]] == 0 &&
							   gc.factory_prod[dst_land] > gc.factory_dmg[dst_land]) {
						continue
					}
					my_territory_targets[dst].Bombers +=
						gc.active_land_planes[src_land][.BOMBER_UNMOVED]
				} else {
					dst_sea := to_sea(dst)
					if gc.team_sea_units[dst_sea][mm.enemy_team[gc.cur_player]] == 0 {
						continue
					}
					my_territory_targets[dst].Bombers +=
						gc.active_land_planes[src_land][.BOMBER_UNMOVED]
				}
			}
		}
		for dst in mm.l2l_1away_via_land_bitset[src_land] {
			if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] ||
			   gc.team_land_units[dst][mm.enemy_team[gc.cur_player]] == 0 {
				continue
			}
			my_territory_targets[to_air(dst)].Infantry += gc.active_armies[src_land][.INF_1_MOVES]
			my_territory_targets[to_air(dst)].Artillery += gc.active_armies[src_land][.ARTY_1_MOVES]
			my_territory_targets[to_air(dst)].Tanks += gc.active_armies[src_land][.TANK_2_MOVES]
		}
		for dst in mm.l2l_2away_via_land_bitset[src_land] {
			if mm.team[gc.owner[dst]] == mm.team[gc.cur_player] ||
			   gc.team_land_units[dst][mm.enemy_team[gc.cur_player]] == 0 {
				continue
			}
			// if all midlands between src and dst have enemy factory or units, skip
			if (mm.l2l_2away_via_midland_bitset[src_land][dst] &
				   ~gc.has_enemy_factory &
				   ~gc.has_enemy_armies) ==
			   {} {
				continue
			}
			my_territory_targets[to_air(dst)].Tanks += gc.active_armies[src_land][.TANK_2_MOVES]
		}
	}
}

prioritize_my_attack_options :: proc(
	gc: ^Game_Cache,
    my_territory_targets: ^[Air_ID]Territory_Target,
	options: ^[dynamic]Attack_Option) {
    // options := make([dynamic]Attack_Option, context.temp_allocator)

	for land_territory in Land_ID {		
		territory := land_to_air(land_territory)
        if my_territory_targets[territory].Infantry == 0 &&
           my_territory_targets[territory].Artillery == 0 &&
           my_territory_targets[territory].Tanks == 0 &&
           my_territory_targets[territory].Fighters == 0 &&
           my_territory_targets[territory].Bombers == 0 {
            continue
        }
		//check if units are placeable here
		// if gc.factory_prod[land_territory] == 0 do continue
		
		land_combatants :Land_Combatants = {}
		
        land_combatants.attackers[0].Infantry += my_territory_targets[territory].Infantry
        land_combatants.attackers[0].Artillery += my_territory_targets[territory].Artillery
        land_combatants.attackers[0].Tanks += my_territory_targets[territory].Tanks
        land_combatants.attackers[0].Fighters += my_territory_targets[territory].Fighters
        land_combatants.attackers[0].Bombers += my_territory_targets[territory].Bombers

		fmt.println("    Possible My Target Territory:", territory)
		hold_value := 0.0
		//calculate battle result
		land_defenders: Land_Defenders = {}
		for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
			land_combatants.defenders.Infantry += gc.idle_armies[land_territory][enemy][.INF]
			land_combatants.defenders.Artillery += gc.idle_armies[land_territory][enemy][.ARTY]
			land_combatants.defenders.AntiAir += gc.idle_armies[land_territory][enemy][.AAGUN]
			land_combatants.defenders.Tanks += gc.idle_armies[land_territory][enemy][.TANK]
			land_combatants.defenders.Fighters += gc.idle_land_planes[land_territory][enemy][.FIGHTER]
			land_combatants.defenders.Bombers += gc.idle_land_planes[land_territory][enemy][.BOMBER]
		}
		results: Battle_Results = simulate_battle(land_combatants)
		fmt.println("    Battle Results: ", results.avg_TUV_swing, ", ", results.invaded_percent)

		// Skip territories that are not sufficiently threatened
		if(results.invaded_percent < 1.0 - win_percentage_needed) do continue


        // Calculate value of attacking territory
        // for i := len(options) - 1; i >= 0; i -= 1 {
            // option := &options[i]
        option : Attack_Option = {}
        // territory := option.territory
        option.territory = land_territory
        option.win_percentage = results.invaded_percent
        
        // Determine territory attack properties
        is_land := 1 //!is_water_territory(territory) ? 1 : 0
        // is_neutral := false //is_neutral_land(gc, territory) ? 1 : 0
        is_can_hold := option.can_hold ? 1 : 0
        is_amphib := option.is_amphib ? 1 : 0
        
        // Count non-infantry defenders
        defending_units := count_non_infantry_defenders(&option)
		is_empty_land := (is_land == 1 && defending_units == 0 && !option.is_amphib) ? 1 : 0

        // Check if adjacent to capital
        is_adjacent_to_capital := land_territory in mm.l2l_1away_via_land_bitset[mm.capital[gc.cur_player]] //is_adjacent_to_my_capital(gc, land_territory)
        is_not_neutral_adj_capital := is_adjacent_to_capital ? 1 : 0 //(is_adjacent_to_capital && !is_neutral_land(gc, territory)) ? 1 : 0
        
        // Check for factory
        is_factory := gc.factory_prod[land_territory] > 0 ? 1 : 0
        
        // Check if FFA mode (more than 2 teams)
        is_ffa := 0 //is_free_for_all(gc) ? 1 : 0
        
        // Get production value and capital status
        is_capital := mm.capital[gc.cur_player] == land_territory
        production := gc.factory_prod[land_territory]
        // production, is_capital := get_production_and_is_capital_triplea(gc, territory)
        
        // Calculate attack value for prioritization
        option.tuv_swing = results.avg_TUV_swing
        tuv_swing := option.tuv_swing
        // if is_ffa == 1 && tuv_swing > 0 {
        //     tuv_swing *= 0.5
        // }
        
        territory_value := f64(1 + is_land + is_can_hold * (1 + 2 * is_ffa * is_land)) *
            f64(1 + is_empty_land) * f64(1 + is_factory) * (1 - 0.5 * f64(is_amphib)) * f64(production)
        
        is_capital_value := is_capital ? 1.0 : 0.0
        is_neutral_value := 0.0
        attack_value := (tuv_swing + territory_value) * (1 + 4.0 * is_capital_value) *
            (1 + 2.0 * f64(is_not_neutral_adj_capital))
        
        // Remove negative value territories
        option.attack_value = attack_value
        fmt.println("    Attack Value: ", attack_value)

        if attack_value <= 0 {
            continue
        }
        option.avg_survivor_def_power = results.avg_survivor_def_power
        append(options, option)
    }
        
    // Sort attack territories by value (highest first)
    slice.sort_by(options[:], proc(a, b: Attack_Option) -> bool {
        return a.attack_value > b.attack_value
    })
}
