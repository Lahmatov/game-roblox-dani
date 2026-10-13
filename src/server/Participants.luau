-- Все участники игры: настоящие игроки и боты.
-- Бот выглядит для остального кода почти как игрок: у него есть Name, DisplayName,
-- Character, Parent и атрибуты (GetAttribute / SetAttribute).

local Players = game:GetService("Players")

local Participants = {}

local bots = {}

local BotObject = {}
BotObject.__index = BotObject

function BotObject:GetAttribute(name: string)
	return self._attributes[name]
end

function BotObject:SetAttribute(name: string, value: any)
	self._attributes[name] = value
end

function Participants.newBot(name: string, id: number)
	local bot = setmetatable({
		Name = name,
		DisplayName = name,
		UserId = -id,
		IsBot = true,
		Parent = Players, -- пока бот в игре, Parent не nil (как у игрока)
		Character = nil,
		_attributes = {},
	}, BotObject)
	table.insert(bots, bot)
	return bot
end

function Participants.removeBot(bot)
	local i = table.find(bots, bot)
	if i then
		table.remove(bots, i)
	end
	bot.Parent = nil
end

function Participants.isBot(participant): boolean
	return type(participant) == "table" and participant.IsBot == true
end

function Participants.bots()
	return table.clone(bots)
end

function Participants.real(): { Player }
	return Players:GetPlayers()
end

function Participants.all()
	local list = Players:GetPlayers()
	for _, bot in bots do
		table.insert(list, bot)
	end
	return list
end

return Participants
