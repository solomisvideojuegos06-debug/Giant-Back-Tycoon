--!strict
--[[
	Config/Products: Developer Products y Game Passes (GDD, sección H).

	IMPORTANTE: los ids son 0 hasta que se creen los productos en el Creator
	Hub (Monetization). Con id 0:
	  - en Studio, comprar concede el producto directamente (modo prueba);
	  - en un servidor publicado, el botón de compra no hace nada.
]]

export type ProductDef = {
	id: number,
	displayName: string,
	description: string,
	robux: number, -- precio orientativo (el real se pone en el Creator Hub)
	coins: number?, -- paquetes de monedas
}

export type PassDef = {
	id: number,
	displayName: string,
	description: string,
	robux: number,
	skin: string?, -- pieles: clave de Config/Skins
}

local Products = table.freeze({
	products = table.freeze({
		Banquet = {
			id = 0,
			displayName = "Banquete",
			description = "+50 % de la Fruta que falta para el siguiente nivel",
			robux = 29,
		} :: ProductDef,
		InstantHatch = {
			id = 0,
			displayName = "Eclosión inmediata",
			description = "El huevo eclosiona ahora",
			robux = 49,
		} :: ProductDef,
		FruitRain = {
			id = 0,
			displayName = "Lluvia de fruta",
			description = "x2 Fruta para todo el servidor durante 10 min",
			robux = 99,
		} :: ProductDef,
		CoinsSmall = { id = 0, displayName = "Saco de monedas", description = "", robux = 49, coins = 500 } :: ProductDef,
		CoinsMedium = { id = 0, displayName = "Cofre de monedas", description = "", robux = 149, coins = 2000 } :: ProductDef,
		CoinsLarge = { id = 0, displayName = "Tesoro de monedas", description = "", robux = 399, coins = 6000 } :: ProductDef,
	}),

	passes = table.freeze({
		DoubleCoins = {
			id = 0,
			displayName = "x2 Monedas",
			description = "Todo lo procesado vale el doble",
			robux = 249,
		} :: PassDef,
		ExpertPilot = {
			id = 0,
			displayName = "Piloto experto",
			description = "Piloto automático a velocidad completa que busca los mejores recursos",
			robux = 149,
		} :: PassDef,
		DoubleNest = {
			id = 0,
			displayName = "Nido doble",
			description = "Incuba 2 huevos a la vez y elige con cuál continuar",
			robux = 199,
		} :: PassDef,
		BigStorage = {
			id = 0,
			displayName = "Almacén gigante",
			description = "+100 % de capacidad de almacén",
			robux = 99,
		} :: PassDef,
		SkinGolden = {
			id = 0,
			displayName = "Piel dorada",
			description = "Tu gigante, de oro",
			robux = 199,
			skin = "Golden",
		} :: PassDef,
		SkinNight = {
			id = 0,
			displayName = "Piel nocturna",
			description = "Azul noche con detalles que brillan",
			robux = 99,
			skin = "Night",
		} :: PassDef,
		SkinCandy = {
			id = 0,
			displayName = "Piel caramelo",
			description = "Rosa y menta",
			robux = 49,
			skin = "Candy",
		} :: PassDef,
	}),
})

return Products
