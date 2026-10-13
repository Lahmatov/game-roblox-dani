-- Звуки: сервер говорит всем игрокам, какой звук сыграть и где.

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local Sfx = {}

-- name — ключ из Config.SOUNDS; position — где звучит (nil — слышно везде одинаково)
function Sfx.play(name: string, position: Vector3?)
	Remotes.get("Sfx"):FireAllClients(name, position)
end

return Sfx
