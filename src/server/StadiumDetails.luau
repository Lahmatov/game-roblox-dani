-- Детали для красоты и реализма: прожекторы, светодиодные бортики, разметка,
-- фасад, конструкции крыши, город вокруг, деревья и фонари.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local StadiumDetails = {}

local WHITE = Color3.fromRGB(240, 240, 240)
local DARK = Color3.fromRGB(40, 42, 48)
local STEEL = Color3.fromRGB(175, 180, 188)
local LED_GREEN = Color3.fromRGB(0, 200, 110)
local FACADE_COLORS = {
	Color3.fromRGB(0, 133, 75),
	Color3.fromRGB(0, 160, 90),
	Color3.fromRGB(120, 195, 70),
	Color3.fromRGB(250, 205, 20),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(30, 110, 180),
}
local AD_TEXTS = {
	"ПРЯТКИ ЗА КУБОК",
	"НАЙДИ КУБОК — ЗАБЕЙ ГОЛ!",
	"ДАНЯ №7",
	"ЗЕЛЁНЫЕ ЛЬВЫ",
	"НЕ ПОПАДИСЬ ВОДЯЩЕМУ!",
	"ОСВОБОДИ ДРУЗЕЙ!",
	"СТАТУИ ОЖИВАЮТ...",
}

local rng = Random.new(11)

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

