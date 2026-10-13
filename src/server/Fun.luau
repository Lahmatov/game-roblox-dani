-- Приколы: случайные события в раунде, лев-талисман, «СИИИУ!», корона лучшего игрока,
-- секретная комната и админ-панель Дани.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Participants = require(script.Parent.Participants)
local Trophy = require(script.Parent.Trophy)
local Statues = require(script.Parent.Statues)
local Economy = require(script.Parent.Economy)
local Effects = require(script.Parent.Effects)
local Commentator = require(script.Parent.Commentator)
local Sfx = require(script.Parent.Sfx)

local Fun = {}

local GOLD = Color3.fromRGB(255, 210, 60)

local map
local gameState: Folder
local announce: (string, Color3?) -> ()
local eventGeneration = 0
local lionUsed = false
local lion: Model? = nil
local mvp: Player? = nil
local adminCooldown: { [string]: number } = {}

local function phase(): string
	return gameState:GetAttribute("Phase") or "Waiting"
end

local function inRound(): boolean
	local p = phase()
	return p == "Hiding" or p == "Seeking"
end

local function findSeeker()
	for _, p in Participants.all() do
		if PlayerState.getRole(p) == "Seeker" then
			return p
		end
	end
	return nil
end

local function playersInRound()
	local list = {}
	for _, p in Participants.all() do
		local role = PlayerState.getRole(p)
		if role == "Hider" or role == "Seeker" or role == "Jailed" then
			table.insert(list, p)
		end
	end
	return list
end

local function randomPitchPoint(): Vector3
	return Vector3.new(math.random(-map.FieldX + 15, map.FieldX - 15), 0, math.random(-map.FieldZ + 10, map.FieldZ - 10))
end

----------------------------------------------------------------------
-- Случайные события
----------------------------------------------------------------------

local function eventBigHeads()
	announce("Головастики! У всех огромные головы!", GOLD)
	Commentator.say("bighead")
	local list = playersInRound()
	for _, p in list do
		Effects.bigHead(p, true)
	end
	task.delay(Config.EVENT_TIME, function()
		for _, p in list do
			Effects.bigHead(p, false)
		end
	end)
end

local function eventBallRain()
	announce("Дождь из мячей!", GOLD)
	Commentator.say("ballrain")
	for _ = 1, 40 do
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2, 2, 2)
		ball.Color = if math.random() < 0.5 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 220, 60)
		ball.Material = Enum.Material.SmoothPlastic
		ball.Position = randomPitchPoint() + Vector3.new(0, math.random(60, 100), 0)
		ball.Parent = Workspace
		Debris:AddItem(ball, 12)
	end
end

local function eventGiantSeeker()
	local seeker = findSeeker()
	if not seeker then
		return
	end
	announce(seeker.DisplayName .. " стал ВЕЛИКАНОМ!", Color3.fromRGB(230, 60, 60))
	Commentator.say("giantseeker")
	Effects.scale(seeker, 2.5)
	task.delay(12, function()
		Effects.scale(seeker, 1)
	end)
end

local function eventGiantBall()
	announce("Берегись! Огромный мяч!", GOLD)
	Commentator.say("giantball")
	local z = math.random(-50, 50)
	local fromLeft = math.random() < 0.5
	local ball = Instance.new("Part")
	ball.Name = "GiantBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(16, 16, 16)
	ball.Color = Color3.new(1, 1, 1)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Position = Vector3.new(if fromLeft then -map.FieldX + 10 else map.FieldX - 10, 8, z)
	ball.Parent = Workspace
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	ball.AssemblyLinearVelocity = Vector3.new(if fromLeft then 45 else -45, 0, math.random(-8, 8))
	for _, offset in { Vector3.new(0, 0, -7.6), Vector3.new(0, 7.6, 0), Vector3.new(7.6, 0, 0) } do
		local patch = Instance.new("Part")
		patch.Shape = Enum.PartType.Ball
		patch.Size = Vector3.new(4, 4, 4)
		patch.Color = Color3.fromRGB(25, 25, 25)
		patch.CanCollide = false
		patch.Massless = true
		patch.Position = ball.Position + offset
		patch.Parent = ball
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ball
		weld.Part1 = patch
		weld.Parent = patch
	end
	Debris:AddItem(ball, 8)
	local hit: { [any]: boolean } = {}
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not ball.Parent then
			connection:Disconnect()
			return
		end
		for _, p in playersInRound() do
			local position = PlayerState.getPosition(p)
			if not hit[p] and position and (position - ball.Position).Magnitude < 10 then
				hit[p] = true
				PlayerState.freeze(p, 1.5)
				Effects.spin(p, 1, 35)
				Commentator.say("smash", p.DisplayName)
			end
		end
	end)
