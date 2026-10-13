-- Роли игроков и их скорость: заморозка, рывок, ускорение от статуи.
-- Роль хранится в атрибуте игрока "Role": Lobby, Hider, Seeker или Jailed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Participants = require(script.Parent.Participants)

local PlayerState = {}

type Status = {
	frozenUntil: number,
	dashUntil: number,
	boostUntil: number,
	safeUntil: number,
}

local statuses: { [Player]: Status } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function status(player: Player): Status
	local s = statuses[player]
	if not s then
		s = { frozenUntil = 0, dashUntil = 0, boostUntil = 0, safeUntil = 0 }
		statuses[player] = s
	end
	return s
end

function PlayerState.now(): number
	return now()
end

function PlayerState.getRole(player: Player): string
	return player:GetAttribute("Role") or "Lobby"
end

function PlayerState.setRole(player: Player, role: string)
	player:SetAttribute("Role", role)
	PlayerState.syncCharacter(player)
end

-- Роль видна и на персонаже: так экран игрока знает, за кем можно наблюдать
function PlayerState.syncCharacter(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute("Participant", true)
		character:SetAttribute("Role", PlayerState.getRole(player))
	end
end

function PlayerState.getCharacterParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

function PlayerState.getPosition(player: Player): Vector3?
	local root = PlayerState.getCharacterParts(player)
	return root and root.Position
end

function PlayerState.teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf + Vector3.new(0, 3, 0))
	end
end

function PlayerState.freeze(player: Player, seconds: number)
	local s = status(player)
	s.frozenUntil = math.max(s.frozenUntil, now() + seconds)
end

function PlayerState.isFrozen(player: Player): boolean
	return status(player).frozenUntil > now()
end

function PlayerState.dash(player: Player, seconds: number)
	status(player).dashUntil = now() + seconds
end

function PlayerState.boost(player: Player, seconds: number)
	local s = status(player)
	s.boostUntil = math.max(s.boostUntil, now() + seconds)
end

function PlayerState.makeSafe(player: Player, seconds: number)
	status(player).safeUntil = now() + seconds
end

function PlayerState.isSafe(player: Player): boolean
	return status(player).safeUntil > now()
end

function PlayerState.reset(player: Player)
	statuses[player] = nil
	player:SetAttribute("Frozen", false)
	player:SetAttribute("Boosted", false)
end

local function speedFor(player: Player, s: Status, t: number): number
	if s.frozenUntil > t then
		return 0
	end
	local role = PlayerState.getRole(player)
	local speed = if role == "Seeker" then Config.SEEKER_SPEED else Config.HIDER_SPEED
	if s.dashUntil > t then
		speed += Config.DASH_BONUS
	end
	if s.boostUntil > t then
		speed += Config.STATUE_BOOST_BONUS
	end
	if Participants.isBot(player) then
		local level = Config.bot()
		speed += if role == "Seeker" then level.SeekerSpeedBonus else level.HiderSpeedBonus
	end
	return speed
end

function PlayerState.start()
	Players.PlayerRemoving:Connect(function(player)
		statuses[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local t = now()
		for _, player in Participants.all() do
			local _, humanoid = PlayerState.getCharacterParts(player)
			if humanoid then
				local s = status(player)
				local frozen = s.frozenUntil > t
				humanoid.WalkSpeed = speedFor(player, s, t)
				humanoid.JumpHeight = if frozen then 0 else Config.JUMP_HEIGHT
				player:SetAttribute("Frozen", frozen)
				player:SetAttribute("Boosted", s.boostUntil > t or s.dashUntil > t)
			end
		end
	end)
end

return PlayerState
