-- Строит стадион «Спортинга» из блоков, когда сервер запускается.
-- Возвращает таблицу Map с важными точками: где лобби, тюрьма, ворота, места для Кубка и т.д.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local StadiumDetails = require(script.Parent.StadiumDetails)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

-- Текстура газона поверх цвета (если загружена)
local function grassTexture(p: BasePart)
	if Config.TEXTURES.Grass > 0 then
		local texture = Instance.new("Texture")
		texture.Texture = "rbxassetid://" .. Config.TEXTURES.Grass
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU = 24
		texture.StudsPerTileV = 24
		texture.Transparency = 0.35
		texture.Parent = p
	end
end

local StadiumBuilder = {}

-- Размеры поля (в студах). Центр поля — точка (0, 0, 0).
local FIELD_X = 110 -- половина длины поля (ворота на x = ±110)
local FIELD_Z = 70 -- половина ширины поля
local GROUND_X = 190
local GROUND_Z = 200

local GOAL_HALF_WIDTH = 8
local GOAL_HEIGHT = 8
local GOAL_DEPTH = 6

-- Трибуны
local ROWS = 10
local ROW_DEPTH = 4
local ROW_RISE = 2
local FIRST_ROW = 3
local STAND_DEPTH = 1 + ROWS * ROW_DEPTH -- 41
local STAND_TOP = FIRST_ROW + (ROWS - 1) * ROW_RISE -- 21
local AISLE = 6
local TUNNEL_WIDTH = 10
local ROOF_Y = 34

-- Цвета «Спортинга»
local GREEN = Color3.fromRGB(0, 128, 72)
local WHITE = Color3.fromRGB(240, 240, 240)
local GRASS = Color3.fromRGB(58, 125, 52)
local GRASS_LIGHT = Color3.fromRGB(72, 145, 62)
local CONCRETE = Color3.fromRGB(150, 150, 155)
local DARK = Color3.fromRGB(45, 45, 50)
local STATUE_STONE = Color3.fromRGB(163, 162, 165)
local SEAT_COLORS = {
	Color3.fromRGB(0, 133, 75), -- зелёный
	Color3.fromRGB(0, 133, 75),
	Color3.fromRGB(110, 190, 70), -- салатовый
	Color3.fromRGB(250, 205, 20), -- жёлтый
	Color3.fromRGB(240, 240, 240), -- белый
	Color3.fromRGB(30, 110, 180), -- синий
	Color3.fromRGB(230, 120, 30), -- оранжевый
}
local mosaic = Random.new(7) -- одна и та же мозаика при каждом запуске