end

----------------------------------------------------------------------
-- Лев-талисман: хватает Кубок и убегает
----------------------------------------------------------------------

local function buildLion(position: Vector3): (Model, BasePart, Humanoid)
	local m = Instance.new("Model")
	m.Name = "Lion"
	local tan = Color3.fromRGB(215, 160, 70)
	local mane = Color3.fromRGB(150, 85, 30)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 2, 6)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0))
	root.Parent = m
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Shape = shape or Enum.PartType.Block
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CanCollide = false
		p.Massless = true
		p.CFrame = root.CFrame * CFrame.new(offset)
		p.Parent = m
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	piece("Body", Vector3.new(3, 2.6, 5.5), Vector3.new(0, 0.3, 0.5), tan)
	piece("Mane", Vector3.new(4, 4, 4), Vector3.new(0, 1.4, -2.6), mane, Enum.PartType.Ball)
	local head = piece("Head", Vector3.new(2.4, 2.4, 2), Vector3.new(0, 1.4, -3.8), tan)
	for _, x in { -0.5, 0.5 } do
		piece("Eye", Vector3.new(0.35, 0.35, 0.2), Vector3.new(x, 1.8, -4.85), Color3.fromRGB(20, 20, 20))
	end
	piece("Nose", Vector3.new(0.6, 0.4, 0.3), Vector3.new(0, 1.2, -4.9), Color3.fromRGB(60, 35, 25))
	for _, x in { -1, 1 } do
		for _, z in { -1.8, 2.4 } do
			piece("Leg", Vector3.new(0.8, 2.2, 0.8), Vector3.new(x, -1.6, z), tan)
		end
	end
	piece("Tail", Vector3.new(0.3, 0.3, 3), Vector3.new(0, 0.8, 4.5), tan)
	piece("TailTip", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 0.8, 6), mane, Enum.PartType.Ball)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2.5
	humanoid.WalkSpeed = Config.LION_SPEED
	humanoid.DisplayName = "Лев"
	humanoid.NameDisplayDistance = 80
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.Parent = m
	m.PrimaryPart = root
	m.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local _ = head
	return m, root, humanoid
end

