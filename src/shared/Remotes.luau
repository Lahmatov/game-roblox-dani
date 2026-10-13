-- Сигналы между сервером и игроками. Сервер их создаёт, игроки ждут.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Volunteer", -- игрок -> сервер: хочу / не хочу водить
	"ToggleBots", -- игрок -> сервер: включить / выключить ботов
	"BotLevel", -- игрок -> сервер: глупые / умные боты
	"Dash", -- игрок -> сервер: рывок
	"Kick", -- игрок -> сервер: пнуть мяч (направление)
	"BuyKit", -- игрок -> сервер: купить форму
	"EquipKit", -- игрок -> сервер: надеть форму
	"Announce", -- сервер -> игроки: большое сообщение на экране
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
