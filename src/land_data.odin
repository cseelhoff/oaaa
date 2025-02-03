package oaaa

Land_ID :: distinct enum u8 {
	Washington,
	London,
	Berlin,
	Moscow,
	Tokyo,
}

LAND_CONNECTIONS := [?][2]Land_ID{{.Berlin, .Moscow}}
factory_locations :: [?]Land_ID{.Washington, .London, .Berlin, .Moscow, .Tokyo}
starting_money := [Player_ID]u8{.Rus = 10, .Ger = 20, .Eng = 6, .Jap = 20, .USA = 6}
starting_armies : [Land_ID][Player_ID][Idle_Army]u8
starting_land_planes : [Land_ID][Player_ID][Idle_Plane]u8

@(init)
init_starting_armies :: proc() {
    starting_armies[.Washington][.Rus][.INF] = 3
    starting_armies[.Washington][.Rus][.ARTY] = 2
}

@(init)
init_starting_land_planes :: proc() {
    starting_land_planes[.Washington][.Rus][.FIGHTER] = 1
}
