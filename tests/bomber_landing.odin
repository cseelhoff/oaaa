package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_bomber_landing_constraints :: proc(t: ^testing.T) {
    gc := oaaa.Game_Cache{}
    test_land := oaaa.Land_ID.Washington

    // Initialize friendly territory
    gc.owner[test_land] = .USA
    gc.friendly_owner = {test_land}

    oaaa.refresh_can_bomber_land_here(&gc)

    // Friendly territory should allow landing
    testing.expect(t, test_land in gc.can_bomber_land_here, "Friendly land should allow bomber landing")
    
    // Enemy territory should not
    gc.owner[test_land] = .Ger
    gc.friendly_owner = {}
    gc.can_bomber_land_here = gc.friendly_owner
    testing.expect(t, test_land not_in gc.can_bomber_land_here, "Enemy land should disallow bomber landing")
}