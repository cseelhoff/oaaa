#+feature global-context
package oaaa

Land_ID :: distinct enum u8 {
    Alaska,
    Algeria,
    Anglo_Egyptian_Sudan,
    Anhwei,
    Archangel,
    Baltic_States,
    Belgian_Congo,
    Belorussia,
    Borneo,
    Brazil,
    Bulgaria_Romania,
    Burma,
    Buryatia_SSR,
    Caroline_Islands,
    Caucasus,
    Central_America,
    Central_United_States,
    East_Indies,
    East_Mexico,
    Eastern_Australia,
    Eastern_Canada,
    Eastern_United_States,
    Egypt,
    Evenki_National_Okrug,
    Finland,
    Formosa,
    France,
    French_Equatorial_Africa,
    French_Indo_China_Thailand,
    French_Madagascar,
    French_West_Africa,
    Germany,
    Gibraltar,
    Greenland,
    Hawaiian_Islands,
    Iceland,
    India,
    Italian_East_Africa,
    Italy,
    Iwo_Jima,
    Japan,
    Karelia_SSR,
    Kazakh_SSR,
    Kiangsu,
    Kwangtung,
    Libya,
    Malaya,
    Manchuria,
    Mexico,
    Midway,
    Morocco,
    New_Guinea,
    New_Zealand,
    Northwestern_Europe,
    Norway,
    Novosibirsk,
    Okinawa,
    Persia,
    Philippine_Islands,
    Poland,
    Rhodesia,
    Russia,
    Sinkiang,
    Solomon_Islands,
    Southern_Europe,
    Soviet_Far_East,
    Szechwan,
    Trans_Jordan,
    Ukraine_SSR,
    Union_of_South_Africa,
    United_Kingdom,
    Vologda,
    Wake_Island,
    West_Indies,
    West_Russia,
    Western_Australia,
    Western_Canada,
    Western_United_States,
    Yakut_SSR,
    Yunnan,
}

