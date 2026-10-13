-- Суперспособности прячущихся: рывок и мяч.
-- Фонарик водящего выдаёт RoundManager.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Participants = require(script.Parent.Participants)
local Sfx = require(script.Parent.Sfx)
local Commentator = require(script.Parent.Commentator)
local Effects = require(script.Parent.Effects)

local Abilities = {}

local gameState: Folder
local announce: (string, Color3?) -> ()
local onTaunt: ((any) -> ())? = nil

local function phase(): string
	return gameState:GetAttribute("Phase") or "Waiting"
end

local function canUse(player: Player): boolean
	local p = phase()
	return PlayerState.getRole(player) == "Hider" and (p == "Hiding" or p == "Seeking") and not PlayerState.isFrozen(player)
end

local function findSeeker(): Player?
	for _, player in Participants.all() do
		if PlayerState.getRole(player) == "Seeker" then
			return player
		end
	end
	return nil
end

local function kickBall(player: Player, direction: Vector3)
	local root = PlayerState.getCharacterParts(player)
	if not root then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = root.CFrame.LookVector
	end
	flat = flat.Unit

	local ball = Instance.new("Part")
	ball.Name = "KickBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2, 2, 2)
	ball.Color = Color3.fromRGB(250, 250, 250)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CFrame = CFrame.new(root.Position + flat * 3 + Vector3.new(0, -1, 0))
	ball.CanCollide = true
	ball.Parent = Workspace
	ball:SetNetworkOwner(nil)
	ball.AssemblyLinearVelocity = flat * Config.KICK_BALL_SPEED + Vector3.new(0, 12, 0)
	local trail = Instance.new("Sparkles")
	trail.SparkleColor = Color3.fromRGB(0, 200, 100)
	trail.Parent = ball
	Debris:AddItem(ball, Config.KICK_BALL_LIFETIME)

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not ball.Parent then
			connection:Disconnect()
			return
		end
		local seeker = findSeeker()
		local seekerPosition = seeker and PlayerState.getPosition(seeker)
		if seeker and seekerPosition and (seekerPosition - ball.Position).Magnitude < 4 then
			connection:Disconnect()
			ball:Destroy()
			if PlayerState.stun(seeker, Config.KICK_FREEZE) then
				announce(player.DisplayName .. " попал мячом в водящего!", Color3.fromRGB(0, 220, 120))
				Commentator.say("kick", player.DisplayName)
			end
		end
	end)
end

function Abilities.start(state: Folder, announceFn: (string, Color3?) -> (), tauntFn: ((any) -> ())?)
	gameState = state
	announce = announceFn
	onTaunt = tauntFn

	Remotes.get("Taunt").OnServerEvent:Connect(function(player)
		Abilities.tryTaunt(player)
	end)

	Remotes.get("Banana").OnServerEvent:Connect(function(player)
		Abilities.tryBanana(player)
	end)

	Remotes.get("Dash").OnServerEvent:Connect(function(player)
		Abilities.tryDash(player)
	end)

	Remotes.get("Kick").OnServerEvent:Connect(function(player, direction)
		Abilities.tryKick(player, direction)
	end)
end

-- Рывок. Возвращает true, если получилось.
function Abilities.tryDash(player): boolean
	local t = PlayerState.now()
	if not canUse(player) or (player:GetAttribute("DashReadyAt") or 0) > t then
		return false
	end
	player:SetAttribute("DashReadyAt", t + Config.DASH_COOLDOWN)
	PlayerState.dash(player, Config.DASH_DURATION)
	Sfx.play("Dash", PlayerState.getPosition(player))
	return true
end

