--!strict
-- Builds the launch complex AND the orbit scene out of Parts at runtime, so the
-- whole environment lives in version control. The rocket is an original two-stage
-- orbital design (engine cluster, grid fins, interstage, second stage, fairing).
-- Swap these placeholders for nicer models in Studio later — systems only need the
-- named references back.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	vcyl(rocket, "Stage2", bx, bz, base.Y + 39, 12, 6.4, WHITE)

	-- Tapered payload fairing + nose tip
	vcyl(rocket, "Fairing", bx, bz, base.Y + 46.5, 3, 6, WHITE)
	vcyl(rocket, "Fairing", bx, bz, base.Y + 49, 2.5, 4.5, WHITE)
	vcyl(rocket, "Fairing", bx, bz, base.Y + 51, 1.5, 3, WHITE)
	part(rocket, {
		Name = "Tip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(bx, base.Y + 52.2, bz),
	})

	-- Capsule window
	block(rocket, "Window", CFrame.new(bx, base.Y + 39, bz + 3.25), Vector3.new(1.4, 1.4, 0.25), Color3.fromRGB(40, 60, 95))

	-- Pilot seat, up inside the capsule
	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Anchored = true
	seat.CanCollide = false
	seat.Transparency = 1
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(bx, base.Y + 38, bz)
	seat.Parent = rocket

	-- Boarding prompt down at the base where players walk up
	local skirt = rocket:FindFirstChild("EngineSkirt") :: BasePart
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.Name = "BoardPrompt"
	boardPrompt.ActionText = "Enter Rocket"
	boardPrompt.ObjectText = "Rocket"
	boardPrompt.HoldDuration = 0.5
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.MaxActivationDistance = Config.Rocket.PromptDistance
	boardPrompt.Parent = skirt

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

	rocket.PrimaryPart = rocket:FindFirstChild("Stage1") :: BasePart
	rocket.Parent = parent
	return rocket, seat, boardPrompt, engineFX
end

local function buildOrbitScene(parent: Instance, center: Vector3): (Seat, ProximityPrompt, Model)
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

	-- Satellite to deploy
	local satellite = Instance.new("Model")
	satellite.Name = "Satellite"
	local satPos = Vector3.new(cx + 26, cy + 5, cz)
	local satBody = part(satellite, {
		Name = "Body",
		Size = Vector3.new(3, 3, 4),
		Position = satPos,
		Color = Color3.fromRGB(188, 194, 205),
		Material = Enum.Material.Metal,
	})
	part(satellite, {
		Name = "Panel",
		Size = Vector3.new(10, 0.2, 4),
		Position = satPos + Vector3.new(6.5, 0, 0),
		Color = Color3.fromRGB(40, 60, 120),
	})
	part(satellite, {
		Name = "Panel",
		Size = Vector3.new(10, 0.2, 4),
		Position = satPos - Vector3.new(6.5, 0, 0),
		Color = Color3.fromRGB(40, 60, 120),
	})
	vcyl(satellite, "Mast", satPos.X, satPos.Z, satPos.Y + 3.2, 3, 0.4, GREY)
	part(satellite, {
		Name = "Dish",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = satPos + Vector3.new(0, 4.6, 0),
		Color = Color3.fromRGB(220, 222, 228),
	})
	satellite.PrimaryPart = satBody
	satellite.Parent = parent

	return orbitSeat, returnPrompt, satellite
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

function WorldBuilder.build(): Complex
	local model = Instance.new("Model")
	model.Name = "SpaceMan"
	model.Parent = Workspace

	part(model, {
		Name = "Ground",
		Size = Vector3.new(280, 1, 320),
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(78, 110, 70),
		Material = Enum.Material.Grass,
	})

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(10, 1, 10)
	spawnPad.Position = Vector3.new(0, 0.5, 74)
	spawnPad.Color = CONCRETE
	spawnPad.Material = Enum.Material.Concrete
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Parent = model

	local suitStation = part(model, {
		Name = "SuitStation",
		Size = Vector3.new(8, 4, 8),
		Position = Vector3.new(16, 2, 62),
		Color = ACCENT,
		Material = Enum.Material.Metal,
	})
	nameTag(suitStation, "🧑‍🚀 SUIT UP", 4)

	local suitPrompt = Instance.new("ProximityPrompt")
	suitPrompt.Name = "SuitPrompt"
	suitPrompt.ActionText = "Put on Space Suit"
	suitPrompt.ObjectText = "Suit Station"
	suitPrompt.HoldDuration = 1
	suitPrompt.RequiresLineOfSight = false
	suitPrompt.MaxActivationDistance = Config.Suit.PromptDistance
	suitPrompt.Parent = suitStation

	local vab = part(model, {
		Name = "VehicleAssemblyBuilding",
		Size = Vector3.new(34, 56, 34),
		Position = Vector3.new(0, 28, 40),
		Color = WHITE,
		Material = Enum.Material.Concrete,
	})
	nameTag(vab, "VEHICLE ASSEMBLY", 30)

	local mc = part(model, {
		Name = "MissionControl",
		Size = Vector3.new(30, 14, 22),
		Position = Vector3.new(-56, 7, 20),
		Color = Color3.fromRGB(208, 210, 216),
		Material = Enum.Material.Concrete,
	})
	nameTag(mc, "MISSION CONTROL", 9)

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

	for i = 0, 3 do
		part(model, {
			Name = "TowerLeg",
			Size = Vector3.new(1, 50, 1),
			Position = Vector3.new(-14 + (i % 2) * 2, 25, -74 + math.floor(i / 2) * 2),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end

	local rocket, seat, boardPrompt, engineFX = buildRocket(model, Vector3.new(padCenter.X, 1, padCenter.Z))
	local orbitSeat, orbitReturnPrompt, satellite = buildOrbitScene(model, Config.Orbit.Center)

	-- Ocean east of the Cape (real terrain water for the splashdown).
	Workspace.Terrain:FillBlock(CFrame.new(Config.Ocean.Center), Config.Ocean.Size, Enum.Material.Water)

	-- Re-entry capsule + parachute, parked underground until splashdown.
	local descentRig, descentSeat = buildDescentRig(model, Config.Splashdown.Point)
	local descentStart = CFrame.new(Config.Splashdown.Point.X, Config.Splashdown.StartHeight, Config.Splashdown.Point.Z)
	local descentParked = CFrame.new(Config.Splashdown.Point.X, -500, Config.Splashdown.Point.Z)
	descentRig:PivotTo(descentParked)

	return {
		Model = model,
		Rocket = rocket,
		RocketSeat = seat,
		RocketStart = rocket:GetPivot(),
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
	}
end

return WorldBuilder
