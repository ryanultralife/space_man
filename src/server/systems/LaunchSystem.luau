--!strict
-- Orchestrates a full flight: countdown → ignition → ascent → orbit transition
-- → satellite deploy, and a return-to-Earth prompt while in orbit. One astronaut
-- flies at a time (there's a single rocket); the flow self-resets if they leave.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LaunchSystem = {}

local notify = Remotes.event("Notify")
local launchFX = Remotes.event("Launch")
local screen = Remotes.event("Screen")

local complex: any = nil
local inFlight = false
local flyingPlayer: Player? = nil
local savedLighting: { [string]: any }? = nil
local abortConn: RBXScriptConnection? = nil

local function setEngine(on: boolean)
	for _, d in complex.EngineFX:GetChildren() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			(d :: any).Enabled = on
		end
	end
end

local function setSpaceLighting()
	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
		FogEnd = Lighting.FogEnd,
	}
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 18, 28)
	Lighting.Ambient = Color3.fromRGB(12, 12, 22)
	Lighting.FogEnd = 1e9
end

local function restoreLighting()
	local s = savedLighting
	if not s then
		return
	end
	for k, v in s do
		(Lighting :: any)[k] = v
	end
	savedLighting = nil
end

local function resetRocket()
	setEngine(false)
	complex.Rocket:PivotTo(complex.RocketStart)
end

local function endFlight()
	if abortConn then
		abortConn:Disconnect()
		abortConn = nil
	end
	restoreLighting()
	resetRocket()
	inFlight = false
	flyingPlayer = nil
end

local function fade(player: Player, action: string, duration: number)
	screen:FireClient(player, action, duration)
end

function LaunchSystem.isBusy(): boolean
	return inFlight
end

function LaunchSystem.beginCountdown(player: Player)
	if inFlight then
		notify:FireClient(player, "A launch is already in progress — stand by.")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	inFlight = true
	flyingPlayer = player

	-- Safety: if the astronaut dies or leaves mid-flight, reset everything.
	abortConn = player.CharacterRemoving:Connect(endFlight)

	task.spawn(function()
		for n = Config.Launch.CountdownFrom, 1, -1 do
			if not inFlight then
				return
			end
			notify:FireClient(player, `T-minus {n}...`)
			task.wait(1)
		end
		if not inFlight then
			return
		end

		notify:FireClient(player, "🔥 Liftoff!")
		setEngine(true)
		launchFX:FireClient(player, Config.Launch.AscentSeconds)

		-- Accelerating climb (translate the pivot straight up in world space).
		local start = complex.Rocket:GetPivot()
		local dur = Config.Launch.AscentSeconds
		local height = Config.Launch.AscentHeight
		local t = 0
		while t < dur do
			local dt = task.wait()
			t += dt
			if not inFlight then
				return
			end
			local f = math.clamp(t / dur, 0, 1)
			complex.Rocket:PivotTo(start + Vector3.new(0, height * f * f, 0))
		end

		notify:FireClient(player, "🛰️ Stage separation — coasting to orbit.")
		task.wait(1)
		if not inFlight then
			return
		end

		-- Transition to orbit while the screen is black.
		fade(player, "out", Config.Launch.FadeSeconds)
		task.wait(Config.Launch.FadeSeconds + 0.1)

		setSpaceLighting()

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			complex.OrbitSeat:Sit(hum)
		end
		task.wait(0.1)
		resetRocket() -- empty rocket returns to the pad for the next astronaut

		fade(player, "in", 0.8)
		task.wait(0.8)
		notify:FireClient(player, "🌍 Orbit achieved! Deploying satellite...")

		-- Drift the satellite away from the capsule.
		local sat = complex.Satellite
		local from = sat:GetPivot()
		local st = 0
		while st < 3 do
			local dt = task.wait()
			st += dt
			sat:PivotTo(from + Vector3.new(math.min(st, 3) * 6, 0, 0))
		end

		notify:FireClient(player, "🛰️ Satellite deployed. Use the capsule's prompt to return to Earth.")
	end)
end

local function onReturn(player: Player)
	if player ~= flyingPlayer then
		notify:FireClient(player, "Only the astronaut in orbit can do that.")
		return
	end
	fade(player, "out", 0.6)
	task.wait(0.7)
	restoreLighting()
	player:LoadCharacter()
	endFlight()
	fade(player, "in", 0.8)
	notify:FireClient(player, "🪂 Welcome back to the Cape!")
end

function LaunchSystem.start(complexRef: any)
	complex = complexRef
	complex.OrbitReturnPrompt.Triggered:Connect(onReturn)
end

return LaunchSystem