-- Пнуть мяч в направлении direction. Возвращает true, если получилось.
function Abilities.tryKick(player, direction): boolean
	local t = PlayerState.now()
	if typeof(direction) ~= "Vector3" or direction ~= direction then
		return false
	end
	if not canUse(player) or phase() ~= "Seeking" or (player:GetAttribute("KickReadyAt") or 0) > t then
		return false
	end
	player:SetAttribute("KickReadyAt", t + Config.KICK_COOLDOWN)
	kickBall(player, direction)
	Sfx.play("Kick", PlayerState.getPosition(player))
	return true
end

-- Дразнилка: смешной звук там, где стоишь. Водящий слышит — зато дают монеты.
function Abilities.tryTaunt(player): boolean
	local t = PlayerState.now()
	if not canUse(player) or phase() ~= "Seeking" or (player:GetAttribute("TauntReadyAt") or 0) > t then
		return false
	end
	player:SetAttribute("TauntReadyAt", t + Config.TAUNT_COOLDOWN)
	-- Только те дразнилки, для которых есть звук
	local taunts = {}
	for i = 1, Config.TAUNT_COUNT do
		local info = Config.SOUNDS["Taunt" .. i]
		if info and info.Id ~= "" then
			table.insert(taunts, "Taunt" .. i)
		end
	end
	if #taunts > 0 then
		Sfx.play(taunts[math.random(1, #taunts)], PlayerState.getPosition(player))
	end
	if onTaunt then
		onTaunt(player)
	end
	return true
end

-- Банановая кожура: водящий наступит — поскользнётся
local function dropBanana(player, position: Vector3)
	local banana = Instance.new("Model")
	banana.Name = "Banana"
	local yellow = Color3.fromRGB(250, 215, 40)
	local parts = {}
	for k = -1, 1 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.5, 0.25, 1.6)
		p.Color = yellow
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, math.rad(k * 55), 0) * CFrame.new(0, 0, 0.6)
		p.Parent = banana
		table.insert(parts, p)
	end
	local tip = Instance.new("Part")
	tip.Size = Vector3.new(0.35, 0.35, 0.35)
	tip.Color = Color3.fromRGB(90, 60, 30)
	tip.Anchored = true
	tip.CanCollide = false
	tip.Position = position + Vector3.new(0, 0.25, 0)
	tip.Parent = banana
	banana.Parent = Workspace
	Debris:AddItem(banana, Config.BANANA_LIFETIME)

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not banana.Parent then
			connection:Disconnect()
			return
		end
		local seeker = findSeeker()
		local seekerPosition = seeker and PlayerState.getPosition(seeker)
		if seeker and seekerPosition and (Vector3.new(seekerPosition.X, position.Y, seekerPosition.Z) - position).Magnitude < 3 then
			if not PlayerState.stun(seeker, Config.BANANA_FREEZE) then
				return -- водящий только что был оглушён — банан пока лежит
			end
			connection:Disconnect()
			banana:Destroy()
			Effects.spin(seeker, 1.2, 30)
			Effects.billboard(seeker, "БАНАН!", Color3.fromRGB(250, 215, 40), 2)
			Sfx.play("Banana", seekerPosition)
			announce("Водящий поскользнулся на банане от " .. player.DisplayName .. "!", Color3.fromRGB(250, 215, 40))
			Commentator.say("slip", player.DisplayName)
		end
	end)
end

function Abilities.tryBanana(player): boolean
	local t = PlayerState.now()
	if not canUse(player) or phase() ~= "Seeking" or (player:GetAttribute("BananaReadyAt") or 0) > t then
		return false
	end
	local position = PlayerState.getPosition(player)
	if not position then
		return false
	end
	player:SetAttribute("BananaReadyAt", t + Config.BANANA_COOLDOWN)
	dropBanana(player, position - Vector3.new(0, 3, 0))
	return true
end

function Abilities.resetCooldowns(player: Player)
	player:SetAttribute("DashReadyAt", 0)
	player:SetAttribute("KickReadyAt", 0)
	player:SetAttribute("TauntReadyAt", 0)
	player:SetAttribute("BananaReadyAt", 0)
end

return Abilities
