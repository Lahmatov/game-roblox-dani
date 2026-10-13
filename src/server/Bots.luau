-- Боты: появляются, если настоящих игроков мало.
-- Бот-прячущийся прячется, ищет Кубок, убегает от водящего, пинает мяч и освобождает друзей.
-- Бот-водящий ищет прячущихся, гонится за ними и первым делом ловит того, у кого Кубок.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Participants = require(script.Parent.Participants)
local PlayerState = require(script.Parent.PlayerState)
local Trophy = require(script.Parent.Trophy)
local Abilities = require(script.Parent.Abilities)
local Transform = require(script.Parent.Transform)
local Sfx = require(script.Parent.Sfx)

local Bots = {}

local NAMES = { "Лео", "Макс", "Тим", "Ник", "Артём", "Миша", "Сава", "Гоша", "Рома", "Стас", "Лёва", "Федя", "Вова", "Илья", "Марк", "Егор" }
local SKIN = {
	Color3.fromRGB(255, 220, 177),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),
	Color3.fromRGB(245, 205, 48),
}
-- Что говорят глупые боты
local PHRASES = {
	idle = { "Я хорошо спрятался!", "Тут меня никто не найдёт", "Кубок? Какой кубок?", "Ой, я заблудился", "А где все?", "Хочу пиццу", "Мама, я на стадионе!", "Я невидимка!" },
	scared = { "АААА!", "Ой-ой-ой!", "Меня не видно!", "Я просто статуя!", "Не трогай меня!" },
	seeker = { "Кто здесь?", "Я всех найду!", "Где же вы?", "Ой, я устал", "Раз, два, три..." },
	caught = { "Ну во-о-от...", "Это нечестно!", "Я же спрятался!", "Спасите!" },
	distracted = { "О, бабочка!", "Смотрите, птичка!", "Я танцую!", "Какой красивый газон!", "Апчхи!" },
	trophy = { "У МЕНЯ КУБОК!", "Ура-а-а!", "Куда бежать?!" },
	prop = { "Я просто мяч...", "Я конус. Честно!", "Меня тут нет", "Я бутылка водички", "Я урна, не смотри" },
}
local WALK_ANIMATION = "rbxassetid://507777826" -- стандартная анимация ходьбы R15
local IDLE_ANIMATION = "rbxassetid://507766666" -- стандартная анимация стояния R15

local map
local gameState: Folder
local nextId = 0

type Brain = {
	bot: any,
	personality: string, -- "searcher" ищет Кубок, "hider" сидит тихо, "rescuer" спасает друзей
	target: Vector3?,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	computedAt: number,
	lastProgressAt: number,
	lastPosition: Vector3?,
	spot: Vector3?,
	visited: { [any]: { [number]: boolean } },
	searchDelay: number,
	distractedUntil: number,
	distractTarget: Vector3?,
	fleeDecisionUntil: number,
	willFlee: boolean,
	fleeWrongWay: boolean,
	chaseTarget: any,
	chaseStartedAt: number,
	ignore: { [any]: number },
	lastRole: string?,
	alive: boolean,
}

local brains: { [any]: Brain } = {}

