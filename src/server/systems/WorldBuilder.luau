--!strict
-- Builds a compact launch complex out of Parts at runtime, so the whole
-- environment lives in version control. Swap these placeholders for nicer
-- models in Studio later — the systems only need the named references back.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

export type Complex = {
	Model: Model,
	Rocket: Model,
	RocketSeat: Seat,
	BoardPrompt: ProximityPrompt,
	SuitStation: BasePart,
	SuitPrompt: ProximityPrompt,
}

local CONCRETE = Color3.fromRGB(150, 150, 158)
local WHITE = Color3.fromRGB(240, 242, 248)
local DARK = Color3.fromRGB(45, 48, 58)
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

local function nameTag(adornee: BasePart, text: string, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.new(0, 280, 0, 54)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 500

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

local function buildRocket(parent: Instance, base: Vector3): (Model, Seat, ProximityPrompt)
	local rocket = Instance.new("Model")
	rocket.Name = "Rocket"

	local bodyHeight = 24
	local body = part(rocket, {
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(bodyHeight, 6, 6),
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(base.X, base.Y + bodyHeight / 2, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
	})

	part(rocket, {
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 6.3, 6.3),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(base.X, base.Y + 6, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
	})

	part(rocket, {
		Name = "Nose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(base.X, base.Y + bodyHeight, base.Z),
	})

	for i = 0, 3 do
		local angle = math.rad(i * 90)
		part(rocket, {
			Name = "Fin",
			Size = Vector3.new(1, 5, 3),
			Color = ACCENT,
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(base.X + math.cos(angle) * 3.2, base.Y + 2.5, base.Z + math.sin(angle) * 3.2)
				* CFrame.Angles(0, -angle, 0),
		})
	end

	local seat = Instance.new("Seat")
	seat.Name = "PilotSeat"
	seat.Anchored = true
	seat.CanCollide = false
	seat.Transparency = 1
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = CFrame.new(base.X, base.Y + 5, base.Z)
	seat.Parent = rocket

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BoardPrompt"
	prompt.ActionText = "Enter Rocket"
	prompt.ObjectText = "Rocket"
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.Rocket.PromptDistance
	prompt.Parent = body

	rocket.PrimaryPart = body
	rocket.Parent = parent
	return rocket, seat, prompt
end

function WorldBuilder.build(): Complex
	local model = Instance.new("Model")
	model.Name = "LaunchComplex"
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
	spawnPad.Position = Vector3.new(0, 0.5, 90)
	spawnPad.Color = CONCRETE
	spawnPad.Material = Enum.Material.Concrete
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Parent = model

	local suitStation = part(model, {
		Name = "SuitStation",
		Size = Vector3.new(8, 4, 8),
		Position = Vector3.new(16, 2, 74),
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

	local rocket, seat, boardPrompt = buildRocket(model, Vector3.new(padCenter.X, 1, padCenter.Z))

	return {
		Model = model,
		Rocket = rocket,
		RocketSeat = seat,
		BoardPrompt = boardPrompt,
		SuitStation = suitStation,
		SuitPrompt = suitPrompt,
	}
end

return WorldBuilder