local function groundLine(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	part(parent, CFrame.lookAt(mid, b), Vector3.new(0.8, 0.2, (b - a).Magnitude + 0.6), WHITE, Enum.Material.SmoothPlastic, false)
end

local function arc(parent: Instance, center: Vector3, radius: number, fromAngle: number, toAngle: number, segments: number)
	for i = 0, segments - 1 do
		local a1 = fromAngle + (toAngle - fromAngle) * i / segments
		local a2 = fromAngle + (toAngle - fromAngle) * (i + 1) / segments
		groundLine(
			parent,
			center + Vector3.new(math.cos(a1) * radius, 0.1, math.sin(a1) * radius),
			center + Vector3.new(math.cos(a2) * radius, 0.1, math.sin(a2) * radius)
		)
	end
end

-- Дополнительная разметка: дуги в углах и у штрафной, технические зоны
local function buildMarkings(root: Instance, o)
	local m = folder("Markings", root)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			-- Дуга в углу смотрит внутрь поля
			local corner = Vector3.new(sx * o.FieldX, 0, sz * o.FieldZ)
			local a1 = math.atan2(0, -sx)
			local a2 = math.atan2(-sz, 0)
			if a2 - a1 > math.pi then
				a2 -= math.pi * 2
			elseif a1 - a2 > math.pi then
				a2 += math.pi * 2
			end
			arc(m, corner, 2.5, a1, a2, 4)
		end
		-- «Полумесяц» у штрафной (радиус 18 от точки пенальти, только снаружи площади)
		local spot = Vector3.new(sx * (o.FieldX - 24), 0, 0)
		local half = math.acos(12 / 18)
		local mid = if sx > 0 then math.pi else 0
		arc(m, spot, 18, mid - half, mid + half, 10)
	end
	-- Технические зоны у скамеек (пунктир)
	for _, bx in { -o.BenchX, o.BenchX } do
		for k = 0, 5 do
			local z = o.FieldZ + 1 + k * 1.2
			groundLine(m, Vector3.new(bx - 9, 0.1, z), Vector3.new(bx - 9, 0.1, z + 0.6))
			groundLine(m, Vector3.new(bx + 9, 0.1, z), Vector3.new(bx + 9, 0.1, z + 0.6))
		end
	end
	-- Беговая дорожка вокруг газона, по которой ходят судьи
	local track = Color3.fromRGB(45, 95, 50)
	part(m, CFrame.new(0, 0.03, o.FieldZ + 5), Vector3.new(o.FieldX * 2 + 20, 0.06, 9), track, Enum.Material.Grass, false)
	part(m, CFrame.new(0, 0.03, -o.FieldZ - 5), Vector3.new(o.FieldX * 2 + 20, 0.06, 9), track, Enum.Material.Grass, false)
end

-- Светодиодные рекламные бортики вокруг поля
local function buildAdBoards(root: Instance, o): { TextLabel }
	local m = folder("AdBoards", root)
	local labels = {}
	local function board(cf: CFrame, length: number)
		local p = part(m, cf * CFrame.new(0, 1, 0), Vector3.new(length, 2, 0.5), Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic)
		part(m, cf * CFrame.new(0, 1, 0.6), Vector3.new(length, 2, 0.6), DARK, Enum.Material.Metal) -- подпорка
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 25
		gui.Parent = p
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(5, 25, 15)
		label.TextColor3 = LED_GREEN
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.Text = AD_TEXTS[#labels % #AD_TEXTS + 1]
		label.Parent = gui
		-- Если загружены картинки рекламы — показываем их поверх текста
		local banners = {}
		for _, id in Config.TEXTURES.AdBanners do
			if id > 0 then
				table.insert(banners, "rbxassetid://" .. id)
			end
		end
		if #banners > 0 then
			local image = Instance.new("ImageLabel")
			image.Name = "Banner"
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Crop
			image.Image = banners[#labels % #banners + 1]
			image.Parent = label
			label:SetAttribute("Banners", table.concat(banners, ","))
		end
		table.insert(labels, label)
	end
	local length = 18
	-- Вдоль длинных сторон (лицом к полю), со щелями для скамеек и прохода
	for _, sz in { -1, 1 } do
		local z = sz * (o.FieldZ + 9.5)
		for x = -o.FieldX + 2, o.FieldX - length, length + 4 do -- между бортиками проход в 4 шага
			local cx = x + length / 2
			local nearBench = sz > 0 and (math.abs(cx - o.BenchX) < 12 or math.abs(cx + o.BenchX) < 12 or math.abs(cx) < 12)
			if not nearBench then
				board(CFrame.lookAt(Vector3.new(cx, 0, z), Vector3.new(cx, 0, 0)), length)
			end
		end
	end
	-- За воротами
	for _, sx in { -1, 1 } do
		local x = sx * (o.FieldX + o.GoalDepth + 6)
		for _, zc in { -40, -20, 20, 40 } do
			local skip = sx < 0 and math.abs(zc - o.JailCenter.Z) < 14
			if not skip then
				board(CFrame.lookAt(Vector3.new(x, 0, zc), Vector3.new(0, 0, zc)), 18)
			end
		end
	end
	return labels
end

-- Прожекторы. В Roblox свет достаёт только на 60 шагов, поэтому над полем висят
-- невидимые лампы — как будто свет от больших прожекторов на мачтах и крышах.
local function buildFloodlights(root: Instance, o)
	local m = folder("Floodlights", root)
	local warm = Color3.fromRGB(255, 248, 232)
	for _, x in { -82, -27, 27, 82 } do
		for _, z in { -32, 32 } do
			local holder = part(m, CFrame.new(x, 46, z), Vector3.new(1, 1, 1), WHITE, Enum.Material.SmoothPlastic, false)
			holder.Transparency = 1
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 120
			spot.Range = 60
			spot.Brightness = 1.6
			spot.Color = warm
			spot.Shadows = false
			spot.Parent = holder
		end
	end
	-- Мачты в углах
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = Vector3.new(sx * 150, 0, sz * 112)
			local height = 72
			local truss = Instance.new("TrussPart")
			truss.Anchored = true
			truss.Size = Vector3.new(2, height, 2)
			truss.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
			truss.Color = STEEL
			truss.Material = Enum.Material.Metal
			truss.CanCollide = false
			truss.Parent = m
			local head = CFrame.lookAt(base + Vector3.new(0, height, 0), Vector3.new(0, 0, 0))
			part(m, head * CFrame.new(0, 0, 1), Vector3.new(16, 9, 1.2), DARK, Enum.Material.Metal, false)
			for row = 0, 2 do
				for col = 0, 4 do
					local lamp = part(m, head * CFrame.new(-6 + col * 3, -3 + row * 3, 0.3), Vector3.new(2.4, 2.4, 0.4), warm, Enum.Material.Neon, false)
					if row == 1 and col == 2 then
						local spot = Instance.new("SpotLight")
						spot.Face = Enum.NormalId.Front
						spot.Angle = 60
						spot.Range = 60
						spot.Brightness = 3
						spot.Color = warm
						spot.Parent = lamp
					end
				end
			end
		end
	end
end

-- Под крышей — стальные балки, по краю крыши — зелёная светодиодная лента; снаружи — цветной фасад
local function buildStandDressing(root: Instance, o)
	local m = folder("StandDressing", root)
	for _, stand in o.Stands do
		local cf, length = stand.cf, stand.length
		for x = -length / 2 + 6, length / 2 - 6, 18 do
			part(m, cf * CFrame.new(x, o.RoofY - 1.4, (o.StandDepth - 4) / 2), Vector3.new(0.8, 1.8, o.StandDepth + 6), STEEL, Enum.Material.Metal, false)
		end
		part(m, cf * CFrame.new(0, o.RoofY - 1.4, -3.6), Vector3.new(length + 4, 1.8, 0.8), STEEL, Enum.Material.Metal, false)
		part(m, cf * CFrame.new(0, o.RoofY - 0.2, -4.1), Vector3.new(length + 4, 0.4, 0.2), LED_GREEN, Enum.Material.Neon, false)

		-- Фасад из разноцветных панелей на задней стене
		local panelW = 5
		for x = -length / 2 + panelW / 2, length / 2 - panelW / 2, panelW do
			if not (stand.skip and math.abs(x) < stand.skip) then
				local color = FACADE_COLORS[rng:NextInteger(1, #FACADE_COLORS)]
				local h = rng:NextInteger(18, 28)
				part(m, cf * CFrame.new(x, h / 2 + 1, o.StandDepth + 2.15), Vector3.new(panelW - 0.3, h, 0.3), color, Enum.Material.SmoothPlastic, false)
			end
		end
	end
end

local function tree(parent: Instance, position: Vector3)
	local h = rng:NextNumber(7, 11)
	part(parent, CFrame.new(position + Vector3.new(0, h / 2, 0)), Vector3.new(1, h, 1), Color3.fromRGB(95, 70, 50), Enum.Material.Wood)
	local leaves = Color3.fromRGB(rng:NextInteger(40, 70), rng:NextInteger(95, 130), rng:NextInteger(40, 60))
	for k = 0, 2 do
		local r = rng:NextNumber(4.5, 6.5) - k
		local ball = part(parent, CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), h + k * 2.2, rng:NextNumber(-1, 1))), Vector3.new(r, r, r), leaves, Enum.Material.Grass)
		ball.Shape = Enum.PartType.Ball
	end
end

local function streetLamp(parent: Instance, position: Vector3)
	part(parent, CFrame.new(position + Vector3.new(0, 6, 0)), Vector3.new(0.5, 12, 0.5), DARK, Enum.Material.Metal)
	local lamp = part(parent, CFrame.new(position + Vector3.new(0, 12.2, 0)), Vector3.new(1.6, 0.6, 1.6), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Range = 24
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = lamp
end

-- Вокруг стадиона: площадь, деревья, фонари, ночной город
local function buildSurroundings(root: Instance, o)
	local m = folder("Surroundings", root)
	-- Земля до горизонта и асфальт вокруг стадиона
	part(m, CFrame.new(0, -1.3, 0), Vector3.new(1600, 2, 1600), Color3.fromRGB(42, 70, 40), Enum.Material.Grass)
	local asphalt = Color3.fromRGB(55, 57, 62)
	part(m, CFrame.new(0, -0.35, 0), Vector3.new(o.GroundX * 2 + 80, 0.5, o.GroundZ * 2 + 80), asphalt, Enum.Material.Asphalt)
	-- Невидимый забор вокруг площади: из стадиона в город не убежать
	local fx, fz = o.GroundX + 40, o.GroundZ + 40
	for _, wall in
		{
			{ Vector3.new(fx, 30, 0), Vector3.new(2, 60, fz * 2) },
			{ Vector3.new(-fx, 30, 0), Vector3.new(2, 60, fz * 2) },
			{ Vector3.new(0, 30, fz), Vector3.new(fx * 2, 60, 2) },
			{ Vector3.new(0, 30, -fz), Vector3.new(fx * 2, 60, 2) },
		}
	do
		local p = part(m, CFrame.new(wall[1]), wall[2], WHITE, Enum.Material.SmoothPlastic)
		p.Name = "Boundary"
		p.Transparency = 1
		p.CanQuery = false
	end

	-- Деревья и фонари по краю площади
	local rx, rz = o.GroundX + 30, o.GroundZ + 30
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local p = Vector3.new(math.cos(a) * rx, 0, math.sin(a) * rz)
		if i % 3 == 0 then
			streetLamp(m, p * 0.93)
		else
			tree(m, p + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
		end
	end
	-- Ночной город на горизонте: дома с горящими окнами
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local dist = rng:NextNumber(330, 520)
		local w, d, h = rng:NextNumber(25, 55), rng:NextNumber(25, 50), rng:NextNumber(30, 140)
		local pos = Vector3.new(math.cos(a) * dist, h / 2 - 0.3, math.sin(a) * dist)
		local cf = CFrame.lookAt(pos, Vector3.new(0, h / 2, 0))
		local shade = rng:NextInteger(28, 50)
		part(m, cf, Vector3.new(w, h, d), Color3.fromRGB(shade, shade + 2, shade + 10), Enum.Material.Concrete)
		local floors = math.floor(h / 8)
		for f = 1, floors - 1 do
			if rng:NextNumber() < 0.55 then
				local lit = Color3.fromRGB(255, rng:NextInteger(200, 235), rng:NextInteger(140, 190))
				part(m, cf * CFrame.new(0, -h / 2 + f * 8, -d / 2 - 0.1), Vector3.new(w * rng:NextNumber(0.4, 0.9), 2, 0.2), lit, Enum.Material.Neon, false)
			end
		end
	end
end

-- Табличка «Как играть» в лобби
local function buildRulesBoard(root: Instance, o)
	local board = part(root, CFrame.lookAt(o.LobbyCenter + Vector3.new(27, 7, 0), o.LobbyCenter + Vector3.new(0, 7, 0)), Vector3.new(34, 12, 0.4), Color3.fromRGB(10, 40, 25), Enum.Material.SmoothPlastic)
	board.Name = "RulesBoard"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = table.concat({
		"КАК ИГРАТЬ",
		"Прячься, пока водящий заперт.",
		"Найди Кубок мира и забей в ворота!",
		"Друзей из тюрьмы освобождай касанием.",
		"Q рывок · F мяч · E предмет · T дразнилка",
	}, "\n")
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 30)
	pad.PaddingTop = UDim.new(0, 20)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.Parent = label
end

function StadiumDetails.build(root: Instance, o)
	buildMarkings(root, o)
	local labels = buildAdBoards(root, o)
	buildFloodlights(root, o)
	buildStandDressing(root, o)
	buildSurroundings(root, o)
	buildRulesBoard(root, o)
	return { AdBoards = labels }
end

-- Бегущая реклама: тексты на бортиках сменяются
function StadiumDetails.animateAdBoards(labels: { TextLabel })
	task.spawn(function()
		local shift = 0
		while true do
			task.wait(5)
			shift += 1
			for i, label in labels do
				if label.Parent then
					label.Text = AD_TEXTS[(i + shift) % #AD_TEXTS + 1]
					local image = label:FindFirstChild("Banner") :: ImageLabel?
					local banners = label:GetAttribute("Banners")
					if image and banners then
						local list = string.split(banners, ",")
						image.Image = list[(i + shift) % #list + 1]
					end
				end
			end
		end
	end)
end

return StadiumDetails
