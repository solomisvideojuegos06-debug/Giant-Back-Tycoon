--!strict
-- Config/Skins: pieles de gigante (cosméticas, GDD sección H). Cambian la paleta.

export type SkinDef = {
	displayName: string,
	primary: Color3,
	secondary: Color3,
	accent: Color3,
	material: Enum.Material?,
	neonAccent: boolean?,
}

local Skins: { [string]: SkinDef } = {
	Golden = {
		displayName = "Dorada",
		primary = Color3.fromRGB(255, 200, 50),
		secondary = Color3.fromRGB(200, 140, 20),
		accent = Color3.fromRGB(255, 245, 200),
		material = Enum.Material.SmoothPlastic,
	},
	Night = {
		displayName = "Nocturna",
		primary = Color3.fromRGB(40, 50, 110),
		secondary = Color3.fromRGB(20, 25, 60),
		accent = Color3.fromRGB(120, 220, 255),
		neonAccent = true,
	},
	Candy = {
		displayName = "Caramelo",
		primary = Color3.fromRGB(255, 140, 200),
		secondary = Color3.fromRGB(120, 230, 200),
		accent = Color3.fromRGB(255, 255, 255),
	},
}

return table.freeze(Skins)
