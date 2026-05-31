--!strict
-- Builds the launch complex AND the orbit scene out of Parts at runtime, so the
-- whole environment lives in version control. The rocket is an original two-stage
-- orbital design (engine cluster, grid fins, interstage, second stage, fairing).
-- Swap these placeholders for nicer models in Studio later — systems only need the
-- named references back.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

export type Complex = {
	Model: Model,
	Rocket: Model,
	RocketSeat: Seat,
	RocketStart: CFrame,
	BoardPrompt: ProximityPrompt,
	EngineFX: BasePart,
	SuitStation: BasePart,
	SuitPrompt: ProximityPrompt,
	OrbitSeat: Seat,
	OrbitReturnPrompt: ProximityPrompt,
	Satellite: Model,
	DescentRig: Model,
	DescentSeat: Seat,
	DescentStart: CFrame,
	DescentParked: CFrame,
	SurfaceGround: BasePart,
	SurfaceSpawn: CFrame,
	Rover: Model,
	RoverSeat: VehicleSeat,
	RoverDrivePrompt: ProximityPrompt,
	SurfaceReturnPrompt: ProximityPrompt,
	FlightConsole: BasePart,
	FlightLabel: TextLabel,
	FlightCyclePrompt: ProximityPrompt,
	Crawler: Model,
	RocketVAB: CFrame,
	CrawlerVAB: CFrame,
	CrawlerPad: CFrame,
	RolloutPrompt: ProximityPrompt,
	MonitorLabel: TextLabel,
	OrbitDeck: BasePart,
	Artemis: Model,
	ArtemisSeats: { Seat },
	ArtemisBoardPrompt: ProximityPrompt,
	ArtemisLaunchPrompt: ProximityPrompt,
	ArtemisEngineFX: BasePart,
	ArtemisStart: CFrame,
	ArtemisSign: TextLabel,
	BoostersPrompt: ProximityPrompt,
	PayloadPrompt: ProximityPrompt,
	BuildLabel: TextLabel,
	TelemetryLabel: TextLabel,
	ElevatorPrompt: ProximityPrompt,
	CrewArmTop: CFrame,
}

local CONCRETE = Color3.fromRGB(150, 150, 158)
local WHITE = Color3.fromRGB(240, 242, 248)
local DARK = Color3.fromRGB(45, 48, 58)
local GREY = Color3.fromRGB(90, 92, 100)
local NOZZLE = Color3.fromRGB(70, 72, 80)
local ACCENT = Color3.fromRGB(70, 130, 220)

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder (Roblox cylinders run along their X axis, so we stand them up).
local function vcyl(parent: Instance, name: string, x: number, z: number, y: number, height: number, dia: number, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, dia, dia),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

local function block(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	return part(parent, {
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CFrame = cframe,
	})
end

-- Hollow, enterable building: floor, roof, 3 solid walls, and a 4th wall with a
-- doorway gap. doorFacing = 1 puts the door on the +Z side, -1 on the -Z side.
local function buildHall(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material, doorW: number, doorH: number, doorFacing: number)
	local hw, hh, hd = size.X / 2, size.Y / 2, size.Z / 2
	local t = 1
	part(parent, { Name = name .. "Floor", Size = Vector3.new(size.X, t, size.Z), Position = center + Vector3.new(0, -hh + t / 2, 0), Color = color, Material = material })
	part(parent, { Name = name .. "Roof", Size = Vector3.new(size.X, t, size.Z), Position = center + Vector3.new(0, hh - t / 2, 0), Color = color, Material = material })
	part(parent, { Name = name .. "Wall", Size = Vector3.new(t, size.Y, size.Z), Position = center + Vector3.new(-hw + t / 2, 0, 0), Color = color, Material = material })
	part(parent, { Name = name .. "Wall", Size = Vector3.new(t, size.Y, size.Z), Position = center + Vector3.new(hw - t / 2, 0, 0), Color = color, Material = material })
	-- Solid wall opposite the door.
	part(parent, { Name = name .. "Wall", Size = Vector3.new(size.X, size.Y, t), Position = center + Vector3.new(0, 0, -doorFacing * (hd - t / 2)), Color = color, Material = material })
	-- Door wall: two side segments + a lintel over the gap.
	local sideW = (size.X - doorW) / 2
	local doorZ = center.Z + doorFacing * (hd - t / 2)
	part(parent, { Name = name .. "Wall", Size = Vector3.new(sideW, size.Y, t), Position = Vector3.new(center.X - (doorW / 2 + sideW / 2), center.Y, doorZ), Color = color, Material = material })
	part(parent, { Name = name .. "Wall", Size = Vector3.new(sideW, size.Y, t), Position = Vector3.new(center.X + (doorW / 2 + sideW / 2), center.Y, doorZ), Color = color, Material = material })
	part(parent, { Name = name .. "Lintel", Size = Vector3.new(doorW, size.Y - doorH, t), Position = Vector3.new(center.X, center.Y + hh - (size.Y - doorH) / 2, doorZ), Color = color, Material = material })
end

local function nameTag(adornee: BasePart, text: string, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.new(0, 280, 0, 54)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 600

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = bb

	bb.Adornee = adornee
	bb.Parent = adornee
end

local function buildRocket(parent: Instance, base: Vector3): (Model, Seat, ProximityPrompt, BasePart)
	local bx, bz = base.X, base.Z
	local rocket = Instance.new("Model")
	rocket.Name = "Rocket"

	-- First stage + engine skirt + accent stripe
	vcyl(rocket, "Stage1", bx, bz, base.Y + 16, 30, 7, WHITE)
	vcyl(rocket, "EngineSkirt", bx, bz, base.Y + 2.5, 3, 7.3, DARK)
	vcyl(rocket, "Stripe", bx, bz, base.Y + 23, 1.5, 7.12, ACCENT)

	-- Engine nozzles (centre + ring of four)
	vcyl(rocket, "Nozzle", bx, bz, base.Y + 2.2, 2.4, 1.8, NOZZLE)
	for i = 0, 3 do
		local a = math.rad(i * 90)
		vcyl(rocket, "Nozzle", bx + math.cos(a) * 2, bz + math.sin(a) * 2, base.Y + 2.2, 2.4, 1.6, NOZZLE)
	end

	-- Base fins
	for i = 0, 3 do
		local a = math.rad(i * 90)
		block(rocket, "Fin", CFrame.new(bx + math.cos(a) * 3.6, base.Y + 4.5, bz + math.sin(a) * 3.6) * CFrame.Angles(0, -a, 0), Vector3.new(0.6, 7, 3), DARK)
	end

	-- Grid fins near the top of the first stage
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		block(rocket, "GridFin", CFrame.new(bx + math.cos(a) * 3.8, base.Y + 26, bz + math.sin(a) * 3.8) * CFrame.Angles(0, -a, 0), Vector3.new(0.3, 2.6, 2.6), GREY)
	end

	-- Interstage + second stage
	vcyl(rocket, "Interstage", bx, bz, base.Y + 32, 2, 7, DARK)
	vcyl(rocket, "Stage2", bx, bz, base.Y + 38, 10, 6.4, WHITE)

	-- Crew capsule on top (you ride inside it), with a side hatch + launch-escape spire.
	vcyl(rocket, "CrewCapsule", bx, bz, base.Y + 44, 4, 6.5, Color3.fromRGB(235, 238, 244))
	part(rocket, {
		Name = "CapsuleDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.5, 6.5, 6.5),
		Color = Color3.fromRGB(235, 238, 244),
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(bx, base.Y + 47.5, bz),
	})
	part(rocket, {
		Name = "CapsuleWindow",
		Size = Vector3.new(0.3, 1.6, 1.6),
		Color = Color3.fromRGB(40, 60, 95),
		Material = Enum.Material.Glass,
		CFrame = CFrame.new(bx + 3.3, base.Y + 45, bz),
	})
	local hatch = part(rocket, {
		Name = "Hatch",
		Size = Vector3.new(0.4, 3.2, 3.2),
		Color = Color3.fromRGB(120, 140, 170),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(bx - 3.3, base.Y + 44, bz),
	})
	vcyl(rocket, "EscapeTower", bx, bz, base.Y + 52, 7, 0.8, Color3.fromRGB(200, 80, 60))

	-- Pilot seat inside the capsule.
	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Anchored = true
	seat.CanCollide = false
	seat.Transparency = 1
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(bx, base.Y + 44, bz)
	seat.Parent = rocket

	-- "Enter Capsule" hatch prompt (reached from the crew access arm).
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.Name = "BoardPrompt"
	boardPrompt.ActionText = "Enter Capsule"
	boardPrompt.ObjectText = "Crew Capsule"
	boardPrompt.HoldDuration = 0.5
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.MaxActivationDistance = 10
	boardPrompt.Parent = hatch

	-- Engine effects host at the very base
	local engineFX = part(rocket, {
		Name = "EngineFX",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(bx, base.Y + 0.6, bz),
	})

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Enabled = false
	flame.EmissionDirection = Enum.NormalId.Bottom
	flame.Rate = 140
	flame.Lifetime = NumberRange.new(0.3, 0.7)
	flame.Speed = NumberRange.new(25, 45)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.LightEmission = 1
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 90, 25))
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	flame.Parent = engineFX

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Enabled = false
	smoke.EmissionDirection = Enum.NormalId.Bottom
	smoke.Rate = 70
	smoke.Lifetime = NumberRange.new(1, 2)
	smoke.Speed = NumberRange.new(12, 22)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Color = ColorSequence.new(Color3.fromRGB(225, 225, 225))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 11) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = engineFX

	local light = Instance.new("PointLight")
	light.Name = "EngineLight"
	light.Enabled = false
	light.Brightness = 6
	light.Range = 32
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Parent = engineFX

	-- Axis-aligned root so the rocket builder can attach boosters at clean offsets.
	local root = part(rocket, {
		Name = "Root",
		Size = Vector3.new(2, 2, 2),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(bx, base.Y, bz),
	})
	rocket.PrimaryPart = root
	rocket.Parent = parent
	return rocket, seat, boardPrompt, engineFX