function Fun.releaseLion(): boolean
	if lion or not Trophy.getGroundPosition() and not Trophy.getCarrier() then
		return false
	end
	local model, root, humanoid = buildLion(map.TunnelExit)
	lion = model
	announce("На поле выбежал ЛЕВ! Он охотится за Кубком!", Color3.fromRGB(255, 160, 40))
	Commentator.say("lion")
	Sfx.play("Lion", root.Position)

	task.spawn(function()
		local startedAt = os.clock()
		local holding = false
		local runUntil = 0
		local target = randomPitchPoint()
		while model.Parent and phase() == "Seeking" and os.clock() - startedAt < 90 do
			local here = root.Position
			if not holding then
				local trophyPosition = Trophy.getGroundPosition()
				local carrier = Trophy.getCarrier()
				local carrierPosition = carrier and PlayerState.getPosition(carrier)
				local goal = trophyPosition or carrierPosition
				if not goal then
					break
				end
				humanoid:MoveTo(goal)
				if (Vector3.new(goal.X, here.Y, goal.Z) - here).Magnitude < 5 then
					if carrier then
						Trophy.drop()
						task.wait(0.1)
					end
					if Trophy.attachTo(root) then
						holding = true
						runUntil = os.clock() + Config.LION_RUN_TIME
						announce("Лев утащил Кубок! Догоните льва!", Color3.fromRGB(255, 160, 40))
					end
				end
			else
				-- Бегает зигзагами по полю
				if (Vector3.new(target.X, here.Y, target.Z) - here).Magnitude < 6 or math.random() < 0.1 then
					target = randomPitchPoint()
				end
				humanoid:MoveTo(target)
				-- Прячущийся догнал льва — Кубок выпадает
				for _, p in Participants.all() do
					if PlayerState.getRole(p) == "Hider" then
						local position = PlayerState.getPosition(p)
						if position and (position - here).Magnitude < 6 then
							Trophy.detach(here)
							holding = false
							Commentator.say("lionDrop", p.DisplayName)
							announce(p.DisplayName .. " отобрал Кубок у льва!", GOLD)
							break
						end
					end
				end
				if holding and os.clock() > runUntil then
					Trophy.detach(here)
					holding = false
					announce("Лев устал и бросил Кубок!", GOLD)
					break
				end
				if not holding then
					break
				end
			end
			task.wait(0.2)
		end
		if holding then
			Trophy.detach(root.Position)
		end
		-- Лев убегает в туннель и исчезает
		humanoid:MoveTo(map.TunnelExit + Vector3.new(0, 0, 12))
		task.wait(4)
		model:Destroy()
		if lion == model then
			lion = nil
		end
	end)
	return true
end

local EVENTS = {
	{ name = "bighead", run = eventBigHeads },
	{ name = "ballrain", run = eventBallRain },
	{ name = "giantseeker", run = eventGiantSeeker },
	{ name = "giantball", run = eventGiantBall },
	{
		name = "lion",
		run = function()
			if not lionUsed then
				lionUsed = Fun.releaseLion()
			else
				eventBallRain()
			end
		end,
	},
}

