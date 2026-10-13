-- Раунды: выбор водящего, прятки, поиски, тюрьма, Кубок, победа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Trophy = require(script.Parent.Trophy)
local Statues = require(script.Parent.Statues)
local Economy = require(script.Parent.Economy)
local Abilities = require(script.Parent.Abilities)
local Participants = require(script.Parent.Participants)
local Bots = require(script.Parent.Bots)
local Transform = require(script.Parent.Transform)
local Sfx = require(script.Parent.Sfx)

local RoundManager = {}

local SEEKER_RED = Color3.fromRGB(230, 50, 50)
local HIDER_GREEN = Color3.fromRGB(40, 210, 110)
local GOLD = Color3.fromRGB(255, 210, 60)

local map
local gameState: Folder
local seekerModel: ObjectValue
local announceRemote: RemoteEvent
local volunteers: { [Player]: boolean } = {}
local lastSeeker: Player? = nil

local seeker: Player? = nil
local hiders: { Player } = {} -- все прячущиеся этого раунда (и свободные, и в тюрьме)

local function announce(text: string, color: Color3?)
	announceRemote:FireAllClients(text, color or Color3.new(1, 1, 1))
end

local function setPhase(phase: string, duration: number?)
	gameState:SetAttribute("Phase", phase)
	gameState:SetAttribute("PhaseEndsAt", if duration then PlayerState.now() + duration else 0)
end

local function timeLeft(): number
	local endsAt = gameState:GetAttribute("PhaseEndsAt") or 0
	return math.max(0, endsAt - PlayerState.now())
end

local function formatTime(seconds: number): string
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function hidersIn(role: string): { Player }
	local list = {}
	for _, player in hiders do
		if player.Parent and PlayerState.getRole(player) == role then
			table.insert(list, player)
		end
	end
	return list
end

local function updateCounters()
	local free = #hidersIn("Hider")
	local jailed = #hidersIn("Jailed")
	gameState:SetAttribute("HidersFree", free)
	gameState:SetAttribute("HidersJailed", jailed)
	gameState:SetAttribute("Seeker", if seeker then seeker.DisplayName else "")

	local phase = gameState:GetAttribute("Phase")
	local text = "ПРЯТКИ ЗА КУБОК"
	if phase == "Hiding" then
		text ..= "\nПрячьтесь! " .. formatTime(timeLeft())
	elseif phase == "Seeking" then
		text ..= "\n" .. formatTime(timeLeft()) .. "\nВ тюрьме: " .. jailed .. " / " .. (free + jailed)
	elseif phase == "Intermission" then
		text ..= "\nСкоро раунд: " .. formatTime(timeLeft())
	end
	map.Scoreboard.Text = text
end

