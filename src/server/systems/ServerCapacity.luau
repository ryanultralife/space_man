--!strict
-- Sets how many players a server holds, based on whether it's a private server.
--   * Public / normal server      → solo (Config.Servers.PublicMax, default 1)
--   * Player-owned private server  → Config.Servers.PrivateMax (default 5)
--
-- `game.PrivateServerOwnerId` is the UserId of the private server's owner, or 0 for a
-- public server (also 0 in Studio playtests, so testing behaves like a public server).
--
-- NOTE: the place's MaxPlayers (set to 5 in default.project.json) is the ceiling the
-- matchmaker uses; runtime can lower it but not raise it past that. And making private
-- servers FREE is a toggle in the experience settings — see the README.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ServerCapacity = {}

function ServerCapacity.apply()
	local isPrivate = game.PrivateServerOwnerId ~= 0
	Players.MaxPlayers = if isPrivate then Config.Servers.PrivateMax else Config.Servers.PublicMax
	print(`[space_man] {if isPrivate then "PRIVATE server" else "PUBLIC server"} — max players: {Players.MaxPlayers}`)
end

return ServerCapacity
