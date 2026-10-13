-- Запуск игры «Прятки за Кубок»

local Players = game:GetService("Players")

local StadiumBuilder = require(script.Parent.StadiumBuilder)
local PlayerState = require(script.Parent.PlayerState)
local Economy = require(script.Parent.Economy)
local RoundManager = require(script.Parent.RoundManager)

Players.RespawnTime = 2

local map = StadiumBuilder.build()
PlayerState.start()
Economy.start()
RoundManager.start(map)