LAND_CONNECTIONS := [?][2]Land_ID{
    {.Alaska, .Western_Canada},
    {.Algeria, .Libya},
    {.Algeria, .Morocco},
    {.Anglo_Egyptian_Sudan, .Belgian_Congo},
    {.Anglo_Egyptian_Sudan, .Egypt},
    {.Anglo_Egyptian_Sudan, .French_Equatorial_Africa},
    {.Anglo_Egyptian_Sudan, .Italian_East_Africa},
    {.Anglo_Egyptian_Sudan, .Rhodesia},
    {.Anhwei, .Kiangsu},
    {.Anhwei, .Kwangtung},
    {.Anhwei, .Manchuria},
    {.Anhwei, .Sinkiang},
    {.Anhwei, .Szechwan},
    {.Archangel, .Evenki_National_Okrug},
    {.Archangel, .Karelia_SSR},
    {.Archangel, .Russia},
    {.Archangel, .Vologda},
    {.Archangel, .West_Russia},
    {.Baltic_States, .Belorussia},
    {.Baltic_States, .Germany},
    {.Baltic_States, .Karelia_SSR},
    {.Baltic_States, .Poland},
    {.Belgian_Congo, .French_Equatorial_Africa},
    {.Belgian_Congo, .Rhodesia},
    {.Belgian_Congo, .Union_of_South_Africa},
    {.Belorussia, .Karelia_SSR},
    {.Belorussia, .Poland},
    {.Belorussia, .Ukraine_SSR},
    {.Belorussia, .West_Russia},
    {.Bulgaria_Romania, .Germany},
    {.Bulgaria_Romania, .Poland},
    {.Bulgaria_Romania, .Southern_Europe},
    {.Bulgaria_Romania, .Ukraine_SSR},
    {.Burma, .French_Indo_China_Thailand},
    {.Burma, .India},
    {.Burma, .Yunnan},
    {.Buryatia_SSR, .Manchuria},
    {.Buryatia_SSR, .Soviet_Far_East},
    {.Buryatia_SSR, .Yakut_SSR},
    {.Caucasus, .Kazakh_SSR},
    {.Caucasus, .Persia},
    {.Caucasus, .Russia},
    {.Caucasus, .Ukraine_SSR},
    {.Caucasus, .West_Russia},
    {.Central_America, .East_Mexico},
    {.Central_United_States, .East_Mexico},
    {.Central_United_States, .Eastern_Canada},
    {.Central_United_States, .Eastern_United_States},
    {.Central_United_States, .Western_United_States},
    {.East_Mexico, .Mexico},
    {.Eastern_Australia, .Western_Australia},
    {.Eastern_Canada, .Eastern_United_States},
    {.Eastern_Canada, .Western_Canada},
    {.Egypt, .Libya},
    {.Egypt, .Trans_Jordan},
    {.Evenki_National_Okrug, .Novosibirsk},
    {.Evenki_National_Okrug, .Sinkiang},
    {.Evenki_National_Okrug, .Vologda},
    {.Evenki_National_Okrug, .Yakut_SSR},
    {.Finland, .Karelia_SSR},
    {.Finland, .Norway},
    {.France, .Germany},
    {.France, .Italy},
    {.France, .Northwestern_Europe},
    {.French_Equatorial_Africa, .French_West_Africa},
    {.French_Indo_China_Thailand, .Malaya},
    {.French_Indo_China_Thailand, .Yunnan},
    {.Germany, .Italy},
    {.Germany, .Northwestern_Europe},
    {.Germany, .Poland},
    {.Germany, .Southern_Europe},
    {.India, .Persia},
    {.Italian_East_Africa, .Rhodesia},
    {.Italy, .Southern_Europe},
    {.Karelia_SSR, .West_Russia},
    {.Kazakh_SSR, .Novosibirsk},
    {.Kazakh_SSR, .Persia},
    {.Kazakh_SSR, .Russia},
    {.Kazakh_SSR, .Sinkiang},
    {.Kazakh_SSR, .Szechwan},
    {.Kiangsu, .Kwangtung},
    {.Kiangsu, .Manchuria},
    {.Kwangtung, .Szechwan},
    {.Kwangtung, .Yunnan},
    {.Mexico, .Western_United_States},
    {.Novosibirsk, .Russia},
    {.Novosibirsk, .Sinkiang},
    {.Novosibirsk, .Vologda},
    {.Persia, .Trans_Jordan},
    {.Poland, .Ukraine_SSR},
    {.Rhodesia, .Union_of_South_Africa},
    {.Russia, .Vologda},
    {.Russia, .West_Russia},
    {.Sinkiang, .Szechwan},
    {.Soviet_Far_East, .Yakut_SSR},
    {.Szechwan, .Yunnan},
    {.Ukraine_SSR, .West_Russia},
    {.Western_Canada, .Western_United_States},
}

factory_locations :: [?]Land_ID{
    .Karelia_SSR,
    .Caucasus,
    .Russia,
    .Italy,
    .Germany,
    .United_Kingdom,
    .India,
    .Japan,
    .Eastern_United_States,
    .Western_United_States,
}

starting_money := [Player_ID]u8{.Rus = 24, .Ger = 41, .Eng = 31, .Jap = 30, .USA = 42}
starting_armies : [Land_ID][Player_ID][Idle_Army]u8
starting_land_planes : [Land_ID][Player_ID][Idle_Plane]u8

