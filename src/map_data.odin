package oaaa

mm: MapData = {
	capital = {.Rus = .Russia, .Ger = .Germany, .Eng = .United_Kingdom, .Jap = .Japan, .USA = .Eastern_United_States},
	team = {.Rus = .Allies, .Ger = .Axis, .Eng = .Allies, .Jap = .Axis, .USA = .Allies},
	value = {
		.Alaska = 2,
		.Algeria = 1,
		.Anglo_Egyptian_Sudan = 0,
		.Anhwei = 1,
		.Archangel = 1,
		.Baltic_States = 2,
		.Belgian_Congo = 1,
		.Belorussia = 2,
		.Borneo = 4,
		.Brazil = 3,
		.Bulgaria_Romania = 2,
		.Burma = 1,
		.Buryatia_SSR = 1,
		.Caroline_Islands = 0,
		.Caucasus = 4,
		.Central_America = 1,
		.Central_United_States = 6,
		.East_Indies = 4,
		.East_Mexico = 0,
		.Eastern_Australia = 1,
		.Eastern_Canada = 3,
		.Eastern_United_States = 12,
		.Egypt = 2,
		.Evenki_National_Okrug = 1,
		.Finland = 1,
		.Formosa = 0,
		.France = 6,
		.French_Equatorial_Africa = 1,
		.French_Indo_China_Thailand = 2,
		.French_Madagascar = 1,
		.French_West_Africa = 1,
		.Germany = 10,
		.Gibraltar = 0,
		.Greenland = 0,
		.Hawaiian_Islands = 1,
		.Iceland = 0,
		.India = 3,
		.Italian_East_Africa = 1,
		.Italy = 3,
		.Iwo_Jima = 0,
		.Japan = 8,
		.Karelia_SSR = 2,
		.Kazakh_SSR = 2,
		.Kiangsu = 2,
		.Kwangtung = 2,
		.Libya = 1,
		.Malaya = 1,
		.Manchuria = 3,
		.Mexico = 2,
		.Midway = 0,
		.Morocco = 1,
		.New_Guinea = 1,
		.New_Zealand = 1,
		.Northwestern_Europe = 2,
		.Norway = 2,
		.Novosibirsk = 1,
		.Okinawa = 0,
		.Persia = 1,
		.Philippine_Islands = 3,
		.Poland = 2,
		.Rhodesia = 1,
		.Russia = 8,
		.Sinkiang = 1,
		.Solomon_Islands = 0,
		.Southern_Europe = 2,
		.Soviet_Far_East = 1,
		.Szechwan = 1,
		.Trans_Jordan = 1,
		.Ukraine_SSR = 2,
		.Union_of_South_Africa = 2,
		.United_Kingdom = 8,
		.Vologda = 2,
		.Wake_Island = 0,
		.West_Indies = 1,
		.West_Russia = 2,
		.Western_Australia = 1,
		.Western_Canada = 1,
		.Western_United_States = 10,
		.Yakut_SSR = 1,
		.Yunnan = 1,
	},
	orig_owner = {
		// Russian territories
		.Evenki_National_Okrug = .Rus,
		.Karelia_SSR = .Rus,
		.Soviet_Far_East = .Rus,
		.Archangel = .Rus,
		.Russia = .Rus,
		.Yakut_SSR = .Rus,
		.Novosibirsk = .Rus,
		.Buryatia_SSR = .Rus,
		.Vologda = .Rus,
		.Kazakh_SSR = .Rus,
		.Caucasus = .Rus,

		// German territories
		.Morocco = .Ger,
		.Baltic_States = .Ger,
		.France = .Ger,
		.Northwestern_Europe = .Ger,
		.Algeria = .Ger,
		.Bulgaria_Romania = .Ger,
		.Ukraine_SSR = .Ger,
		.Poland = .Ger,
		.Norway = .Ger,
		.Germany = .Ger,
		.Italy = .Ger,
		.Southern_Europe = .Ger,
		.Libya = .Ger,
		.Belorussia = .Ger,
		.West_Russia = .Ger,
		.Finland = .Ger,

		// British territories
		.French_Equatorial_Africa = .Eng,
		.Belgian_Congo = .Eng,
		.French_Madagascar = .Eng,
		.Iceland = .Eng,
		.Anglo_Egyptian_Sudan = .Eng,
		.Trans_Jordan = .Eng,
		.Burma = .Eng,
		.Eastern_Australia = .Eng,
		.Egypt = .Eng,
		.Union_of_South_Africa = .Eng,
		.Western_Canada = .Eng,
		.Eastern_Canada = .Eng,
		.New_Zealand = .Eng,
		.India = .Eng,
		.Italian_East_Africa = .Eng,
		.French_West_Africa = .Eng,
		.Persia = .Eng,
		.Western_Australia = .Eng,
		.Gibraltar = .Eng,
		.United_Kingdom = .Eng,
		.Rhodesia = .Eng,

		// Japanese territories
		.Caroline_Islands = .Jap,
		.Iwo_Jima = .Jap,
		.Wake_Island = .Jap,
		.Formosa = .Jap,
		.Kiangsu = .Jap,
		.Japan = .Jap,
		.Malaya = .Jap,
		.Borneo = .Jap,
		.East_Indies = .Jap,
		.Philippine_Islands = .Jap,
		.Kwangtung = .Jap,
		.Okinawa = .Jap,
		.French_Indo_China_Thailand = .Jap,
		.Solomon_Islands = .Jap,
		.New_Guinea = .Jap,
		.Manchuria = .Jap,

		// American territories
		.West_Indies = .USA,
		.Anhwei = .USA,
		.Mexico = .USA,
		.Yunnan = .USA,
		.Western_United_States = .USA,
		.Central_United_States = .USA,
		.Sinkiang = .USA,
		.East_Mexico = .USA,
		.Alaska = .USA,
		.Central_America = .USA,
		.Greenland = .USA,
		.Szechwan = .USA,
		.Brazil = .USA,
		.Eastern_United_States = .USA,
		.Hawaiian_Islands = .USA,
		.Midway = .USA,
	},
	color = {
		.Rus = "\033[1;31m",
		.Ger = "\033[1;34m",
		.Eng = "\033[1;95m",
		.Jap = "\033[1;33m",
		.USA = "\033[1;32m",
	},
}