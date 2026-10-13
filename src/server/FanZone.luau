-- Символика «Спортинга» (гербы, баннеры, флаги) и фан-зона вокруг стадиона:
-- парковка, фудтраки, палатки болельщиков, детская площадка, фонтан, статуя льва.
-- Всё это ещё и новые места, где можно спрятаться.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local FanZone = {}

local GREEN = Color3.fromRGB(0, 128, 72)
local DARK_GREEN = Color3.fromRGB(0, 90, 50)
local WHITE = Color3.fromRGB(245, 245, 245)
local GOLD = Color3.fromRGB(240, 190, 40)
local DARK = Color3.fromRGB(40, 42, 48)

local rng = Random.new(23)

local function part(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function text(p: BasePart, face: Enum.NormalId, value: string, color: Color3, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new()
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = value
	label.Parent = gui
	return label
end

----------------------------------------------------------------------
-- Герб в стиле «Спортинга»: зелёный щит с белыми полосами и золотой лев сверху.
-- Строится лицом к оси -Z своей системы координат, scale = 1 — около 7 шагов в высоту.
----------------------------------------------------------------------
local function crest(parent: Instance, cf: CFrame, scale: number, collide: boolean?)
	local m = Instance.new("Model")
	m.Name = "Crest"
	m.Parent = parent
	local d = 0.3 * math.max(1, scale * 0.6)
	local function piece(offset: CFrame, size: Vector3, color: Color3, material: Enum.Material?)
		return part(m, cf * offset, size, color, material, collide)
	end
	local s = scale
	piece(CFrame.new(0, 0, 0), Vector3.new(4.4 * s, 4.4 * s, d), GOLD, Enum.Material.Foil)
	piece(CFrame.new(0, 0, -d * 0.6), Vector3.new(4 * s, 4 * s, d), GREEN)
	for k = 0, 3 do
		piece(CFrame.new(0, (-1.4 + k * 0.9) * s, -d * 1.2), Vector3.new(4 * s, 0.42 * s, d), WHITE)
	end
	piece(CFrame.new(0, -2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(3.1 * s, 3.1 * s, d), GOLD, Enum.Material.Foil)
	piece(CFrame.new(0, -2.2 * s, -d * 0.6) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(2.75 * s, 2.75 * s, d), GREEN)
	local mane = piece(CFrame.new(0, 3 * s, -d * 0.4), Vector3.new(2.8 * s, 2.8 * s, 2.8 * s), Color3.fromRGB(200, 140, 30))
	mane.Shape = Enum.PartType.Ball
	local head = piece(CFrame.new(0, 3 * s, -d - 0.9 * s), Vector3.new(1.8 * s, 1.8 * s, 1.8 * s), GOLD, Enum.Material.Foil)
	head.Shape = Enum.PartType.Ball
	return m
end

----------------------------------------------------------------------
-- Гербы, баннеры и флаги на стадионе
----------------------------------------------------------------------
local BANNERS = { "SPORTING", "ВПЕРЁД, ЛЬВЫ!", "SPORTING CP", "ЗЕЛЁНЫЕ ЛЬВЫ" }

local function buildSportingDecor(root: Instance, o)
	local m = folder("SportingDecor", root)
	-- Огромный герб в центральном круге
	crest(m, CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(90), 0, 0), 3.2, false)

	for index, stand in o.Stands do
		local cf, length = stand.cf, stand.length
		-- Баннеры и гербы под крышей, лицом к полю
		local count = math.max(3, math.floor(length / 50))
		for k = 0, count - 1 do
			local x = -length / 2 + length * (k + 0.5) / count
			if k % 2 == 0 then
				crest(m, cf * CFrame.new(x, o.RoofY - 5.5, -4.2), 0.9, false)
			else
				local isBanter = Config.FAN_BANTER and index == 2 and k == 1
				local banner = part(m, cf * CFrame.new(x, o.RoofY - 4.8, -4.2), Vector3.new(26, 5, 0.2), if isBanter then Color3.fromRGB(20, 20, 20) else GREEN, Enum.Material.Fabric, false)
				if isBanter then
					text(banner, Enum.NormalId.Front, Config.BANTER_TEXT, Color3.fromRGB(255, 70, 70))
				else
					text(banner, Enum.NormalId.Front, BANNERS[(index + k) % #BANNERS + 1], WHITE)
				end
			end
		end
		-- Флаги на крыше
		for k = 0, 5 do
			local x = -length / 2 + length * (k + 0.5) / 6
			part(m, cf * CFrame.new(x, o.RoofY + 5, 2), Vector3.new(0.3, 10, 0.3), WHITE, Enum.Material.Metal, false)
			for stripe = 0, 3 do
				part(m, cf * CFrame.new(x + 2.4, o.RoofY + 8.6 - stripe * 0.75, 2), Vector3.new(4.5, 0.75, 0.1), if stripe % 2 == 0 then GREEN else WHITE, Enum.Material.Fabric, false)
			end
		end
		-- Большие гербы на фасаде снаружи
		for _, x in { -length / 4, length / 4 } do
			if not (stand.skip and math.abs(x) < stand.skip + 8) then
				crest(m, cf * CFrame.new(x, 20, o.StandDepth + 2.6) * CFrame.Angles(0, math.pi, 0), 1.6, false)
			end
		end
	end

	-- Фанатский баннер на передней стенке южной трибуны
	if Config.FAN_BANTER then
		local south = o.Stands[2]
		for _, x in { -60, 60 } do
			local banner = part(m, south.cf * CFrame.new(x, 1.6, -0.15), Vector3.new(30, 2.6, 0.1), Color3.fromRGB(15, 15, 15), Enum.Material.Fabric, false)
			text(banner, Enum.NormalId.Front, Config.BANTER_TEXT, Color3.fromRGB(255, 80, 80))
		end
	end

	-- Гербы над туннелем, у табло и в лобби
	local north = o.Stands[1]
	crest(m, north.cf * CFrame.new(0, 12.5, -0.6), 0.8, false)
	local east = o.Stands[3]
	for _, x in { -26, 26 } do
		crest(m, east.cf * CFrame.new(x, o.RoofY + 8, 18), 1, false)
	end
	for _, z in { -14, 14 } do
		crest(m, CFrame.lookAt(o.LobbyCenter + Vector3.new(-29.4, 7, z), o.LobbyCenter + Vector3.new(0, 7, z)), 0.9, false)
	end
end

----------------------------------------------------------------------
-- Фан-зона
----------------------------------------------------------------------

local CAR_COLORS = {
	Color3.fromRGB(200, 30, 30),
	Color3.fromRGB(30, 80, 200),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(30, 30, 35),
	Color3.fromRGB(0, 128, 72),
	Color3.fromRGB(230, 190, 30),
	Color3.fromRGB(150, 150, 155),
}

local function wheel(parent: Instance, cf: CFrame)
	local w = part(parent, cf * CFrame.Angles(0, 0, 0), Vector3.new(0.8, 1.6, 1.6), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	w.Shape = Enum.PartType.Cylinder
end

local function car(parent: Instance, cf: CFrame)
	local color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	part(parent, cf * CFrame.new(0, 1.4, 0), Vector3.new(4.2, 1.6, 8.4), color, Enum.Material.Metal)
	local cabin = part(parent, cf * CFrame.new(0, 2.8, 0.4), Vector3.new(3.8, 1.3, 4.4), Color3.fromRGB(60, 80, 100), Enum.Material.Glass)
	cabin.Transparency = 0.2
	for _, x in { -2.1, 2.1 } do
		for _, z in { -2.8, 2.8 } do
			wheel(parent, cf * CFrame.new(x, 0.8, z))
		end
	end
end

local function bus(parent: Instance, cf: CFrame)
	part(parent, cf * CFrame.new(0, 3.6, 0), Vector3.new(5.5, 5.8, 24), GREEN, Enum.Material.Metal)
	part(parent, cf * CFrame.new(0, 4.6, 0), Vector3.new(5.6, 1.6, 22), Color3.fromRGB(40, 60, 80), Enum.Material.Glass)
	local side = part(parent, cf * CFrame.new(2.85, 2.2, 0), Vector3.new(0.1, 1.6, 18), WHITE, Enum.Material.SmoothPlastic, false)
	text(side, Enum.NormalId.Right, "SPORTING CP", GREEN)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -8, 8 } do
			wheel(parent, cf * CFrame.new(x, 0.9, z))
		end
	end
end

local function foodTruck(parent: Instance, cf: CFrame, label: string, color: Color3)
	part(parent, cf * CFrame.new(0, 3.4, 0), Vector3.new(6.5, 6, 13), color, Enum.Material.Metal)
	part(parent, cf * CFrame.new(-3.4, 6.3, 0), Vector3.new(2, 0.2, 9), WHITE, Enum.Material.Fabric) -- навес
	part(parent, cf * CFrame.new(-3.6, 3, 0), Vector3.new(1, 0.3, 8), Color3.fromRGB(150, 110, 70), Enum.Material.Wood) -- прилавок
	local sign = part(parent, cf * CFrame.new(0, 7.2, 0), Vector3.new(5, 1.6, 10), Color3.fromRGB(20, 20, 20))
	text(sign, Enum.NormalId.Left, label, Color3.fromRGB(255, 220, 80))
	for _, x in { -3, 3 } do
		for _, z in { -4.5, 4.5 } do
			wheel(parent, cf * CFrame.new(x, 0.8, z))
		end
	end
end

local function tent(parent: Instance, cf: CFrame)
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			part(parent, cf * CFrame.new(x, 3, z), Vector3.new(0.3, 6, 0.3), WHITE, Enum.Material.Metal)
		end
	end
	for k = 0, 4 do
		part(parent, cf * CFrame.new(-4 + k * 2, 6.2, 0), Vector3.new(2, 0.3, 9), if k % 2 == 0 then GREEN else WHITE, Enum.Material.Fabric)
	end
	part(parent, cf * CFrame.new(0, 1, 0), Vector3.new(6, 0.3, 2.4), Color3.fromRGB(150, 110, 70), Enum.Material.Wood) -- стол
	part(parent, cf * CFrame.new(0, 0.5, 0), Vector3.new(0.4, 1, 0.4), DARK, Enum.Material.Metal)
	part(parent, cf * CFrame.new(0, 3, 4.05), Vector3.new(8, 6, 0.1), GREEN, Enum.Material.Fabric) -- задняя стенка — за ней можно спрятаться
end

local function bush(parent: Instance, position: Vector3)
	local r = rng:NextNumber(3, 5)
	local color = Color3.fromRGB(rng:NextInteger(35, 60), rng:NextInteger(95, 125), rng:NextInteger(35, 55))
	for k = 0, 2 do
		local b = part(parent, CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5), r * 0.45, rng:NextNumber(-1.5, 1.5))), Vector3.new(r, r, r), color, Enum.Material.Grass)
		b.Shape = Enum.PartType.Ball
		local _ = k
	end
end

local function lionStatue(parent: Instance, cf: CFrame)
	part(parent, cf * CFrame.new(0, 1.5, 0), Vector3.new(12, 3, 16), Color3.fromRGB(120, 120, 125), Enum.Material.Marble)
	local plate = part(parent, cf * CFrame.new(0, 1.5, -8.05), Vector3.new(10, 2, 0.1), GOLD, Enum.Material.Foil)
	text(plate, Enum.NormalId.Front, "ЛЕВ «СПОРТИНГА»", Color3.fromRGB(60, 40, 0))
	local function gold(offset: Vector3, size: Vector3, shape: Enum.PartType?)
		local p = part(parent, cf * CFrame.new(offset), size, GOLD, Enum.Material.Foil)
		if shape then
			p.Shape = shape
		end
	end
	gold(Vector3.new(0, 6, 1), Vector3.new(5, 4.5, 9))
	gold(Vector3.new(0, 8.5, -3.5), Vector3.new(6.5, 6.5, 6.5), Enum.PartType.Ball)
	gold(Vector3.new(0, 8.5, -6), Vector3.new(4, 4, 3.5))
	for _, x in { -1.8, 1.8 } do
		for _, z in { -2.5, 4.5 } do
			gold(Vector3.new(x, 4, z), Vector3.new(1.5, 3.5, 1.5))
		end
	end
	gold(Vector3.new(0, 7, 7), Vector3.new(0.6, 0.6, 4))
end

local function playground(parent: Instance, cf: CFrame)
	local red, blue, yellow = Color3.fromRGB(220, 50, 50), Color3.fromRGB(40, 110, 220), Color3.fromRGB(250, 205, 30)
	part(parent, cf * CFrame.new(0, 0.05, 0), Vector3.new(30, 0.1, 24), Color3.fromRGB(180, 70, 60), Enum.Material.Fabric) -- мягкое покрытие
	-- Горка
	part(parent, cf * CFrame.new(-8, 3.5, 0), Vector3.new(5, 0.5, 5), blue, Enum.Material.SmoothPlastic)
	for _, x in { -10.2, -5.8 } do
		for _, z in { -2.2, 2.2 } do
			part(parent, cf * CFrame.new(x, 1.75, z), Vector3.new(0.4, 3.5, 0.4), yellow, Enum.Material.Metal)
		end
	end
	local slide = Instance.new("WedgePart")
	slide.Anchored = true
	slide.Size = Vector3.new(3, 3.5, 8)
	slide.CFrame = cf * CFrame.new(-8, 1.75, -6.5) * CFrame.Angles(0, math.pi, 0)
	slide.Color = red
	slide.Material = Enum.Material.SmoothPlastic
	slide.Parent = parent
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 4, 2)
	ladder.CFrame = cf * CFrame.new(-8, 2, 3.6)
	ladder.Color = yellow
	ladder.Parent = parent
	-- Качели
	for _, x in { 4, 12 } do
		part(parent, cf * CFrame.new(x, 3, -3), Vector3.new(0.4, 6, 0.4), red, Enum.Material.Metal)
		part(parent, cf * CFrame.new(x, 3, 3), Vector3.new(0.4, 6, 0.4), red, Enum.Material.Metal)
	end
	part(parent, cf * CFrame.new(8, 6, -3), Vector3.new(8.4, 0.4, 0.4), red, Enum.Material.Metal)
	part(parent, cf * CFrame.new(8, 6, 3), Vector3.new(8.4, 0.4, 0.4), red, Enum.Material.Metal)
	for _, x in { 6, 10 } do
		part(parent, cf * CFrame.new(x, 1.5, 0), Vector3.new(1.8, 0.2, 1.2), blue, Enum.Material.Wood)
	end