end

-- Rebuilds the strap-on boosters + payload colour from the rocket's attributes.
function WorldBuilder.applyRocketBuild(rocket: Model)
	local root = rocket:FindFirstChild("Root") :: BasePart?
	if not root then
		return
	end
	for _, d in rocket:GetChildren() do
		if d:IsA("BasePart") and d.Name == "BuiltBooster" then
			d:Destroy()
		end
	end

	local boosters = rocket:GetAttribute("Boosters") or 0
	local angles = {}
	if boosters == 2 then
		angles = { 0, 180 }
	elseif boosters == 4 then
		angles = { 0, 90, 180, 270 }
	end
	for _, deg in angles do
		local a = math.rad(deg)
		part(rocket, {
			Name = "BuiltBooster",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(24, 4, 4),
			Color = WHITE,
			Material = Enum.Material.SmoothPlastic,
			CFrame = root.CFrame * CFrame.new(math.cos(a) * 5.4, 14, math.sin(a) * 5.4) * CFrame.Angles(0, 0, math.rad(90)),
		})
		part(rocket, {
			Name = "BuiltBooster",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Color = Color3.fromRGB(210, 80, 60),
			Material = Enum.Material.SmoothPlastic,
			CFrame = root.CFrame * CFrame.new(math.cos(a) * 5.4, 26.5, math.sin(a) * 5.4),
		})
	end

	local payload = rocket:GetAttribute("Payload") or "Rover"
	local cap = rocket:FindFirstChild("CrewCapsule") :: BasePart?
	if cap then
		cap.Color = if payload == "Satellite"
			then Color3.fromRGB(188, 194, 205)
			elseif payload == "Crew" then Color3.fromRGB(235, 238, 244)
			else Color3.fromRGB(220, 200, 80)
	end
end

