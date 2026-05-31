--!strict
-- Shared module: code reachable by both the client and the server
-- (lives in ReplicatedStorage.Shared at runtime).

local Greeting = {}

function Greeting.message(): string
	return "Welcome to space_man 🚀"
end

return Greeting
