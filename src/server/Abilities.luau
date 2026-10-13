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
			PlayerState.freeze(seeker, Config.KICK_FREEZE)
			announce(player.DisplayName .. " попал мячом в водящего!", Color3.fromRGB(0, 220, 120))
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
	Sfx.play("Taunt" .. math.random(1, Config.TAUNT_COUNT), PlayerState.getPosition(player))
	if onTaunt then
		onTaunt(player)
	end
	return true
end

function Abilities.resetCooldowns(player: Player)
	player:SetAttribute("DashReadyAt", 0)
	player:SetAttribute("KickReadyAt", 0)
	player:SetAttribute("TauntReadyAt", 0)
end

return Abilities
