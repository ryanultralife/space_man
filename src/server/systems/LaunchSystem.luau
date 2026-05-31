--!strict
-- Orchestrates a full mission: countdown → ignition → ascent → orbit → satellite
-- deploy → re-entry under parachute → ocean splashdown → rescue-boat pickup → home.
-- One astronaut flies at a time; the flow self-resets if they die or leave.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LaunchSystem = {}

local notify = Remotes.event("Notify")
local launchFX = Remotes.event("Launch")
local screen = Remotes.event("Screen")
local rescuePrompt = Remotes.event("RescuePrompt")
local rescue = Remotes.event("Rescue")

local complex: any = nil
local inFlight = false
local canReturn = false
local awaitingRescue = false
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

local function setParachute(show: boolean)
	local chute = complex.DescentRig:FindFirstChild("Parachute")
	if not chute then
		return
	end
	for _, p in chute:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = if show then (p:GetAttribute("Vis") or 0) else 1
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

local function resetDescent()
	complex.DescentRig:PivotTo(complex.DescentParked)
	setParachute(true)
end

local function endFlight()
	if abortConn then
		abortConn:Disconnect()
		abortConn = nil
	end
	restoreLighting()
	resetRocket()
	resetDescent()
	inFlight = false
	canReturn = false
	awaitingRescue = false
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

		fade(player, "out", Config.Launch.FadeSeconds)
		task.wait(Config.Launch.FadeSeconds + 0.1)
		setSpaceLighting()

		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			complex.OrbitSeat:Sit(hum)
		end
		task.wait(0.1)
		resetRocket()

		fade(player, "in", 0.8)
		task.wait(0.8)
		notify:FireClient(player, "🌍 Orbit achieved! Deploying satellite...")

		local sat = complex.Satellite
		local from = sat:GetPivot()
		local st = 0
		while st < 3 do
			local dt = task.wait()
			st += dt
			sat:PivotTo(from + Vector3.new(math.min(st, 3) * 6, 0, 0))
		end

		notify:FireClient(player, "🛰️ Satellite deployed. Use the capsule's prompt to head home.")
		canReturn = true
	end)
end

local function onReturn(player: Player)
	if player ~= flyingPlayer or not canReturn then
		return
	end
	canReturn = false

	task.spawn(function()
		fade(player, "out", 0.7)
		task.wait(0.8)
		restoreLighting()

		complex.DescentRig:PivotTo(complex.DescentStart)
		setParachute(true)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			complex.DescentSeat:Sit(hum)
		end

		fade(player, "in", 0.8)
		notify:FireClient(player, "🔥 Re-entry! Parachute deployed — splashing down.")

		local sx = Config.Splashdown.Point.X
		local sz = Config.Splashdown.Point.Z
		local startY = Config.Splashdown.StartHeight
		local dur = Config.Splashdown.DescentSeconds
		local t = 0
		while t < dur do
			local dt = task.wait()
			t += dt
			if not inFlight then
				return
			end
			local f = math.clamp(t / dur, 0, 1)
			local y = startY + (2 - startY) * f
			local sway = math.sin(t * 1.4) * 7 * (1 - f)
			complex.DescentRig:PivotTo(CFrame.new(sx + sway, y, sz))
		end

		setParachute(false) -- chute released on touchdown
		notify:FireClient(player, "🌊 Splashdown! You're floating safely — call for pickup.")
		awaitingRescue = true
		rescuePrompt:FireClient(player, true)
	end)
end

function LaunchSystem.requestRescue(player: Player)
	if player ~= flyingPlayer or not awaitingRescue then
		return
	end
	awaitingRescue = false
	rescuePrompt:FireClient(player, false)
	notify:FireClient(player, "🚤 Rescue boats dispatched!")

	task.spawn(function()
		local target = complex.DescentRig:GetPivot().Position
		local boat = WorldBuilder.makeBoat(Vector3.new(Config.Rescue.ShoreX, 1, Config.Splashdown.Point.Z))
		local from = boat:GetPivot()
		local to = CFrame.new(target.X - 9, 1, target.Z)
		local dur = Config.Rescue.BoatSpeedSeconds
		local t = 0
		while t < dur do
			local dt = task.wait()
			t += dt
			if not inFlight then
				boat:Destroy()
				return
			end
			boat:PivotTo(from:Lerp(to, math.clamp(t / dur, 0, 1)))
		end

		notify:FireClient(player, "🪝 Pulling you aboard...")
		task.wait(1.2)
		fade(player, "out", 0.6)
		task.wait(0.7)
		player:LoadCharacter()
		boat:Destroy()
		endFlight()
		fade(player, "in", 0.8)
		notify:FireClient(player, "✅ Rescued! Welcome back to the Cape.")
	end)
end

function LaunchSystem.start(complexRef: any)
	complex = complexRef
	complex.OrbitReturnPrompt.Triggered:Connect(onReturn)
	rescue.OnServerEvent:Connect(function(player: Player)
		LaunchSystem.requestRescue(player)
	end)
end

return LaunchSystem
