package oaaa

Active_Unit :: enum {
    Infantry_1_Moves,
    Infantry_0_Moves,
    Artillery_1_Moves,
    Artillery_0_Moves,
    Tank_2_Moves,
    Tank_1_Moves,
    Tank_0_Moves,
    AAGun_1_Moves,
    AAGun_0_Moves,
    Transport_Empty_Unmoved,
	Transport_Empty_2_Moves,
	Transport_Empty_1_Moves,
	Transport_Empty_0_Moves,
	Transport_Infantry_Unmoved,
	Transport_Infantry_2_Moves,
	Transport_Infantry_1_Moves,
	Transport_Infantry_0_Moves,
	Transport_Infantry_Unloaded,
	Transport_Artillery_Unmoved,
	Transport_Artillery_2_Moves,
	Transport_Artillery_1_Moves,
	Transport_Artillery_0_Moves,
	Transport_Artillery_Unloaded,
	Transport_Tank_Unmoved,
	Transport_Tank_2_Moves,
	Transport_Tank_1_Moves,
	Transport_Tank_0_Moves,
	Transport_Tank_Unloaded,
	Transport_Infantry_Infantry_2_Moves,
	Transport_Infantry_Infantry_1_Moves,
	Transport_Infantry_Infantry_0_Moves,
	Transport_Infantry_Infantry_Unloaded,
	Transport_Infantry_Artillery_2_Moves,
	Transport_Infantry_Artillery_1_Moves,
	Transport_Infantry_Artillery_0_Moves,
	Transport_Infantry_Artillery_Unloaded,
	Transport_Infantry_Tank_2_Moves,
	Transport_Infantry_Tank_1_Moves,
	Transport_Infantry_Tank_0_Moves,
	Transport_Infantry_Tank_Unloaded,
	Submarine_2_Moves,
	Submarine_0_Moves,
	Destroyer_2_Moves,
	Destroyer_0_Moves,
	Carrier_2_Moves,
	Carrier_0_Moves,
	Cruiser_2_Moves,
	Cruiser_0_Moves,
	Cruiser_Bombarded,
	Battleship_2_Moves,
	Battleship_0_Moves,
	Battleship_Bombarded,
	Battleship_Damaged_2_Moves,
	Battleship_Damaged_0_Moves,
	Battleship_Damaged_Bombarded,
    Fighter_Unmoved, // distinct from 4_moves, for when ships placed under fighter
	Fighter_4_Moves,
	Fighter_3_Moves,
	Fighter_2_Moves,
	Fighter_1_Moves,
	Fighter_0_Moves,
	Bomber_Unmoved,
	Bomber_5_Moves,
	Bomber_4_Moves,
	Bomber_3_Moves,
	Bomber_2_Moves,
	Bomber_1_Moves,
	Bomber_0_Moves,
    Factory,
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

