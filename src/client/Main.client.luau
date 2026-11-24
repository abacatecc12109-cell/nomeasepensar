--[[
	Main (cliente)
	--------------
	Inicia os controladores do jogador depois que o mundo foi publicado.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent:WaitForChild("Controllers")
local ObstacleController = require(Controllers.ObstacleController)
local CheckpointVisuals = require(Controllers.CheckpointVisuals)
local AmbientController = require(Controllers.AmbientController)
local HUDController = require(Controllers.HUDController)
local SkyController = require(Controllers.SkyController)
local SoundController = require(Controllers.SoundController)
local LifeController = require(Controllers.LifeController)

local info = ReplicatedStorage:WaitForChild("CourseInfo")
while not info:GetAttribute("Ready") do
	info:GetAttributeChangedSignal("Ready"):Wait()
end

SkyController.start()
ObstacleController.start()
CheckpointVisuals.start()
AmbientController.start()
HUDController.start(AmbientController.regionAt)
SoundController.start(AmbientController, ObstacleController)
LifeController.start()
