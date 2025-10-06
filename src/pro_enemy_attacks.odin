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
                    if gc.owner[to_land(dst)] != gc.cur_player &&
                       gc.active_armies[to_land(dst)][.INF_1_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.ARTY_1_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.TANK_2_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.AAGUN_1_MOVES] == 0 &&
                       gc.active_land_planes[to_land(dst)][.FIGHTER_UNMOVED] == 0 &&
                       gc.active_land_planes[to_land(dst)][.BOMBER_UNMOVED] == 0 {
                       continue
                    }
					enemy_attack_options[enemy][dst].Fighters += enemy_gc.active_land_planes[src_land][.FIGHTER_UNMOVED]
				}
			}
			if enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED] > 0 {
                get_airs(get_valid_unmoved_bomber_moves(&enemy_gc), &air_array)
				for dst in sa.slice(&air_array) {
                    if gc.owner[to_land(dst)] != gc.cur_player &&
                       gc.active_armies[to_land(dst)][.INF_1_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.ARTY_1_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.TANK_2_MOVES] == 0 &&
                       gc.active_armies[to_land(dst)][.AAGUN_1_MOVES] == 0 &&
                       gc.active_land_planes[to_land(dst)][.FIGHTER_UNMOVED] == 0 &&
                       gc.active_land_planes[to_land(dst)][.BOMBER_UNMOVED] == 0 {
                       continue
                    }
					enemy_attack_options[enemy][dst].Bombers += enemy_gc.active_land_planes[src_land][.BOMBER_UNMOVED]
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
