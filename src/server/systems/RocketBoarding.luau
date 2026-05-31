--!strict
-- Crew boarding, the realistic way: ride the service-tower elevator up to the access
-- arm, then enter the capsule hatch to launch. Gated on being suited up with the
-- rocket out on the pad.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RocketBoarding = {}

local notify = Remotes.event("Notify")
local screen = Remotes.event("Screen")

function RocketBoarding.start(complex: any, launchSystem: any)
	-- Crew elevator: ride up to the access arm.
	complex.ElevatorPrompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		if not player:GetAttribute("HasSuit") then
			notify:FireClient(player, "🚫 Put on a space suit first (the Suit-Up Room).")
			return
		end
		if not launchSystem.isReady() then
			notify:FireClient(player, "🚧 Roll the rocket out to the pad first (at the VAB).")
			return
		end
		screen:FireClient(player, "out", 0.5)
		task.wait(0.6)
		hrp.CFrame = complex.CrewArmTop
		screen:FireClient(player, "in", 0.5)
		notify:FireClient(player, "🛗 Up top! Cross the access arm and enter the capsule.")
	end)

	-- Capsule hatch: enter + launch.
	complex.BoardPrompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if not player:GetAttribute("HasSuit") then
			notify:FireClient(player, "🚫 No suit, no launch — visit the Suit-Up Room first!")
			return
		end
		if launchSystem.isBusy() then
			notify:FireClient(player, "🚀 A launch is in progress — wait for the astronaut to return.")
			return
		end
		if not launchSystem.isReady() then
			notify:FireClient(player, "🚧 The rocket isn't on the pad yet — roll it out from the VAB.")
			return
		end
		complex.RocketSeat:Sit(humanoid)
		launchSystem.beginCountdown(player)
	end)
end

return RocketBoarding
