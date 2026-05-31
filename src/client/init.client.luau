--!strict
-- Client entry point. Sets up the HUD and shows server notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notifier = require(script.ui.Notifier)

Notifier.init()

local notify = Remotes.event("Notify")
notify.OnClientEvent:Connect(function(message: string)
	Notifier.show(message)
end)
