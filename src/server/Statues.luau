-- Футболисты-статуи. Иногда оживают:
--   зелёная статуя помогает (кого коснётся — тот бегает быстрее),
--   красная статуя мешает (кого коснётся — тот замирает и роняет Кубок).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)
local Trophy = require(script.Parent.Trophy)

local Statues = {}

local GOOD_COLOR = Color3.fromRGB(40, 220, 90)
local BAD_COLOR = Color3.fromRGB(230, 40, 40)

type Statue = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	home: CFrame,
	parts: { BasePart },
	light: PointLight,
	awake: boolean,
	mode: string,
	touched: { [Player]: number },
	token: number,
}

local statues: { Statue } = {}
local stoneColor = Color3.fromRGB(163, 162, 165)
local enabled = false
local generation = 0
local announce: (string, Color3?) -> ()

local function buildStatue(parent: Instance, home: CFrame, index: number): Statue
	local model = Instance.new("Model")
	model.Name = "Statue" .. index

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = home * CFrame.new(0, 3, 0)
	root.Anchored = true
	root.Parent = model

	local parts = {}
	local function limb(name: string, size: Vector3, offset: Vector3, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Shape = shape or Enum.PartType.Block
		p.Color = stoneColor
		p.Material = Enum.Material.Slate
		p.CFrame = root.CFrame * CFrame.new(offset)
		p.CanCollide = false
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		table.insert(parts, p)
		return p
	end

	limb("Torso", Vector3.new(2, 2, 1), Vector3.zero).CanCollide = true
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0)).CanCollide = true
	limb("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	limb("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	limb("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	limb("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))
	limb("Ball", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0.5, -2.4, -1.2), Enum.PartType.Ball)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.WalkSpeed = Config.STATUE_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.Parent = model

	model.PrimaryPart = root

	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 2
	light.Enabled = false
	light.Parent = root

	-- Табличка-круг под статуей
	local plate = Instance.new("Part")
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(0.2, 5, 5)
	plate.CFrame = home * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	plate.Anchored = true
	plate.CanCollide = false
	plate.Color = Color3.fromRGB(110, 110, 115)
	plate.Material = Enum.Material.Concrete
	plate.Parent = parent

	model.Parent = parent

	return {
		model = model,
		root = root,
		humanoid = humanoid,
		home = home,
		parts = parts,
		light = light,
		awake = false,
		mode = "good",
		touched = {},
		token = 0,
	}
end

local function paint(statue: Statue, color: Color3, material: Enum.Material)
	for _, p in statue.parts do
		if p.Name ~= "Ball" then
			p.Color = color
			p.Material = material
		end
	end
end

local function sleep(statue: Statue)
	statue.awake = false
	statue.token += 1
	statue.root.Anchored = true
	statue.model:PivotTo(statue.home * CFrame.new(0, 3, 0))
	paint(statue, stoneColor, Enum.Material.Slate)
	statue.light.Enabled = false
	table.clear(statue.touched)
end

local function nearestPlayer(position: Vector3, range: number): (Player?, Vector3?)
	local best, bestPosition, bestDistance = nil, nil, range
	for _, player in Players:GetPlayers() do
		local role = PlayerState.getRole(player)
		if role == "Hider" or role == "Seeker" then
			local p = PlayerState.getPosition(player)
			if p then
				local d = (p - position).Magnitude
				if d < bestDistance then
					best, bestPosition, bestDistance = player, p, d
				end
			end
		end
	end
	return best, bestPosition
end

local function touch(statue: Statue, player: Player)
	local t = PlayerState.now()
	if (statue.touched[player] or 0) > t then
		return
	end
	statue.touched[player] = t + 3
	if statue.mode == "good" then
		PlayerState.boost(player, Config.STATUE_BOOST_TIME)
	else
		PlayerState.freeze(player, Config.STATUE_FREEZE)
		if Trophy.getCarrier() == player then
			Trophy.drop()
			announce("Красная статуя выбила Кубок у " .. player.DisplayName .. "!", BAD_COLOR)
		end
	end
end

local function wake(statue: Statue)
	statue.awake = true
	statue.mode = if math.random() < 0.5 then "good" else "bad"
	local color = if statue.mode == "good" then GOOD_COLOR else BAD_COLOR
	paint(statue, color, Enum.Material.Neon)
	statue.light.Color = color
	statue.light.Enabled = true
	statue.root.Anchored = false
	statue.root:SetNetworkOwner(nil)
	statue.token += 1
	local token = statue.token
	local function active()
		return statue.awake and statue.token == token
	end

	task.spawn(function()
		local endsAt = os.clock() + Config.STATUE_AWAKE_TIME
		while enabled and active() and os.clock() < endsAt do
			local target, targetPosition = nearestPlayer(statue.root.Position, 90)
			if target and targetPosition then
				statue.humanoid:MoveTo(targetPosition)
				if (targetPosition - statue.root.Position).Magnitude <= Config.STATUE_TOUCH_DISTANCE then
					touch(statue, target)
				end
			end
			task.wait(0.2)
		end
		-- Возвращаемся домой
		if active() then
			statue.humanoid:MoveTo(statue.home.Position)
			local giveUpAt = os.clock() + 8
			while active() and os.clock() < giveUpAt and (statue.root.Position - statue.home.Position).Magnitude > 6 do
				task.wait(0.3)
			end
		end
		if active() then
			sleep(statue)
		end
	end)
end

function Statues.build(parent: Instance, homes: { CFrame }, color: Color3, announceFn: (string, Color3?) -> ())
	stoneColor = color
	announce = announceFn
	local folder = Instance.new("Folder")
	folder.Name = "Statues"
	folder.Parent = parent
	for i, home in homes do
		table.insert(statues, buildStatue(folder, home, i))
	end
end

function Statues.enable()
	if enabled then
		return
	end
	enabled = true
	generation += 1
	local myGeneration = generation
	task.spawn(function()
		while enabled and generation == myGeneration do
			task.wait(math.random(Config.STATUE_WAKE_MIN, Config.STATUE_WAKE_MAX))
			if not enabled or generation ~= myGeneration then
				break
			end
			local sleeping = {}
			for _, statue in statues do
				if not statue.awake then
					table.insert(sleeping, statue)
				end
			end
			local count = math.min(#sleeping, math.random(1, 2))
			for _ = 1, count do
				local statue = table.remove(sleeping, math.random(1, #sleeping))
				wake(statue)
			end
			if count > 0 then
				announce("Статуи ожили! Зелёные помогают, красные мешают!", Color3.fromRGB(255, 220, 60))
			end
		end
	end)
end

function Statues.disable()
	enabled = false
	for _, statue in statues do
		if statue.awake then
			sleep(statue)
		end
	end
end

return Statues
