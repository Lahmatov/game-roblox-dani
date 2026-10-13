-- Экран игрока: таймер, роль, сообщения, кнопки суперспособностей и магазин.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local gameState = ReplicatedStorage:WaitForChild("GameState")

local FONT = Enum.Font.SourceSansBold
local GREEN = Color3.fromRGB(0, 128, 72)
local DARK = Color3.fromRGB(20, 24, 30)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(220, 50, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "PryatkiUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Font = FONT
	l.TextStrokeTransparency = 0.4
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = WHITE
	b.TextScaled = true
	b.Font = FONT
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

-- Верхняя панель: фаза и время
local top = Instance.new("Frame")
top.Size = UDim2.fromOffset(360, 70)
top.Position = UDim2.new(0.5, -180, 0, 8)
top.BackgroundColor3 = DARK
top.BackgroundTransparency = 0.25
top.Parent = gui
corner(top, 12)
local phaseLabel = label(top, "", UDim2.new(1, -16, 0.6, 0), UDim2.fromOffset(8, 2))
local roleLabel = label(top, "", UDim2.new(1, -16, 0.4, -4), UDim2.new(0, 8, 0.6, 0))
roleLabel.TextColor3 = GOLD

-- Большое сообщение
local announceLabel = label(gui, "", UDim2.new(0.8, 0, 0, 50), UDim2.new(0.1, 0, 0, 90))
announceLabel.TextTransparency = 1
announceLabel.TextStrokeTransparency = 1

-- Подсказка о состоянии (тюрьма, заморозка, Кубок)
local statusLabel = label(gui, "", UDim2.new(0.7, 0, 0, 40), UDim2.new(0.15, 0, 1, -170))

-- Кнопки суперспособностей
local abilities = Instance.new("Frame")
abilities.Size = UDim2.fromOffset(170, 270)
abilities.Position = UDim2.new(1, -180, 1, -390)
abilities.BackgroundTransparency = 1
abilities.Parent = gui
local dashButton = button(abilities, "Рывок (Q)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 0), Color3.fromRGB(30, 120, 220))
local kickButton = button(abilities, "Мяч (F)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 70), GREEN)
local transformButton = button(abilities, "Предмет (E)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 140), Color3.fromRGB(230, 120, 20))
local tauntButton = button(abilities, "Дразнилка (T)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 210), Color3.fromRGB(200, 50, 160))

-- Сердцебиение: края экрана краснеют, когда водящий рядом
local heartFrame = Instance.new("Frame")
-- Рамка рисуется снаружи краёв, поэтому делаем её чуть меньше экрана — тогда она ровно по краям
heartFrame.Size = UDim2.new(1, -80, 1, -80)
heartFrame.Position = UDim2.fromOffset(40, 40)
heartFrame.BackgroundTransparency = 1
heartFrame.Parent = gui
local heartStroke = Instance.new("UIStroke")
heartStroke.Color = Color3.fromRGB(220, 0, 30)
heartStroke.Thickness = 40
heartStroke.Transparency = 1
heartStroke.Parent = heartFrame

-- Наблюдение: пойманные и зрители смотрят глазами других
local spectate = Instance.new("Frame")
spectate.Size = UDim2.fromOffset(360, 50)
spectate.Position = UDim2.new(0.5, -180, 1, -120)
spectate.BackgroundTransparency = 1
spectate.Visible = false
spectate.Parent = gui
local prevButton = button(spectate, "◀", UDim2.fromOffset(50, 50), UDim2.fromOffset(0, 0), Color3.fromRGB(60, 60, 80))
local watchButton = button(spectate, "Смотреть за игроками", UDim2.new(1, -110, 1, 0), UDim2.fromOffset(55, 0), Color3.fromRGB(60, 60, 80))
local nextButton = button(spectate, "▶", UDim2.fromOffset(50, 50), UDim2.new(1, -50, 0, 0), Color3.fromRGB(60, 60, 80))

-- Кнопка «Хочу водить»
local volunteerButton = button(gui, "", UDim2.fromOffset(200, 54), UDim2.new(0, 12, 0.5, -60), RED)

-- Кнопки «Боты» и «Глупые / Умные»
local botsButton = button(gui, "", UDim2.fromOffset(200, 54), UDim2.new(0, 12, 0.5, -124), Color3.fromRGB(40, 90, 170))
local levelButton = button(gui, "", UDim2.fromOffset(200, 54), UDim2.new(0, 12, 0.5, -188), Color3.fromRGB(150, 80, 200))

-- Магазин
local shopButton = button(gui, "Магазин", UDim2.fromOffset(200, 54), UDim2.new(0, 12, 0.5, 4), Color3.fromRGB(200, 140, 0))
local coinsLabel = label(gui, "", UDim2.fromOffset(200, 30), UDim2.new(0, 12, 0.5, 64))
coinsLabel.TextColor3 = GOLD

local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 420, 0, 440)
shop.Position = UDim2.new(0.5, -210, 0.5, -220)
shop.BackgroundColor3 = DARK
shop.Visible = false
shop.Parent = gui
corner(shop, 14)
label(shop, "Магазин форм", UDim2.new(1, -60, 0, 44), UDim2.fromOffset(12, 6))
local closeButton = button(shop, "X", UDim2.fromOffset(40, 40), UDim2.new(1, -48, 0, 8), RED)
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -24, 1, -64)
list.Position = UDim2.fromOffset(12, 56)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shop
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = list

local kitButtons: { [string]: TextButton } = {}
for _, kit in Config.KITS do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(40, 46, 56)
	row.Parent = list
	corner(row)
	local shirt = Instance.new("Frame")
	shirt.Size = UDim2.fromOffset(30, 22)
	shirt.Position = UDim2.fromOffset(10, 6)
	shirt.BackgroundColor3 = kit.Shirt
	shirt.Parent = row
	local shorts = Instance.new("Frame")
	shorts.Size = UDim2.fromOffset(30, 16)
	shorts.Position = UDim2.fromOffset(10, 30)
	shorts.BackgroundColor3 = kit.Shorts
	shorts.Parent = row
	local name = label(row, kit.Name, UDim2.new(0.5, -50, 1, -12), UDim2.fromOffset(50, 6))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local b = button(row, "", UDim2.new(0.45, 0, 1, -12), UDim2.new(0.55, -6, 0, 6), GREEN)
	b.Activated:Connect(function()
		local owned = string.split(player:GetAttribute("OwnedKits") or "", ",")
		if table.find(owned, kit.Id) then
			Remotes.get("EquipKit"):FireServer(kit.Id)
		else
			Remotes.get("BuyKit"):FireServer(kit.Id)
		end
	end)
	kitButtons[kit.Id] = b
end

local function refreshShop()
	local coins = player:GetAttribute("Coins") or 0
	coinsLabel.Text = "Монеты: " .. coins
	local owned = string.split(player:GetAttribute("OwnedKits") or "", ",")
	local equipped = player:GetAttribute("EquippedKit")
	for _, kit in Config.KITS do
		local b = kitButtons[kit.Id]
		if equipped == kit.Id then
			b.Text = "Надета"
			b.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
		elseif table.find(owned, kit.Id) then
			b.Text = "Надеть"
			b.BackgroundColor3 = GREEN
		else
			b.Text = "Купить: " .. kit.Price
			b.BackgroundColor3 = if coins >= kit.Price then Color3.fromRGB(200, 140, 0) else Color3.fromRGB(90, 70, 40)
		end
	end
end
for _, attr in { "Coins", "OwnedKits", "EquippedKit" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshShop)
end
refreshShop()

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
closeButton.Activated:Connect(function()
	shop.Visible = false
end)

levelButton.Activated:Connect(function()
	local nextLevel = if gameState:GetAttribute("BotLevel") == "dumb" then "normal" else "dumb"
	Remotes.get("BotLevel"):FireServer(nextLevel)
end)

botsButton.Activated:Connect(function()
	Remotes.get("ToggleBots"):FireServer(not gameState:GetAttribute("BotsEnabled"))
end)

volunteerButton.Activated:Connect(function()
	Remotes.get("Volunteer"):FireServer(not player:GetAttribute("Volunteer"))
end)

-- Действия
local function dash()
	Remotes.get("Dash"):FireServer()
end
local function kick()
	local camera = Workspace.CurrentCamera
	Remotes.get("Kick"):FireServer(camera.CFrame.LookVector)
end
local function transform()
	Remotes.get("Transform"):FireServer()
end
dashButton.Activated:Connect(dash)
transformButton.Activated:Connect(transform)
local function taunt()
	Remotes.get("Taunt"):FireServer()
end
tauntButton.Activated:Connect(taunt)
kickButton.Activated:Connect(kick)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		dash()
	elseif input.KeyCode == Enum.KeyCode.F then
		kick()
	elseif input.KeyCode == Enum.KeyCode.E then
		transform()
	elseif input.KeyCode == Enum.KeyCode.T then
		taunt()
	end
end)

-- Сообщения от сервера
local announceTween: Tween? = nil
Remotes.get("Announce").OnClientEvent:Connect(function(text: string, color: Color3)
	if announceTween then
		announceTween:Cancel()
	end
	announceLabel.Text = text
	announceLabel.TextColor3 = color
	announceLabel.TextTransparency = 0
	announceLabel.TextStrokeTransparency = 0.3
	announceTween = TweenService:Create(
		announceLabel,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 3.5),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	announceTween:Play()
end)

-- Звуки
local function makeSound(name: string, parent: Instance): Sound?
	local info = Config.SOUNDS[name]
	if not info or info.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = info.Id
	sound.Volume = info.Volume or 1
	sound.PlaybackSpeed = info.Speed or 1
	sound.Parent = parent
	return sound
end

local function playSound(name: string, position: Vector3?)
	local parent: Instance = gui
	local holder: Attachment? = nil
	if position then
		holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		parent = holder :: Attachment
	end
	local sound = makeSound(name, parent)
	if not sound then
		if holder then
			holder:Destroy()
		end
		return
	end
	if position then
		sound.RollOffMaxDistance = 150
	end
	local info = Config.SOUNDS[name]
	sound.TimePosition = info.Start or 0
	sound:Play()
	-- Нарезка: через Length секунд плавно стихает
	if info.Length then
		local volume = sound.Volume
		task.delay(math.max(0, info.Length - 1), function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(1), { Volume = 0 }):Play()
			end
		end)
		task.delay(info.Length, function()
			if sound.Parent then
				sound:Stop()
				sound.Volume = volume
			end
		end)
	end
	task.delay(math.max(8, (info.Length or 0) + 1), function()
		if holder then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end)
end

Remotes.get("Sfx").OnClientEvent:Connect(function(name: string, position: Vector3?)
	playSound(name, position)
end)

-- Музыка и болельщики играют по кругу
local loops: { [string]: Sound } = {}
for _, name in { "LobbyMusic", "RoundMusic", "Crowd" } do
	local sound = makeSound(name, gui)
	if sound then
		sound.Looped = true
		loops[name] = sound
	end
end
local function setLoop(name: string, on: boolean)
	local sound = loops[name]
	if sound then
		if on and not sound.IsPlaying then
			sound:Play()
		elseif not on and sound.IsPlaying then
			sound:Stop()
		end
	end
end

-- Наблюдение
local watching: Model? = nil
local function candidates(): { Model }
	local list = {}
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and m ~= player.Character and m:GetAttribute("Participant") then
			local role = m:GetAttribute("Role")
			local humanoid = m:FindFirstChildOfClass("Humanoid")
			if humanoid and (role == "Hider" or role == "Seeker" or role == "Jailed") then
				table.insert(list, m)
			end
		end
	end
	return list
end
local function watch(step: number)
	local list = candidates()
	if #list == 0 then
		watching = nil
		return
	end
	local index = (watching and table.find(list, watching)) or 0
	index = (index - 1 + step) % #list + 1
	watching = list[index]
end
local function stopWatching()
	watching = nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end
prevButton.Activated:Connect(function()
	watch(-1)
end)
nextButton.Activated:Connect(function()
	watch(1)
end)
watchButton.Activated:Connect(function()
	if watching then
		stopWatching()
	else
		watch(1)
	end
end)

local nextBeatAt = 0
local lastTickSecond = -1

local ROLE_NAMES = {
	Lobby = "Ты в ложе",
	Hider = "Ты прячешься",
	Seeker = "Ты ВОДЯЩИЙ",
	Jailed = "Ты в тюрьме",
}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function cooldownText(base: string, readyAt: number, t: number): (string, boolean)
	local left = readyAt - t
	if left > 0 then
		return base .. " " .. math.ceil(left), false
	end
	return base, true
end

-- Обновление экрана
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0

	local t = Workspace:GetServerTimeNow()
	local phase = gameState:GetAttribute("Phase") or "Waiting"
	local left = (gameState:GetAttribute("PhaseEndsAt") or 0) - t
	local role = player:GetAttribute("Role") or "Lobby"

	local botsOn = gameState:GetAttribute("BotsEnabled") == true
	if phase == "Waiting" then
		phaseLabel.Text = if botsOn then "Сейчас начнём с ботами..." else "Ждём игроков (нужно " .. Config.MIN_PLAYERS .. ")"
	elseif phase == "Intermission" then
		phaseLabel.Text = "Раунд через " .. formatTime(left)
	elseif phase == "Hiding" then
		phaseLabel.Text = "Прячьтесь! " .. formatTime(left)
	elseif phase == "Seeking" then
		local free = gameState:GetAttribute("HidersFree") or 0
		local jailed = gameState:GetAttribute("HidersJailed") or 0
		phaseLabel.Text = "Поиски " .. formatTime(left) .. "  |  в тюрьме " .. jailed .. "/" .. (free + jailed)
	else
		phaseLabel.Text = "Конец раунда"
	end
	roleLabel.Text = ROLE_NAMES[role] or ""

	-- Состояние
	local carrier = gameState:GetAttribute("TrophyCarrier") or ""
	if player:GetAttribute("Frozen") then
		statusLabel.Text = "Ты замер!"
		statusLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	elseif role == "Jailed" then
		statusLabel.Text = "Ты в тюрьме! Жди, пока друг подбежит и коснётся тебя."
		statusLabel.TextColor3 = RED
	elseif carrier == player.Name then
		statusLabel.Text = "У тебя Кубок! Беги к любым воротам!"
		statusLabel.TextColor3 = GOLD
	elseif role == "Seeker" and phase == "Hiding" then
		statusLabel.Text = "Не подглядывай! Скоро тебя выпустят."
		statusLabel.TextColor3 = WHITE
	elseif role == "Seeker" and carrier ~= "" then
		statusLabel.Text = "Кубок у игрока! Лови его, пока он не забил!"
		statusLabel.TextColor3 = RED
	elseif player:GetAttribute("Prop") then
		statusLabel.Text = "Ты — " .. string.lower(player:GetAttribute("Prop")) .. "! Замри, когда водящий рядом."
		statusLabel.TextColor3 = Color3.fromRGB(255, 170, 60)
	elseif player:GetAttribute("Boosted") then
		statusLabel.Text = "Ускорение!"
		statusLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
	else
		statusLabel.Text = ""
	end

	-- Музыка
	local inRound = phase == "Hiding" or phase == "Seeking"
	setLoop("LobbyMusic", not inRound and role == "Lobby")
	setLoop("RoundMusic", phase == "Seeking")
	setLoop("Crowd", inRound or role ~= "Lobby")

	-- Последние 10 секунд — тикают часы
	if (phase == "Hiding" or phase == "Seeking") and left > 0 and left <= 10 then
		local second = math.ceil(left)
		if second ~= lastTickSecond then
			lastTickSecond = second
			playSound("Tick")
		end
	end

	-- Сердцебиение
	local seekerModel = gameState:FindFirstChild("SeekerModel") :: ObjectValue?
	local seekerCharacter = seekerModel and seekerModel.Value :: Model?
	local seekerRoot = seekerCharacter and seekerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local closeness = 0
	if role == "Hider" and phase == "Seeking" and seekerRoot and myRoot then
		local d = (seekerRoot.Position - myRoot.Position).Magnitude
		closeness = math.clamp(1 - d / Config.HEARTBEAT_DISTANCE, 0, 1)
	end
	if closeness > 0 and t >= nextBeatAt then
		nextBeatAt = t + (1.1 - closeness * 0.75)
		heartStroke.Transparency = 0.75 - closeness * 0.55
		TweenService:Create(heartStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		playSound("Heartbeat")
	elseif closeness == 0 then
		heartStroke.Transparency = 1
	end

	-- Наблюдение
	local canWatch = role == "Jailed" or (role == "Lobby" and (phase == "Hiding" or phase == "Seeking"))
	spectate.Visible = canWatch
	if not canWatch and watching then
		stopWatching()
	end
	if watching then
		local humanoid = watching.Parent and watching:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Workspace.CurrentCamera.CameraSubject = humanoid
			watchButton.Text = "Смотришь: " .. watching.Name
		else
			watch(1)
		end
	else
		watchButton.Text = "Смотреть за игроками"
	end

	-- Кнопки
	local isHider = role == "Hider" and (phase == "Hiding" or phase == "Seeking")
	abilities.Visible = isHider
	if isHider then
		local dashText, dashReady = cooldownText("Рывок (Q)", player:GetAttribute("DashReadyAt") or 0, t)
		dashButton.Text = dashText
		dashButton.BackgroundTransparency = if dashReady then 0 else 0.5
		local kickText, kickReady = cooldownText("Мяч (F)", player:GetAttribute("KickReadyAt") or 0, t)
		kickButton.Text = kickText
		kickButton.BackgroundTransparency = if kickReady and phase == "Seeking" then 0 else 0.5
		local prop = player:GetAttribute("Prop")
		transformButton.Text = if prop then "Стать собой (E)" else "Предмет (E)"
		local tauntText, tauntReady = cooldownText("Дразнилка (T)", player:GetAttribute("TauntReadyAt") or 0, t)
		tauntButton.Text = tauntText
		tauntButton.BackgroundTransparency = if tauntReady and phase == "Seeking" then 0 else 0.5
	end

	local inLobby = role == "Lobby"
	volunteerButton.Visible = inLobby and phase ~= "Hiding" and phase ~= "Seeking"
	botsButton.Visible = volunteerButton.Visible
	levelButton.Visible = volunteerButton.Visible and botsOn
	local level = Config.BOT_LEVELS[gameState:GetAttribute("BotLevel") or "dumb"]
	levelButton.Text = "Боты: " .. (if level then level.Name else "?")
	botsButton.Text = if botsOn then "Боты: ВКЛ" else "Боты: ВЫКЛ"
	botsButton.BackgroundColor3 = if botsOn then Color3.fromRGB(40, 90, 170) else Color3.fromRGB(70, 70, 80)
	if player:GetAttribute("Volunteer") then
		volunteerButton.Text = "Я хочу водить ✔"
		volunteerButton.BackgroundColor3 = RED
	else
		volunteerButton.Text = "Хочу водить!"
		volunteerButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	end
end)