@(init)
init_starting_armies :: proc() {
    // Russian territories
    starting_armies[.Karelia_SSR][.Rus][.INF] = 4
    starting_armies[.Karelia_SSR][.Rus][.ARTY] = 1
    starting_armies[.Archangel][.Rus][.INF] = 1
    starting_armies[.Archangel][.Rus][.TANK] = 1
    starting_armies[.Caucasus][.Rus][.INF] = 3
    starting_armies[.Caucasus][.Rus][.ARTY] = 1
    starting_armies[.Caucasus][.Rus][.TANK] = 1
    starting_armies[.Russia][.Rus][.INF] = 4
    starting_armies[.Russia][.Rus][.ARTY] = 1
    starting_armies[.Russia][.Rus][.TANK] = 2
    starting_armies[.Evenki_National_Okrug][.Rus][.INF] = 2
    starting_armies[.Novosibirsk][.Rus][.INF] = 1
    starting_armies[.Yakut_SSR][.Rus][.INF] = 1
    starting_armies[.Soviet_Far_East][.Rus][.INF] = 2
    starting_armies[.Buryatia_SSR][.Rus][.INF] = 2
    starting_armies[.Kazakh_SSR][.Rus][.INF] = 1

    // German territories
    starting_armies[.France][.Ger][.INF] = 1
    starting_armies[.France][.Ger][.TANK] = 2
    starting_armies[.Northwestern_Europe][.Ger][.INF] = 1
    starting_armies[.Northwestern_Europe][.Ger][.TANK] = 1
    starting_armies[.Italy][.Ger][.INF] = 1
    starting_armies[.Italy][.Ger][.TANK] = 1
    starting_armies[.Southern_Europe][.Ger][.INF] = 1
    starting_armies[.Southern_Europe][.Ger][.ARTY] = 1
    starting_armies[.Germany][.Ger][.INF] = 3
    starting_armies[.Germany][.Ger][.TANK] = 2
    starting_armies[.Norway][.Ger][.INF] = 2
    starting_armies[.Finland][.Ger][.INF] = 3
    starting_armies[.Bulgaria_Romania][.Ger][.INF] = 2
    starting_armies[.Bulgaria_Romania][.Ger][.TANK] = 1
    starting_armies[.Poland][.Ger][.INF] = 2
    starting_armies[.Poland][.Ger][.TANK] = 1
    starting_armies[.Baltic_States][.Ger][.INF] = 1
    starting_armies[.Baltic_States][.Ger][.TANK] = 1
    starting_armies[.Ukraine_SSR][.Ger][.INF] = 3
    starting_armies[.Ukraine_SSR][.Ger][.ARTY] = 1
    starting_armies[.Ukraine_SSR][.Ger][.TANK] = 1
    starting_armies[.Belorussia][.Ger][.INF] = 3
    starting_armies[.West_Russia][.Ger][.INF] = 3
    starting_armies[.West_Russia][.Ger][.ARTY] = 1
    starting_armies[.West_Russia][.Ger][.TANK] = 1
    starting_armies[.Morocco][.Ger][.INF] = 1
    starting_armies[.Libya][.Ger][.INF] = 1
    starting_armies[.Libya][.Ger][.TANK] = 1
    starting_armies[.Algeria][.Ger][.INF] = 1
    starting_armies[.Algeria][.Ger][.ARTY] = 1

    // British territories
    starting_armies[.Eastern_Canada][.Eng][.TANK] = 1
    starting_armies[.United_Kingdom][.Eng][.INF] = 2
    starting_armies[.United_Kingdom][.Eng][.ARTY] = 1
    starting_armies[.United_Kingdom][.Eng][.TANK] = 1
    starting_armies[.Persia][.Eng][.INF] = 1
    starting_armies[.India][.Eng][.INF] = 3
    starting_armies[.Trans_Jordan][.Eng][.INF] = 1
    starting_armies[.Egypt][.Eng][.INF] = 1
    starting_armies[.Egypt][.Eng][.ARTY] = 1
    starting_armies[.Egypt][.Eng][.TANK] = 1
    starting_armies[.Union_of_South_Africa][.Eng][.INF] = 1
    starting_armies[.Eastern_Australia][.Eng][.INF] = 2
    starting_armies[.Western_Australia][.Eng][.INF] = 1
    starting_armies[.Burma][.Eng][.INF] = 1
    starting_armies[.New_Zealand][.Eng][.INF] = 1
    starting_armies[.Western_Canada][.Eng][.INF] = 1

    // Japanese territories
    starting_armies[.Manchuria][.Jap][.INF] = 3
    starting_armies[.Kwangtung][.Jap][.INF] = 1
    starting_armies[.Kwangtung][.Jap][.ARTY] = 1
    starting_armies[.Kiangsu][.Jap][.INF] = 4
    starting_armies[.French_Indo_China_Thailand][.Jap][.INF] = 2
    starting_armies[.French_Indo_China_Thailand][.Jap][.ARTY] = 1
    starting_armies[.Solomon_Islands][.Jap][.INF] = 1
    starting_armies[.New_Guinea][.Jap][.INF] = 1
    starting_armies[.Borneo][.Jap][.INF] = 1
    starting_armies[.East_Indies][.Jap][.INF] = 2
    starting_armies[.Philippine_Islands][.Jap][.INF] = 1
    starting_armies[.Philippine_Islands][.Jap][.ARTY] = 1
    starting_armies[.Malaya][.Jap][.INF] = 1
    starting_armies[.Iwo_Jima][.Jap][.INF] = 1
    starting_armies[.Caroline_Islands][.Jap][.INF] = 1
    starting_armies[.Okinawa][.Jap][.INF] = 1
    starting_armies[.Wake_Island][.Jap][.INF] = 1
    starting_armies[.Japan][.Jap][.INF] = 4
    starting_armies[.Japan][.Jap][.ARTY] = 1
    starting_armies[.Japan][.Jap][.TANK] = 1

    // American territories
    starting_armies[.Eastern_United_States][.USA][.INF] = 2
    starting_armies[.Eastern_United_States][.USA][.ARTY] = 1
    starting_armies[.Eastern_United_States][.USA][.TANK] = 1
    starting_armies[.Szechwan][.USA][.INF] = 2
    starting_armies[.Yunnan][.USA][.INF] = 2
    starting_armies[.Anhwei][.USA][.INF] = 2
    starting_armies[.Midway][.USA][.INF] = 1
    starting_armies[.Hawaiian_Islands][.USA][.INF] = 1
    starting_armies[.Alaska][.USA][.INF] = 1
    starting_armies[.Western_United_States][.USA][.INF] = 2
    starting_armies[.Central_United_States][.USA][.INF] = 1
}

