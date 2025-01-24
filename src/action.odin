package oaaa

Action_ID :: distinct enum u8 {
	Washington_Action,
	London_Action,
	Berlin_Action,
	Moscow_Action,
	Tokyo_Action,
	Pacific_Action,
	Atlantic_Action,
	Baltic_Action,
	Skip_Action,
	Inf_Action,
	Arty_Action,
	Tank_Action,
	AAGun_Action,
	Fighter_Action,
	Bomber_Action,
	Trans_Action,
	Sub_Action,
	Destroyer_Action,
	Carrier_Action,
	Cruiser_Action,
	Battleship_Action,
}

to_action :: proc{air_to_action, land_to_action, sea_to_action, int_to_action}

to_action_bitset :: proc{sea_to_action_bitset, air_to_action_bitset}

air_to_action :: #force_inline proc(air: Air_ID) -> Action_ID {
	return Action_ID(air)
}

land_to_action :: #force_inline proc(land: Land_ID) -> Action_ID {
	return Action_ID(land)
}

sea_to_action :: #force_inline proc(sea: Sea_ID) -> Action_ID {
	return Action_ID(to_air(sea))
}

int_to_action :: #force_inline proc(i: int) -> Action_ID {
	assert(i >= 0 && i < len(Action_ID))
	return Action_ID(i)
}

sea_to_action_bitset :: #force_inline proc(sea: Sea_Bitset) -> Action_Bitset {
	return transmute(Action_Bitset)(u32(transmute(u8)sea) << len(Land_ID))
}

air_to_action_bitset :: #force_inline proc(air: Air_Bitset) -> Action_Bitset {
	return transmute(Action_Bitset)u32(transmute(u16)air)
}
