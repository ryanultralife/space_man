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
	-- Astrovan: ride the suited crew from the suit-up room out to the pad (real KSC step).
	local astrovanBusy = false
	complex.AstrovanPrompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if not player:GetAttribute("HasSuit") then
			notify:FireClient(player, "🚫 Suit up in the Suit-Up Room first.")
			return
		end
		if astrovanBusy then
			notify:FireClient(player, "🚐 The Astrovan is already running — catch the next ride.")
			return
		end
		astrovanBusy = true
		complex.AstrovanSeat:Sit(humanoid)
		notify:FireClient(player, "🚐 Riding the Astrovan out to the pad...")
		task.spawn(function()
			local from, to = complex.AstrovanStart, complex.AstrovanPad
			local dur = 8
			local t = 0
			while t < dur do
				local dt = task.wait()
				t += dt
				complex.Astrovan:PivotTo(from:Lerp(to, math.clamp(t / dur, 0, 1)))
			end
			complex.Astrovan:PivotTo(to)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = false
			end
			task.wait(0.15)
			if player.Character then
				player.Character:PivotTo(CFrame.new(-26, 3, -72))
			end
			notify:FireClient(player, "🛗 At the pad — take the crew elevator up the tower.")
			task.wait(1)
			local t2 = 0
			while t2 < 6 do
				local dt = task.wait()
				t2 += dt
				complex.Astrovan:PivotTo(to:Lerp(from, math.clamp(t2 / 6, 0, 1)))
			end
			complex.Astrovan:PivotTo(from)
			astrovanBusy = false
		end)
	end)

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
