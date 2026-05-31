--!strict
-- Server entry point. Everything is wrapped so that if any system fails to start,
-- a big red sign appears in-game with the error (instead of the world silently
-- not building) — makes problems easy to spot and report.

local Workspace = game:GetService("Workspace")

local function showError(message: string)
	warn("[space_man] STARTUP ERROR: " .. message)
	local anchor = Instance.new("Part")
	anchor.Name = "SpaceManError"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Position = Vector3.new(0, 24, 48)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 900, 0, 240)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.Text = "space_man failed to start:\n\n" .. message
	label.Parent = billboard
end

local ok, err = pcall(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.Config)

	local ServerCapacity = require(script.systems.ServerCapacity)
	local WorldBuilder = require(script.systems.WorldBuilder)
	local SuitSystem = require(script.systems.SuitSystem)
	local LaunchSystem = require(script.systems.LaunchSystem)
	local RocketBoarding = require(script.systems.RocketBoarding)
	local RocketBuilder = require(script.systems.RocketBuilder)

	ServerCapacity.apply()
	Workspace.Gravity = Config.Gravity[Config.CurrentWorld] or 196.2

	local complex = WorldBuilder.build()
	SuitSystem.start(complex)
	LaunchSystem.start(complex)
	RocketBoarding.start(complex, LaunchSystem)
	RocketBuilder.start(complex, LaunchSystem)

	print(`[space_man] server ready — world: {Config.CurrentWorld}, gravity: {Workspace.Gravity}`)
end)

if not ok then
	showError(tostring(err))
end