local function make(className: string, parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return make("Part", parent, cf, size, color, material)
end

-- Украшение, через которое можно проходить (линии, полосы газона)
local function deco(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = box(parent, cf, size, color, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Белая линия на газоне от точки a до точки b
local function line(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	deco(parent, CFrame.lookAt(mid, b), Vector3.new(1, 0.2, length + 1), WHITE)
end

local function lightingEffect(className: string, props: { [string]: any })
	local old = Lighting:FindFirstChildOfClass(className)
	if old then
		old:Destroy()
	end
	local effect = Instance.new(className)
	for k, v in props do
		(effect :: any)[k] = v
	end
	effect.Parent = Lighting
	return effect
end

-- Вечерний матч: тёмно-синее небо со звёздами, лёгкая дымка, свечение прожекторов.
-- Самое красивое освещение (Future) включается в default.project.json — скриптом его не поменять.
local function setupLighting()
	Lighting.ClockTime = 20.3
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(38, 42, 56)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 84, 108)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	local sky = lightingEffect("Sky", { StarCount = 3000, CelestialBodiesShown = true })
	local faces = Config.TEXTURES.Sky
	if faces.Bk > 0 then
		for _, face in { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" } do
			(sky :: any)["Skybox" .. face] = "rbxassetid://" .. faces[face]
		end
	end
	lightingEffect("Atmosphere", {
		Density = 0.32,
		Offset = 0.2,
		Color = Color3.fromRGB(105, 115, 150),
		Decay = Color3.fromRGB(50, 60, 95),
		Glare = 0.3,
		Haze = 1.4,
	})
	lightingEffect("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.4 })
	lightingEffect("ColorCorrectionEffect", {
		Brightness = 0.02,
		Contrast = 0.1,
		Saturation = 0.12,
		TintColor = Color3.fromRGB(255, 250, 240),
	})
	lightingEffect("SunRaysEffect", { Intensity = 0.02, Spread = 0.6 })
end

local function buildPitch(root: Instance)
	local m = folder("Pitch", root)
	grassTexture(box(m, CFrame.new(0, -1, 0), Vector3.new(GROUND_X * 2, 2, GROUND_Z * 2), GRASS, Enum.Material.Grass))

	-- Полосы газона (как после стрижки)
	for i = 0, 10 do
		if i % 2 == 0 then
			grassTexture(deco(m, CFrame.new(-FIELD_X + 10 + i * 20, 0.05, 0), Vector3.new(20, 0.1, FIELD_Z * 2), GRASS_LIGHT, Enum.Material.Grass))
		end
	end

	local function L(x1, z1, x2, z2)
		line(m, Vector3.new(x1, 0.1, z1), Vector3.new(x2, 0.1, z2))
	end

	-- Границы поля и средняя линия
	L(-FIELD_X, -FIELD_Z, FIELD_X, -FIELD_Z)
	L(-FIELD_X, FIELD_Z, FIELD_X, FIELD_Z)
	L(-FIELD_X, -FIELD_Z, -FIELD_X, FIELD_Z)
	L(FIELD_X, -FIELD_Z, FIELD_X, FIELD_Z)
	L(0, -FIELD_Z, 0, FIELD_Z)

	-- Центральный круг
	local segments = 32
	local radius = 18
	for i = 0, segments - 1 do
		local a1 = i / segments * math.pi * 2
		local a2 = (i + 1) / segments * math.pi * 2
		L(math.cos(a1) * radius, math.sin(a1) * radius, math.cos(a2) * radius, math.sin(a2) * radius)
	end
	deco(m, CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 2, 2), WHITE).Shape = Enum.PartType.Cylinder

	-- Штрафные и вратарские площади
	for _, s in { -1, 1 } do
		local x0 = s * FIELD_X
		local x1 = s * (FIELD_X - 36)
		L(x1, -40, x1, 40)
		L(x0, -40, x1, -40)
		L(x0, 40, x1, 40)
		local x2 = s * (FIELD_X - 12)
		L(x2, -18, x2, 18)
		L(x0, -18, x2, -18)
		L(x0, 18, x2, 18)
		deco(m, CFrame.new(s * (FIELD_X - 24), 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 1.5, 1.5), WHITE).Shape =
			Enum.PartType.Cylinder
	end

	-- Угловые флажки
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, CFrame.new(sx * FIELD_X, 2.5, sz * FIELD_Z), Vector3.new(0.3, 5, 0.3), WHITE).CanCollide = false
			deco(m, CFrame.new(sx * FIELD_X, 4.5, sz * FIELD_Z + 0.8), Vector3.new(0.1, 1, 1.4), Color3.fromRGB(255, 220, 0))
		end
	end
end

-- Ворота. Возвращает границы зоны «гола».
local function buildGoal(root: Instance, s: number)
	local m = folder(s > 0 and "GoalEast" or "GoalWest", root)
	local x = s * FIELD_X
	local back = x + s * GOAL_DEPTH
	local w = GOAL_HALF_WIDTH
	local h = GOAL_HEIGHT

	-- Штанги и перекладина
	for _, sz in { -1, 1 } do
		box(m, CFrame.new(x, h / 2, sz * (w + 0.5)), Vector3.new(1, h, 1), WHITE, Enum.Material.Metal)
	end
	box(m, CFrame.new(x, h + 0.5, 0), Vector3.new(1, 1, w * 2 + 2), WHITE, Enum.Material.Metal)

	-- Сетка
	-- Сетка: невидимая стенка (чтобы мяч и игроки не проходили) и нитки клеточкой
	local function net(cf: CFrame, size: Vector3)
		local wall = box(m, cf, size, WHITE, Enum.Material.Fabric)
		wall.Transparency = 1
		local thin = math.min(size.X, size.Y, size.Z)
		local axes = {}
		for _, axis in { "X", "Y", "Z" } do
			if size[axis] > thin then
				table.insert(axes, axis)
			end
		end
		local function unit(axis: string): Vector3
			return Vector3.new(if axis == "X" then 1 else 0, if axis == "Y" then 1 else 0, if axis == "Z" then 1 else 0)
		end
		for i, along in axes do
			local across = axes[3 - i]
			local length = size[along]
			local span = size[across]
			local count = math.floor(span / 1)
			for k = 0, count do
				local offset = unit(across) * (-span / 2 + k * span / count)
				local lineSize = unit(along) * length + Vector3.new(0.06, 0.06, 0.06)
				deco(m, cf + offset, lineSize, Color3.fromRGB(235, 235, 235), Enum.Material.Fabric)
			end
		end
	end
	net(CFrame.new(back, h / 2, 0), Vector3.new(0.3, h, w * 2 + 1))
	for _, sz in { -1, 1 } do
		net(CFrame.new(x + s * GOAL_DEPTH / 2, h / 2, sz * (w + 0.5)), Vector3.new(GOAL_DEPTH, h, 0.3))
	end
	net(CFrame.new(x + s * GOAL_DEPTH / 2, h, 0), Vector3.new(GOAL_DEPTH, 0.3, w * 2 + 1))

	return {
		XMin = math.min(x, back),
		XMax = math.max(x, back),
		ZHalf = w,
		YMax = h + 2,
	}
end

local function buildBench(root: Instance, x: number, z: number)
	local m = folder("Bench", root)
	local plexi = Color3.fromRGB(200, 220, 255)
	box(m, CFrame.new(x, 1.25, z), Vector3.new(14, 0.5, 2), GREEN)
	for _, sx in { -6, 0, 6 } do
		box(m, CFrame.new(x + sx, 0.5, z), Vector3.new(0.5, 1, 1.5), DARK, Enum.Material.Metal)
	end
	box(m, CFrame.new(x, 2.5, z + 1.2), Vector3.new(14, 3, 0.4), GREEN)
	local roof = box(m, CFrame.new(x, 5.5, z), Vector3.new(15, 0.3, 4), plexi, Enum.Material.Glass)
	roof.Transparency = 0.4
	for _, sx in { -1, 1 } do
		local side = box(m, CFrame.new(x + sx * 7.5, 2.75, z), Vector3.new(0.3, 5.5, 4), plexi, Enum.Material.Glass)
		side.Transparency = 0.4
	end
end

-- Одна трибуна. cf — где её передний край, трибуна поднимается в сторону своей оси +Z.
local function buildStand(root: Instance, name: string, cf: CFrame, length: number, withTunnel: boolean)
	local m = folder(name, root)
	local spots = {}

	local function place(localCF: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		return box(m, cf * localCF, size, color, material or Enum.Material.Concrete)
	end

	-- Проходы между секторами
	local gaps = {
		{ x = -length / 3, w = AISLE, kind = "ramp" },
		{ x = 0, w = withTunnel and TUNNEL_WIDTH or AISLE, kind = withTunnel and "tunnel" or "ramp" },
		{ x = length / 3, w = AISLE, kind = "ramp" },
	}
	local sectors = {}
	local cursor = -length / 2
	for _, g in gaps do
		table.insert(sectors, { cursor, g.x - g.w / 2 })
		cursor = g.x + g.w / 2
	end
	table.insert(sectors, { cursor, length / 2 })

	-- Ряды с сиденьями
	for _, sector in sectors do
		local w = sector[2] - sector[1]
		local cx = (sector[1] + sector[2]) / 2
		place(CFrame.new(cx, FIRST_ROW / 2, 0.5), Vector3.new(w, FIRST_ROW, 1), WHITE)
		local glass = place(CFrame.new(cx, FIRST_ROW + 0.6, 0.5), Vector3.new(w, 1.2, 0.2), Color3.fromRGB(200, 225, 240), Enum.Material.Glass)
		glass.Transparency = 0.6
		place(CFrame.new(cx, FIRST_ROW + 1.25, 0.5), Vector3.new(w, 0.15, 0.3), Color3.fromRGB(190, 195, 200), Enum.Material.Metal)
		for i = 0, ROWS - 1 do
			local top = FIRST_ROW + i * ROW_RISE
			local z0 = 1 + i * ROW_DEPTH
			place(CFrame.new(cx, top / 2, z0 + ROW_DEPTH / 2), Vector3.new(w, top, ROW_DEPTH), CONCRETE)
			-- Разноцветные сиденья мозаикой, как на стадионе «Алваладе»
			local chunks = math.max(1, math.floor(w / 5))
			local chunkW = w / chunks
			for c = 0, chunks - 1 do
				local seatColor = SEAT_COLORS[mosaic:NextInteger(1, #SEAT_COLORS)]
				local x = sector[1] + chunkW * (c + 0.5)
				place(CFrame.new(x, top + 0.5, z0 + 1.6), Vector3.new(chunkW - 0.25, 1, 1.4), seatColor, Enum.Material.SmoothPlastic)
				place(CFrame.new(x, top + 1.5, z0 + 3.2), Vector3.new(chunkW - 0.25, 3, 0.4), seatColor, Enum.Material.SmoothPlastic)
			end
		end
	end

	for _, g in gaps do
		if g.kind == "ramp" then
			-- Пандус, чтобы забежать наверх
			make(
				"WedgePart",
				m,
				cf * CFrame.new(g.x, STAND_TOP / 2, 1 + (STAND_DEPTH - 1) / 2),
				Vector3.new(g.w, STAND_TOP, STAND_DEPTH - 1),
				CONCRETE,
				Enum.Material.Concrete
			)
		else
			-- Туннель к раздевалкам
			local inner = g.w / 2 - 0.5
			for _, sx in { -1, 1 } do
				place(CFrame.new(g.x + sx * inner, 4.5, (STAND_DEPTH + 2) / 2), Vector3.new(1, 9, STAND_DEPTH + 2), DARK)
			end
			place(CFrame.new(g.x, 9.5, (STAND_DEPTH + 2) / 2), Vector3.new(g.w, 1, STAND_DEPTH + 2), DARK)
			local lamp = box(m, cf * CFrame.new(g.x, 8.8, STAND_DEPTH / 2), Vector3.new(1, 0.2, 4), WHITE, Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.5
			light.Parent = lamp
			table.insert(spots, cf * Vector3.new(g.x, 10, STAND_DEPTH - 6)) -- на крыше туннеля
		end
	end

	-- Задняя стена
	local backZ = STAND_DEPTH + 1
	if withTunnel then
		local half = TUNNEL_WIDTH / 2
		local sideLength = length / 2 - half
		place(CFrame.new(-(half + sideLength / 2), 15, backZ), Vector3.new(sideLength, 30, 2), CONCRETE)
		place(CFrame.new(half + sideLength / 2, 15, backZ), Vector3.new(sideLength, 30, 2), CONCRETE)
		place(CFrame.new(0, 19.5, backZ), Vector3.new(TUNNEL_WIDTH, 21, 2), CONCRETE)
	else
		place(CFrame.new(0, 15, backZ), Vector3.new(length, 30, 2), CONCRETE)
	end

	-- Крыша, колонны и прожекторы
	place(CFrame.new(0, ROOF_Y, (STAND_DEPTH + 2 - 4) / 2), Vector3.new(length + 4, 1, STAND_DEPTH + 6), WHITE, Enum.Material.Metal)
	for _, x in { -length / 2 + 2, -length / 6, length / 6, length / 2 - 2 } do
		place(CFrame.new(x, (ROOF_Y - 0.5) / 2, -3), Vector3.new(1.5, ROOF_Y - 0.5, 1.5), WHITE, Enum.Material.Metal)
	end
	local lamps = 6
	for k = 1, lamps do
		local x = -length / 2 + length * (k - 0.5) / lamps
		local lamp = box(m, cf * CFrame.new(x, ROOF_Y - 0.9, -2.5) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(8, 0.5, 2), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
		lamp.CanCollide = false
		box(m, cf * CFrame.new(x, ROOF_Y - 0.55, -2.4) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(8.4, 0.3, 2.4), DARK, Enum.Material.Metal).CanCollide = false
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 110
		spot.Range = 60
		spot.Brightness = 2.5
		spot.Color = Color3.fromRGB(255, 245, 225)
		spot.Parent = lamp
	end

	-- Лестница на крышу (снаружи, за задней стеной)
	make("TrussPart", m, cf * CFrame.new(length / 2 - 6, 18, STAND_DEPTH + 3), Vector3.new(2, 36, 2), DARK, Enum.Material.Metal)

	-- Места, где можно спрятать Кубок
	table.insert(spots, cf * Vector3.new(length / 2 - 12, ROOF_Y + 0.5, STAND_DEPTH - 2)) -- на крыше
	table.insert(spots, cf * Vector3.new(-length / 2 + 3, STAND_TOP, STAND_DEPTH - 3.5)) -- верхний ряд, в углу
	table.insert(spots, cf * Vector3.new(length / 4, FIRST_ROW + 4 * ROW_RISE, 1 + 4 * ROW_DEPTH + 0.4)) -- среди сидений

	return spots
end

-- Раздевалки за главной трибуной (в системе координат главной трибуны)
local function buildDressingRooms(root: Instance, cf: CFrame)
	local m = folder("DressingRooms", root)
	local spots = {}
	local H = 10
	local z0 = STAND_DEPTH + 2 -- 43
	local z1 = z0 + 30 -- 73
	local zMid = (z0 + z1) / 2
	local wallColor = Color3.fromRGB(225, 230, 225)

	local function place(localCF: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		return box(m, cf * localCF, size, color, material or Enum.Material.SmoothPlastic)
	end

	place(CFrame.new(0, 0.1, zMid), Vector3.new(60, 0.2, 30), Color3.fromRGB(200, 200, 205), Enum.Material.Marble)
	place(CFrame.new(-30.5, H / 2, zMid), Vector3.new(1, H, 30), wallColor)
	place(CFrame.new(30.5, H / 2, zMid), Vector3.new(1, H, 30), wallColor)
	place(CFrame.new(0, H / 2, z1 + 0.5), Vector3.new(62, H, 1), wallColor)
	place(CFrame.new(0, H + 0.5, zMid), Vector3.new(62, 1, 31), CONCRETE, Enum.Material.Concrete)

	local doorZ = zMid
	for _, sx in { -1, 1 } do
		local roomColor = if sx < 0 then GREEN else Color3.fromRGB(30, 60, 140)
		local x = sx * 5.5
		place(CFrame.new(x, H / 2, (z0 + doorZ - 3) / 2), Vector3.new(1, H, doorZ - 3 - z0), wallColor)
		place(CFrame.new(x, H / 2, (doorZ + 3 + z1) / 2), Vector3.new(1, H, z1 - doorZ - 3), wallColor)
		place(CFrame.new(x, (7 + H) / 2, doorZ), Vector3.new(1, H - 7, 6), wallColor)

		-- Шкафчики
		for j = 0, 5 do
			place(CFrame.new(sx * 28.5, 3.5, z0 + 3 + j * 4.5), Vector3.new(2, 7, 2), roomColor, Enum.Material.Metal)
		end
		-- Скамейка
		place(CFrame.new(sx * 18, 1, zMid), Vector3.new(3, 2, 20), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)

		local lamp = place(CFrame.new(sx * 18, H - 0.2, zMid), Vector3.new(4, 0.2, 4), WHITE, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.2
		light.Parent = lamp

		table.insert(spots, cf * Vector3.new(sx * 28.5, 0.2, z0 + 5.25)) -- между шкафчиками
		table.insert(spots, cf * Vector3.new(sx * 20.5, 0.2, z1 - 3)) -- в углу за скамейкой
	end
	table.insert(spots, cf * Vector3.new(0, 0.2, z1 - 2)) -- конец коридора

	return spots
end

local function buildScoreboard(root: Instance, cf: CFrame): TextLabel
	local board = box(root, cf, Vector3.new(44, 16, 2), DARK, Enum.Material.Metal)
	board.Name = "Scoreboard"
	for _, sx in { -18, 18 } do
		box(root, cf * CFrame.new(sx, -6, 3), Vector3.new(1, 4, 1), DARK, Enum.Material.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = "ПРЯТКИ ЗА КУБОК"
	label.Parent = gui
	return label
end

-- Тюрьма: клетка за западными воротами
local function buildJail(root: Instance, center: Vector3)
	local m = folder("Jail", root)
	local half = 7
	local height = 10
	box(m, CFrame.new(center + Vector3.new(0, 0.25, 0)), Vector3.new(half * 2, 0.5, half * 2), DARK, Enum.Material.DiamondPlate)
	box(m, CFrame.new(center + Vector3.new(0, height + 0.25, 0)), Vector3.new(half * 2 + 1, 0.5, half * 2 + 1), DARK, Enum.Material.DiamondPlate)
	for i = 0, 7 do
		local t = -half + i * 2
		for _, pos in { Vector3.new(t, 0, -half), Vector3.new(half, 0, t), Vector3.new(-t, 0, half), Vector3.new(-half, 0, -t) } do
			box(m, CFrame.new(center + pos + Vector3.new(0, height / 2, 0)), Vector3.new(0.5, height, 0.5), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
		end
	end
	local sign = box(m, CFrame.new(center + Vector3.new(half + 0.6, height - 1.5, 0)) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(8, 2, 0.2), Color3.fromRGB(180, 30, 30))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = "ТЮРЬМА"
	label.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 80)
	light.Range = 16
	light.Parent = sign
	return half
end

-- Лобби — стеклянная ложа высоко над стадионом
local function buildLobby(root: Instance, center: Vector3)
	local m = folder("Lobby", root)
	local size = 60
	-- VIP-ложа: ковёр цвета газона, деревянный край, стеклянные стены с видом на ночной город
	box(m, CFrame.new(center), Vector3.new(size, 1, size), Color3.fromRGB(30, 95, 55), Enum.Material.Fabric)
	box(m, CFrame.new(center + Vector3.new(0, 0.55, 0)), Vector3.new(size - 8, 0.1, size - 8), Color3.fromRGB(40, 120, 70), Enum.Material.Fabric)
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local trimSize = if d.X ~= 0 then Vector3.new(2, 1.2, size) else Vector3.new(size, 1.2, 2)
		box(m, CFrame.new(center + d * (size / 2 - 1) + Vector3.new(0, 1, 0)), trimSize, Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
	end
	for _, x in { -18, 18 } do
		for _, z in { -18, 18 } do
			local lamp = box(m, CFrame.new(center + Vector3.new(x, 13.3, z)), Vector3.new(4, 0.3, 4), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Range = 30
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 235, 200)
			light.Parent = lamp
		end
	end
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local wallSize = if d.X ~= 0 then Vector3.new(1, 14, size) else Vector3.new(size, 14, 1)
		local wall = box(m, CFrame.new(center + d * (size / 2) + Vector3.new(0, 7, 0)), wallSize, WHITE, Enum.Material.Glass)
		wall.Transparency = 0.8
	end
	local roof = box(m, CFrame.new(center + Vector3.new(0, 14, 0)), Vector3.new(size, 1, size), WHITE, Enum.Material.Glass)
	roof.Transparency = 0.9

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0))
	spawn.Color = Color3.fromRGB(255, 200, 50)
	spawn.Material = Enum.Material.Foil
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = m

	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1.5
	light.Parent = spawn
end

local function buildSeekerBox(root: Instance, center: Vector3)
	local m = folder("SeekerBox", root)
	local s = 14
	for _, cf in
		{
			CFrame.new(center + Vector3.new(0, -0.5, 0)),
			CFrame.new(center + Vector3.new(0, 10.5, 0)),
		}
	do
		box(m, cf, Vector3.new(s, 1, s), DARK)
	end
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local wallSize = if d.X ~= 0 then Vector3.new(1, 10, s) else Vector3.new(s, 10, 1)
		box(m, CFrame.new(center + d * (s / 2) + Vector3.new(0, 5, 0)), wallSize, DARK)
	end
	local label = box(m, CFrame.new(center + Vector3.new(0, 6, -s / 2 + 0.6)), Vector3.new(10, 3, 0.2), Color3.fromRGB(150, 20, 20))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = label
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = WHITE
	text.TextScaled = true
	text.Font = Enum.Font.SourceSansBold
	text.Text = "Не подглядывай! Скоро выпустим..."
	text.Parent = gui
end

function StadiumBuilder.build()
	local old = Workspace:FindFirstChild("Stadium")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Stadium"

	setupLighting()
	buildPitch(root)

	local goals = { buildGoal(root, 1), buildGoal(root, -1) }

	buildBench(root, -25, FIELD_Z + 8)
	buildBench(root, 25, FIELD_Z + 8)

	local trophySpots = {}
	local function addSpots(list)
		for _, p in list do
			table.insert(trophySpots, p)
		end
	end

	local northCF = CFrame.new(0, 0, 85)
	local southCF = CFrame.new(0, 0, -85) * CFrame.Angles(0, math.pi, 0)
	local eastCF = CFrame.new(135, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	local westCF = CFrame.new(-135, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)

	addSpots(buildStand(root, "MainStand", northCF, 230, true))
	addSpots(buildStand(root, "SouthStand", southCF, 230, false))
	addSpots(buildStand(root, "EastStand", eastCF, 170, false))
	addSpots(buildStand(root, "WestStand", westCF, 170, false))
	addSpots(buildDressingRooms(root, northCF))

	local scoreboardCF = eastCF * CFrame.new(0, ROOF_Y + 0.5 + 8, 18)
	local scoreboard = buildScoreboard(root, scoreboardCF)
	table.insert(trophySpots, (eastCF * CFrame.new(-10, ROOF_Y + 0.5, 22)).Position) -- за табло

	-- Ещё места: за скамейками и в углах стадиона
	table.insert(trophySpots, Vector3.new(-25, 0, FIELD_Z + 10.5))
	table.insert(trophySpots, Vector3.new(25, 0, FIELD_Z + 10.5))
	table.insert(trophySpots, Vector3.new(125, 0, 100))
	table.insert(trophySpots, Vector3.new(-125, 0, -100))

	local jailCenter = Vector3.new(-124, 0, 45)
	local jailHalf = buildJail(root, jailCenter)

	-- Места, где прячутся боты: все места Кубка и ещё несколько
	local hideSpots = table.clone(trophySpots)
	for _, s in { -1, 1 } do
		table.insert(hideSpots, Vector3.new(s * (FIELD_X + GOAL_DEPTH + 3), 0, 5)) -- за сеткой ворот
		table.insert(hideSpots, Vector3.new(s * (FIELD_X + GOAL_DEPTH + 3), 0, -5))
		table.insert(hideSpots, Vector3.new(s * 125, 0, s * -100)) -- углы стадиона
	end

	local lobbyCenter = Vector3.new(0, 250, -650) -- далеко за городом, чтобы не висело над стадионом
	buildLobby(root, lobbyCenter)

	local seekerBoxCenter = Vector3.new(0, 300, 400)
	buildSeekerBox(root, seekerBoxCenter)

	-- Места для статуй вдоль боковых линий
	local statueHomes = {}
	for _, sz in { -1, 1 } do
		for _, x in { -95, -60, 60, 95 } do
			local pos = Vector3.new(x, 0, sz * (FIELD_Z + 6))
			table.insert(statueHomes, CFrame.lookAt(pos, Vector3.new(x, 0, 0)))
		end
	end

	local details = StadiumDetails.build(root, {
		FieldX = FIELD_X,
		FieldZ = FIELD_Z,
		GroundX = GROUND_X,
		GroundZ = GROUND_Z,
		GoalHalfWidth = GOAL_HALF_WIDTH,
		GoalHeight = GOAL_HEIGHT,
		GoalDepth = GOAL_DEPTH,
		RoofY = ROOF_Y,
		StandDepth = STAND_DEPTH,
		Stands = {
			{ cf = northCF, length = 230, skip = 32 }, -- за главной трибуной стоят раздевалки
			{ cf = southCF, length = 230 },
			{ cf = eastCF, length = 170 },
			{ cf = westCF, length = 170 },
		},
		BenchX = 25,
		JailCenter = jailCenter,
		LobbyCenter = lobbyCenter,
	})

	root.Parent = Workspace

	return {
		Root = root,
		LobbyCFrame = CFrame.new(lobbyCenter + Vector3.new(0, 4, 0)),
		SeekerBoxCFrame = CFrame.new(seekerBoxCenter + Vector3.new(0, 3, 0)),
		SeekerReleaseCFrame = CFrame.lookAt(Vector3.new(0, 3, 80), Vector3.new(0, 3, 0)), -- выход из туннеля
		HiderSpawnCenter = Vector3.new(0, 3, 0),
		JailCenter = jailCenter,
		JailHalf = jailHalf,
		Goals = goals,
		TrophySpots = trophySpots,
		HideSpots = hideSpots,
		StatueHomes = statueHomes,
		Scoreboard = scoreboard,
		StatueColor = STATUE_STONE,
		AdBoards = details.AdBoards,
	}
end

return StadiumBuilder