local function buildOrbitScene(parent: Instance, center: Vector3): (Seat, ProximityPrompt, Model, BasePart)
	local cx, cy, cz = center.X, center.Y, center.Z
	local earthCenter = Vector3.new(cx, cy - 520, cz)

	part(parent, {
		Name = "Earth",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(700, 700, 700),
		Position = earthCenter,
		Color = Color3.fromRGB(38, 86, 162),
		Material = Enum.Material.SmoothPlastic,
	})
	part(parent, {
		Name = "Atmosphere",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(744, 744, 744),
		Position = earthCenter,
		Color = Color3.fromRGB(135, 180, 255),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.62,
		CanCollide = false,
	})

	local dirs = {
		Vector3.new(1, 0.35, 0.2),
		Vector3.new(-0.6, 0.5, 0.5),
		Vector3.new(0.2, -0.45, 0.85),
		Vector3.new(-0.35, -0.6, -0.55),
		Vector3.new(0.55, 0.25, -0.75),
	}
	for i, d in dirs do
		local size = 150 + i * 12
		part(parent, {
			Name = "Continent",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = earthCenter + d.Unit * 330,
			Color = Color3.fromRGB(72, 148, 84),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	-- Re-entry capsule the player rides in orbit
	vcyl(parent, "Capsule", cx, cz, cy, 3, 7, Color3.fromRGB(205, 210, 218))
	part(parent, {
		Name = "CapsuleDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(cx, cy + 2.4, cz),
		Color = Color3.fromRGB(205, 210, 218),
		Material = Enum.Material.SmoothPlastic,
	})

	local orbitSeat = Instance.new("Seat")
	orbitSeat.Name = "OrbitSeat"
	orbitSeat.Anchored = true
	orbitSeat.CanCollide = false
	orbitSeat.Transparency = 1
	orbitSeat.Size = Vector3.new(3, 1, 3)
	orbitSeat.CFrame = CFrame.new(cx, cy + 0.5, cz)
	orbitSeat.Parent = parent

	local capsulePart = parent:FindFirstChild("Capsule") :: BasePart
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.Name = "OrbitReturnPrompt"
	returnPrompt.ActionText = "Return to Earth"
	returnPrompt.ObjectText = "Re-entry Capsule"
	returnPrompt.HoldDuration = 1
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.MaxActivationDistance = 18
	returnPrompt.Parent = capsulePart

	-- Pre-placed satellite (scenery); player-deployed ones are spawned at runtime.
	local satellite = WorldBuilder.makeSatellite(Vector3.new(cx + 26, cy + 5, cz))

	-- Standing deck for extra crew members (the lone OrbitSeat only seats one).
	local deck = part(parent, {
		Name = "OrbitDeck",
		Size = Vector3.new(16, 1, 16),
		Position = Vector3.new(cx, cy - 1, cz),
		Color = Color3.fromRGB(70, 74, 82),
		Material = Enum.Material.DiamondPlate,
	})

	return orbitSeat, returnPrompt, satellite, deck
end

local function buildDescentRig(parent: Instance, base: Vector3): (Model, Seat)
	local bx, bz = base.X, base.Z
	local rig = Instance.new("Model")
	rig.Name = "DescentRig"

	-- Axis-aligned root so we can re-orient the rig safely while descending.
	local root = part(rig, {
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(bx, base.Y + 2, bz),
	})

	vcyl(rig, "Capsule", bx, bz, base.Y + 1.5, 3, 7, Color3.fromRGB(60, 64, 72))
	vcyl(rig, "Shield", bx, bz, base.Y + 0.2, 0.8, 7.4, Color3.fromRGB(34, 31, 29))
	part(rig, {
		Name = "CapsuleDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(bx, base.Y + 3.9, bz),
		Color = Color3.fromRGB(70, 74, 82),
		Material = Enum.Material.SmoothPlastic,
	})

	local seat = Instance.new("Seat")
	seat.Name = "DescentSeat"
	seat.Anchored = true
	seat.CanCollide = false
	seat.Transparency = 1
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(bx, base.Y + 2, bz)
	seat.Parent = rig

	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	chute.Parent = rig

	local canopy = part(chute, {
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(46, 18, 46),
		Position = Vector3.new(bx, base.Y + 34, bz),
		Color = Color3.fromRGB(232, 96, 52),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Transparency = 0.05,
	})
	canopy:SetAttribute("Vis", 0.05)

	for i = 0, 5 do
		local a = math.rad(i * 60)
		local rim = Vector3.new(bx + math.cos(a) * 19, base.Y + 30, bz + math.sin(a) * 19)
		local cap = Vector3.new(bx + math.cos(a) * 2.5, base.Y + 6, bz + math.sin(a) * 2.5)
		local mid = (rim + cap) / 2
		local line = part(chute, {
			Name = "Line",
			Size = Vector3.new(0.18, 0.18, (rim - cap).Magnitude),
			Color = Color3.fromRGB(240, 240, 245),
			CanCollide = false,
			CFrame = CFrame.lookAt(mid, cap),
		})
		line:SetAttribute("Vis", 0)
	end

	rig.PrimaryPart = root
	rig.Parent = parent
	return rig, seat
end

local function buildRover(parent: Instance, position: Vector3): (Model, VehicleSeat, ProximityPrompt)
	local p = position
	local rover = Instance.new("Model")
	rover.Name = "Rover"

	local chassis = part(rover, {
		Name = "Chassis",
		Size = Vector3.new(6, 1.4, 9),
		Position = p,
		Color = Color3.fromRGB(220, 200, 80),
		Material = Enum.Material.Metal,
	})
	part(rover, {
		Name = "Body",
		Size = Vector3.new(5, 1.6, 5),
		Position = p + Vector3.new(0, 1.4, -1.2),
		Color = Color3.fromRGB(235, 238, 244),
	})
	part(rover, {
		Name = "Solar",
		Size = Vector3.new(5.4, 0.2, 4),
		Position = p + Vector3.new(0, 2.3, -1.2),
		Color = Color3.fromRGB(40, 60, 120),
	})

	for i = 0, 3 do
		local wx = if i % 2 == 0 then 3.2 else -3.2
		local wz = if i < 2 then 3 else -3
		part(rover, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 3, 3),
			Color = Color3.fromRGB(40, 42, 48),
			CFrame = CFrame.new(p.X + wx, p.Y - 0.6, p.Z + wz),
		})
	end

	vcyl(rover, "Mast", p.X - 1.6, p.Z - 1.2, p.Y + 2.8, 2.4, 0.3, Color3.fromRGB(120, 122, 130))

	local seat = Instance.new("VehicleSeat")
	seat.Name = "RoverSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(3, 1, 3)
	seat.Position = p + Vector3.new(0, 1.5, 1.6)
	seat.Color = Color3.fromRGB(55, 58, 68)
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Parent = rover

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RoverDrivePrompt"
	prompt.ActionText = "Drive Rover"
	prompt.ObjectText = "Rover"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = chassis

	rover.PrimaryPart = chassis
	rover.Parent = parent
	return rover, seat, prompt
end

