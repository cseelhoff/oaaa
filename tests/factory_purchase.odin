package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_buy_factory :: proc(t: ^testing.T) {
    // Test buying a factory in Moscow
    gc := oaaa.Game_Cache{}
    gc.money[.USA] = 15
    gc.cur_player = .USA
    
    // Add Moscow to valid actions
    gc.valid_actions = {.Moscow_Action}
    
    // Execute purchase
    oaaa.buy_factory(&gc)
    
    // Verify factory is built
    testing.expect(t, gc.factory_prod[oaaa.Land_ID.Moscow] > 0, 
        "Factory should be built in Moscow")
}