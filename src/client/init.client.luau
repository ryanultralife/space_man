--!strict
-- Client entry point. Runs on each player's device.
-- (This becomes a LocalScript named "Client" in StarterPlayerScripts.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Greeting = require(ReplicatedStorage.Shared.Greeting)

print(`[client] {Greeting.message()}`)
