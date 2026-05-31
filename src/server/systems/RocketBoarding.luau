--!strict
-- Boarding gate: the rocket's prompt seats the player and kicks off the launch,
-- but only if they're suited up and no flight is already underway.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RocketBoarding = {}

local notify = Remotes.event("Notify")

function RocketBoarding.start(complex: any, launchSystem: any)
	local prompt: ProximityPrompt = complex.BoardPrompt
	local seat: Seat = complex.RocketSeat

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if not player:GetAttribute("HasSuit") then
			notify:FireClient(player, "🚫 No suit, no launch — put on a space suit first!")
			return
		end
		if launchSystem.isBusy() then
			notify:FireClient(player, "🚀 A launch is in progress — wait for the astronaut to return.")
			return
		end
		if not launchSystem.isReady() then
			notify:FireClient(player, "🚧 The rocket isn't on the pad yet — roll it out from the Vehicle Assembly Building first.")
			return
		end
		seat:Sit(humanoid)
		launchSystem.beginCountdown(player)
	end)
end

return RocketBoarding
