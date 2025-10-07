package oaaa

import sa "core:container/small_array"
import "core:fmt"
import "core:math"


generate_enemy_attack_options :: proc(gc: ^Game_Cache, enemy_attack_options: ^[Player_ID][Air_ID]Territory_Target) {
	//loop through enemies
	enemy_gc := gc^
    air_array: Air_ID_Array
	for enemy in sa.slice(&mm.enemies[gc.cur_player]) {
		enemy_gc.cur_player = enemy
		rotate_turns_reset(&enemy_gc)
		refresh_can_fighter_land_here(&enemy_gc)
		refresh_can_bomber_land_here(&enemy_gc)

		// Process fighters
		for src_land in Land_ID {
			enemy_gc.current_territory = to_air(src_land)
			if enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED] > 0 {
                get_airs(get_valid_unmoved_fighter_moves(&enemy_gc), &air_array)
				for dst in sa.slice(&air_array) {
                    // check if dst is land or sea
                    if is_land(dst) {
                        dst_land := to_land(dst)
                        // not concerned with land thats not mine and if I have no troops there to lose
                        if gc.owner[dst_land] != gc.cur_player &&
                        gc.active_armies[dst_land][.INF_1_MOVES] == 0 &&
                        gc.active_armies[dst_land][.ARTY_1_MOVES] == 0 &&
                        gc.active_armies[dst_land][.TANK_2_MOVES] == 0 &&
                        gc.active_armies[dst_land][.AAGUN_1_MOVES] == 0 &&
                        gc.active_land_planes[dst_land][.FIGHTER_UNMOVED] == 0 &&
                        gc.active_land_planes[dst_land][.BOMBER_UNMOVED] == 0 {
                        continue
                        }
                        enemy_attack_options[enemy][dst].Fighters += enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
                    }
                    else {
                        dst_sea := to_sea(dst)
                        if gc.active_ships[dst_sea][.TRANS_EMPTY_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1A_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1T_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_2I_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_1A_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_1T_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.SUB_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.DESTROYER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.CARRIER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.CRUISER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.BATTLESHIP_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.BS_DAMAGED_2_MOVES] == 0 &&
                           gc.active_sea_planes[dst_sea][.FIGHTER_UNMOVED] == 0 {                           
                           continue
                        }
                        enemy_attack_options[enemy][dst].Fighters += enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
                    }
				}
			}
			if enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
                get_airs(get_valid_unmoved_bomber_moves(&enemy_gc), &air_array)
				for dst in sa.slice(&air_array) {
                    
                    if is_land(dst) {
                        dst_land := to_land(dst)
                        if gc.owner[dst_land] != gc.cur_player &&
                        gc.active_armies[dst_land][.INF_1_MOVES] == 0 &&
                        gc.active_armies[dst_land][.ARTY_1_MOVES] == 0 &&
                        gc.active_armies[dst_land][.TANK_2_MOVES] == 0 &&
                        gc.active_armies[dst_land][.AAGUN_1_MOVES] == 0 &&
                        gc.active_land_planes[dst_land][.FIGHTER_UNMOVED] == 0 &&
                        gc.active_land_planes[dst_land][.BOMBER_UNMOVED] == 0 {
                        continue
                        }
                        enemy_attack_options[enemy][dst].Bombers += enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED]
                    } else {
                        dst_sea := to_sea(dst)
                        if gc.active_ships[dst_sea][.TRANS_EMPTY_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1A_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1T_UNMOVED] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_2I_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_1A_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.TRANS_1I_1T_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.SUB_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.DESTROYER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.CARRIER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.CRUISER_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.BATTLESHIP_2_MOVES] == 0 &&
                           gc.active_ships[dst_sea][.BS_DAMAGED_2_MOVES] == 0 &&
                           gc.active_sea_planes[dst_sea][.FIGHTER_UNMOVED] == 0 {                           
                           continue
                        }
                        enemy_attack_options[enemy][dst].Bombers += enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED]
                    }
				}
			}
            for dst in mm.l2l_1away_via_land_bitset[src_land] {
                if gc.owner[dst] != gc.cur_player &&
                   gc.active_armies[dst][.INF_1_MOVES] == 0 &&
                   gc.active_armies[dst][.ARTY_1_MOVES] == 0 &&
                   gc.active_armies[dst][.TANK_2_MOVES] == 0 &&
                   gc.active_armies[dst][.AAGUN_1_MOVES] == 0 &&
                   gc.active_land_planes[dst][.FIGHTER_UNMOVED] == 0 &&
                   gc.active_land_planes[dst][.BOMBER_UNMOVED] == 0 {
                   continue
                }
                enemy_attack_options[enemy][to_air(dst)].Infantry += enemy_gc.active_armies[src_land][.INF_1_MOVES]
                enemy_attack_options[enemy][to_air(dst)].Artillery += enemy_gc.active_armies[src_land][.ARTY_1_MOVES]
                enemy_attack_options[enemy][to_air(dst)].Tanks += enemy_gc.active_armies[src_land][.TANK_2_MOVES]
            }
            for dst in mm.l2l_2away_via_land_bitset[src_land] {
                if gc.owner[dst] != gc.cur_player &&
                   gc.active_armies[dst][.INF_1_MOVES] == 0 &&
                   gc.active_armies[dst][.ARTY_1_MOVES] == 0 &&
                   gc.active_armies[dst][.TANK_2_MOVES] == 0 &&
                   gc.active_armies[dst][.AAGUN_1_MOVES] == 0 &&
                   gc.active_land_planes[dst][.FIGHTER_UNMOVED] == 0 &&
                   gc.active_land_planes[dst][.BOMBER_UNMOVED] == 0 {
                   continue
                }
                // if all midlands between src and dst have enemy factory or units, skip
                if (mm.l2l_2away_via_midland_bitset[src_land][dst] & ~enemy_gc.has_enemy_factory & ~enemy_gc.has_enemy_units) == {} {
                    continue
                }
                enemy_attack_options[enemy][to_air(dst)].Tanks += enemy_gc.active_armies[src_land][.TANK_2_MOVES]
            }
        }
    }
}
