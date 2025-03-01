package oaaa

Sea_ID :: enum {
	Sea_1,
	Sea_2,
	Sea_3,
	Sea_4,
	Sea_5,
	Sea_6,
	Sea_7,
	Sea_8,
	Sea_9,
	Sea_10,
	Sea_11,
	Sea_12,
	Sea_13,
	Sea_14,
	Sea_15,
	Sea_16,
	Sea_17,
	Sea_18,
	Sea_19,
	Sea_20,
	Sea_21,
	Sea_22,
	Sea_23,
	Sea_24,
	Sea_25,
	Sea_26,
	Sea_27,
	Sea_28,
	Sea_29,
	Sea_30,
	Sea_31,
	Sea_32,
	Sea_33,
	Sea_34,
	Sea_35,
	Sea_36,
	Sea_37,
	Sea_38,
	Sea_39,
	Sea_40,
	Sea_41,
	Sea_42,
	Sea_43,
	Sea_44,
	Sea_45,
	Sea_46,
	Sea_47,
	Sea_48,
	Sea_49,
	Sea_50,
	Sea_51,
	Sea_52,
	Sea_53,
	Sea_54,
	Sea_55,
	Sea_56,
	Sea_57,
	Sea_58,
	Sea_59,
	Sea_60,
	Sea_61,
	Sea_62,
	Sea_63,
	Sea_64,
	Sea_65,
}

Canal_ID :: enum {
	Suez_Canal,
	Panama_Canal,
}