@(init)
init_starting_land_planes :: proc() {
    // Russian territories
    starting_land_planes[.Karelia_SSR][.Rus][.FIGHTER] = 1
    starting_land_planes[.Russia][.Rus][.FIGHTER] = 1

    // German territories
    starting_land_planes[.Northwestern_Europe][.Ger][.FIGHTER] = 1
    starting_land_planes[.Germany][.Ger][.FIGHTER] = 1
    starting_land_planes[.Germany][.Ger][.BOMBER] = 1
    starting_land_planes[.Norway][.Ger][.FIGHTER] = 1
    starting_land_planes[.Bulgaria_Romania][.Ger][.FIGHTER] = 1
    starting_land_planes[.Poland][.Ger][.FIGHTER] = 1
    starting_land_planes[.Ukraine_SSR][.Ger][.FIGHTER] = 1

    // British territories
    starting_land_planes[.United_Kingdom][.Eng][.FIGHTER] = 2
    starting_land_planes[.United_Kingdom][.Eng][.BOMBER] = 1
    starting_land_planes[.Egypt][.Eng][.FIGHTER] = 1

    // Japanese territories
    starting_land_planes[.Manchuria][.Jap][.FIGHTER] = 1
    starting_land_planes[.French_Indo_China_Thailand][.Jap][.FIGHTER] = 1
    starting_land_planes[.Japan][.Jap][.FIGHTER] = 1
    starting_land_planes[.Japan][.Jap][.BOMBER] = 1

    // American territories
    starting_land_planes[.Eastern_United_States][.USA][.FIGHTER] = 1
    starting_land_planes[.Eastern_United_States][.USA][.BOMBER] = 1
    starting_land_planes[.Szechwan][.USA][.FIGHTER] = 1
    starting_land_planes[.Hawaiian_Islands][.USA][.FIGHTER] = 1
    starting_land_planes[.Western_United_States][.USA][.FIGHTER] = 1
}
