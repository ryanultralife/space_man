--!strict
-- Client entry point: HUD toasts, screen fades, and launch camera shake.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifier = require(script.ui.Notifier)

Notifier.init()

Remotes.event("Notify").OnClientEvent:Connect(function(message: string)
	Notifier.show(message)
end)

Remotes.event("Screen").OnClientEvent:Connect(function(action: string, duration: number)
	Notifier.fade(action, duration)
end)

Remotes.event("Launch").OnClientEvent:Connect(function(duration: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= duration then
			humanoid.CameraOffset = Vector3.zero
			if connection then
				connection:Disconnect()
			end
			return
		end
		local shake = 0.5
		humanoid.CameraOffset = Vector3.new(
			(math.random() - 0.5) * shake,
			(math.random() - 0.5) * shake,
			(math.random() - 0.5) * shake
		)
	end)
end)

-- Rescue button: server tells us when to show it; clicking asks for pickup.
Remotes.event("RescuePrompt").OnClientEvent:Connect(function(show: boolean)
	Notifier.setRescueVisible(show)
end)

Notifier.RescueClicked:Connect(function()
	Remotes.event("Rescue"):FireServer()
end)
