-- Статуя сына: его настоящий аватар из Roblox на золотом постаменте.
-- Включается, если в Config.HERO_USER_ID вписан его номер в Roblox.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local HeroStatue = {}

local GOLD = Color3.fromRGB(255, 196, 37)

local function buildOne(parent: Instance, description: HumanoidDescription, cf: CFrame, scale: number)
	local holder = Instance.new("Model")
	holder.Name = "HeroStatue"

	-- Постамент с табличкой
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Anchored = true
	pedestal.Size = Vector3.new(6 * scale, 2, 6 * scale)
	pedestal.CFrame = cf * CFrame.new(0, 1, 0)
	pedestal.Color = GOLD
	pedestal.Material = Enum.Material.Foil
	pedestal.Reflectance = 0.2
	pedestal.Parent = holder

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = pedestal
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(60, 40, 0)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = Config.HERO_TITLE
	label.Parent = gui

	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14 * scale
	light.Brightness = 1.5
	light.Parent = pedestal

	-- Сам аватар
	local avatar = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	avatar.Name = "Avatar"
	local animate = avatar:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, d in avatar:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	if scale ~= 1 then
		avatar:ScaleTo(scale)
	end
	-- Ставим на постамент: ноги на верх постамента
	local _, size = avatar:GetBoundingBox()
	avatar:PivotTo(cf * CFrame.new(0, 2 + size.Y / 2, 0))
	avatar.Parent = holder

	holder.Parent = parent
	return holder
end

-- places — список CFrame: где поставить статую (смотрит вдоль своей оси -Z)
function HeroStatue.build(parent: Instance, places: { { cf: CFrame, scale: number } })
	if (Config.HERO_USER_ID or 0) <= 0 then
		return
	end
	task.spawn(function()
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(Config.HERO_USER_ID)
		end)
		if not ok then
			warn("Не получилось загрузить аватар для статуи:", description)
			return
		end
		for _, place in places do
			local built, err = pcall(buildOne, parent, description, place.cf, place.scale)
			if not built then
				warn("Не получилось поставить статую:", err)
			end
		end
	end)
end

return HeroStatue
