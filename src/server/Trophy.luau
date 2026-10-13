-- Кубок мира: прячется в случайном месте, его можно подобрать, уронить и забить в ворота.

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Trophy = {}

local GOLD = Color3.fromRGB(255, 196, 37)

local model: Model? = nil
local base: BasePart? = nil
local carryWeld: WeldConstraint? = nil
local carrier: Player? = nil
local pickupBlockedUntil = 0
local hintThread: thread? = nil
local gameState: Folder

local function setCarrier(player: Player?)
	carrier = player
	gameState:SetAttribute("TrophyCarrier", if player then player.Name else "")
end

local function buildModel(): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = "WorldCup"

	local function piece(shape: Enum.PartType, size: Vector3, offset: Vector3, color: Color3?): BasePart
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.Color = color or GOLD
		p.Material = Enum.Material.Foil
		p.Reflectance = 0.3
		p.CanCollide = false
		p.Massless = true
		p.CFrame = CFrame.new(offset)
		p.Parent = m
		return p
	end

	local root = piece(Enum.PartType.Cylinder, Vector3.new(0.8, 1.6, 1.6), Vector3.new(0, 0.4, 0), Color3.fromRGB(0, 110, 60))
	root.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	root.Name = "Base"
	root.Anchored = true
	local parts = {
		piece(Enum.PartType.Block, Vector3.new(0.7, 1.4, 0.7), Vector3.new(0, 1.5, 0)),
		piece(Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 2.5, 0)),
		piece(Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 3.4, 0)),
	}
	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	m.PrimaryPart = root

	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 6
	light.Brightness = 0.6
	light.Parent = root

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Enabled = false
	sparkles.Parent = parts[3]

	local sound = Instance.new("Sound")
	sound.Name = "Hint"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 2
	sound.RollOffMaxDistance = 160
	sound.Parent = root

	return m, root
end

local function placeAt(position: Vector3)
	if not model or not base then
		return
	end
	base.Anchored = true
	model:PivotTo(CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)))
end

-- Найти пол под точкой, чтобы Кубок не висел в воздухе
local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if model then
		table.insert(ignore, model)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position, Vector3.new(0, -50, 0), params)
	return if result then result.Position else Vector3.new(position.X, 0, position.Z)
end

function Trophy.init(state: Folder)
	gameState = state
	setCarrier(nil)
end

function Trophy.spawn(spots: { Vector3 })
	Trophy.remove()
	model, base = buildModel()
	placeAt(spots[math.random(1, #spots)])
	model.Parent = Workspace
	pickupBlockedUntil = 0

	hintThread = task.spawn(function()
		while model do
			task.wait(Config.TROPHY_HINT_INTERVAL)
			if not model then
				break
			end
			local sparkles = model:FindFirstChildWhichIsA("Sparkles", true)
			local sound = base and base:FindFirstChild("Hint") :: Sound?
			if sparkles then
				sparkles.Enabled = true
			end
			if sound and not carrier then
				sound:Play()
			end
			task.wait(Config.TROPHY_HINT_DURATION)
			if sparkles then
				sparkles.Enabled = false
			end
		end
	end)
end

function Trophy.remove()
	if hintThread and coroutine.status(hintThread) ~= "running" then
		task.cancel(hintThread)
	end
	hintThread = nil
	if model then
		model:Destroy()
	end
	model, base, carryWeld = nil, nil, nil
	setCarrier(nil)
end

function Trophy.getCarrier(): Player?
	return carrier
end

function Trophy.pickUp(player: Player)
	local root = PlayerState.getCharacterParts(player)
	if not root or not base or carrier then
		return
	end
	base.Anchored = false
	model:PivotTo(root.CFrame * CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = base
	weld.Parent = base
	carryWeld = weld
	setCarrier(player)
end

-- Уронить Кубок там, где сейчас стоит игрок (или в заданной точке)
function Trophy.drop(at: Vector3?)
	if not carrier or not base then
		return
	end
	local position = at or PlayerState.getPosition(carrier) or base.Position
	if carryWeld then
		carryWeld:Destroy()
		carryWeld = nil
	end
	setCarrier(nil)
	placeAt(groundBelow(position + Vector3.new(0, 2, 0)))
	pickupBlockedUntil = PlayerState.now() + 1.5
end

-- Кто-то из прячущихся рядом? Подбираем.
function Trophy.update(hiders: { Player })
	if not base or carrier or PlayerState.now() < pickupBlockedUntil then
		return nil
	end
	for _, player in hiders do
		if PlayerState.getRole(player) == "Hider" and not PlayerState.isFrozen(player) then
			local position = PlayerState.getPosition(player)
			if position and (position - base.Position).Magnitude <= Config.TROPHY_PICKUP_DISTANCE then
				Trophy.pickUp(player)
				return player
			end
		end
	end
	return nil
end

-- Если носителя больше нет (вышел, упал), роняем Кубок
function Trophy.checkCarrier()
	if carrier and not PlayerState.getPosition(carrier) then
		local lastPosition = if base then base.Position - Vector3.new(0, 4, 0) else nil
		Trophy.drop(lastPosition)
	end
end

return Trophy
