package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_submarine_combat :: proc(t: ^testing.T) {
    // Setup a sea with submarines and destroyers
    gc := oaaa.Game_Cache{}
    test_sea := oaaa.Sea_ID.Pacific
    gc.active_ships[test_sea][.SUB_2_MOVES] = 1
    gc.idle_ships[test_sea][.USA][.SUB] = 1
    gc.enemy_destroyer_total[test_sea] = 0

    // Submarines can attack without destroyers
    testing.expect(t, oaaa.no_defender_threat_exists(&gc, test_sea), 
        "Submarines should be able to attack without destroyers")

    // Add destroyer to prevent submarine attack
    gc.active_ships[test_sea][.DESTROYER_0_MOVES] = 1
    gc.idle_ships[test_sea][.Ger][.DESTROYER] = 1
    gc.allied_destroyers_total[test_sea] = 1

    testing.expect(t, !oaaa.no_defender_threat_exists(&gc, test_sea),
        "Destroyers should block submarine attacks")
}