SEA_CONNECTIONS :: [?][2]Sea_ID {
	{.Sea_1, .Sea_2},
	{.Sea_1, .Sea_10},
	{.Sea_2, .Sea_3},
	{.Sea_2, .Sea_7},
	{.Sea_2, .Sea_9},
	{.Sea_2, .Sea_10},
	{.Sea_3, .Sea_4},
	{.Sea_3, .Sea_6},
	{.Sea_3, .Sea_7},
	{.Sea_5, .Sea_6},
	{.Sea_6, .Sea_7},
	{.Sea_6, .Sea_8},
	{.Sea_7, .Sea_8},
	{.Sea_7, .Sea_9},
	{.Sea_8, .Sea_9},
	{.Sea_8, .Sea_13},
	{.Sea_9, .Sea_10},
	{.Sea_9, .Sea_12},
	{.Sea_9, .Sea_13},
	{.Sea_10, .Sea_11},
	{.Sea_10, .Sea_12},
	{.Sea_11, .Sea_12},
	{.Sea_11, .Sea_18},
	{.Sea_12, .Sea_13},
	{.Sea_12, .Sea_18},
	{.Sea_12, .Sea_22},
	{.Sea_12, .Sea_23},
	{.Sea_13, .Sea_14},
	{.Sea_13, .Sea_23},
	{.Sea_14, .Sea_15},
	{.Sea_15, .Sea_16},
	{.Sea_15, .Sea_17},
	{.Sea_17, .Sea_34},
	{.Sea_18, .Sea_19},
	{.Sea_18, .Sea_22},
	{.Sea_19, .Sea_20},
	{.Sea_19, .Sea_55},
	{.Sea_20, .Sea_21},
	{.Sea_20, .Sea_42},
	{.Sea_21, .Sea_22},
	{.Sea_21, .Sea_25},
	{.Sea_21, .Sea_26},
	{.Sea_21, .Sea_41},
	{.Sea_22, .Sea_23},
	{.Sea_22, .Sea_25},
	{.Sea_23, .Sea_24},
	{.Sea_23, .Sea_25},
	{.Sea_24, .Sea_25},
	{.Sea_24, .Sea_27},
	{.Sea_25, .Sea_26},
	{.Sea_25, .Sea_27},
	{.Sea_26, .Sea_27},
	{.Sea_27, .Sea_28},
	{.Sea_28, .Sea_29},
	{.Sea_28, .Sea_33},
	{.Sea_29, .Sea_30},
	{.Sea_29, .Sea_31},
	{.Sea_29, .Sea_32},
	{.Sea_30, .Sea_31},
	{.Sea_30, .Sea_37},
	{.Sea_30, .Sea_38},
	{.Sea_31, .Sea_32},
	{.Sea_31, .Sea_35},
	{.Sea_31, .Sea_37},
	{.Sea_32, .Sea_33},
	{.Sea_32, .Sea_34},
	{.Sea_32, .Sea_35},
	{.Sea_33, .Sea_34},
	{.Sea_34, .Sea_35},
	{.Sea_35, .Sea_36},
	{.Sea_35, .Sea_37},
	{.Sea_36, .Sea_37},
	{.Sea_36, .Sea_47},
	{.Sea_36, .Sea_48},
	{.Sea_36, .Sea_61},
	{.Sea_37, .Sea_38},
	{.Sea_37, .Sea_46},
	{.Sea_37, .Sea_47},
	{.Sea_38, .Sea_39},
	{.Sea_38, .Sea_46},
	{.Sea_39, .Sea_40},
	{.Sea_39, .Sea_45},
	{.Sea_40, .Sea_41},
	{.Sea_40, .Sea_43},
	{.Sea_40, .Sea_44},
	{.Sea_40, .Sea_45},
	{.Sea_41, .Sea_42},
	{.Sea_41, .Sea_43},
	{.Sea_42, .Sea_43},
	{.Sea_42, .Sea_54},
	{.Sea_42, .Sea_55},
	{.Sea_43, .Sea_44},
	{.Sea_43, .Sea_53},
	{.Sea_43, .Sea_54},
	{.Sea_44, .Sea_45},
	{.Sea_44, .Sea_49},
	{.Sea_44, .Sea_50},
	{.Sea_44, .Sea_52},
	{.Sea_44, .Sea_53},
	{.Sea_45, .Sea_46},
	{.Sea_45, .Sea_49},
	{.Sea_46, .Sea_47},
	{.Sea_46, .Sea_49},
	{.Sea_47, .Sea_48},
	{.Sea_47, .Sea_49},
	{.Sea_48, .Sea_49},
	{.Sea_48, .Sea_50},
	{.Sea_48, .Sea_51},
	{.Sea_48, .Sea_60},
	{.Sea_48, .Sea_61},
	{.Sea_49, .Sea_50},
	{.Sea_50, .Sea_51},
	{.Sea_50, .Sea_52},
	{.Sea_51, .Sea_52},
	{.Sea_51, .Sea_59},
	{.Sea_51, .Sea_60},
	{.Sea_52, .Sea_53},
	{.Sea_52, .Sea_57},
	{.Sea_52, .Sea_59},
	{.Sea_53, .Sea_54},
	{.Sea_53, .Sea_56},
	{.Sea_53, .Sea_57},
	{.Sea_54, .Sea_55},
	{.Sea_54, .Sea_56},
	{.Sea_55, .Sea_56},
	{.Sea_56, .Sea_57},
	{.Sea_56, .Sea_65},
	{.Sea_57, .Sea_58},
	{.Sea_57, .Sea_59},
	{.Sea_57, .Sea_64},
	{.Sea_57, .Sea_65},
	{.Sea_58, .Sea_59},
	{.Sea_58, .Sea_60},
	{.Sea_58, .Sea_63},
	{.Sea_58, .Sea_64},
	{.Sea_59, .Sea_60},
	{.Sea_60, .Sea_61},
	{.Sea_60, .Sea_63},
	{.Sea_61, .Sea_62},
	{.Sea_62, .Sea_60},
	{.Sea_62, .Sea_63},
	{.Sea_63, .Sea_64},
	{.Sea_64, .Sea_65},
}

CANALS := [?]Canal{{lands = {.Egypt, .Trans_Jordan}, seas = {.Sea_17, .Sea_34}},{lands = {.Central_America, .Central_America}, seas = {.Sea_18, .Sea_19}}}

