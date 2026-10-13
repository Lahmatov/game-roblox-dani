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
abilities.Size = UDim2.fromOffset(170, 130)
abilities.Position = UDim2.new(1, -180, 1, -250)
abilities.BackgroundTransparency = 1
abilities.Parent = gui
local dashButton = button(abilities, "Рывок (Q)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 0), Color3.fromRGB(30, 120, 220))
local kickButton = button(abilities, "Мяч (F)", UDim2.new(1, 0, 0, 58), UDim2.fromOffset(0, 70), GREEN)

-- Кнопка «Хочу водить»
local volunteerButton = button(gui, "", UDim2.fromOffset(200, 54), UDim2.new(0, 12, 0.5, -60), RED)

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
dashButton.Activated:Connect(dash)
kickButton.Activated:Connect(kick)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q then
		dash()
	elseif input.KeyCode == Enum.KeyCode.F then
		kick()
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

	if phase == "Waiting" then
		phaseLabel.Text = "Ждём игроков (нужно " .. Config.MIN_PLAYERS .. ")"
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
	elseif player:GetAttribute("Boosted") then
		statusLabel.Text = "Ускорение!"
		statusLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
	else
		statusLabel.Text = ""
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
	end

	local inLobby = role == "Lobby"
	volunteerButton.Visible = inLobby and phase ~= "Hiding" and phase ~= "Seeking"
	if player:GetAttribute("Volunteer") then
		volunteerButton.Text = "Я хочу водить ✔"
		volunteerButton.BackgroundColor3 = RED
	else
		volunteerButton.Text = "Хочу водить!"
		volunteerButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	end
end)
