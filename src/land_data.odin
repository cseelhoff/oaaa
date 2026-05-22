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

starting_money := [Nation_ID]u8{.Russia = 24, .Germany = 41, .United_Kingdom = 31, .Japan = 30, .USA = 42}
starting_armies : [Land_ID][Nation_ID][Roster_Army]u8
starting_land_planes : [Land_ID][Nation_ID][Roster_Plane]u8

@(init)
init_starting_armies :: proc() {
    // Russian territories
    starting_armies[.Karelia_SSR][.Russia][.Infantry] = 4
    starting_armies[.Karelia_SSR][.Russia][.Artillery] = 1
    starting_armies[.Archangel][.Russia][.Infantry] = 1
    starting_armies[.Archangel][.Russia][.Tank] = 1
    starting_armies[.Caucasus][.Russia][.Infantry] = 3
    starting_armies[.Caucasus][.Russia][.Artillery] = 1
    starting_armies[.Caucasus][.Russia][.Tank] = 1
    starting_armies[.Russia][.Russia][.Infantry] = 4
    starting_armies[.Russia][.Russia][.Artillery] = 1
    starting_armies[.Russia][.Russia][.Tank] = 2
    starting_armies[.Evenki_National_Okrug][.Russia][.Infantry] = 2
    starting_armies[.Novosibirsk][.Russia][.Infantry] = 1
    starting_armies[.Yakut_SSR][.Russia][.Infantry] = 1
    starting_armies[.Soviet_Far_East][.Russia][.Infantry] = 2
    starting_armies[.Buryatia_SSR][.Russia][.Infantry] = 2
    starting_armies[.Kazakh_SSR][.Russia][.Infantry] = 1

    // German territories
    starting_armies[.France][.Germany][.Infantry] = 1
    starting_armies[.France][.Germany][.Tank] = 2
    starting_armies[.Northwestern_Europe][.Germany][.Infantry] = 1
    starting_armies[.Northwestern_Europe][.Germany][.Tank] = 1
    starting_armies[.Italy][.Germany][.Infantry] = 1
    starting_armies[.Italy][.Germany][.Tank] = 1
    starting_armies[.Southern_Europe][.Germany][.Infantry] = 1
    starting_armies[.Southern_Europe][.Germany][.Artillery] = 1
    starting_armies[.Germany][.Germany][.Infantry] = 3
    starting_armies[.Germany][.Germany][.Tank] = 2
    starting_armies[.Norway][.Germany][.Infantry] = 2
    starting_armies[.Finland][.Germany][.Infantry] = 3
    starting_armies[.Bulgaria_Romania][.Germany][.Infantry] = 2
    starting_armies[.Bulgaria_Romania][.Germany][.Tank] = 1
    starting_armies[.Poland][.Germany][.Infantry] = 2
    starting_armies[.Poland][.Germany][.Tank] = 1
    starting_armies[.Baltic_States][.Germany][.Infantry] = 1
    starting_armies[.Baltic_States][.Germany][.Tank] = 1
    starting_armies[.Ukraine_SSR][.Germany][.Infantry] = 3
    starting_armies[.Ukraine_SSR][.Germany][.Artillery] = 1
    starting_armies[.Ukraine_SSR][.Germany][.Tank] = 1
    starting_armies[.Belorussia][.Germany][.Infantry] = 3
    starting_armies[.West_Russia][.Germany][.Infantry] = 3
    starting_armies[.West_Russia][.Germany][.Artillery] = 1
    starting_armies[.West_Russia][.Germany][.Tank] = 1
    starting_armies[.Morocco][.Germany][.Infantry] = 1
    starting_armies[.Libya][.Germany][.Infantry] = 1
    starting_armies[.Libya][.Germany][.Tank] = 1
    starting_armies[.Algeria][.Germany][.Infantry] = 1
    starting_armies[.Algeria][.Germany][.Artillery] = 1

    // British territories
    starting_armies[.Eastern_Canada][.United_Kingdom][.Tank] = 1
    starting_armies[.United_Kingdom][.United_Kingdom][.Infantry] = 2
    starting_armies[.United_Kingdom][.United_Kingdom][.Artillery] = 1
    starting_armies[.United_Kingdom][.United_Kingdom][.Tank] = 1
    starting_armies[.Persia][.United_Kingdom][.Infantry] = 1
    starting_armies[.India][.United_Kingdom][.Infantry] = 3
    starting_armies[.Trans_Jordan][.United_Kingdom][.Infantry] = 1
    starting_armies[.Egypt][.United_Kingdom][.Infantry] = 1
    starting_armies[.Egypt][.United_Kingdom][.Artillery] = 1
    starting_armies[.Egypt][.United_Kingdom][.Tank] = 1
    starting_armies[.Union_of_South_Africa][.United_Kingdom][.Infantry] = 1
    starting_armies[.Eastern_Australia][.United_Kingdom][.Infantry] = 2
    starting_armies[.Western_Australia][.United_Kingdom][.Infantry] = 1
    starting_armies[.Burma][.United_Kingdom][.Infantry] = 1
    starting_armies[.New_Zealand][.United_Kingdom][.Infantry] = 1
    starting_armies[.Western_Canada][.United_Kingdom][.Infantry] = 1

    // Japanese territories
    starting_armies[.Manchuria][.Japan][.Infantry] = 3
    starting_armies[.Kwangtung][.Japan][.Infantry] = 1
    starting_armies[.Kwangtung][.Japan][.Artillery] = 1
    starting_armies[.Kiangsu][.Japan][.Infantry] = 4
    starting_armies[.French_Indo_China_Thailand][.Japan][.Infantry] = 2
    starting_armies[.French_Indo_China_Thailand][.Japan][.Artillery] = 1
    starting_armies[.Solomon_Islands][.Japan][.Infantry] = 1
    starting_armies[.New_Guinea][.Japan][.Infantry] = 1
    starting_armies[.Borneo][.Japan][.Infantry] = 1
    starting_armies[.East_Indies][.Japan][.Infantry] = 2
    starting_armies[.Philippine_Islands][.Japan][.Infantry] = 1
    starting_armies[.Philippine_Islands][.Japan][.Artillery] = 1
    starting_armies[.Malaya][.Japan][.Infantry] = 1
    starting_armies[.Iwo_Jima][.Japan][.Infantry] = 1
    starting_armies[.Caroline_Islands][.Japan][.Infantry] = 1
    starting_armies[.Okinawa][.Japan][.Infantry] = 1
    starting_armies[.Wake_Island][.Japan][.Infantry] = 1
    starting_armies[.Japan][.Japan][.Infantry] = 4
    starting_armies[.Japan][.Japan][.Artillery] = 1
    starting_armies[.Japan][.Japan][.Tank] = 1

    // American territories
    starting_armies[.Eastern_United_States][.USA][.Infantry] = 2
    starting_armies[.Eastern_United_States][.USA][.Artillery] = 1
    starting_armies[.Eastern_United_States][.USA][.Tank] = 1
    starting_armies[.Szechwan][.USA][.Infantry] = 2
    starting_armies[.Yunnan][.USA][.Infantry] = 2
    starting_armies[.Anhwei][.USA][.Infantry] = 2
    starting_armies[.Midway][.USA][.Infantry] = 1
    starting_armies[.Hawaiian_Islands][.USA][.Infantry] = 1
    starting_armies[.Alaska][.USA][.Infantry] = 1
    starting_armies[.Western_United_States][.USA][.Infantry] = 2
    starting_armies[.Central_United_States][.USA][.Infantry] = 1
}

