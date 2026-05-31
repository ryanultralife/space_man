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
	HelmetColor = Color3.fromRGB(235, 240, 245),
	SuitColor = Color3.fromRGB(220, 224, 230),
	PromptDistance = 9,
}

Config.Rocket = {
	-- Seconds for the crawler to roll the rocket from the assembly building to the pad.
	RolloutSeconds = 30,
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

return Config