COASTAL_CONNECTIONS := [?]Coastal_Connection {
	{land = .Eastern_Canada, sea = .Sea_1},
	{land = .Greenland, sea = .Sea_2},
	{land = .Finland, sea = .Sea_3},
	{land = .Iceland, sea = .Sea_3},
	{land = .Norway, sea = .Sea_3},
	{land = .Archangel, sea = .Sea_4},
	{land = .Karelia_SSR, sea = .Sea_4},
	{land = .Baltic_States, sea = .Sea_5},
	{land = .Finland, sea = .Sea_5},
	{land = .Germany, sea = .Sea_5},
	{land = .Karelia_SSR, sea = .Sea_5},
	{land = .Northwestern_Europe, sea = .Sea_5},
	{land = .Norway, sea = .Sea_5},
	{land = .Northwestern_Europe, sea = .Sea_6},
	{land = .Norway, sea = .Sea_6},
	{land = .United_Kingdom, sea = .Sea_6},
	{land = .United_Kingdom, sea = .Sea_7},
	{land = .France, sea = .Sea_8},
	{land = .Northwestern_Europe, sea = .Sea_8},
	{land = .United_Kingdom, sea = .Sea_8},
	{land = .Eastern_Canada, sea = .Sea_10},
	{land = .Central_United_States, sea = .Sea_11},
	{land = .East_Mexico, sea = .Sea_11},
	{land = .Eastern_United_States, sea = .Sea_11},
	{land = .Gibraltar, sea = .Sea_13},
	{land = .Morocco, sea = .Sea_13},
	{land = .Algeria, sea = .Sea_14},
	{land = .France, sea = .Sea_14},
	{land = .Gibraltar, sea = .Sea_14},
	{land = .Morocco, sea = .Sea_14},
	{land = .Italy, sea = .Sea_15},
	{land = .Libya, sea = .Sea_15},
	{land = .Southern_Europe, sea = .Sea_15},
	{land = .Bulgaria_Romania, sea = .Sea_16},
	{land = .Caucasus, sea = .Sea_16},
	{land = .Ukraine_SSR, sea = .Sea_16},
	{land = .Egypt, sea = .Sea_17},
	{land = .Trans_Jordan, sea = .Sea_17},
	{land = .Central_America, sea = .Sea_18},
	{land = .East_Mexico, sea = .Sea_18},
	{land = .West_Indies, sea = .Sea_18},
	{land = .Central_America, sea = .Sea_19},
	{land = .East_Mexico, sea = .Sea_19},
	{land = .Brazil, sea = .Sea_22},
	{land = .French_West_Africa, sea = .Sea_23},
	{land = .Belgian_Congo, sea = .Sea_24},
	{land = .French_Equatorial_Africa, sea = .Sea_24},
	{land = .Union_of_South_Africa, sea = .Sea_27},
	{land = .French_Madagascar, sea = .Sea_28},
	{land = .Union_of_South_Africa, sea = .Sea_28},
	{land = .French_Madagascar, sea = .Sea_29},
	{land = .French_Madagascar, sea = .Sea_32},
	{land = .French_Madagascar, sea = .Sea_33},
	{land = .Italian_East_Africa, sea = .Sea_33},
	{land = .Rhodesia, sea = .Sea_33},
	{land = .Anglo_Egyptian_Sudan, sea = .Sea_34},
	{land = .Egypt, sea = .Sea_34},
	{land = .Italian_East_Africa, sea = .Sea_34},
	{land = .Persia, sea = .Sea_34},
	{land = .Trans_Jordan, sea = .Sea_34},
	{land = .India, sea = .Sea_35},
	{land = .Burma, sea = .Sea_36},
	{land = .French_Indo_China_Thailand, sea = .Sea_36},
	{land = .Malaya, sea = .Sea_36},
	{land = .East_Indies, sea = .Sea_37},
	{land = .Western_Australia, sea = .Sea_38},
	{land = .Eastern_Australia, sea = .Sea_39},
	{land = .New_Zealand, sea = .Sea_40},
	{land = .Solomon_Islands, sea = .Sea_44},
	{land = .Eastern_Australia, sea = .Sea_45},
	{land = .Western_Australia, sea = .Sea_46},
	{land = .Borneo, sea = .Sea_47},
	{land = .Philippine_Islands, sea = .Sea_48},
	{land = .New_Guinea, sea = .Sea_49},
	{land = .Caroline_Islands, sea = .Sea_50},
	{land = .Okinawa, sea = .Sea_51},
	{land = .Wake_Island, sea = .Sea_52},
	{land = .Hawaiian_Islands, sea = .Sea_53},
	{land = .Mexico, sea = .Sea_55},
	{land = .Western_United_States, sea = .Sea_56},
	{land = .Midway, sea = .Sea_57},
	{land = .Iwo_Jima, sea = .Sea_59},
	{land = .Japan, sea = .Sea_60},
	{land = .Formosa, sea = .Sea_61},
	{land = .Kiangsu, sea = .Sea_61},
	{land = .Kwangtung, sea = .Sea_61},
	{land = .Yunnan, sea = .Sea_61},
	{land = .Japan, sea = .Sea_62},
	{land = .Manchuria, sea = .Sea_62},
	{land = .Buryatia_SSR, sea = .Sea_63},
	{land = .Soviet_Far_East, sea = .Sea_63},
	{land = .Alaska, sea = .Sea_64},
	{land = .Alaska, sea = .Sea_65},
	{land = .Western_Canada, sea = .Sea_65},
}

