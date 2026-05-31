--!strict
-- Orchestrates missions for a CREW (1 player for the Standard rocket, up to 4 for the
-- Artemis). A mission: countdown → ignition → ascent → arrival (orbit + satellite, or
-- a low-gravity surface) → "Return to Earth" → parachute splashdown → rescue-boat pickup.
-- Only ONE mission runs at a time. The flow self-resets if a crew member dies or leaves.
--
-- Standard rocket: assembled at the VAB, rolled out to the pad, solo, uses the flight
-- plan's destination. Artemis: on its own pad, unlocked only in a free private server
-- with 2+ players, carries up to 4 to the Moon together.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
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
local crew: { Player } = {}
local missionModel: Model? = nil
local missionEngineFX: BasePart? = nil
local missionResetCF: CFrame? = nil
local missionDest = "EarthOrbit"
local savedLighting: { [string]: any }? = nil
local abortConns: { RBXScriptConnection } = {}
local deployedSats: { { name: string, status: string } } = {}

local function labelFor(dest: string): string
	return DEST_LABEL[dest] or dest
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function isCrew(player: Player): boolean
	return table.find(crew, player) ~= nil
end

local function notifyCrew(message: string)
	for _, p in crew do
		notify:FireClient(p, message)
	end
end

local function fadeCrew(action: string, duration: number)
	for _, p in crew do
		screen:FireClient(p, action, duration)
	end
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

local function setEngine(fx: BasePart?, on: boolean)
	if not fx then
		return
	end
	for _, d in fx:GetChildren() do
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

local function resetMissionVehicle()
	setEngine(missionEngineFX, false)
	if missionModel and missionResetCF then
		missionModel:PivotTo(missionResetCF)
	end
end

local function resetDescent()
	complex.DescentRig:PivotTo(complex.DescentParked)
	setParachute(true)
end

local function endFlight()
	for _, c in abortConns do
		c:Disconnect()
	end
	abortConns = {}
	restoreLighting()
	Workspace.Gravity = Config.Gravity.Earth
	setEngine(complex.EngineFX, false)
	setEngine(complex.ArtemisEngineFX, false)
	complex.Rocket:PivotTo(complex.RocketVAB)
	complex.Crawler:PivotTo(complex.CrawlerVAB)
	complex.Artemis:PivotTo(complex.ArtemisStart)
	resetDescent()
	inFlight = false
	canReturn = false
	awaitingRescue = false
	rocketAtPad = false
	crew = {}
	missionModel = nil
	missionEngineFX = nil
	missionResetCF = nil
end

local function connectAborts()
	for _, p in crew do
		table.insert(abortConns, p.CharacterRemoving:Connect(endFlight))
	end
end

local function placeCrewSurface()
	for _, p in crew do
		local hum = humanoidOf(p)
		if hum then
			hum.Sit = false
		end
	end
	task.wait(0.15)
	for i, p in crew do
		if p.Character then
			p.Character:PivotTo(complex.SurfaceSpawn * CFrame.new((i - 1) * 5, 0, 0))
		end
	end
end

local function placeCrewOrbit()
	for i, p in crew do
		local hum = humanoidOf(p)
		if not hum then
			continue
		end
		if i == 1 then
			complex.OrbitSeat:Sit(hum)
		else
			hum.Sit = false
			if p.Character then
				p.Character:PivotTo(complex.OrbitDeck.CFrame * CFrame.new((i - 2) * 4 - 2, 4, 0))
			end
		end
	end
end

local function runMission()
	task.spawn(function()
		for n = Config.Launch.CountdownFrom, 1, -1 do
			if not inFlight then
				return
			end
			notifyCrew(`T-minus {n}...`)
			task.wait(1)
		end
		if not inFlight then
			return
		end

		notifyCrew("🔥 Liftoff!")
		setEngine(missionEngineFX, true)
		for _, p in crew do
			launchFX:FireClient(p, Config.Launch.AscentSeconds)
		end

		local model = missionModel :: Model
		local start = model:GetPivot()
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
			model:PivotTo(start + Vector3.new(0, height * f * f, 0))
		end

		notifyCrew(`🛰️ Stage separation — on course for {labelFor(missionDest)}.`)
		task.wait(1)
		if not inFlight then
			return
		end

		fadeCrew("out", Config.Launch.FadeSeconds)
		task.wait(Config.Launch.FadeSeconds + 0.1)
		setSpaceLighting()

		if missionDest == "Moon" or missionDest == "Mars" then
			Workspace.Gravity = Config.Gravity[missionDest] or Config.Gravity.Moon
			complex.SurfaceGround.Color = if missionDest == "Mars" then MARS_GROUND else MOON_GROUND
			placeCrewSurface()
			resetMissionVehicle()
			fadeCrew("in", 0.9)
			task.wait(0.3)
			notifyCrew(`🛬 Touchdown on {labelFor(missionDest)}! Explore — return via the ascent stage.`)
			canReturn = true
		else
			placeCrewOrbit()
			task.wait(0.1)
			resetMissionVehicle()
			fadeCrew("in", 0.8)
			task.wait(0.8)
			notifyCrew("🌍 Orbit achieved! Deploying satellite...")

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
			notifyCrew(`🛰️ {name} deployed and nominal — track it at Mission Control.`)
			canReturn = true
		end
	end)
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

