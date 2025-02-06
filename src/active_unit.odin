package oaaa

Active_Unit :: enum {
    INF_1_MOVES,
    INF_0_MOVES,
    ARTY_1_MOVES,
    ARTY_0_MOVES,
    TANK_2_MOVES,
    TANK_1_MOVES,
    TANK_0_MOVES,
    AAGUN_1_MOVES,
    AAGUN_0_MOVES,
    TRANS_EMPTY_UNMOVED,
	TRANS_EMPTY_2_MOVES,
	TRANS_EMPTY_1_MOVES,
	TRANS_EMPTY_0_MOVES,
	TRANS_1I_UNMOVED,
	TRANS_1I_2_MOVES,
	TRANS_1I_1_MOVES,
	TRANS_1I_0_MOVES,
	TRANS_1I_UNLOADED,
	TRANS_1A_UNMOVED,
	TRANS_1A_2_MOVES,
	TRANS_1A_1_MOVES,
	TRANS_1A_0_MOVES,
	TRANS_1A_UNLOADED,
	TRANS_1T_UNMOVED,
	TRANS_1T_2_MOVES,
	TRANS_1T_1_MOVES,
	TRANS_1T_0_MOVES,
	TRANS_1T_UNLOADED,
	TRANS_2I_2_MOVES,
	TRANS_2I_1_MOVES,
	TRANS_2I_0_MOVES,
	TRANS_2I_UNLOADED,
	TRANS_1I_1A_2_MOVES,
	TRANS_1I_1A_1_MOVES,
	TRANS_1I_1A_0_MOVES,
	TRANS_1I_1A_UNLOADED,
	TRANS_1I_1T_2_MOVES,
	TRANS_1I_1T_1_MOVES,
	TRANS_1I_1T_0_MOVES,
	TRANS_1I_1T_UNLOADED,
	SUB_2_MOVES,
	SUB_0_MOVES,
	DESTROYER_2_MOVES,
	DESTROYER_0_MOVES,
	CARRIER_2_MOVES,
	CARRIER_0_MOVES,
	CRUISER_2_MOVES,
	CRUISER_0_MOVES,
	CRUISER_BOMBARDED,
	BATTLESHIP_2_MOVES,
	BATTLESHIP_0_MOVES,
	BATTLESHIP_BOMBARDED,
	BS_DAMAGED_2_MOVES,
	BS_DAMAGED_0_MOVES,
	BS_DAMAGED_BOMBARDED,
    FIGHTER_UNMOVED, // distinct from 4_moves, for when ships placed under fighter
	FIGHTER_4_MOVES,
	FIGHTER_3_MOVES,
	FIGHTER_2_MOVES,
	FIGHTER_1_MOVES,
	FIGHTER_0_MOVES,
	BOMBER_UNMOVED,
	BOMBER_5_MOVES,
	BOMBER_4_MOVES,
	BOMBER_3_MOVES,
	BOMBER_2_MOVES,
	BOMBER_1_MOVES,
	BOMBER_0_MOVES,
    FACTORY,
}

to_unit :: proc {
	army_to_unit,
	ship_to_unit,
	plane_to_unit,
}

to_army:: proc(au: Active_Unit) -> Active_Army {
    return Active_Army(au)
}

to_ship:: proc(au: Active_Unit) -> Active_Ship {
    return Active_Ship(int(au) - len(Active_Army))
}

to_plane:: proc(au: Active_Unit) -> Active_Plane {
	return Active_Plane(int(au) - len(Active_Army) - len(Active_Ship))
}

army_to_unit:: proc(army: Active_Army) -> Active_Unit {
	return Active_Unit(int(army))
}

ship_to_unit:: proc(ship: Active_Ship) -> Active_Unit {
	return Active_Unit(int(ship) + len(Active_Army))
}


plane_to_unit:: proc(plane: Active_Plane) -> Active_Unit {
	return Active_Unit(int(plane) + len(Active_Army) + len(Active_Ship))
}