local function buildSurface(parent: Instance, center: Vector3): (BasePart, CFrame, Model, VehicleSeat, ProximityPrompt, ProximityPrompt)
	local cx, cy, cz = center.X, center.Y, center.Z

	local ground = part(parent, {
		Name = "SurfaceGround",
		Size = Vector3.new(1200, 4, 1200),
		Position = Vector3.new(cx, cy - 2, cz),
		Color = Color3.fromRGB(132, 132, 138),
		Material = Enum.Material.Sand,
	})

	local spots = {
		Vector3.new(40, 30), Vector3.new(-50, 60), Vector3.new(70, -40),
		Vector3.new(-30, -70), Vector3.new(95, 55), Vector3.new(-80, -20),
	}
	for i, s in spots do
		local r = 4 + (i % 3) * 3
		part(parent, {
			Name = "Rock",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(r * 2, r * 2, r * 2),
			Position = Vector3.new(cx + s.X, cy + r * 0.4, cz + s.Y),
			Color = Color3.fromRGB(110, 110, 116),
			Material = Enum.Material.Slate,
		})
	end

	part(parent, {
		Name = "BaseHab",
		Size = Vector3.new(16, 8, 12),
		Position = Vector3.new(cx - 34, cy + 4, cz - 22),
		Color = Color3.fromRGB(225, 228, 235),
		Material = Enum.Material.Metal,
	})
	part(parent, {
		Name = "BaseDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(26, 26, 26),
		Position = Vector3.new(cx - 16, cy + 3, cz - 22),
		Color = Color3.fromRGB(205, 212, 222),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})

	-- Lander / ascent stage (carries you home)
	local landerPos = Vector3.new(cx, cy, cz - 6)
	part(parent, {
		Name = "LanderBase",
		Size = Vector3.new(9, 4, 9),
		Position = landerPos + Vector3.new(0, 3, 0),
		Color = Color3.fromRGB(184, 150, 60),
		Material = Enum.Material.Metal,
	})
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		block(parent, "LanderLeg", CFrame.new(cx + math.cos(a) * 6, cy + 1.5, cz - 6 + math.sin(a) * 6) * CFrame.Angles(math.rad(20), -a, 0), Vector3.new(0.6, 6, 0.6), Color3.fromRGB(90, 92, 100))
	end
	local landerCap = part(parent, {
		Name = "LanderCapsule",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Position = landerPos + Vector3.new(0, 7, 0),
		Color = Color3.fromRGB(200, 205, 212),
		Material = Enum.Material.SmoothPlastic,
	})
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.Name = "SurfaceReturnPrompt"
	returnPrompt.ActionText = "Return to Earth"
	returnPrompt.ObjectText = "Ascent Stage"
	returnPrompt.HoldDuration = 1
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.MaxActivationDistance = 14
	returnPrompt.Parent = landerCap

	local rover, roverSeat, drivePrompt = buildRover(parent, Vector3.new(cx + 16, cy + 2.1, cz + 6))
	local spawnCF = CFrame.new(Vector3.new(cx + 6, cy + 4, cz + 8), Vector3.new(cx + 16, cy + 2, cz + 6))

	return ground, spawnCF, rover, roverSeat, drivePrompt, returnPrompt
end

function WorldBuilder.makeSatellite(position: Vector3): Model
	local satellite = Instance.new("Model")
	satellite.Name = "Satellite"
	local satBody = part(satellite, {
		Name = "Body",
		Size = Vector3.new(3, 3, 4),
		Position = position,
		Color = Color3.fromRGB(188, 194, 205),
		Material = Enum.Material.Metal,
	})
	part(satellite, {
		Name = "Panel",
		Size = Vector3.new(10, 0.2, 4),
		Position = position + Vector3.new(6.5, 0, 0),
		Color = Color3.fromRGB(40, 60, 120),
	})
	part(satellite, {
		Name = "Panel",
		Size = Vector3.new(10, 0.2, 4),
		Position = position - Vector3.new(6.5, 0, 0),
		Color = Color3.fromRGB(40, 60, 120),
	})
	vcyl(satellite, "Mast", position.X, position.Z, position.Y + 3.2, 3, 0.4, GREY)
	part(satellite, {
		Name = "Dish",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = position + Vector3.new(0, 4.6, 0),
		Color = Color3.fromRGB(220, 222, 228),
	})
	satellite.PrimaryPart = satBody
	satellite.Parent = Workspace
	return satellite
end

local function buildCrawler(parent: Instance, pos: Vector3): Model
	local crawler = Instance.new("Model")
	crawler.Name = "Crawler"
	local deck = part(crawler, {
		Name = "Deck",
		Size = Vector3.new(20, 1.2, 26),
		Position = pos,
		Color = Color3.fromRGB(70, 72, 80),
		Material = Enum.Material.DiamondPlate,
	})
	for _, x in { -8, 8 } do
		part(crawler, {
			Name = "Tread",
			Size = Vector3.new(3, 1.8, 26),
			Position = pos + Vector3.new(x, -0.5, 0),
			Color = Color3.fromRGB(34, 36, 42),
			Material = Enum.Material.Metal,
		})
	end
	crawler.PrimaryPart = deck
	crawler.Parent = parent
	return crawler
end

