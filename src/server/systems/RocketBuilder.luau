--!strict
-- Rocket builder consoles at the assembly bay: cycle the number of strap-on boosters
-- and the payload. Changes apply to the parked rocket immediately (you watch it
-- change) and ride with it through rollout and launch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)

local RocketBuilder = {}

local notify = Remotes.event("Notify")

local BOOSTER_CYCLE: { [number]: number } = { [0] = 2, [2] = 4, [4] = 0 }
local PAYLOAD_CYCLE = { Rover = "Satellite", Satellite = "Crew", Crew = "Rover" }

local function refresh(complex: any)
	local boosters = complex.Rocket:GetAttribute("Boosters") or 0
	local payload = complex.Rocket:GetAttribute("Payload") or "Rover"
	complex.BuildLabel.Text = `🔧 Boosters: {boosters}  |  Payload: {payload}`
end

function RocketBuilder.start(complex: any, launchSystem: any)
	complex.BoostersPrompt.Triggered:Connect(function(player: Player)
		if launchSystem.isBusy() then
			notify:FireClient(player, "🔧 Can't rebuild the rocket during a launch.")
			return
		end
		local cur = complex.Rocket:GetAttribute("Boosters") or 0
		complex.Rocket:SetAttribute("Boosters", BOOSTER_CYCLE[cur] or 0)
		WorldBuilder.applyRocketBuild(complex.Rocket)
		refresh(complex)
		notify:FireClient(player, `🚀 Boosters: {complex.Rocket:GetAttribute("Boosters")}`)
	end)

	complex.PayloadPrompt.Triggered:Connect(function(player: Player)
		if launchSystem.isBusy() then
			notify:FireClient(player, "🔧 Can't rebuild the rocket during a launch.")
			return
		end
		local cur = complex.Rocket:GetAttribute("Payload") or "Rover"
		complex.Rocket:SetAttribute("Payload", PAYLOAD_CYCLE[cur] or "Rover")
		WorldBuilder.applyRocketBuild(complex.Rocket)
		refresh(complex)
		notify:FireClient(player, `📦 Payload: {complex.Rocket:GetAttribute("Payload")}`)
	end)

	refresh(complex)
end

return RocketBuilder