-- Случайная точка в центральном круге
local function hiderSpawnCFrame(): CFrame
	local angle = math.random() * math.pi * 2
	local r = math.random() * 14
	return CFrame.new(map.HiderSpawnCenter + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
end

local function jailCFrame(): CFrame
	local h = map.JailHalf - 2
	return CFrame.new(map.JailCenter + Vector3.new(math.random(-h, h), 0.5, math.random(-h, h)))
end

local function addSeekerGear(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("SeekerTag") then
		return
	end
	local flashlight = Instance.new("SpotLight")
	flashlight.Name = "Flashlight"
	flashlight.Face = Enum.NormalId.Front
	flashlight.Range = 60
	flashlight.Angle = 50
	flashlight.Brightness = 6
	flashlight.Color = Color3.fromRGB(255, 250, 220)
	flashlight.Shadows = true
	flashlight.Parent = head

	local tag = Instance.new("BillboardGui")
	tag.Name = "SeekerTag"
	tag.Size = UDim2.fromOffset(140, 34)
	tag.StudsOffset = Vector3.new(0, 2.5, 0)
	tag.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "ВОДЯЩИЙ"
	label.TextColor3 = SEEKER_RED
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = tag
	tag.Parent = head
end

local function removeSeekerGear(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		for _, name in { "Flashlight", "SeekerTag" } do
			local child = head:FindFirstChild(name)
			if child then
				child:Destroy()
			end
		end
	end
end

-- Куда поставить игрока, когда он появился (или заново появился) в раунде
local function placeByRole(player: Player)
	local role = PlayerState.getRole(player)
	local phase = gameState:GetAttribute("Phase")
	if role == "Seeker" then
		if phase == "Hiding" then
			PlayerState.teleport(player, map.SeekerBoxCFrame)
		else
			PlayerState.teleport(player, map.SeekerReleaseCFrame)
		end
		addSeekerGear(player)
	elseif role == "Hider" then
		PlayerState.teleport(player, hiderSpawnCFrame())
	elseif role == "Jailed" then
		PlayerState.teleport(player, jailCFrame())
	else
		PlayerState.teleport(player, map.LobbyCFrame)
	end
end

local function chooseSeeker(candidates: { Player }): Player
	local wanted = {}
	for _, player in candidates do
		if volunteers[player] then
			table.insert(wanted, player)
		end
	end
	local pool = if #wanted > 0 then wanted else candidates
	-- Не даём одному и тому же водить два раза подряд, если есть другие
	if #pool > 1 and lastSeeker then
		local filtered = {}
		for _, player in pool do
			if player ~= lastSeeker then
				table.insert(filtered, player)
			end
		end
		pool = filtered
	end
	return pool[math.random(1, #pool)]
end

local function jail(player: Player)
	if Trophy.getCarrier() == player then
		Trophy.drop()
		announce(player.DisplayName .. " уронил Кубок!", GOLD)
	end
	Sfx.play("Catch", PlayerState.getPosition(player))
	Transform.revert(player)
	PlayerState.setRole(player, "Jailed")
	PlayerState.teleport(player, jailCFrame())
	if seeker then
		Economy.addCoins(seeker, Config.COINS.CATCH)
	end
	announce("Водящий поймал " .. player.DisplayName .. "! Он в тюрьме.", SEEKER_RED)
	updateCounters()
end

local function release(rescuer: Player, prisoner: Player)
	PlayerState.setRole(prisoner, "Hider")
	PlayerState.makeSafe(prisoner, Config.RESCUE_IMMUNITY)
	PlayerState.teleport(prisoner, hiderSpawnCFrame())
	Economy.addCoins(rescuer, Config.COINS.RESCUE)
	Sfx.play("Rescue", PlayerState.getPosition(rescuer))
	announce(rescuer.DisplayName .. " освободил " .. prisoner.DisplayName .. "!", HIDER_GREEN)
	updateCounters()
end

-- Салют из конфетти и рёв стадиона
local function celebrateGoal(position: Vector3)
	Sfx.play("Goal")
	Sfx.play("Cheer")
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position + Vector3.new(0, 4, 0)
	holder.Parent = game:GetService("Workspace")
	local confetti = Instance.new("ParticleEmitter")
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 170, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	confetti.Size = NumberSequence.new(0.4)
	confetti.Speed = NumberRange.new(25, 45)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Lifetime = NumberRange.new(2, 4)
	confetti.Acceleration = Vector3.new(0, -20, 0)
	confetti.Rate = 0
	confetti.Parent = holder
	confetti:Emit(300)
	task.delay(6, function()
		holder:Destroy()
	end)
end

local function inGoal(position: Vector3): boolean
	for _, goal in map.Goals do
		if
			position.X > goal.XMin
			and position.X < goal.XMax
			and math.abs(position.Z) < goal.ZHalf
			and position.Y < goal.YMax
		then
			return true
		end
	end
	return false
end

-- Одна проверка во время поисков. Возвращает победителя ("Hiders" / "Seeker") и причину.
local function tick(): (string?, string?, Player?)
	if #Participants.real() == 0 then
		return nil, "Все игроки ушли.", nil
	end
	if not seeker or not seeker.Parent then
		return "Hiders", "Водящий ушёл из игры. Прячущиеся победили!", nil
	end
	local free = hidersIn("Hider")
	local jailed = hidersIn("Jailed")
	if #free + #jailed == 0 then
		return "Seeker", "Все прячущиеся ушли из игры.", nil
	end

	Trophy.checkCarrier()

	-- Водящий ловит
	local seekerPosition = PlayerState.getPosition(seeker)
	if seekerPosition and not PlayerState.isFrozen(seeker) then
		for _, player in free do
			local position = PlayerState.getPosition(player)
			if position and not PlayerState.isSafe(player) and (position - seekerPosition).Magnitude <= Config.CATCH_DISTANCE then
				jail(player)
			end
		end
	end

	free = hidersIn("Hider")
	jailed = hidersIn("Jailed")
	if #free == 0 then
		return "Seeker", "Водящий поймал всех! Водящий победил!", seeker
	end

	-- Друзья освобождают из тюрьмы касанием
	for _, rescuer in free do
		local rescuerPosition = PlayerState.getPosition(rescuer)
		if rescuerPosition and not PlayerState.isFrozen(rescuer) then
			for _, prisoner in jailed do
				local prisonerPosition = PlayerState.getPosition(prisoner)
				if
					PlayerState.getRole(prisoner) == "Jailed"
					and prisonerPosition
					and (prisonerPosition - rescuerPosition).Magnitude <= Config.RESCUE_DISTANCE
				then
					release(rescuer, prisoner)
				end
			end
		end
	end

	-- Кубок
	local picked = Trophy.update(free)
	if picked then
		Transform.revert(picked) -- с Кубком над головой предметом не притворишься
		Sfx.play("Trophy")
		announce(picked.DisplayName .. " нашёл Кубок мира! Беги к воротам!", GOLD)
	end
	local carrier = Trophy.getCarrier()
	if carrier then
		local position = PlayerState.getPosition(carrier)
		if position and inGoal(position) then
			celebrateGoal(position)
			return "Hiders", "ГООООЛ! " .. carrier.DisplayName .. " забил Кубок в ворота! Прячущиеся победили!", carrier
		end
	end

	if timeLeft() <= 0 then
		return "Seeker", "Время вышло! Кубок не забили. Водящий победил!", seeker
	end
	return nil, nil, nil
end

local function botsEnabled(): boolean
	return gameState:GetAttribute("BotsEnabled") == true
end

-- Хватает ли людей, чтобы начать раунд (с ботами хватает и одного)
local function enoughPlayers(): boolean
	local real = #Participants.real()
	if botsEnabled() then
		return real >= 1
	end
	return real >= Config.MIN_PLAYERS
end

local function waitPhase(seconds: number, phase: string, abort: (() -> boolean)?): boolean
	setPhase(phase, seconds)
	while timeLeft() > 0 do
		if abort and abort() then
			return false
		end
		updateCounters()
		task.wait(0.25)
	end
	return true
end

local function endRound(winner: string?, reason: string, hero: Player?)
	setPhase("End", Config.END_TIME)
	Statues.disable()
	Transform.revertAll()
	seekerModel.Value = nil
	announce(reason, if winner == "Seeker" then SEEKER_RED else HIDER_GREEN)

	for _, player in hiders do
		if player.Parent then
			Economy.addCoins(player, Config.COINS.PLAY)
			if winner == "Hiders" then
				Economy.addCoins(player, Config.COINS.WIN)
			end
		end
	end
	if seeker and seeker.Parent then
		Economy.addCoins(seeker, Config.COINS.PLAY)
		if winner == "Seeker" then
			Economy.addCoins(seeker, Config.COINS.WIN)
		end
	end
	if hero and hero.Parent and winner == "Hiders" then
		Economy.addCoins(hero, Config.COINS.GOAL)
	end
	gameState:SetAttribute("LastWinner", winner or "")
	updateCounters()

	task.wait(Config.END_TIME)

	Trophy.remove()
	for _, player in Participants.all() do
		removeSeekerGear(player)
		PlayerState.setRole(player, "Lobby")
		PlayerState.reset(player)
		Abilities.resetCooldowns(player)
		PlayerState.teleport(player, map.LobbyCFrame)
	end
	Bots.despawnAll()
	if seeker then
		lastSeeker = seeker
	end
	seeker = nil
	table.clear(hiders)
	updateCounters()
end

local function runRound()
	-- Добавляем ботов, если людей мало
	if botsEnabled() then
		local real = #Participants.real()
		local count = math.clamp(Config.BOT_FILL_TO - real, 0, Config.MAX_HIDERS + 1 - real)
		for _ = 1, count do
			Bots.spawn()
		end
		if count > 0 then
			announce("В игру добавлены боты: " .. count, Color3.fromRGB(150, 200, 255))
		end
	end
	local players = Participants.all()
	seeker = chooseSeeker(players)
	table.clear(hiders)
	for _, player in players do
		PlayerState.reset(player)
		Abilities.resetCooldowns(player)
		if player == seeker then
			PlayerState.setRole(player, "Seeker")
		elseif #hiders < Config.MAX_HIDERS then
			PlayerState.setRole(player, "Hider")
			table.insert(hiders, player)
		else
			PlayerState.setRole(player, "Lobby") -- мест нет, смотрит из ложи
		end
	end
	local currentSeeker = seeker :: Player

	-- Прячемся
	setPhase("Hiding", Config.HIDE_TIME)
	for _, player in players do
		placeByRole(player)
	end
	announce(currentSeeker.DisplayName .. " водит! Прячьтесь!", HIDER_GREEN)

	local finished = waitPhase(Config.HIDE_TIME, "Hiding", function()
		return not currentSeeker.Parent or #hidersIn("Hider") == 0 or #Participants.real() == 0
	end)
	if not finished then
		if #Participants.real() == 0 then
			endRound(nil, "Все игроки ушли.", nil)
		elseif not currentSeeker.Parent then
			endRound("Hiders", "Водящий ушёл из игры. Прячущиеся победили!", nil)
		else
			endRound(nil, "Все прячущиеся ушли из игры.", nil)
		end
		return
	end

	-- Ищем!
	setPhase("Seeking", Config.ROUND_TIME)
	PlayerState.teleport(currentSeeker, map.SeekerReleaseCFrame)
	addSeekerGear(currentSeeker)
	seekerModel.Value = currentSeeker.Character
	Trophy.spawn(map.TrophySpots)
	Statues.enable()
	Sfx.play("Whistle")
	announce("Водящий вышел искать! Найдите Кубок мира и забейте его в ворота!", GOLD)

	local lastCounters = 0
	while true do
		local winner, reason, hero = tick()
		if reason then
			endRound(winner, reason, hero)
			return
		end
		if os.clock() - lastCounters > 0.5 then
			lastCounters = os.clock()
			updateCounters()
		end
		task.wait(0.1)
	end
end

local function onCharacterAdded(player: Player, _character: Model)
	-- Подождать, пока персонаж загрузится, потом поставить на место по роли
	task.wait(0.2)
	Transform.forget(player)
	PlayerState.syncCharacter(player)
	local phase = gameState:GetAttribute("Phase")
	if phase == "Hiding" or phase == "Seeking" then
		local role = PlayerState.getRole(player)
		if role == "Hider" and Trophy.getCarrier() == player then
			Trophy.drop()
		end
		placeByRole(player)
		if role == "Seeker" and phase == "Seeking" then
			seekerModel.Value = player.Character
		end
	end
end

-- Превратиться в предмет / стать собой (для людей и ботов)
function RoundManager.toggleTransform(participant): boolean
	local phase = gameState:GetAttribute("Phase")
	local can = PlayerState.getRole(participant) == "Hider"
		and (phase == "Hiding" or phase == "Seeking")
		and Trophy.getCarrier() ~= participant
		and not PlayerState.isFrozen(participant)
	local changed = Transform.toggle(participant, can)
	if changed then
		Sfx.play("Transform", PlayerState.getPosition(participant))
	end
	return changed
end

function RoundManager.start(builtMap)
	map = builtMap

	gameState = Instance.new("Folder")
	gameState.Name = "GameState"
	seekerModel = Instance.new("ObjectValue")
	seekerModel.Name = "SeekerModel" -- персонаж водящего: по нему стучит сердце
	seekerModel.Parent = gameState
	gameState.Parent = ReplicatedStorage
	announceRemote = Remotes.get("Announce")

	Trophy.init(gameState)
	Statues.build(map.Root, map.StatueHomes, map.StatueColor, announce)
	Abilities.start(gameState, announce)

	local function setupPlayer(player: Player)
		PlayerState.setRole(player, "Lobby")
		player:SetAttribute("Volunteer", false)
		Abilities.resetCooldowns(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	gameState:SetAttribute("BotsEnabled", Config.BOTS_ENABLED)
	Bots.init(map, gameState)
	Remotes.get("ToggleBots").OnServerEvent:Connect(function(_player, enabled)
		if type(enabled) == "boolean" then
			gameState:SetAttribute("BotsEnabled", enabled)
		end
	end)
	gameState:SetAttribute("BotLevel", Config.BOT_LEVEL)
	Remotes.get("BotLevel").OnServerEvent:Connect(function(_player, level)
		if type(level) == "string" and Config.BOT_LEVELS[level] then
			Config.BOT_LEVEL = level
			gameState:SetAttribute("BotLevel", level)
		end
	end)

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		volunteers[player] = nil
		if lastSeeker == player then
			lastSeeker = nil
		end
	end)

	Remotes.get("Transform").OnServerEvent:Connect(function(player)
		RoundManager.toggleTransform(player)
	end)

	Remotes.get("Volunteer").OnServerEvent:Connect(function(player, wants)
		volunteers[player] = wants == true
		player:SetAttribute("Volunteer", wants == true)
	end)

	task.spawn(function()
		while true do
			-- Ждём игроков
			setPhase("Waiting")
			updateCounters()
			while not enoughPlayers() do
				task.wait(1)
			end

			local ready = waitPhase(Config.INTERMISSION_TIME, "Intermission", function()
				return not enoughPlayers()
			end)
			if ready then
				local ok, err = pcall(runRound)
				if not ok then
					warn("Ошибка в раунде:", err)
					Statues.disable()
					Trophy.remove()
					for _, player in Participants.all() do
						removeSeekerGear(player)
						PlayerState.setRole(player, "Lobby")
						PlayerState.reset(player)
						PlayerState.teleport(player, map.LobbyCFrame)
					end
					Bots.despawnAll()
					seeker = nil
					table.clear(hiders)
				end
			end
		end
	end)
end

return RoundManager
