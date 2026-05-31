--!strict
-- Central tunables for space_man. Edit values here; every system reads from this.

local Config = {}

-- Roblox gravity units (default Workspace.Gravity is 196.2 ≈ Earth's 9.81 m/s²).
-- Other bodies are scaled by their real surface-gravity ratio to Earth.
Config.Gravity = {
	Earth = 196.2,
	Moon = 32.4, -- ~1.62 / 9.81 * 196.2
	Mars = 74.4, -- ~3.72 / 9.81 * 196.2
	Orbit = 0, -- microgravity
} :: { [string]: number }

-- Which world this place currently represents.
-- (Later milestone: split worlds into separate Roblox places and teleport between them.)
Config.CurrentWorld = "Earth"

Config.Suit = {
	-- AddGear = false: suiting up just flags you (a quick sparkle) and keeps your own
	-- avatar/outfit. Set true if you want the game to add a helmet + life-support pack.
	AddGear = false,
	HelmetColor = Color3.fromRGB(235, 240, 245),
	SuitColor = Color3.fromRGB(220, 224, 230),
	PromptDistance = 9,
}

Config.Rocket = {
	-- Seconds for the crawler to roll the rocket from the assembly building to the pad.
	RolloutSeconds = 30,
	RolloutReturnSeconds = 8, -- crawler retreat back to the VAB afterwards
	PromptDistance = 11,
}

Config.Launch = {
	CountdownFrom = 5,
	AscentSeconds = 7,
	AscentHeight = 260,
	FadeSeconds = 0.7,
}

Config.Orbit = {
	-- Where the orbit scene lives (far from the launch site; we relocate the player here).
	Center = Vector3.new(0, 0, 6000),
}

Config.Splashdown = {
	Point = Vector3.new(300, 0, -10), -- in the sea, just off the island's east shore
	StartHeight = 360, -- altitude the parachute descent begins from
	FloatY = 1.5, -- where the capsule rests, half-submerged
	DescentSeconds = 9,
}

Config.Rescue = {
	ShoreX = 205, -- rescue boats set off from the island's east shore
	BoatSpeedSeconds = 5,
}

Config.Ocean = {
	Center = Vector3.new(520, -20, -10),
	Size = Vector3.new(760, 40, 520),
}

Config.Rover = {
	Speed = 42,
	TurnRate = 1.8,
}

Config.Surface = {
	-- Reusable surface world (recoloured per destination), far from the launch site.
	Center = Vector3.new(0, 0, 12000),
}

Config.Destinations = { "EarthOrbit", "Moon", "Mars" }

Config.Servers = {
	PublicMax = 1, -- public/normal servers are solo
	PrivateMax = 4, -- free private servers hold up to 4 (the Artemis crew size)
}

return Config