local function buildArtemis(parent: Instance, base: Vector3): (Model, { Seat }, ProximityPrompt, ProximityPrompt, BasePart, TextLabel)
	local bx, bz = base.X, base.Z
	local artemis = Instance.new("Model")
	artemis.Name = "Artemis"
	local ORANGE = Color3.fromRGB(196, 98, 40)

	-- Core stage + skirt + engine cluster
	vcyl(artemis, "Core", bx, bz, base.Y + 17, 34, 8, ORANGE)
	vcyl(artemis, "CoreSkirt", bx, bz, base.Y + 2.5, 3, 8.3, DARK)
	for i = 0, 3 do
		local a = math.rad(i * 90)
		vcyl(artemis, "Nozzle", bx + math.cos(a) * 2.2, bz + math.sin(a) * 2.2, base.Y + 2, 2.6, 1.8, NOZZLE)
	end

	-- Two solid boosters
	for _, sx in { -6.4, 6.4 } do
		vcyl(artemis, "Booster", bx + sx, bz, base.Y + 14, 28, 4, WHITE)
		vcyl(artemis, "BoosterNose", bx + sx, bz, base.Y + 29.5, 3, 4, Color3.fromRGB(210, 80, 60))
		vcyl(artemis, "BoosterNozzle", bx + sx, bz, base.Y + 1.6, 2, 2.8, NOZZLE)
	end

	-- Service module + tapered Orion-style capsule
	vcyl(artemis, "Service", bx, bz, base.Y + 36, 4, 7, Color3.fromRGB(150, 152, 160))
	local capBase = vcyl(artemis, "Capsule", bx, bz, base.Y + 40, 4, 7.6, WHITE)
	vcyl(artemis, "Capsule", bx, bz, base.Y + 43, 2.5, 5.4, WHITE)
	vcyl(artemis, "Capsule", bx, bz, base.Y + 45, 1.5, 3.4, WHITE)
	part(artemis, {
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3.4, 3.4),
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(bx, base.Y + 46.4, bz),
	})

	-- Four crew seats inside the capsule
	local seats: { Seat } = {}
	for i = 0, 3 do
		local ox = if i % 2 == 0 then -1.6 else 1.6
		local oz = if i < 2 then -1.6 else 1.6
		local s = Instance.new("Seat")
		s.Name = "ArtemisSeat"
		s.Anchored = true
		s.CanCollide = false
		s.Transparency = 1
		s.Size = Vector3.new(2.2, 1, 2.2)
		s.CFrame = CFrame.new(bx + ox, base.Y + 39, bz + oz)
		s.Parent = artemis
		table.insert(seats, s)
	end

	-- Engine effects
	local engineFX = part(artemis, {
		Name = "EngineFX",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(bx, base.Y + 0.6, bz),
	})
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Enabled = false
	flame.EmissionDirection = Enum.NormalId.Bottom
	flame.Rate = 200
	flame.Lifetime = NumberRange.new(0.3, 0.8)
	flame.Speed = NumberRange.new(30, 55)
	flame.SpreadAngle = Vector2.new(14, 14)
	flame.LightEmission = 1
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 90, 25))
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	flame.Parent = engineFX
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Enabled = false
	smoke.EmissionDirection = Enum.NormalId.Bottom
	smoke.Rate = 90
	smoke.Lifetime = NumberRange.new(1, 2.2)
	smoke.Speed = NumberRange.new(14, 26)
	smoke.SpreadAngle = Vector2.new(28, 28)
	smoke.Color = ColorSequence.new(Color3.fromRGB(225, 225, 225))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 14) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = engineFX
	local light = Instance.new("PointLight")
	light.Name = "EngineLight"
	light.Enabled = false
	light.Brightness = 7
	light.Range = 40
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Parent = engineFX

	-- Board low on the skirt; LAUNCH up by the crew seats (only seated crew can reach it).
	local skirt = artemis:FindFirstChild("CoreSkirt") :: BasePart
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.Name = "ArtemisBoardPrompt"
	boardPrompt.ActionText = "Board Artemis"
	boardPrompt.ObjectText = "Artemis — crew of 4"
	boardPrompt.HoldDuration = 0.4
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.MaxActivationDistance = 16
	boardPrompt.KeyboardKeyCode = Enum.KeyCode.E
	boardPrompt.Parent = skirt

	local launchPrompt = Instance.new("ProximityPrompt")
	launchPrompt.Name = "ArtemisLaunchPrompt"
	launchPrompt.ActionText = "LAUNCH Crew"
	launchPrompt.ObjectText = "Artemis"
	launchPrompt.HoldDuration = 1
	launchPrompt.RequiresLineOfSight = false
	launchPrompt.MaxActivationDistance = 12
	launchPrompt.KeyboardKeyCode = Enum.KeyCode.G
	launchPrompt.Parent = capBase

	local signGui = Instance.new("BillboardGui")
	signGui.Name = "ArtemisSign"
	signGui.Size = UDim2.new(0, 360, 0, 50)
	signGui.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	signGui.AlwaysOnTop = true
	signGui.MaxDistance = 450
	signGui.Adornee = capBase
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.TextScaled = true
	signLabel.Text = "ARTEMIS"
	signLabel.Parent = signGui
	signGui.Parent = capBase

	artemis.PrimaryPart = artemis:FindFirstChild("Core") :: BasePart
	artemis.Parent = parent
	return artemis, seats, boardPrompt, launchPrompt, engineFX, signLabel
end

function WorldBuilder.makeBoat(position: Vector3): Model
	local boat = Instance.new("Model")
	boat.Name = "RescueBoat"
	local hull = part(boat, {
		Name = "Hull",
		Size = Vector3.new(12, 2.5, 5),
		Position = position,
		Color = Color3.fromRGB(185, 60, 55),
		Material = Enum.Material.SmoothPlastic,
	})
	part(boat, {
		Name = "Deck",
		Size = Vector3.new(12, 0.4, 5),
		Position = position + Vector3.new(0, 1.45, 0),
		Color = Color3.fromRGB(220, 222, 228),
	})
	part(boat, {
		Name = "Cabin",
		Size = Vector3.new(4, 2.6, 4),
		Position = position + Vector3.new(-2.5, 2.8, 0),
		Color = Color3.fromRGB(236, 238, 244),
	})
	part(boat, {
		Name = "Beacon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		Position = position + Vector3.new(-2.5, 4.3, 0),
		Color = Color3.fromRGB(255, 90, 60),
		Material = Enum.Material.Neon,
	})
	boat.PrimaryPart = hull
	boat.Parent = Workspace
	return boat
end

local function setupScenery()
	-- Florida-afternoon lighting with atmosphere, bloom and sun rays for realism.
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.ExposureCompensation = 0.15
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 165)
	Lighting.GeographicLatitude = 28.5

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmos = Instance.new("Atmosphere")
		atmos.Density = 0.34
		atmos.Haze = 1.4
		atmos.Glare = 0.2
		atmos.Color = Color3.fromRGB(199, 207, 217)
		atmos.Decay = Color3.fromRGB(150, 170, 200)
		atmos.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 24
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("SunRaysEffect") then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.12
		rays.Spread = 0.6
		rays.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Contrast = 0.08
		cc.Saturation = 0.08
		cc.Parent = Lighting
	end

	-- Make the static baseplate look like real grass.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(86, 122, 74)
	end
end