end

local function fountain(parent: Instance, cf: CFrame)
	local base = part(parent, cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.6, 18, 18), Color3.fromRGB(170, 170, 175), Enum.Material.Marble)
	base.Shape = Enum.PartType.Cylinder
	local water = part(parent, cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 16, 16), Color3.fromRGB(80, 160, 230), Enum.Material.Glass, false)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.3
	local column = part(parent, cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(5, 2, 2), Color3.fromRGB(170, 170, 175), Enum.Material.Marble)
	column.Shape = Enum.PartType.Cylinder
	crest(parent, cf * CFrame.new(0, 7.5, 0), 0.5, false)
	local splash = Instance.new("ParticleEmitter")
	splash.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	splash.Size = NumberSequence.new(0.4)
	splash.Speed = NumberRange.new(8, 12)
	splash.SpreadAngle = Vector2.new(15, 15)
	splash.Lifetime = NumberRange.new(1, 1.5)
	splash.Acceleration = Vector3.new(0, -25, 0)
	splash.Rate = 40
	splash.EmitDirection = Enum.NormalId.Right
	splash.Parent = column
end

-- Камерные вышки и ящики с инвентарём у поля — ещё укрытия
local function buildPitchProps(root: Instance, o, hide: { Vector3 })
	local m = folder("PitchProps", root)
	for _, sz in { -1, 1 } do
		for _, x in { -o.FieldX * 0.7, o.FieldX * 0.7 } do
			local base = Vector3.new(x, 0, sz * (o.FieldZ + 12.5))
			for _, lx in { -2.5, 2.5 } do
				for _, lz in { -2.5, 2.5 } do
					part(m, CFrame.new(base + Vector3.new(lx, 4, lz)), Vector3.new(0.4, 8, 0.4), DARK, Enum.Material.Metal)
				end
			end
			part(m, CFrame.new(base + Vector3.new(0, 8.2, 0)), Vector3.new(6, 0.4, 6), DARK, Enum.Material.DiamondPlate)
			part(m, CFrame.new(base + Vector3.new(0, 9.6, 0)), Vector3.new(1.4, 1.4, 2.6), Color3.fromRGB(25, 25, 28), Enum.Material.Metal) -- камера
			local ladder = Instance.new("TrussPart")
			ladder.Anchored = true
			ladder.Size = Vector3.new(2, 8, 2)
			ladder.CFrame = CFrame.new(base + Vector3.new(0, 4, sz * 3.6))
			ladder.Color = DARK
			ladder.Parent = m
			table.insert(hide, base + Vector3.new(0, 8.5, 0))
		end
	end
	-- Ящики с мячами и инвентарём в углах
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = Vector3.new(sx * (o.FieldX + 4), 0, sz * (o.FieldZ + 4))
			part(m, CFrame.new(base + Vector3.new(0, 1.5, 0)), Vector3.new(4, 3, 4), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
			part(m, CFrame.new(base + Vector3.new(sx * 4.2, 1.5, 0)), Vector3.new(4, 3, 4), Color3.fromRGB(110, 78, 45), Enum.Material.Wood)
			part(m, CFrame.new(base + Vector3.new(sx * 2, 4.5, 0)), Vector3.new(4, 3, 4), Color3.fromRGB(125, 90, 52), Enum.Material.Wood)
			table.insert(hide, base + Vector3.new(sx * 2, 0, -sz * 3.5))
		end
	end
end

local function lamp(parent: Instance, position: Vector3)
	part(parent, CFrame.new(position + Vector3.new(0, 7, 0)), Vector3.new(0.5, 14, 0.5), DARK, Enum.Material.Metal)
	local head = part(parent, CFrame.new(position + Vector3.new(0, 14.2, 0)), Vector3.new(2.4, 0.6, 2.4), Color3.fromRGB(255, 235, 200), Enum.Material.Neon, false)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	light.Range = 40
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 225, 180)
	light.Parent = head