local function phase(): string
	return gameState:GetAttribute("Phase") or "Waiting"
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distance(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

----------------------------------------------------------------------
-- Персонаж бота
----------------------------------------------------------------------

local function buildCharacter(name: string): Model
	local kit = Config.KITS[math.random(1, #Config.KITS)]
	local skin = SKIN[math.random(1, #SKIN)]
	local model: Model? = nil
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = skin
		description.LeftArmColor = kit.Shirt
		description.RightArmColor = kit.Shirt
		description.TorsoColor = kit.Shirt
		description.LeftLegColor = kit.Shorts
		description.RightLegColor = kit.Shorts
		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		-- Запасной простой человечек, если Roblox не смог сделать обычного
		local m = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.Parent = m
		local function limb(partName: string, size: Vector3, offset: Vector3, color: Color3)
			local p = Instance.new("Part")
			p.Name = partName
			p.Size = size
			p.Color = color
			p.CFrame = root.CFrame * CFrame.new(offset)
			p.CanCollide = partName == "Head"
			p.Parent = m
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
		limb("Torso", Vector3.new(2, 2, 1), Vector3.zero, kit.Shirt)
		limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), skin)
		limb("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), kit.Shirt)
		limb("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), kit.Shirt)
		limb("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), kit.Shorts)
		limb("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), kit.Shorts)
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = 2
		humanoid.Parent = m
		m.PrimaryPart = root
		model = m
	end
	local character = model :: Model
	character.Name = name
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 60
	end
	-- Скрипт анимации игрока у бота не работает, поэтому убираем его и анимируем сами
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	return character
end

local function setupAnimations(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = WALK_ANIMATION
		local idleAnim = Instance.new("Animation")
		idleAnim.AnimationId = IDLE_ANIMATION
		local walk = animator:LoadAnimation(walkAnim)
		local idle = animator:LoadAnimation(idleAnim)
		idle:Play()
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 then
				if not walk.IsPlaying then
					idle:Stop()
					walk:Play()
				end
			elseif walk.IsPlaying then
				walk:Stop()
				idle:Play()
			end
		end)
	end)
end

----------------------------------------------------------------------
-- Ходьба по стадиону с поиском пути
----------------------------------------------------------------------

local function humanoidOf(bot): Humanoid?
	local character = bot.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function stop(brain: Brain)
	brain.target = nil
	table.clear(brain.waypoints)
	local humanoid = humanoidOf(brain.bot)
	local position = PlayerState.getPosition(brain.bot)
	if humanoid and position then
		humanoid:MoveTo(position)
	end
end

local function computePath(brain: Brain, from: Vector3, to: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 8,
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	table.clear(brain.waypoints)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(brain.waypoints, waypoint)
		end
		brain.waypointIndex = math.min(2, #brain.waypoints)
	end
	brain.computedAt = os.clock()
end

-- Идти к точке. Путь пересчитывается, если цель сдвинулась или бот застрял.
local function go(brain: Brain, target: Vector3, recomputeEvery: number?)
	local humanoid = humanoidOf(brain.bot)
	local position = PlayerState.getPosition(brain.bot)
	if not humanoid or not position then
		return
	end
	local now = os.clock()

	-- Застрял? (за 2 секунды почти не сдвинулся)
	if brain.lastPosition and (position - brain.lastPosition).Magnitude > 1.5 then
		brain.lastProgressAt = now
		brain.lastPosition = position
	elseif not brain.lastPosition then
		brain.lastPosition = position
		brain.lastProgressAt = now
	end
	local stuck = now - brain.lastProgressAt > 2 and humanoid.WalkSpeed > 0

	local targetMoved = not brain.target or (brain.target - target).Magnitude > 6
	local stale = now - brain.computedAt > (recomputeEvery or 4)
	if targetMoved or stale or stuck or #brain.waypoints == 0 then
		brain.target = target
		computePath(brain, position, target)
		if stuck then
			humanoid.Jump = true
			brain.lastProgressAt = now
		end
	end

	local waypoint = brain.waypoints[brain.waypointIndex]
	if waypoint then
		if distance(position, waypoint.Position) < 3 and brain.waypointIndex < #brain.waypoints then
			brain.waypointIndex += 1
			waypoint = brain.waypoints[brain.waypointIndex]
		end
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	else
		-- Пути нет — просто идём напрямую
		humanoid:MoveTo(target)
	end
end

----------------------------------------------------------------------
-- Болтовня
----------------------------------------------------------------------

local function say(bot, kind: string)
	local character = bot.Character
	local head = character and character:FindFirstChild("Head")
	local list = PHRASES[kind]
	if not head or not list then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Speech"
	bubble.Size = UDim2.fromOffset(180, 44)
	bubble.StudsOffset = Vector3.new(0, 3.6, 0)
	bubble.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(20, 20, 20)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = list[math.random(1, #list)]
	label.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	bubble.Parent = head
	task.delay(3, function()
		if bubble.Parent then
			bubble:Destroy()
		end
	end)
end

----------------------------------------------------------------------
-- Что видит бот
----------------------------------------------------------------------

local function canSee(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Participants.all() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(from + Vector3.new(0, 1.5, 0), (to - from), params)
	return result == nil
end

-- Сколько секунд уже идут поиски
local function seekingElapsed(): number
	local endsAt = gameState:GetAttribute("PhaseEndsAt") or 0
	return Config.ROUND_TIME - (endsAt - PlayerState.now())
end

local function findSeeker()
	for _, p in Participants.all() do
		if PlayerState.getRole(p) == "Seeker" then
			return p
		end
	end
	return nil
end

local function goalTarget(position: Vector3): Vector3
	local x = if position.X >= 0 then 113 else -113
	return Vector3.new(x, 0, 0)
end

local function randomSpot(brain: Brain, spots: { Vector3 }): Vector3
	local visited = brain.visited[spots]
	if not visited then
		visited = {}
		brain.visited[spots] = visited
	end
	local options = {}
	for i = 1, #spots do
		if not visited[i] then
			table.insert(options, i)
		end
	end
	if #options == 0 then
		table.clear(visited)
		for i = 1, #spots do
			table.insert(options, i)
		end
	end
	local index = options[math.random(1, #options)]
	visited[index] = true
	return spots[index]
end

----------------------------------------------------------------------
-- Мысли бота
----------------------------------------------------------------------

local function thinkJailed(brain: Brain, position: Vector3)
	-- Подойти к решётке со стороны поля, чтобы друзья могли освободить
	local center = map.JailCenter
	local spot = Vector3.new(center.X + map.JailHalf - 1.5, 0, math.clamp(position.Z, center.Z - 5, center.Z + 5))
	if distance(position, spot) > 1.5 then
		go(brain, spot)
	end
end

local function openFieldSpot(): Vector3
	return Vector3.new(math.random(-90, 90), 0, math.random(-55, 55))
end

-- Глупый бот иногда отвлекается: идёт куда-то или пляшет на месте
local function distracted(brain: Brain, position: Vector3): boolean
	local level = Config.bot()
	local now = os.clock()
	if now < brain.distractedUntil then
		local humanoid = humanoidOf(brain.bot)
		if brain.distractTarget then
			go(brain, brain.distractTarget)
		elseif humanoid then
			stop(brain)
			humanoid.Jump = true -- танцует
		end
		return true
	end
	if math.random() < level.DistractChance then
		brain.distractedUntil = now + math.random(2, 5)
		brain.distractTarget = if math.random() < 0.5
			then position + Vector3.new(math.random(-25, 25), 0, math.random(-25, 25))
			else nil
		say(brain.bot, "distracted")
		return true
	end
	return false
end

local function thinkHider(brain: Brain, position: Vector3)
	local bot = brain.bot
	local level = Config.bot()
	if phase() == "Hiding" then
		if not brain.spot then
			brain.spot = if math.random() < level.OpenHideChance then openFieldSpot() else randomSpot(brain, map.HideSpots)
		end
		go(brain, brain.spot :: Vector3)
		return
	end

	local seeker = findSeeker()
	local seekerPosition = seeker and PlayerState.getPosition(seeker)
	local seekerDistance = if seekerPosition then distance(position, seekerPosition) else math.huge

	-- С Кубком — бежим к воротам!
	if Trophy.getCarrier() == bot then
		if brain.target == nil or math.random() < level.TalkChance * 3 then
			say(bot, "trophy")
		end
		if seekerDistance < 15 and math.random() < level.DashChance then
			Abilities.tryDash(bot)
		end
		go(brain, goalTarget(position), 1.5)
		return
	end

	if distracted(brain, position) then
		return
	end

	-- Водящий рядом — убегаем (глупый бот может и не догадаться, или убежать не туда)
	local now = os.clock()
	if seekerPosition and seekerDistance < level.FleeDistance and canSee(position, seekerPosition) then
		if now > brain.fleeDecisionUntil then
			brain.fleeDecisionUntil = now + 3
			brain.willFlee = math.random() < level.FleeChance
			brain.fleeWrongWay = math.random() < level.WrongWayChance
			say(bot, "scared")
		end
	end
	if seekerPosition and seekerDistance < level.FleeDistance and now < brain.fleeDecisionUntil and brain.willFlee then
		if seekerDistance > 8 and math.random() < level.KickChance then
			-- Глупые боты пинают мяч куда попало
			local angle = math.rad(math.random(-90, 90)) * (1 - level.FleeChance)
			Abilities.tryKick(bot, CFrame.Angles(0, angle, 0) * (seekerPosition - position))
		end
		if seekerDistance < 14 and math.random() < level.DashChance then
			Abilities.tryDash(bot)
		end
		if math.random() < level.BananaChance then
			Abilities.tryBanana(bot)
		end
		local away = flat(position - seekerPosition)
		if away.Magnitude < 0.1 then
			away = Vector3.new(1, 0, 0)
		end
		if brain.fleeWrongWay then
			away = -away
		end
		local escape = position + away.Unit * 30
		escape = Vector3.new(math.clamp(escape.X, -130, 130), 0, math.clamp(escape.Z, -80, 80))
		brain.spot = nil
		go(brain, escape, 1)
		return
	end

	-- Видим Кубок — бежим за ним
	local trophyPosition = Trophy.getGroundPosition()
	if
		trophyPosition
		and seekingElapsed() > level.NoticeDelay
		and distance(position, trophyPosition) < level.TrophySight
		and canSee(position, trophyPosition + Vector3.new(0, 1, 0))
	then
		go(brain, trophyPosition, 1.5)
		return
	end

	-- Спасаем друзей из тюрьмы, если водящий далеко
	if brain.personality == "rescuer" and seekerDistance > 50 then
		for _, p in Participants.all() do
			if PlayerState.getRole(p) == "Jailed" then
				local prisonerPosition = PlayerState.getPosition(p)
				if prisonerPosition then
					local center = map.JailCenter
					local outside = Vector3.new(center.X + map.JailHalf + 1.5, 0, math.clamp(prisonerPosition.Z, center.Z - 6, center.Z + 6))
					go(brain, outside, 2)
					return
				end
			end
		end
	end

	-- Ищем Кубок по разным местам или тихо сидим (искать начинаем не сразу)
	if brain.personality ~= "searcher" or seekingElapsed() < brain.searchDelay then
		brain.spot = brain.spot or randomSpot(brain, map.HideSpots)
		if distance(position, brain.spot :: Vector3) > 3 then
			go(brain, brain.spot :: Vector3)
		else
			stop(brain)
			if math.random() < level.TalkChance then
				say(bot, if Transform.isTransformed(bot) then "prop" else "idle")
			end
			if math.random() < level.TalkChance then
				Abilities.tryTaunt(bot) -- глупые боты сами себя выдают дразнилкой
			end
			if not Transform.isTransformed(bot) and math.random() < level.TransformChance then
				if Transform.transform(bot) then
					Sfx.play("Transform", position)
					say(bot, "prop")
				end
			end
			-- Иногда посидевший бот тоже идёт искать
			if brain.personality == "hider" and math.random() < 0.005 then
				brain.personality = "searcher"
				brain.spot = nil
			end
		end
	else
		if not brain.spot or distance(position, brain.spot :: Vector3) < 5 then
			brain.spot = randomSpot(brain, map.TrophySpots)
		end
		go(brain, brain.spot :: Vector3)
	end
end

local function thinkSeeker(brain: Brain, position: Vector3)
	if phase() ~= "Seeking" or PlayerState.isFrozen(brain.bot) then
		return
	end
	local level = Config.bot()
	local now = os.clock()
	if math.random() < level.TalkChance then
		say(brain.bot, "seeker")
	end

	-- Главная цель — тот, у кого Кубок
	local carrier = Trophy.getCarrier()
	local carrierPosition = carrier and PlayerState.getPosition(carrier)
	local carrierRange = if level.Sight >= 70 then 160 else level.Sight * 2
	if carrierPosition and distance(position, carrierPosition) < carrierRange then
		go(brain, carrierPosition, 0.75)
		return
	end

	if distracted(brain, position) then
		return
	end

	-- Ближайший прячущийся, которого видно (глупый водящий быстро сдаётся)
	local best, bestPosition, bestDistance = nil, nil, level.Sight
	for _, p in Participants.all() do
		if PlayerState.getRole(p) == "Hider" and not PlayerState.isSafe(p) and (brain.ignore[p] or 0) < now then
			local pPosition = PlayerState.getPosition(p)
			if pPosition then
				local d = distance(position, pPosition)
				-- Предмет (конус, мяч...) бот замечает только совсем рядом
				local limit = if Transform.isTransformed(p)
					then math.min(bestDistance, Config.TRANSFORMED_SPOT_DISTANCE)
					else bestDistance
				if d < limit and (d < 15 or canSee(position, pPosition)) then
					best, bestPosition, bestDistance = p, pPosition, d
				end
			end
		end
	end
	if best and bestPosition then
		if brain.chaseTarget ~= best then
			brain.chaseTarget = best
			brain.chaseStartedAt = now
		elseif now - brain.chaseStartedAt > level.GiveUpChase then
			brain.ignore[best] = now + 8
			brain.chaseTarget = nil
			say(brain.bot, "seeker")
		end
		brain.spot = nil
		go(brain, bestPosition, 0.75)
		return
	end
	brain.chaseTarget = nil

	-- Никого не видно — обходим места, где обычно прячутся
	if not brain.spot or distance(position, brain.spot :: Vector3) < 5 then
		brain.spot = randomSpot(brain, map.HideSpots)
	end
	go(brain, brain.spot :: Vector3)
end

local function think(brain: Brain)
	local bot = brain.bot
	local position = PlayerState.getPosition(bot)
	if not position then
		return
	end
	local p = phase()
	if p ~= "Hiding" and p ~= "Seeking" then
		stop(brain)
		return
	end
	local role = PlayerState.getRole(bot)
	if role ~= brain.lastRole then
		if role == "Jailed" then
			say(bot, "caught")
		end
		brain.lastRole = role
	end
	if role == "Seeker" then
		thinkSeeker(brain, position)
	elseif role == "Hider" then
		thinkHider(brain, position)
	elseif role == "Jailed" then
		brain.spot = nil
		thinkJailed(brain, position)
	end
end

----------------------------------------------------------------------
-- Появление и удаление ботов
----------------------------------------------------------------------

function Bots.init(builtMap, state: Folder)
	map = builtMap
	gameState = state
end

-- Создать бота и поставить его в лобби. Возвращает объект-участника.
function Bots.spawn()
	nextId += 1
	local name = "Бот " .. NAMES[(nextId - 1) % #NAMES + 1]
	local bot = Participants.newBot(name, nextId)
	local character = buildCharacter(name)
	character:PivotTo(map.LobbyCFrame + Vector3.new(math.random(-15, 15), 3, math.random(-15, 15)))
	character.Parent = Workspace
	bot.Character = character
	PlayerState.setRole(bot, "Lobby")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	setupAnimations(character)

	-- Характеры по очереди, чтобы в каждом раунде были и искатели, и спасатели
	local personalities = { "searcher", "rescuer", "hider", "searcher", "rescuer" }
	local brain: Brain = {
		bot = bot,
		personality = personalities[(nextId - 1) % #personalities + 1],
		target = nil,
		waypoints = {},
		waypointIndex = 1,
		computedAt = 0,
		lastProgressAt = os.clock(),
		lastPosition = nil,
		spot = nil,
		visited = {},
		searchDelay = math.random(Config.bot().SearchDelayMin, Config.bot().SearchDelayMax),
		distractedUntil = 0,
		distractTarget = nil,
		fleeDecisionUntil = 0,
		willFlee = false,
		fleeWrongWay = false,
		chaseTarget = nil,
		chaseStartedAt = 0,
		ignore = {},
		lastRole = nil,
		alive = true,
	}
	brains[bot] = brain

	task.spawn(function()
		while brain.alive do
			local ok, err = pcall(think, brain)
			if not ok then
				warn("Бот", name, "запутался:", err)
			end
			task.wait(Config.bot().ThinkInterval + math.random() * 0.1)
		end
	end)
	return bot
end

function Bots.despawnAll()
	for bot, brain in brains do
		brain.alive = false
		Transform.forget(bot)
		if bot.Character then
			bot.Character:Destroy()
			bot.Character = nil
		end
		Participants.removeBot(bot)
	end
	table.clear(brains)
end

return Bots