function WorldBuilder.build(): Complex
	setupScenery()

	local model = Instance.new("Model")
	model.Name = "SpaceMan"
	model.Parent = Workspace

	-- Ground + spawn are static in the place (see default.project.json) so they show
	-- in Studio's Edit view too; the rest of the complex is generated here on Play.
	-- Suit-up room (enterable). Walk in the front door and use the console to suit up.
	local suitCenter = Vector3.new(20, 6, 64)
	buildHall(model, "Suit", suitCenter, Vector3.new(16, 12, 12), Color3.fromRGB(214, 217, 224), Enum.Material.Concrete, 5, 8, 1)
	local suitStation = part(model, {
		Name = "SuitStation",
		Size = Vector3.new(17, 1, 13),
		Position = suitCenter + Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(150, 152, 160),
		Material = Enum.Material.Concrete,
	})
	nameTag(suitStation, "🧑‍🚀 SUIT-UP ROOM", 3)
	local suitConsole = part(model, {
		Name = "SuitConsole",
		Size = Vector3.new(4, 3, 1.5),
		Position = suitCenter + Vector3.new(0, -4, -4),
		Color = Color3.fromRGB(40, 60, 90),
		Material = Enum.Material.Metal,
	})
	local suitPrompt = Instance.new("ProximityPrompt")
	suitPrompt.Name = "SuitPrompt"
	suitPrompt.ActionText = "Put on Space Suit"
	suitPrompt.ObjectText = "Suit-Up Room"
	suitPrompt.HoldDuration = 1
	suitPrompt.RequiresLineOfSight = false
	suitPrompt.MaxActivationDistance = Config.Suit.PromptDistance
	suitPrompt.Parent = suitConsole

	-- Vehicle Assembly Building (enterable). Big high-bay door faces the pad (-Z).
	local vabCenter = Vector3.new(0, 28, 40)
	buildHall(model, "VAB", vabCenter, Vector3.new(34, 56, 34), WHITE, Enum.Material.Concrete, 16, 34, -1)
	local vabCore = part(model, { Name = "VehicleAssemblyBuilding", Size = Vector3.new(1, 1, 1), Position = vabCenter + Vector3.new(0, 30, 0), Transparency = 1, CanCollide = false })
	nameTag(vabCore, "VEHICLE ASSEMBLY", 4)
	-- Ground console by the VAB's pad-facing door for the rollout prompt.
	local vab = part(model, { Name = "VABConsole", Size = Vector3.new(4, 3, 1.5), Position = Vector3.new(0, 1.5, 21), Color = DARK, Material = Enum.Material.Metal })
	-- Tall vertical "high-bay door" stripes + a top band so it reads like a real VAB.
	for i = -1, 2 do
		part(model, {
			Name = "VABStripe",
			Size = Vector3.new(5, 46, 0.6),
			Position = Vector3.new(i * 8 - 4, 24, 57.3),
			Color = Color3.fromRGB(70, 76, 92),
			Material = Enum.Material.Metal,
		})
	end
	part(model, {
		Name = "VABBand",
		Size = Vector3.new(34.6, 4, 34.6),
		Position = Vector3.new(0, 50, 40),
		Color = ACCENT,
		Material = Enum.Material.Metal,
	})

	-- Mission Control (enterable). Walk in the north door; screens are on the east wall.
	local mcCenter = Vector3.new(-56, 7, 20)
	buildHall(model, "MC", mcCenter, Vector3.new(30, 14, 22), Color3.fromRGB(208, 210, 216), Enum.Material.Concrete, 6, 9, 1)
	local mc = part(model, { Name = "MissionControl", Size = Vector3.new(1, 1, 1), Position = mcCenter + Vector3.new(0, 8, 0), Transparency = 1, CanCollide = false })
	nameTag(mc, "MISSION CONTROL", 2)

	part(model, {
		Name = "Crawlerway",
		Size = Vector3.new(16, 0.3, 112),
		Position = Vector3.new(0, 0.15, -16),
		Color = Color3.fromRGB(120, 110, 95),
		Material = Enum.Material.Ground,
	})

	local padCenter = Vector3.new(0, 0.5, -72)
	part(model, {
		Name = "LaunchPad",
		Size = Vector3.new(40, 1, 40),
		Position = padCenter,
		Color = DARK,
		Material = Enum.Material.Slate,
	})

	-- Fixed service tower (lattice) beside the pad.
	local towerX, towerZ = -13, -72
	for _, c in { Vector3.new(-3, 0, -3), Vector3.new(3, 0, -3), Vector3.new(-3, 0, 3), Vector3.new(3, 0, 3) } do
		part(model, {
			Name = "TowerLeg",
			Size = Vector3.new(1, 56, 1),
			Position = Vector3.new(towerX + c.X, 28, towerZ + c.Z),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	for level = 1, 6 do
		local y = level * 8
		part(model, { Name = "TowerBeam", Size = Vector3.new(7, 0.5, 0.5), Position = Vector3.new(towerX, y, towerZ - 3), Color = DARK, Material = Enum.Material.Metal })
		part(model, { Name = "TowerBeam", Size = Vector3.new(7, 0.5, 0.5), Position = Vector3.new(towerX, y, towerZ + 3), Color = DARK, Material = Enum.Material.Metal })
		part(model, { Name = "TowerBeam", Size = Vector3.new(0.5, 0.5, 7), Position = Vector3.new(towerX - 3, y, towerZ), Color = DARK, Material = Enum.Material.Metal })
		part(model, { Name = "TowerBeam", Size = Vector3.new(0.5, 0.5, 7), Position = Vector3.new(towerX + 3, y, towerZ), Color = DARK, Material = Enum.Material.Metal })
	end

	-- Crew access arm (walkway) from the tower to the capsule hatch, at capsule height.
	part(model, { Name = "CrewArm", Size = Vector3.new(11, 0.6, 3), Position = Vector3.new(-6.5, 44, towerZ), Color = Color3.fromRGB(150, 152, 160), Material = Enum.Material.Metal })
	part(model, { Name = "ArmRail", Size = Vector3.new(11, 1.4, 0.3), Position = Vector3.new(-6.5, 45, towerZ - 1.4), Color = ACCENT, Material = Enum.Material.Metal })
	part(model, { Name = "ArmRail", Size = Vector3.new(11, 1.4, 0.3), Position = Vector3.new(-6.5, 45, towerZ + 1.4), Color = ACCENT, Material = Enum.Material.Metal })

	-- Crew elevator at the tower base — ride it up to the access arm.
	local elevatorCar = part(model, { Name = "ElevatorCar", Size = Vector3.new(4, 5, 4), Position = Vector3.new(towerX, 3, towerZ), Color = Color3.fromRGB(90, 94, 104), Material = Enum.Material.Metal, Transparency = 0.15 })
	local elevatorPrompt = Instance.new("ProximityPrompt")
	elevatorPrompt.Name = "ElevatorPrompt"
	elevatorPrompt.ActionText = "Take Crew Elevator"
	elevatorPrompt.ObjectText = "Service Tower"
	elevatorPrompt.HoldDuration = 0.5
	elevatorPrompt.RequiresLineOfSight = false
	elevatorPrompt.MaxActivationDistance = 12
	elevatorPrompt.Parent = elevatorCar
	local crewArmTop = CFrame.lookAt(Vector3.new(towerX + 3, 45.5, towerZ), Vector3.new(0, 45.5, towerZ))

	-- Lightning masts around the pad.
	for _, m in { Vector3.new(-22, 0, -94), Vector3.new(22, 0, -94), Vector3.new(0, 0, -50) } do
		part(model, { Name = "LightningMast", Size = Vector3.new(1.5, 78, 1.5), Position = Vector3.new(m.X, 39, m.Z), Color = Color3.fromRGB(120, 122, 130), Material = Enum.Material.Metal })
		part(model, { Name = "MastTip", Shape = Enum.PartType.Ball, Size = Vector3.new(2.5, 2.5, 2.5), Position = Vector3.new(m.X, 79, m.Z), Color = Color3.fromRGB(200, 60, 50), Material = Enum.Material.Neon })
	end

	local rocket, seat, boardPrompt, engineFX = buildRocket(model, Vector3.new(padCenter.X, 1, padCenter.Z))
	local orbitSeat, orbitReturnPrompt, satellite, orbitDeck = buildOrbitScene(model, Config.Orbit.Center)

	-- Park the rocket at the VAB on a crawler-transporter; it rolls out to the pad later.
	local rocketPad = rocket:GetPivot()
	local rocketVAB = rocketPad + Vector3.new(0, 0, 90)
	rocket:PivotTo(rocketVAB)
	local crawler = buildCrawler(model, Vector3.new(0, 0.6, 18))
	local crawlerVAB = crawler:GetPivot()
	local crawlerPad = crawlerVAB + Vector3.new(0, 0, -90)

	-- Rocket builder: configure the parked rocket before rollout.
	rocket:SetAttribute("Boosters", 0)
	rocket:SetAttribute("Payload", "Rover")
	WorldBuilder.applyRocketBuild(rocket)

	local boostersConsole = part(model, { Name = "BoostersConsole", Size = Vector3.new(5, 3, 2), Position = Vector3.new(11, 1.5, 16), Color = Color3.fromRGB(44, 48, 58), Material = Enum.Material.Metal })
	local payloadConsole = part(model, { Name = "PayloadConsole", Size = Vector3.new(5, 3, 2), Position = Vector3.new(17, 1.5, 16), Color = Color3.fromRGB(44, 48, 58), Material = Enum.Material.Metal })

	local buildBillboard = Instance.new("BillboardGui")
	buildBillboard.Name = "BuildPlan"
	buildBillboard.Size = UDim2.new(0, 320, 0, 44)
	buildBillboard.StudsOffsetWorldSpace = Vector3.new(3, 3, 0)
	buildBillboard.AlwaysOnTop = true
	buildBillboard.MaxDistance = 100
	buildBillboard.Adornee = boostersConsole
	local buildLabel = Instance.new("TextLabel")
	buildLabel.Size = UDim2.fromScale(1, 1)
	buildLabel.BackgroundTransparency = 1
	buildLabel.Font = Enum.Font.GothamBold
	buildLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	buildLabel.TextStrokeTransparency = 0.4
	buildLabel.TextScaled = true
	buildLabel.Text = "🔧 Boosters: 0  |  Payload: Rover"
	buildLabel.Parent = buildBillboard
	buildBillboard.Parent = boostersConsole

	local boostersPrompt = Instance.new("ProximityPrompt")
	boostersPrompt.Name = "BoostersPrompt"
	boostersPrompt.ActionText = "Cycle Boosters"
	boostersPrompt.ObjectText = "Rocket Builder"
	boostersPrompt.HoldDuration = 0.3
	boostersPrompt.RequiresLineOfSight = false
	boostersPrompt.MaxActivationDistance = 10
	boostersPrompt.Parent = boostersConsole

	local payloadPrompt = Instance.new("ProximityPrompt")
	payloadPrompt.Name = "PayloadPrompt"
	payloadPrompt.ActionText = "Cycle Payload"
	payloadPrompt.ObjectText = "Rocket Builder"
	payloadPrompt.HoldDuration = 0.3
	payloadPrompt.RequiresLineOfSight = false
	payloadPrompt.MaxActivationDistance = 10
	payloadPrompt.Parent = payloadConsole

	-- Ocean east of the Cape. Prefer real terrain water; fall back to a water-coloured
	-- part if the place has no Terrain object (so this can never crash the build).
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		terrain:FillBlock(CFrame.new(Config.Ocean.Center), Config.Ocean.Size, Enum.Material.Water)
	else
		part(model, {
			Name = "Ocean",
			Size = Vector3.new(Config.Ocean.Size.X, 2, Config.Ocean.Size.Z),
			Position = Config.Ocean.Center + Vector3.new(0, 19, 0),
			Color = Color3.fromRGB(40, 96, 150),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
	end

	-- Re-entry capsule + parachute, parked underground until splashdown.
	local descentRig, descentSeat = buildDescentRig(model, Config.Splashdown.Point)
	local descentStart = CFrame.new(Config.Splashdown.Point.X, Config.Splashdown.StartHeight, Config.Splashdown.Point.Z)
	local descentParked = CFrame.new(Config.Splashdown.Point.X, -500, Config.Splashdown.Point.Z)
	descentRig:PivotTo(descentParked)

	-- Surface world (Moon / Mars, recoloured per destination) with the deployable rover.
	local surfaceGround, surfaceSpawn, rover, roverSeat, roverDrivePrompt, surfaceReturnPrompt =
		buildSurface(model, Config.Surface.Center)

	-- Second pad + the Artemis (crewed Moon rocket); unlocked in private servers.
	part(model, {
		Name = "ArtemisPad",
		Size = Vector3.new(40, 1, 40),
		Position = Vector3.new(90, 0.5, -72),
		Color = DARK,
		Material = Enum.Material.Slate,
	})
	local artemis, artemisSeats, artemisBoardPrompt, artemisLaunchPrompt, artemisEngineFX, artemisSign =
		buildArtemis(model, Vector3.new(90, 1, -72))
	local artemisStart = artemis:GetPivot()

	-- Flight-plan console near the pad to pick a destination.
	local flightConsole = part(model, {
		Name = "FlightConsole",
		Size = Vector3.new(6, 3, 2),
		Position = Vector3.new(-16, 1.5, 62),
		Color = Color3.fromRGB(40, 44, 54),
		Material = Enum.Material.Metal,
	})
	flightConsole:SetAttribute("Dest", "EarthOrbit")

	local flightBillboard = Instance.new("BillboardGui")
	flightBillboard.Name = "FlightPlan"
	flightBillboard.Size = UDim2.new(0, 240, 0, 40)
	flightBillboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	flightBillboard.AlwaysOnTop = true
	flightBillboard.MaxDistance = 90
	flightBillboard.Adornee = flightConsole

	local flightLabel = Instance.new("TextLabel")
	flightLabel.Size = UDim2.fromScale(1, 1)
	flightLabel.BackgroundTransparency = 1
	flightLabel.Font = Enum.Font.GothamBold
	flightLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	flightLabel.TextStrokeTransparency = 0.4
	flightLabel.TextScaled = true
	flightLabel.Text = "Destination: Earth Orbit"
	flightLabel.Parent = flightBillboard
	flightBillboard.Parent = flightConsole

	local flightCyclePrompt = Instance.new("ProximityPrompt")
	flightCyclePrompt.Name = "FlightCyclePrompt"
	flightCyclePrompt.ActionText = "Change Destination"
	flightCyclePrompt.ObjectText = "Flight Plan"
	flightCyclePrompt.HoldDuration = 0.3
	flightCyclePrompt.RequiresLineOfSight = false
	flightCyclePrompt.MaxActivationDistance = 10
	flightCyclePrompt.Parent = flightConsole

	-- Rollout prompt on the VAB (assemble + roll the rocket to the pad).
	local rolloutPrompt = Instance.new("ProximityPrompt")
	rolloutPrompt.Name = "RolloutPrompt"
	rolloutPrompt.ActionText = "Assemble & Roll Out Rocket"
	rolloutPrompt.ObjectText = "Vehicle Assembly Building"
	rolloutPrompt.HoldDuration = 0.5
	rolloutPrompt.RequiresLineOfSight = false
	rolloutPrompt.MaxActivationDistance = 20
	rolloutPrompt.Parent = vab

	-- Mission Control satellite-monitor screen (on the east face of the MC building).
	local screenPart = part(model, {
		Name = "MonitorScreen",
		Size = Vector3.new(0.4, 7, 12),
		Position = Vector3.new(-40.6, 8, 20),
		Color = Color3.fromRGB(8, 10, 16),
		Material = Enum.Material.SmoothPlastic,
	})
	local monitorGui = Instance.new("SurfaceGui")
	monitorGui.Name = "Monitor"
	monitorGui.Face = Enum.NormalId.Right
	monitorGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	monitorGui.PixelsPerStud = 50
	monitorGui.Parent = screenPart

	local monitorBg = Instance.new("Frame")
	monitorBg.Size = UDim2.fromScale(1, 1)
	monitorBg.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	monitorBg.BorderSizePixel = 0
	monitorBg.Parent = monitorGui

	local monitorTitle = Instance.new("TextLabel")
	monitorTitle.Size = UDim2.new(1, 0, 0, 64)
	monitorTitle.BackgroundTransparency = 1
	monitorTitle.Font = Enum.Font.GothamBold
	monitorTitle.TextColor3 = Color3.fromRGB(120, 210, 255)
	monitorTitle.TextScaled = true
	monitorTitle.Text = "🛰️ SATELLITE MONITOR"
	monitorTitle.Parent = monitorBg

	local monitorLabel = Instance.new("TextLabel")
	monitorLabel.Position = UDim2.new(0, 18, 0, 74)
	monitorLabel.Size = UDim2.new(1, -36, 1, -86)
	monitorLabel.BackgroundTransparency = 1
	monitorLabel.Font = Enum.Font.Code
	monitorLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
	monitorLabel.TextXAlignment = Enum.TextXAlignment.Left
	monitorLabel.TextYAlignment = Enum.TextYAlignment.Top
	monitorLabel.TextSize = 24
	monitorLabel.Text = "Initializing..."
	monitorLabel.Parent = monitorBg

	-- Mission Control launch-telemetry screen (next to the satellite monitor).
	local telemetryPart = part(model, {
		Name = "TelemetryScreen",
		Size = Vector3.new(0.4, 7, 12),
		Position = Vector3.new(-40.6, 8, 6),
		Color = Color3.fromRGB(8, 12, 16),
		Material = Enum.Material.SmoothPlastic,
	})
	local telemetryGui = Instance.new("SurfaceGui")
	telemetryGui.Name = "Telemetry"
	telemetryGui.Face = Enum.NormalId.Right
	telemetryGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	telemetryGui.PixelsPerStud = 50
	telemetryGui.Parent = telemetryPart
	local telemetryBg = Instance.new("Frame")
	telemetryBg.Size = UDim2.fromScale(1, 1)
	telemetryBg.BackgroundColor3 = Color3.fromRGB(8, 12, 16)
	telemetryBg.BorderSizePixel = 0
	telemetryBg.Parent = telemetryGui
	local telemetryTitle = Instance.new("TextLabel")
	telemetryTitle.Size = UDim2.new(1, 0, 0, 64)
	telemetryTitle.BackgroundTransparency = 1
	telemetryTitle.Font = Enum.Font.GothamBold
	telemetryTitle.TextColor3 = Color3.fromRGB(120, 210, 255)
	telemetryTitle.TextScaled = true
	telemetryTitle.Text = "🚀 LAUNCH CONTROL"
	telemetryTitle.Parent = telemetryBg
	local telemetryLabel = Instance.new("TextLabel")
	telemetryLabel.Position = UDim2.new(0, 18, 0, 74)
	telemetryLabel.Size = UDim2.new(1, -36, 1, -86)
	telemetryLabel.BackgroundTransparency = 1
	telemetryLabel.Font = Enum.Font.Code
	telemetryLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
	telemetryLabel.TextXAlignment = Enum.TextXAlignment.Left
	telemetryLabel.TextYAlignment = Enum.TextYAlignment.Top
	telemetryLabel.TextSize = 26
	telemetryLabel.Text = "Standing by."
	telemetryLabel.Parent = telemetryBg

	return {
		Model = model,
		Rocket = rocket,
		RocketSeat = seat,
		RocketStart = rocketPad,
		BoardPrompt = boardPrompt,
		EngineFX = engineFX,
		SuitStation = suitStation,
		SuitPrompt = suitPrompt,
		OrbitSeat = orbitSeat,
		OrbitReturnPrompt = orbitReturnPrompt,
		Satellite = satellite,
		DescentRig = descentRig,
		DescentSeat = descentSeat,
		DescentStart = descentStart,
		DescentParked = descentParked,
		SurfaceGround = surfaceGround,
		SurfaceSpawn = surfaceSpawn,
		Rover = rover,
		RoverSeat = roverSeat,
		RoverDrivePrompt = roverDrivePrompt,
		SurfaceReturnPrompt = surfaceReturnPrompt,
		FlightConsole = flightConsole,
		FlightLabel = flightLabel,
		FlightCyclePrompt = flightCyclePrompt,
		Crawler = crawler,
		RocketVAB = rocketVAB,
		CrawlerVAB = crawlerVAB,
		CrawlerPad = crawlerPad,
		RolloutPrompt = rolloutPrompt,
		MonitorLabel = monitorLabel,
		OrbitDeck = orbitDeck,
		Artemis = artemis,
		ArtemisSeats = artemisSeats,
		ArtemisBoardPrompt = artemisBoardPrompt,
		ArtemisLaunchPrompt = artemisLaunchPrompt,
		ArtemisEngineFX = artemisEngineFX,
		ArtemisStart = artemisStart,
		ArtemisSign = artemisSign,
		BoostersPrompt = boostersPrompt,
		PayloadPrompt = payloadPrompt,
		BuildLabel = buildLabel,
		TelemetryLabel = telemetryLabel,
		ElevatorPrompt = elevatorPrompt,
		CrewArmTop = crewArmTop,
	}
end

return WorldBuilder