starting_ships: [Sea_ID][Player_ID][Idle_Ship]u8
starting_sea_planes: [Sea_ID][Player_ID][Idle_Plane]u8

@(init)
init_starting_ships :: proc() {
	// Russian ships
	starting_ships[.Sea_4][.Rus][.SUB] = 1

	// German ships
	starting_ships[.Sea_5][.Ger][.TRANS_EMPTY] = 1
	starting_ships[.Sea_5][.Ger][.SUB] = 2
	starting_ships[.Sea_5][.Ger][.CRUISER] = 1
	starting_ships[.Sea_9][.Ger][.SUB] = 2
	starting_ships[.Sea_15][.Ger][.TRANS_EMPTY] = 1
	starting_ships[.Sea_15][.Ger][.BATTLESHIP] = 1

	// British ships
	starting_ships[.Sea_10][.Eng][.TRANS_EMPTY] = 1
	starting_ships[.Sea_10][.Eng][.DESTROYER] = 1
	starting_ships[.Sea_7][.Eng][.BATTLESHIP] = 1
	starting_ships[.Sea_7][.Eng][.TRANS_EMPTY] = 1
	starting_ships[.Sea_14][.Eng][.CRUISER] = 1
	starting_ships[.Sea_17][.Eng][.DESTROYER] = 1
	starting_ships[.Sea_35][.Eng][.CARRIER] = 1
	starting_ships[.Sea_35][.Eng][.TRANS_EMPTY] = 1
	starting_ships[.Sea_35][.Eng][.CRUISER] = 1
	starting_ships[.Sea_39][.Eng][.TRANS_EMPTY] = 1
	starting_ships[.Sea_39][.Eng][.SUB] = 1
	starting_ships[.Sea_39][.Eng][.CRUISER] = 1

	// Japanese ships
	starting_ships[.Sea_37][.Jap][.BATTLESHIP] = 1
	starting_ships[.Sea_37][.Jap][.CARRIER] = 1
	starting_ships[.Sea_61][.Jap][.TRANS_EMPTY] = 1
	starting_ships[.Sea_61][.Jap][.DESTROYER] = 1
	starting_ships[.Sea_60][.Jap][.TRANS_EMPTY] = 1
	starting_ships[.Sea_60][.Jap][.BATTLESHIP] = 1
	starting_ships[.Sea_60][.Jap][.DESTROYER] = 1
	starting_ships[.Sea_50][.Jap][.CRUISER] = 1
	starting_ships[.Sea_50][.Jap][.CARRIER] = 1
	starting_ships[.Sea_44][.Jap][.SUB] = 1

	// American ships
	starting_ships[.Sea_11][.USA][.TRANS_EMPTY] = 2
	starting_ships[.Sea_19][.USA][.CRUISER] = 1
	starting_ships[.Sea_11][.USA][.DESTROYER] = 1
	starting_ships[.Sea_56][.USA][.BATTLESHIP] = 1
	starting_ships[.Sea_56][.USA][.DESTROYER] = 1
	starting_ships[.Sea_56][.USA][.TRANS_EMPTY] = 1
	starting_ships[.Sea_53][.USA][.CARRIER] = 1
	starting_ships[.Sea_53][.USA][.SUB] = 1
	starting_ships[.Sea_53][.USA][.DESTROYER] = 1
}

@(init)
init_starting_sea_planes :: proc() {
	// British sea-based planes
	starting_sea_planes[.Sea_35][.Eng][.FIGHTER] = 1

	// Japanese sea-based planes
	starting_sea_planes[.Sea_37][.Jap][.FIGHTER] = 2
	starting_sea_planes[.Sea_50][.Jap][.FIGHTER] = 1

	// American sea-based planes
	starting_sea_planes[.Sea_53][.USA][.FIGHTER] = 1
}
