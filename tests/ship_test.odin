package oaaa_test

import "core:testing"
import oaaa "../src"

@(test)
test_ship_costs :: proc(t: ^testing.T) {
    // All transport variants should have the same cost
    trans_cost := oaaa.Cost_Buy[oaaa.Buy_Action.BUY_TRANS]
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.TRANS_EMPTY] == trans_cost, "Empty transport cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.TRANS_1I] == trans_cost, "Transport with 1 infantry cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.TRANS_1A] == trans_cost, "Transport with 1 artillery cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.TRANS_1T] == trans_cost, "Transport with 1 tank cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.TRANS_2I] == trans_cost, "Transport with 2 infantry cost mismatch")
    
    // Combat ships should have their specific costs
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.SUB] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_SUB], "Submarine cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.DESTROYER] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_DESTROYER], "Destroyer cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.CARRIER] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_CARRIER], "Carrier cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.CRUISER] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_CRUISER], "Cruiser cost mismatch")
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.BATTLESHIP] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_BATTLESHIP], "Battleship cost mismatch")
    
    // Damaged battleship should cost the same as regular battleship
    testing.expect(t, oaaa.COST_IDLE_SHIP[oaaa.Idle_Ship.BS_DAMAGED] == oaaa.Cost_Buy[oaaa.Buy_Action.BUY_BATTLESHIP], "Damaged battleship cost mismatch")
}

@(test)
test_ship_combat_stats :: proc(t: ^testing.T) {
    // Test attack values
    testing.expect(t, oaaa.DESTROYER_ATTACK == 2, "Destroyer attack value incorrect")
    testing.expect(t, oaaa.CARRIER_ATTACK == 1, "Carrier attack value incorrect")
    testing.expect(t, oaaa.CRUISER_ATTACK == 3, "Cruiser attack value incorrect")
    testing.expect(t, oaaa.BATTLESHIP_ATTACK == 4, "Battleship attack value incorrect")
    
    // Test defense values
    testing.expect(t, oaaa.DESTROYER_DEFENSE == 2, "Destroyer defense value incorrect")
    testing.expect(t, oaaa.CARRIER_DEFENSE == 2, "Carrier defense value incorrect")
    testing.expect(t, oaaa.CRUISER_DEFENSE == 3, "Cruiser defense value incorrect")
    testing.expect(t, oaaa.BATTLESHIP_DEFENSE == 4, "Battleship defense value incorrect")
    
    // Test that active ships have correct attack values
    testing.expect(t, oaaa.Active_Ship_Attack[oaaa.Active_Ship.BATTLESHIP_0_MOVES] == oaaa.BATTLESHIP_ATTACK, "Active battleship attack value incorrect")
    testing.expect(t, oaaa.Active_Ship_Attack[oaaa.Active_Ship.BS_DAMAGED_0_MOVES] == oaaa.BATTLESHIP_ATTACK, "Active damaged battleship attack value incorrect")
    testing.expect(t, oaaa.Active_Ship_Attack[oaaa.Active_Ship.CRUISER_0_MOVES] == oaaa.CRUISER_ATTACK, "Active cruiser attack value incorrect")
}

@(test)
test_ship_state_transitions :: proc(t: ^testing.T) {
    // Test that bombarding ships transition to correct state
    testing.expect(t, oaaa.Ship_After_Bombard[oaaa.Active_Ship.BATTLESHIP_0_MOVES] == oaaa.Active_Ship.BATTLESHIP_BOMBARDED, "Battleship bombard transition incorrect")
    testing.expect(t, oaaa.Ship_After_Bombard[oaaa.Active_Ship.BS_DAMAGED_0_MOVES] == oaaa.Active_Ship.BS_DAMAGED_BOMBARDED, "Damaged battleship bombard transition incorrect")
    testing.expect(t, oaaa.Ship_After_Bombard[oaaa.Active_Ship.CRUISER_0_MOVES] == oaaa.Active_Ship.CRUISER_BOMBARDED, "Cruiser bombard transition incorrect")
}
