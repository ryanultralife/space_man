--!strict
-- Server entry point. Runs once when the server starts.
-- (This becomes a Script named "Server" in ServerScriptService.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Greeting = require(ReplicatedStorage.Shared.Greeting)

print(`[server] {Greeting.message()}`)
