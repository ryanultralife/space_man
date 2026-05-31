--!strict
-- Orchestrates a full mission. The rocket is assembled at the VAB and must be
-- rolled out to the pad first. The flight-plan console picks a destination:
--   * Earth Orbit  → orbit scene + satellite deploy (tracked at Mission Control)
--   * Moon / Mars  → low-gravity surface, deploy + drive the rover
-- "Return to Earth" brings you home via a parachute splashdown + rescue-boat pickup.
-- One astronaut flies at a time; the flow self-resets if they die or leave.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LaunchSystem = {}

local notify = Remotes.event("Notify")
local launchFX = Remotes.event("Launch")
local screen = Remotes.event("Screen")
local rescuePrompt = Remotes.event("RescuePrompt")
local rescue = Remotes.event("Rescue")

local DEST_LABEL = { EarthOrbit = "Earth Orbit", Moon = "the Moon", Mars = "Mars" }
local MOON_GROUND = Color3.fromRGB(150, 150, 156)
local MARS_GROUND = Color3.fromRGB(170, 92, 58)

local complex: any = nil
local inFlight = false
local rollingOut = false
local rocketAtPad = false
local canReturn = false
local awaitingRescue = false
local flyingPlayer: Player? = nil
local savedLighting: { [string]: any }? = nil
local abortConn: RBXScriptConnection? = nil
local deployedSats: { { name: string, status: string } } = {}

local function labelFor(dest: string): string
	return DEST_LABEL[dest] or dest
end

local function refreshMonitor()
	if not complex then
		return
	end
	if #deployedSats == 0 then
		complex.MonitorLabel.Text = "No satellites deployed yet.\n\nFly an Earth Orbit mission\nto deploy one."
		return
	end
	local lines = {}
	for _, s in deployedSats do
		table.insert(lines, `{s.name}   [ ● {s.status} ]`)
	end
	complex.MonitorLabel.Text = `In orbit: {#deployedSats}\n\n` .. table.concat(lines, "\n")
end

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
	if savedLighting then
		return
	end
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
	complex.Rocket:PivotTo(complex.RocketVAB)
	rocketAtPad = false
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
	Workspace.Gravity = Config.Gravity.Earth
	resetRocket()
	complex.Crawler:PivotTo(complex.CrawlerVAB)
	resetDescent()
	inFlight = false
	canReturn = false
	awaitingRescue = false
	flyingPlayer = nil
end

local function fade(player: Player, action: string, duration: number)
	screen:FireClient(player, action, duration)
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function LaunchSystem.isBusy(): boolean
	return inFlight or rollingOut
end

function LaunchSystem.isReady(): boolean
	return rocketAtPad and not inFlight and not rollingOut
end

function LaunchSystem.beginRollout(player: Player)
	if inFlight or rollingOut then
		notify:FireClient(player, "🚜 Hold on — something's already moving.")
		return
	end
	if rocketAtPad then
		notify:FireClient(player, "The rocket is already on the pad — suit up and board!")
		return
	end
	rollingOut = true
	notify:FireClient(player, `🚜 Assembling and rolling the rocket out to the pad (~{Config.Rocket.RolloutSeconds}s)...`)

	task.spawn(function()
		complex.Crawler:PivotTo(complex.CrawlerVAB)
		local rFrom, rTo = complex.RocketVAB, complex.RocketStart
		local cFrom, cTo = complex.CrawlerVAB, complex.CrawlerPad
		local dur = Config.Rocket.RolloutSeconds
		local t = 0
		while t < dur do
			local dt = task.wait()
			t += dt
			local f = math.clamp(t / dur, 0, 1)
			complex.Rocket:PivotTo(rFrom:Lerp(rTo, f))
			complex.Crawler:PivotTo(cFrom:Lerp(cTo, f))
		end
		complex.Rocket:PivotTo(rTo)
		complex.Crawler:PivotTo(cTo)
		rocketAtPad = true
		rollingOut = false
		notify:FireClient(player, "🚀 Rocket's on the pad! Suit up and board.")

		-- Crawler retreats to the VAB.
		local rdur = Config.Rocket.RolloutReturnSeconds
		local rt = 0
		while rt < rdur do
			local dt = task.wait()
			rt += dt
			complex.Crawler:PivotTo(cTo:Lerp(cFrom, math.clamp(rt / rdur, 0, 1)))
		end
		complex.Crawler:PivotTo(cFrom)
	end)
end

