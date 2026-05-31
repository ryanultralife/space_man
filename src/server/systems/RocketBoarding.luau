--!strict
-- Boarding gate: the rocket's prompt only seats the player if they're suited up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RocketBoarding = {}

local notify = Remotes.event("Notify")

function RocketBoarding.start(complex: any)
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
		seat:Sit(humanoid)
		notify:FireClient(player, "🚀 Boarded! Rollout & launch are coming in the next update.")
	end)
end

return RocketBoarding
