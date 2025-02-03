package oaaa

Sea_ID :: enum {
	Pacific,
	Atlantic,
	Baltic,
}

Canal_ID :: enum {
	Pacific_Baltic,
}

SEA_CONNECTIONS :: [?][2]Sea_ID{{.Pacific, .Atlantic}, {.Atlantic, .Baltic}}
CANALS := [?]Canal{{lands = {.Berlin, .Moscow}, seas = {.Pacific, .Baltic}}}

starting_ships : [Sea_ID][Player_ID][Idle_Ship]u8
starting_sea_planes : [Sea_ID][Player_ID][Idle_Plane]u8

@(init)
init_starting_ships :: proc() {
    starting_ships[.Pacific][.Rus][.SUB] = 2
}

@(init)
init_starting_sea_planes :: proc() {
    starting_sea_planes[.Pacific][.Rus][.FIGHTER] = 2    
}