@(init)
init_starting_land_planes :: proc() {
    // Russian territories
    starting_land_planes[.Karelia_SSR][.Russia][.Fighter] = 1
    starting_land_planes[.Russia][.Russia][.Fighter] = 1

    // German territories
    starting_land_planes[.Northwestern_Europe][.Germany][.Fighter] = 1
    starting_land_planes[.Germany][.Germany][.Fighter] = 1
    starting_land_planes[.Germany][.Germany][.Bomber] = 1
    starting_land_planes[.Norway][.Germany][.Fighter] = 1
    starting_land_planes[.Bulgaria_Romania][.Germany][.Fighter] = 1
    starting_land_planes[.Poland][.Germany][.Fighter] = 1
    starting_land_planes[.Ukraine_SSR][.Germany][.Fighter] = 1

    // British territories
    starting_land_planes[.United_Kingdom][.United_Kingdom][.Fighter] = 2
    starting_land_planes[.United_Kingdom][.United_Kingdom][.Bomber] = 1
    starting_land_planes[.Egypt][.United_Kingdom][.Fighter] = 1

    // Japanese territories
    starting_land_planes[.Manchuria][.Japan][.Fighter] = 1
    starting_land_planes[.French_Indo_China_Thailand][.Japan][.Fighter] = 1
    starting_land_planes[.Japan][.Japan][.Fighter] = 1
    starting_land_planes[.Japan][.Japan][.Bomber] = 1

    // American territories
    starting_land_planes[.Eastern_United_States][.USA][.Fighter] = 1
    starting_land_planes[.Eastern_United_States][.USA][.Bomber] = 1
    starting_land_planes[.Szechwan][.USA][.Fighter] = 1
    starting_land_planes[.Hawaiian_Islands][.USA][.Fighter] = 1
    starting_land_planes[.Western_United_States][.USA][.Fighter] = 1
}