function LaunchSystem.beginCountdown(player: Player)
	if inFlight then
		notify:FireClient(player, "A launch is already in progress — stand by.")
		return
	end
	if not humanoidOf(player) then
		return
	end

	local dest = complex.FlightConsole:GetAttribute("Dest") or "EarthOrbit"
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

		notify:FireClient(player, `🛰️ Stage separation — on course for {labelFor(dest)}.`)
		task.wait(1)
		if not inFlight then
			return
		end

		fade(player, "out", Config.Launch.FadeSeconds)
		task.wait(Config.Launch.FadeSeconds + 0.1)
		setSpaceLighting()

		if dest == "Moon" or dest == "Mars" then
			Workspace.Gravity = Config.Gravity[dest] or Config.Gravity.Moon
			complex.SurfaceGround.Color = if dest == "Mars" then MARS_GROUND else MOON_GROUND

			local hum = humanoidOf(player)
			if hum then
				hum.Sit = false
			end
			task.wait(0.15)
			if player.Character then
				player.Character:PivotTo(complex.SurfaceSpawn)
			end
			resetRocket()

			fade(player, "in", 0.9)
			task.wait(0.3)
			notify:FireClient(player, `🛬 Touchdown on {labelFor(dest)}! Walk up to your rover and drive — return via the ascent stage.`)
			canReturn = true
		else
			local hum = humanoidOf(player)
			if hum then
				complex.OrbitSeat:Sit(hum)
			end
			task.wait(0.1)
			resetRocket()

			fade(player, "in", 0.8)
			task.wait(0.8)
			notify:FireClient(player, "🌍 Orbit achieved! Deploying satellite...")

			local idx = #deployedSats + 1
			local name = string.format("SAT-%02d", idx)
			local sat = WorldBuilder.makeSatellite(Config.Orbit.Center + Vector3.new(18, 2 + idx * 3, 0))
			local from = sat:GetPivot()
			local st = 0
			while st < 2.5 do
				local dt = task.wait()
				st += dt
				sat:PivotTo(from + Vector3.new(math.min(st, 2.5) * 8, 0, math.sin(st * 2) * 4))
			end

			table.insert(deployedSats, { name = name, status = "Nominal" })
			refreshMonitor()
			notify:FireClient(player, `🛰️ {name} deployed and nominal — track it at Mission Control.`)
			canReturn = true
		end
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
		Workspace.Gravity = Config.Gravity.Earth

		complex.DescentRig:PivotTo(complex.DescentStart)
		setParachute(true)
		local hum = humanoidOf(player)
		if hum then
			hum.Sit = false
			task.wait(0.05)
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

		setParachute(false)
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

local function onCycleDestination(player: Player)
	if inFlight or rollingOut then
		notify:FireClient(player, "Can't change the flight plan mid-mission.")
		return
	end
	local cur = complex.FlightConsole:GetAttribute("Dest") or "EarthOrbit"
	local idx = table.find(Config.Destinations, cur) or 1
	local nextDest = Config.Destinations[(idx % #Config.Destinations) + 1]
	complex.FlightConsole:SetAttribute("Dest", nextDest)
	complex.FlightLabel.Text = "Destination: " .. labelFor(nextDest)
	notify:FireClient(player, "🧭 Destination set: " .. labelFor(nextDest))
end

local function onDrive(player: Player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	-- Lift the player onto the seat; the VehicleSeat grabs them on contact.
	hrp.CFrame = complex.RoverSeat.CFrame * CFrame.new(0, 2, 0)
end

function LaunchSystem.start(complexRef: any)
	complex = complexRef
	complex.OrbitReturnPrompt.Triggered:Connect(onReturn)
	complex.SurfaceReturnPrompt.Triggered:Connect(onReturn)
	complex.FlightCyclePrompt.Triggered:Connect(onCycleDestination)
	complex.RoverDrivePrompt.Triggered:Connect(onDrive)
	complex.RolloutPrompt.Triggered:Connect(function(player: Player)
		LaunchSystem.beginRollout(player)
	end)

	rescue.OnServerEvent:Connect(function(player: Player)
		LaunchSystem.requestRescue(player)
	end)

	refreshMonitor()

	-- Kinematic rover driving while a player occupies the seat.
	RunService.Heartbeat:Connect(function(dt: number)
		local seat = complex.RoverSeat
		if not seat.Occupant then
			return
		end
		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat
		if throttle == 0 and steer == 0 then
			return
		end
		local turn = -steer * Config.Rover.TurnRate * dt
		local fwd = throttle * Config.Rover.Speed * dt
		complex.Rover:PivotTo(complex.Rover:GetPivot() * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -fwd))
	end)
end

return LaunchSystem
