-- Превращение в предметы: прячущийся становится конусом, мячом, бутылкой или урной.
-- Персонаж становится невидимым, а к нему приклеивается предмет.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Transform = {}

type Active = {
	prop: Model,
	hidden: { [Instance]: number },
	nameDisplay: Enum.HumanoidDisplayDistanceType?,
}

local active: { [any]: Active } = {}
local lastToggle: { [any]: number } = {}

local function part(model: Model, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.Parent = model
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр в Roblox лежит на боку, ставим его стоя

-- Каждый предмет строится так, что его низ — в точке (0, 0, 0)
local BUILDERS = {
	{
		name = "Конус",
		build = function(m: Model)
			local orange = Color3.fromRGB(255, 120, 20)
			part(m, Enum.PartType.Block, Vector3.new(2.4, 0.3, 2.4), CFrame.new(0, 0.15, 0), orange)
			part(m, Enum.PartType.Cylinder, Vector3.new(1, 1.8, 1.8), CFrame.new(0, 0.8, 0) * UPRIGHT, orange)
			part(m, Enum.PartType.Cylinder, Vector3.new(0.8, 1.3, 1.3), CFrame.new(0, 1.7, 0) * UPRIGHT, Color3.new(1, 1, 1))
			part(m, Enum.PartType.Cylinder, Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 2.5, 0) * UPRIGHT, orange)
		end,
	},
	{
		name = "Мяч",
		build = function(m: Model)
			part(m, Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 1.3, 0), Color3.new(1, 1, 1))
			for _, offset in { Vector3.new(0, 1.3, -1.2), Vector3.new(1.2, 1.3, 0), Vector3.new(0, 2.5, 0) } do
				part(m, Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(offset), Color3.fromRGB(25, 25, 25))
			end
		end,
	},
	{
		name = "Бутылка",
		build = function(m: Model)
			local water = part(m, Enum.PartType.Cylinder, Vector3.new(2.4, 1.1, 1.1), CFrame.new(0, 1.2, 0) * UPRIGHT, Color3.fromRGB(120, 190, 255), Enum.Material.Glass)
			water.Transparency = 0.3
			part(m, Enum.PartType.Cylinder, Vector3.new(0.4, 0.5, 0.5), CFrame.new(0, 2.6, 0) * UPRIGHT, Color3.fromRGB(20, 90, 200))
		end,
	},
	{
		name = "Урна",
		build = function(m: Model)
			part(m, Enum.PartType.Cylinder, Vector3.new(3, 2.2, 2.2), CFrame.new(0, 1.5, 0) * UPRIGHT, Color3.fromRGB(0, 110, 60), Enum.Material.Metal)
			part(m, Enum.PartType.Cylinder, Vector3.new(0.3, 2.4, 2.4), CFrame.new(0, 3.1, 0) * UPRIGHT, Color3.fromRGB(0, 80, 45), Enum.Material.Metal)
		end,
	},
}

Transform.PROP_NAMES = {}
for _, b in BUILDERS do
	table.insert(Transform.PROP_NAMES, b.name)
end

function Transform.isTransformed(participant): boolean
	return active[participant] ~= nil
end

function Transform.revert(participant)
	local state = active[participant]
	if not state then
		return
	end
	active[participant] = nil
	participant:SetAttribute("Prop", nil)
	if state.prop.Parent then
		state.prop:Destroy()
	end
	for object, transparency in state.hidden do
		if object.Parent then
			(object :: any).Transparency = transparency
		end
	end
	local character = participant.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and state.nameDisplay then
		humanoid.DisplayDistanceType = state.nameDisplay
	end
end

function Transform.revertAll()
	for participant in active do
		Transform.revert(participant)
	end
	table.clear(lastToggle)
end

function Transform.transform(participant, index: number?): boolean
	local root, humanoid = PlayerState.getCharacterParts(participant)
	if not root or not humanoid or active[participant] then
		return false
	end
	local character = participant.Character :: Model
	local i = index or ((participant:GetAttribute("PropIndex") or 0) % #BUILDERS + 1)
	participant:SetAttribute("PropIndex", i)
	local builder = BUILDERS[i]

	-- Прячем персонажа (и запоминаем, как было)
	local hidden = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then
			hidden[d] = (d :: any).Transparency
			;(d :: any).Transparency = 1
		end
	end
	local nameDisplay = humanoid.DisplayDistanceType
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- Строим предмет и приклеиваем к персонажу у самой земли
	local prop = Instance.new("Model")
	prop.Name = "Prop"
	builder.build(prop)
	local ground = root.CFrame * CFrame.new(0, -(root.Size.Y / 2 + humanoid.HipHeight), 0)
	for _, p in prop:GetChildren() do
		if p:IsA("BasePart") then
			p.CFrame = ground * p.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	prop.Parent = character

	active[participant] = { prop = prop, hidden = hidden, nameDisplay = nameDisplay }
	participant:SetAttribute("Prop", builder.name)
	return true
end

-- Нажал кнопку: превратиться в следующий предмет или стать собой
function Transform.toggle(participant, canTransform: boolean): boolean
	local t = PlayerState.now()
	if (lastToggle[participant] or 0) + Config.TRANSFORM_COOLDOWN > t then
		return false
	end
	if active[participant] then
		lastToggle[participant] = t
		Transform.revert(participant)
		return true
	end
	if not canTransform then
		return false
	end
	lastToggle[participant] = t
	return Transform.transform(participant)
end

-- Персонаж пропал (вышел, переродился) — забываем превращение
function Transform.forget(participant)
	active[participant] = nil
	lastToggle[participant] = nil
	participant:SetAttribute("Prop", nil)
end

return Transform