function Fun.startRoundEvents()
	eventGeneration += 1
	lionUsed = false
	local myGeneration = eventGeneration
	if not Config.EVENTS_ENABLED then
		return
	end
	task.spawn(function()
		while eventGeneration == myGeneration do
			task.wait(math.random(Config.EVENT_INTERVAL_MIN, Config.EVENT_INTERVAL_MAX))
			if eventGeneration ~= myGeneration or phase() ~= "Seeking" then
				break
			end
			local event = EVENTS[math.random(1, #EVENTS)]
			local ok, err = pcall(event.run)
			if not ok then
				warn("Событие", event.name, "сломалось:", err)
			end
		end
	end)
end

function Fun.stopRoundEvents()
	eventGeneration += 1
	if lion then
		lion:Destroy()
		lion = nil
	end
	for _, p in Participants.all() do
		Effects.bigHead(p, false)
		Effects.scale(p, 1)
	end
end

----------------------------------------------------------------------
-- Гол и лучший игрок
----------------------------------------------------------------------

-- Празднование гола, как у Роналду
function Fun.siuu(hero)
	Effects.jump(hero)
	Effects.spin(hero, 0.7, 30)
	Effects.billboard(hero, "СИИИУ!", GOLD, 4)
	Sfx.play("Siuu", PlayerState.getPosition(hero))
	announce("СИИИУ!", GOLD)
end

-- Лучший игрок раунда носит корону в следующем раунде
function Fun.setMvp(player)
	if mvp and mvp ~= player then
		Effects.crown(mvp, false)
	end
	mvp = if player and not Participants.isBot(player) then player else nil
	if mvp then
		announce("👑 " .. mvp.DisplayName .. " — лучший игрок матча! В следующем раунде — с короной!", GOLD)
	end
end

function Fun.applyMvp()
	if mvp and mvp.Parent then
		Effects.crown(mvp, true)
	end
end

function Fun.removeCrown()
	if mvp then
		Effects.crown(mvp, false)
	end
end

----------------------------------------------------------------------
-- Секретная комната (вход — люк у углового флажка)
----------------------------------------------------------------------

local function buildSecretRoom(root: Instance)
	local m = Instance.new("Folder")
	m.Name = "SecretRoom"
	m.Parent = root
	local function part(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local center = Vector3.new(0, -80, 0)
	local gold = Color3.fromRGB(255, 200, 40)
	part(CFrame.new(center), Vector3.new(30, 1, 30), Color3.fromRGB(60, 30, 80), Enum.Material.Fabric)
	part(CFrame.new(center + Vector3.new(0, 12, 0)), Vector3.new(30, 1, 30), Color3.fromRGB(30, 20, 45))
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local size = if d.X ~= 0 then Vector3.new(1, 12, 30) else Vector3.new(30, 12, 1)
		part(CFrame.new(center + d * 15 + Vector3.new(0, 6, 0)), size, Color3.fromRGB(45, 25, 65), Enum.Material.Brick)
	end
	-- Надпись на стене
	local sign = part(CFrame.new(center + Vector3.new(0, 7, -14.4)), Vector3.new(20, 5, 0.2), Color3.fromRGB(20, 10, 30))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "ДАНЯ БЫЛ ЗДЕСЬ ★ 7"
	label.TextColor3 = gold
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = gui
	-- Золотой мяч на подставке
	part(CFrame.new(center + Vector3.new(-8, 1.5, -8)), Vector3.new(2.5, 2, 2.5), Color3.fromRGB(80, 60, 30), Enum.Material.Marble)
	local ball = part(CFrame.new(center + Vector3.new(-8, 3.6, -8)), Vector3.new(2.2, 2.2, 2.2), gold, Enum.Material.Foil)
	ball.Shape = Enum.PartType.Ball
	-- Сундук
	local chest = part(CFrame.new(center + Vector3.new(6, 1.6, -6)), Vector3.new(4, 2.2, 2.6), Color3.fromRGB(120, 70, 30), Enum.Material.Wood)
	chest.Name = "Chest"
	part(CFrame.new(center + Vector3.new(6, 2.85, -6)), Vector3.new(4.1, 0.3, 2.7), gold, Enum.Material.Foil)
	local chestPrompt = Instance.new("ProximityPrompt")
	chestPrompt.ActionText = "Открыть сундук"
	chestPrompt.ObjectText = "Секретный сундук"
	chestPrompt.HoldDuration = 0.5
	chestPrompt.Parent = chest
	-- Свет
	for _, offset in { Vector3.new(-8, 10, -8), Vector3.new(8, 10, 8) } do
		local lamp = part(CFrame.new(center + offset), Vector3.new(2, 0.3, 2), Color3.fromRGB(255, 120, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Color = Color3.fromRGB(255, 140, 255)
		light.Parent = lamp
	end
	-- Выход
	local exit = part(CFrame.new(center + Vector3.new(0, 4, 14.4)), Vector3.new(4, 7, 0.3), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	exit.Name = "Exit"
	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ActionText = "Выйти на стадион"
	exitPrompt.Parent = exit

	-- Люк у западного углового флажка
	local hatchPosition = Vector3.new(-map.FieldX + 6, 0.1, -map.FieldZ + 6)
	local hatch = part(CFrame.new(hatchPosition) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 3, 3), Color3.fromRGB(70, 72, 78), Enum.Material.DiamondPlate)
	hatch.Shape = Enum.PartType.Cylinder
	hatch.Name = "Hatch"
	hatch.CanCollide = false
	local hatchPrompt = Instance.new("ProximityPrompt")
	hatchPrompt.ActionText = "Залезть в люк"
	hatchPrompt.ObjectText = "Люк"
	hatchPrompt.MaxActivationDistance = 6
	hatchPrompt.Parent = hatch

	hatchPrompt.Triggered:Connect(function(player)
		PlayerState.teleport(player, CFrame.new(center + Vector3.new(0, 1, 8)))
	end)
	exitPrompt.Triggered:Connect(function(player)
		PlayerState.teleport(player, CFrame.new(hatchPosition + Vector3.new(4, 0, 4)))
	end)
	chestPrompt.Triggered:Connect(function(player)
		if Economy.claimSecret(player) then
			Effects.confetti(chest.Position + Vector3.new(0, 3, 0), 120)
			Remotes.get("Announce"):FireClient(player, "Секретный сундук! +" .. Config.SECRET_REWARD .. " монет!", GOLD)
		else
			Remotes.get("Announce"):FireClient(player, "Сундук пуст. Приходи завтра!", Color3.fromRGB(200, 200, 200))
		end
	end)
	return center
end

----------------------------------------------------------------------
-- Админ-панель Дани
----------------------------------------------------------------------

function Fun.isAdmin(player: Player): boolean
	if Config.HERO_USER_ID > 0 and player.UserId == Config.HERO_USER_ID then
		return true
	end
	if table.find(Config.ADMIN_USER_IDS, player.UserId) then
		return true
	end
	return Config.ADMIN_IN_STUDIO and RunService:IsStudio()
end

local discoGeneration = 0
local function disco()
	discoGeneration += 1
	local myGeneration = discoGeneration
	local lights = {}
	for _, d in map.Root:GetDescendants() do
		if d:IsA("SpotLight") or d:IsA("PointLight") then
			table.insert(lights, { light = d, color = d.Color })
		end
	end
	task.spawn(function()
		local hue = 0
		local endsAt = os.clock() + 20
		while os.clock() < endsAt and discoGeneration == myGeneration do
			hue = (hue + 0.13) % 1
			for i, item in lights do
				item.light.Color = Color3.fromHSV((hue + i * 0.07) % 1, 0.9, 1)
			end
			task.wait(0.3)
		end
		for _, item in lights do
			item.light.Color = item.color
		end
	end)
end

local ADMIN_COMMANDS = {
	tiny = function(admin)
		Commentator.say("tiny")
		local list = {}
		for _, p in Participants.all() do
			if p ~= admin then
				Effects.scale(p, 0.5)
				table.insert(list, p)
			end
		end
		task.delay(30, function()
			for _, p in list do
				Effects.scale(p, 1)
			end
		end)
	end,
	bighead = eventBigHeads,
	disco = function(admin)
		Commentator.say("disco")
		announce(admin.DisplayName .. " включил ДИСКОТЕКУ!", Color3.fromRGB(255, 100, 255))
		disco()
	end,
	statues = function()
		Statues.wakeAll()
		Commentator.say("statue")
	end,
	moon = function(admin)
		admin:SetAttribute("MoonMode", not admin:GetAttribute("MoonMode"))
	end,
	fireworks = function()
		local z = map.SideZ
		for _, offset in { Vector3.new(-80, 45, z), Vector3.new(0, 50, z), Vector3.new(80, 45, z), Vector3.new(-80, 45, -z), Vector3.new(0, 50, -z), Vector3.new(80, 45, -z) } do
			Effects.confetti(offset, 200)
		end
		Sfx.play("Goal")
	end,
	ballrain = eventBallRain,
	giantball = eventGiantBall,
	lion = function()
		if phase() == "Seeking" then
			Fun.releaseLion()
		end
	end,
	giant = eventGiantSeeker,
}

local function runAdmin(player: Player, command: any)
	if type(command) ~= "string" or not ADMIN_COMMANDS[command] or not Fun.isAdmin(player) then
		return
	end
	local key = tostring(player.UserId) .. command
	local t = os.clock()
	if (adminCooldown[key] or 0) > t then
		return
	end
	adminCooldown[key] = t + 5
	local ok, err = pcall(ADMIN_COMMANDS[command], player)
	if not ok then
		warn("Админ-команда", command, "сломалась:", err)
	end
end

----------------------------------------------------------------------

function Fun.init(builtMap, state: Folder, announceFn: (string, Color3?) -> ())
	map = builtMap
	gameState = state
	announce = announceFn
	map.SecretRoomCenter = buildSecretRoom(map.Root)

	local function setupPlayer(player: Player)
		player:SetAttribute("IsAdmin", Fun.isAdmin(player))
	end
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if mvp == player then
			mvp = nil
		end
	end)
	Remotes.get("Admin").OnServerEvent:Connect(runAdmin)
end

-- Для проверок и для ботов: выполнить админ-команду напрямую
Fun.runAdmin = runAdmin
Fun.inRound = inRound

return Fun