end

local function buildFanZone(root: Instance, o, hide: { Vector3 }, trophy: { Vector3 })
	local m = folder("FanZone", root)
	local gx, gz = o.GroundX, o.GroundZ
	-- Фонари по всей фан-зоне
	local lamps = folder("Lamps", m)
	for x = -gx + 30, gx - 30, 60 do
		lamp(lamps, Vector3.new(x, 0, -(gz + 35)))
		lamp(lamps, Vector3.new(x, 0, gz + 20))
	end
	for z = -gz + 40, gz - 40, 70 do
		lamp(lamps, Vector3.new(gx + 30, 0, z))
		lamp(lamps, Vector3.new(-gx - 25, 0, z))
	end
	-- Парковка (юг): машины и автобусы болельщиков
	local park = folder("Parking", m)
	for row = 0, 1 do
		local z = -(gz + 22 + row * 26)
		for x = -gx + 20, gx - 20, 16 do
			if rng:NextNumber() < 0.75 then
				local cf = CFrame.new(x + rng:NextNumber(-1, 1), 0, z) * CFrame.Angles(0, if row == 0 then 0 else math.pi, 0)
				car(park, cf)
				if rng:NextNumber() < 0.25 then
					table.insert(hide, (cf * CFrame.new(3.8, 0, 0)).Position)
				end
			end
		end
	end
	for _, x in { -gx + 30, gx - 30 } do
		local cf = CFrame.new(x, 0, -(gz + 70)) * CFrame.Angles(0, math.rad(90), 0)
		bus(park, cf)
		table.insert(hide, (cf * CFrame.new(4.5, 0, 0)).Position)
	end
	table.insert(trophy, Vector3.new(0, 0, -(gz + 35)))

	-- Фудтраки (восток)
	local food = folder("FoodTrucks", m)
	local trucks = { { "ПИЦЦА", Color3.fromRGB(220, 60, 40) }, { "ХОТ-ДОГИ", Color3.fromRGB(240, 180, 30) }, { "МОРОЖЕНОЕ", Color3.fromRGB(120, 190, 240) }, { "ПОПКОРН", Color3.fromRGB(230, 230, 230) } }
	for i, t in trucks do
		local z = -gz * 0.6 + (i - 1) * gz * 0.4
		local cf = CFrame.new(gx + 40, 0, z)
		foodTruck(food, cf, t[1], t[2])
		table.insert(hide, (cf * CFrame.new(5, 0, 0)).Position)
		-- Столики с зонтиками
		for k = 0, 1 do
			local tp = Vector3.new(gx + 22, 0, z - 6 + k * 12)
			part(food, CFrame.new(tp + Vector3.new(0, 1.2, 0)), Vector3.new(3, 0.3, 3), WHITE, Enum.Material.SmoothPlastic)
			part(food, CFrame.new(tp + Vector3.new(0, 2.5, 0)), Vector3.new(0.3, 5, 0.3), DARK, Enum.Material.Metal)
			local umbrella = part(food, CFrame.new(tp + Vector3.new(0, 5, 0)), Vector3.new(6, 0.4, 6), if k == 0 then GREEN else WHITE, Enum.Material.Fabric)
			local _ = umbrella
		end
	end
	table.insert(trophy, Vector3.new(gx + 46, 0, 0))

	-- Палатки болельщиков (запад)
	local tents = folder("FanTents", m)
	for i = 0, 5 do
		local z = -gz * 0.7 + i * gz * 0.28
		local cf = CFrame.new(-gx - 35, 0, z) * CFrame.Angles(0, math.rad(90), 0)
		tent(tents, cf)
		table.insert(hide, (cf * CFrame.new(0, 0, 5.5)).Position)
	end
	table.insert(trophy, Vector3.new(-gx - 35, 0, 0))

	-- Север: статуя льва у входа, фонтан, детская площадка
	local plaza = folder("Plaza", m)
	lionStatue(plaza, CFrame.lookAt(Vector3.new(0, 0, gz + 30), Vector3.new(0, 0, 0)))
	table.insert(hide, Vector3.new(0, 0, gz + 42))
	fountain(plaza, CFrame.new(-70, 0, gz + 35))
	playground(plaza, CFrame.new(75, 0, gz + 40))
	table.insert(hide, Vector3.new(67, 0, gz + 36))
	table.insert(trophy, Vector3.new(-70, 0, gz + 48))

	-- Кусты по всей площади
	local bushes = folder("Bushes", m)
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local p = Vector3.new(math.cos(a) * (gx + o.Fan * 0.75), 0, math.sin(a) * (gz + o.Fan * 0.75))
		bush(bushes, p)
		if i % 4 == 0 then
			table.insert(hide, p + Vector3.new(0, 0, 3))
		end
	end
end

function FanZone.build(root: Instance, o)
	local hide, trophy = {}, {}
	buildSportingDecor(root, o)
	buildPitchProps(root, o, hide)
	buildFanZone(root, o, hide, trophy)
	return hide, trophy
end

FanZone.crest = crest

return FanZone
