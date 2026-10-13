-- Монеты, магазин форм и сохранение.
-- Сохранение работает только в опубликованной игре, где включено
-- «Enable Studio Access to API Services» (Game Settings -> Security).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Economy = {}

type Profile = {
	Coins: number,
	Owned: { [string]: boolean },
	Equipped: string,
}

local profiles: { [Player]: Profile } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("PryatkiZaKubok_v1")
	end)
	if ok then
		store = result
	else
		warn("Сохранение недоступно:", result)
	end
end

local function defaultProfile(): Profile
	return { Coins = 0, Owned = { [Config.DEFAULT_KIT] = true }, Equipped = Config.DEFAULT_KIT }
end

local function publish(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local owned = {}
	for id in profile.Owned do
		table.insert(owned, id)
	end
	player:SetAttribute("Coins", profile.Coins)
	player:SetAttribute("OwnedKits", table.concat(owned, ","))
	player:SetAttribute("EquippedKit", profile.Equipped)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Монеты") :: IntValue?
	if coins then
		coins.Value = profile.Coins
	end
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), profile)
	end)
	if not ok then
		warn("Не получилось сохранить", player.Name, err)
	end
end

local function load(player: Player)
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if ok and type(data) == "table" then
			profile.Coins = tonumber(data.Coins) or 0
			if type(data.Owned) == "table" then
				for id, owned in data.Owned do
					if owned and Config.getKit(id) then
						profile.Owned[id] = true
					end
				end
			end
			if type(data.SecretDay) == "string" then
				(profile :: any).SecretDay = data.SecretDay
			end
			if type(data.Equipped) == "string" and profile.Owned[data.Equipped] then
				profile.Equipped = data.Equipped
			end
		end
	end
	profiles[player] = profile
end

local BODY_PARTS = { "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

function Economy.applyKit(player: Player)
	local profile = profiles[player]
	local character = player.Character
	if not profile or not character then
		return
	end
	local kit = Config.getKit(profile.Equipped)
	if not kit then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	-- Запоминаем настоящий цвет кожи, чтобы вернуть его под формой с рисунком
	if not colors:GetAttribute("Saved") then
		for _, name in BODY_PARTS do
			colors:SetAttribute(name, (colors :: any)[name])
		end
		colors:SetAttribute("Saved", true)
	end

	local shirtId = kit.ShirtTemplate or 0
	local pantsId = kit.PantsTemplate or 0
	if shirtId > 0 and pantsId > 0 then
		for _, name in BODY_PARTS do
			(colors :: any)[name] = colors:GetAttribute(name)
		end
		local shirt = Instance.new("Shirt")
		shirt.ShirtTemplate = "rbxassetid://" .. shirtId
		shirt.Parent = character
		local pants = Instance.new("Pants")
		pants.PantsTemplate = "rbxassetid://" .. pantsId
		pants.Parent = character
	else
		colors.TorsoColor3 = kit.Shirt
		colors.LeftArmColor3 = kit.Shirt
		colors.RightArmColor3 = kit.Shirt
		colors.LeftLegColor3 = kit.Shorts
		colors.RightLegColor3 = kit.Shorts
	end
end

-- Сундук в секретной комнате: награда раз в день. Возвращает true, если дали монеты.
function Economy.claimSecret(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local today = os.date("!%Y-%m-%d")
	if (profile :: any).SecretDay == today then
		return false
	end
	(profile :: any).SecretDay = today
	profile.Coins += Config.SECRET_REWARD
	publish(player)
	return true
end

function Economy.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Coins += amount
	publish(player)
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	load(player)
	if player.Parent == nil then
		profiles[player] = nil
		return
	end
	publish(player)

	player.CharacterAppearanceLoaded:Connect(function()
		Economy.applyKit(player)
	end)
	if player.Character then
		Economy.applyKit(player)
	end
end

function Economy.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	Remotes.get("BuyKit").OnServerEvent:Connect(function(player, kitId)
		local profile = profiles[player]
		local kit = type(kitId) == "string" and Config.getKit(kitId)
		if not profile or not kit or profile.Owned[kit.Id] or profile.Coins < kit.Price then
			return
		end
		profile.Coins -= kit.Price
		profile.Owned[kit.Id] = true
		profile.Equipped = kit.Id
		publish(player)
		Economy.applyKit(player)
	end)

	Remotes.get("EquipKit").OnServerEvent:Connect(function(player, kitId)
		local profile = profiles[player]
		if not profile or type(kitId) ~= "string" or not profile.Owned[kitId] then
			return
		end
		profile.Equipped = kitId
		publish(player)
		Economy.applyKit(player)
	end)
end

return Economy
