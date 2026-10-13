-- Запуск игры «Прятки за Кубок»

local Players = game:GetService("Players")

local StadiumBuilder = require(script.Parent.StadiumBuilder)
local PlayerState = require(script.Parent.PlayerState)
local Economy = require(script.Parent.Economy)
local RoundManager = require(script.Parent.RoundManager)
local HeroStatue = require(script.Parent.HeroStatue)

Players.RespawnTime = 2

local map = StadiumBuilder.build()
PlayerState.start()
Economy.start()
RoundManager.start(map)

-- Статуя сына: в лобби, где все появляются, и большая — за восточными воротами
HeroStatue.build(map.Root, {
	{ cf = CFrame.lookAt(map.LobbyCFrame.Position + Vector3.new(0, -3.5, -20), map.LobbyCFrame.Position + Vector3.new(0, -3.5, 0)), scale = 1.5 },
	{ cf = CFrame.lookAt(Vector3.new(126, 0, -30), Vector3.new(0, 0, -30)), scale = 2 },
})
