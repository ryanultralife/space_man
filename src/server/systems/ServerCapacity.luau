--!strict
-- Player limits.
--
-- `Players.MaxPlayers` is READ-ONLY at runtime — it's set once in the place settings
-- (default.project.json sets it to 4 so private servers can hold the Artemis crew).
-- Since that one value is shared by every server, we keep PUBLIC servers solo by
-- sending extra joiners away with a note to use a free private server instead.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ServerCapacity = {}

function ServerCapacity.apply()
	local isPrivate = game.PrivateServerOwnerId ~= 0

	-- Private servers (and Studio playtests) allow the full crew; public is solo.
	if isPrivate or RunService:IsStudio() then
		print(`[space_man] {if isPrivate then "PRIVATE" else "STUDIO"} server — up to {Config.Servers.PrivateMax}`)
		return
	end

	print(`[space_man] PUBLIC server — solo (max {Config.Servers.PublicMax})`)
	local function enforceSolo(player: Player)
		if #Players:GetPlayers() > Config.Servers.PublicMax then
			player:Kick(
				`🚀 This is a solo public server! Make a FREE private server to fly with up to {Config.Servers.PrivateMax} friends.`
			)
		end
	end

	Players.PlayerAdded:Connect(enforceSolo)
	for _, player in Players:GetPlayers() do
		enforceSolo(player)
	end
end

return ServerCapacity
