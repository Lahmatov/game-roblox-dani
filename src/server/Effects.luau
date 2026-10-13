-- Смешные эффекты для персонажей: кружение, прыжок, рост, большая голова, надпись, корона, конфетти.

local Workspace = game:GetService("Workspace")

local PlayerState = require(script.Parent.PlayerState)

local Effects = {}

local GOLD = Color3.fromRGB(255, 200, 40)

local function humanoidOf(participant): Humanoid?
	local _, humanoid = PlayerState.getCharacterParts(participant)
	return humanoid
end

-- Покрутиться на месте (как после гола или если поскользнулся)
function Effects.spin(participant, seconds: number, speed: number?)
	local root = PlayerState.getCharacterParts(participant)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinAttachment"
	attachment.Parent = root
	local spin = Instance.new("AngularVelocity")
	spin.Attachment0 = attachment
	spin.AngularVelocity = Vector3.new(0, speed or 25, 0)
	spin.MaxTorque = math.huge
	spin.RelativeTo = Enum.ActuatorRelativeTo.World
	spin.Parent = root
	task.delay(seconds, function()
		spin:Destroy()
		attachment:Destroy()
	end)
end

function Effects.jump(participant)
	local humanoid = humanoidOf(participant)
	if humanoid then
		humanoid.Jump = true
	end
end

-- Сделать персонажа больше или меньше (1 — обычный размер)
function Effects.scale(participant, factor: number)
	local character = participant.Character
	if character then
		pcall(function()
			character:ScaleTo(factor)
		end)
	end
end

-- Большая голова (или обратно)
function Effects.bigHead(participant, on: boolean)
	local character = participant.Character
	local humanoid = humanoidOf(participant)
	if not character or not humanoid then
		return
	end
	local headScale = humanoid:FindFirstChild("HeadScale") :: NumberValue?
	if headScale then
		headScale.Value = if on then 2.5 else 1
		return
	end
	-- Запасной способ: просто увеличить голову
	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		local original = head:GetAttribute("OriginalSize")
		if on and not original then
			head:SetAttribute("OriginalSize", head.Size)
			head.Size = head.Size * 2.5
		elseif not on and original then
			head.Size = original
			head:SetAttribute("OriginalSize", nil)
		end
	end
end

-- Надпись над головой на несколько секунд
function Effects.billboard(participant, text: string, color: Color3?, seconds: number?)
	local character = participant.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("FunText")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FunText"
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or GOLD
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = gui
	gui.Parent = head
	task.delay(seconds or 3, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Корона и золотой след у лучшего игрока
function Effects.crown(participant, on: boolean)
	local character = participant.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not head or not root then
		return
	end
	for _, holder in { head, root } do
		for _, name in { "Crown", "CrownTrail", "TrailTop", "TrailBottom" } do
			local old = holder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end
	if not on then
		return
	end
	local crown = Instance.new("Model")
	crown.Name = "Crown"
	local function piece(size: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = GOLD
		p.Material = Enum.Material.Foil
		p.Reflectance = 0.3
		p.CanCollide = false
		p.Massless = true
		p.CFrame = head.CFrame * CFrame.new(offset)
		p.Parent = crown
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = p
		weld.Parent = p
	end
	local y = head.Size.Y / 2 + 0.2
	piece(Vector3.new(1.4, 0.35, 1.4), Vector3.new(0, y, 0))
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		piece(Vector3.new(0.25, 0.6, 0.25), Vector3.new(math.cos(a) * 0.55, y + 0.45, math.sin(a) * 0.55))
	end
	crown.Parent = head

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "CrownTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 255, 200))
	trail.Lifetime = 0.6
	trail.LightEmission = 1
	trail.Parent = root
end

-- Взрыв конфетти в точке
function Effects.confetti(position: Vector3, count: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = position
	holder.Parent = Workspace
	local confetti = Instance.new("ParticleEmitter")
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 190, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 160, 255)),
	})
	confetti.Size = NumberSequence.new(0.5)
	confetti.Speed = NumberRange.new(20, 40)
	confetti.SpreadAngle = Vector2.new(180, 180)
	confetti.Lifetime = NumberRange.new(2, 3.5)
	confetti.Acceleration = Vector3.new(0, -15, 0)
	confetti.LightEmission = 0.6
	confetti.Rate = 0
	confetti.Parent = holder
	confetti:Emit(count or 150)
	task.delay(5, function()
		holder:Destroy()
	end)
end

return Effects