-- Standard rocket: solo crew of 1, uses the flight-plan destination.
function LaunchSystem.beginCountdown(player: Player)
	if inFlight then
		notify:FireClient(player, "A launch is already in progress — stand by.")
		return
	end
	if not humanoidOf(player) then
		return
	end
	crew = { player }
	missionModel = complex.Rocket
	missionEngineFX = complex.EngineFX
	missionResetCF = complex.RocketVAB
	missionDest = complex.FlightConsole:GetAttribute("Dest") or "EarthOrbit"
	inFlight = true
	connectAborts()
	runMission()
end

local function onReturn(player: Player)
	if not isCrew(player) or not canReturn then
		return
	end
	canReturn = false

	task.spawn(function()
		fadeCrew("out", 0.7)
		task.wait(0.8)
		restoreLighting()
		Workspace.Gravity = Config.Gravity.Earth
		complex.DescentRig:PivotTo(complex.DescentStart)
		setParachute(true)

		local sx = Config.Splashdown.Point.X
		local sz = Config.Splashdown.Point.Z

		if #crew <= 1 then
			-- Solo: ride the parachute down.
			local hum = humanoidOf(crew[1])
			if hum then
				hum.Sit = false
				task.wait(0.05)
				complex.DescentSeat:Sit(hum)
			end
			fadeCrew("in", 0.8)
			notifyCrew("🔥 Re-entry! Parachute deployed — splashing down.")
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
		else
			-- Crew: set down together at the splashdown point.
			notifyCrew("🔥 Re-entry — splashing down!")
			complex.DescentRig:PivotTo(CFrame.new(sx, 2, sz))
			for i, p in crew do
				local hum = humanoidOf(p)
				if not hum then
					continue
				end
				if i == 1 then
					complex.DescentSeat:Sit(hum)
				else
					hum.Sit = false
					if p.Character then
						p.Character:PivotTo(CFrame.new(sx + (i - 2) * 4 - 2, 4, sz + 6))
					end
				end
			end
			task.wait(1)
			fadeCrew("in", 0.9)
		end

		setParachute(false)
		notifyCrew("🌊 Splashdown! You're floating safely — call for pickup.")
		awaitingRescue = true
		for _, p in crew do
			rescuePrompt:FireClient(p, true)
		end
	end)
end

function LaunchSystem.requestRescue(player: Player)
	if not isCrew(player) or not awaitingRescue then
		return
	end
	awaitingRescue = false
	local members = table.clone(crew)
	for _, p in members do
		rescuePrompt:FireClient(p, false)
	end
	notifyCrew("🚤 Rescue boats dispatched!")

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

		notifyCrew("🪝 Pulling you aboard...")
		task.wait(1.2)
		for _, p in members do
			screen:FireClient(p, "out", 0.6)
		end
		task.wait(0.7)
		for _, p in members do
			p:LoadCharacter()
		end
		boat:Destroy()
		endFlight()
		for _, p in members do
			screen:FireClient(p, "in", 0.8)
			notify:FireClient(p, "✅ Rescued! Welcome back to the Cape.")
		end
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
	hrp.CFrame = complex.RoverSeat.CFrame * CFrame.new(0, 2, 0)
end

local function artemisUnlocked(): boolean
	return game.PrivateServerOwnerId ~= 0 and #Players:GetPlayers() >= 2
end

local function updateArtemisSign()
	if not complex then
		return
	end
	complex.ArtemisSign.Text = if artemisUnlocked()
		then "🚀 ARTEMIS — crew of 4 — board & LAUNCH!"
		else "🔒 ARTEMIS — needs a free private server (2+ players)"
end

local function onArtemisBoard(player: Player)
	if inFlight then
		notify:FireClient(player, "🚀 A mission is underway — stand by.")
		return
	end
	if not artemisUnlocked() then
		notify:FireClient(player, "🔒 Artemis unlocks in a FREE private server with 2+ players.")
		return
	end
	if not player:GetAttribute("HasSuit") then
		notify:FireClient(player, "🚫 Suit up before boarding Artemis.")
		return
	end
	local hum = humanoidOf(player)
	if not hum then
		return
	end
	for _, s in complex.ArtemisSeats do
		if not s.Occupant then
			s:Sit(hum)
			notify:FireClient(player, "🧑‍🚀 Boarded Artemis. When the crew's ready, hold LAUNCH (G) up top.")
			return
		end
	end
	notify:FireClient(player, "Artemis is full (4 crew).")
end

local function onArtemisLaunch(player: Player)
	if inFlight then
		notify:FireClient(player, "🚀 A mission is already underway.")
		return
	end
	if not artemisUnlocked() then
		notify:FireClient(player, "🔒 Artemis is locked.")
		return
	end
	local gathered: { Player } = {}
	for _, s in complex.ArtemisSeats do
		local occupant = s.Occupant
		if occupant then
			local p = Players:GetPlayerFromCharacter(occupant.Parent)
			if p then
				table.insert(gathered, p)
			end
		end
	end
	if #gathered == 0 then
		notify:FireClient(player, "No crew aboard Artemis yet — board first (E).")
		return
	end
	crew = gathered
	missionModel = complex.Artemis
	missionEngineFX = complex.ArtemisEngineFX
	missionResetCF = complex.ArtemisStart
	missionDest = "Moon" -- Artemis is the crewed Moon mission
	inFlight = true
	connectAborts()
	runMission()
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
	complex.ArtemisBoardPrompt.Triggered:Connect(onArtemisBoard)
	complex.ArtemisLaunchPrompt.Triggered:Connect(onArtemisLaunch)

	rescue.OnServerEvent:Connect(function(player: Player)
		LaunchSystem.requestRescue(player)
	end)

	Players.PlayerAdded:Connect(updateArtemisSign)
	Players.PlayerRemoving:Connect(updateArtemisSign)
	updateArtemisSign()
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
