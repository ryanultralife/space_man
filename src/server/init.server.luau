--!strict
-- Server entry point. Sets world gravity, builds the world,
-- and starts the gameplay systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local ServerCapacity = require(script.systems.ServerCapacity)
local WorldBuilder = require(script.systems.WorldBuilder)
local SuitSystem = require(script.systems.SuitSystem)
local LaunchSystem = require(script.systems.LaunchSystem)
local RocketBoarding = require(script.systems.RocketBoarding)

-- Public servers are solo; player-owned private servers hold up to 5.
ServerCapacity.apply()

Workspace.Gravity = Config.Gravity[Config.CurrentWorld] or 196.2

local complex = WorldBuilder.build()
SuitSystem.start(complex)
LaunchSystem.start(complex)
RocketBoarding.start(complex, LaunchSystem)

print(`[space_man] server ready — world: {Config.CurrentWorld}, gravity: {Workspace.Gravity}`)
