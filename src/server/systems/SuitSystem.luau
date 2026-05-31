--!strict
-- Suit-up gate: triggering the Suit Station prompt equips a space suit
-- (helmet + life-support pack) on the player's character and flags them as
-- suited. The suit is lost on respawn, so they must suit up each life.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SuitSystem = {}

local notify = Remotes.event("Notify")

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function sparkle(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(3, 7)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(Color3.fromRGB(140, 220, 255), Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new(0.6)
	emitter.LightEmission = 0.6
	emitter.Parent = root
	emitter:Emit(45)
	task.delay(1.6, function()
		emitter:Destroy()
	end)
end

local function applySuit(character: Model)
	-- Quick sparkle for feedback — we do NOT cover the player's own avatar/outfit.
	sparkle(character)
	if not Config.Suit.AddGear then
		return
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	if head and not character:FindFirstChild("SM_Helmet") then
		local helmet = Instance.new("Part")
		helmet.Name = "SM_Helmet"
		helmet.Shape = Enum.PartType.Ball
		helmet.Size = head.Size * 1.7
		helmet.Color = Config.Suit.HelmetColor
		helmet.Material = Enum.Material.Glass
		helmet.Transparency = 0.35
		helmet.CanCollide = false
		helmet.Massless = true
		helmet.CFrame = head.CFrame
		helmet.Parent = character
		weld(helmet, head)
	end

	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if torso and not character:FindFirstChild("SM_Pack") then
		local pack = Instance.new("Part")
		pack.Name = "SM_Pack"
		pack.Size = Vector3.new(1.6, 2, 0.8)
		pack.Color = Config.Suit.SuitColor
		pack.Material = Enum.Material.Metal
		pack.CanCollide = false
		pack.Massless = true
		pack.CFrame = torso.CFrame * CFrame.new(0, 0.2, 0.85)
		pack.Parent = character
		weld(pack, torso)
	end
end

-- White EVA spacewalk suit worn in orbit: white shells over the body (covering any
-- avatar/outfit), a helmet with a gold visor, and a life-support backpack. Fully
-- removable (all parts are named EVA_*).
function SuitSystem.applyEva(character: Model?)
	if not character or character:FindFirstChild("EVA_Helmet") then
		return
	end
	local EVA_WHITE = Color3.fromRGB(238, 240, 245)

	local function shell(partName: string, mul: number)
		local p = character:FindFirstChild(partName) :: BasePart?
		if not p then
			return
		end
		local s = Instance.new("Part")
		s.Name = "EVA_Shell"
		s.Size = p.Size * mul
		s.Color = EVA_WHITE
		s.Material = Enum.Material.SmoothPlastic
		s.CanCollide = false
		s.Massless = true
		s.CFrame = p.CFrame
		s.Parent = character
		weld(s, p)
	end

	shell("UpperTorso", 1.18)
	shell("LowerTorso", 1.16)
	shell("LeftUpperArm", 1.35)
	shell("RightUpperArm", 1.35)
	shell("LeftLowerArm", 1.3)
	shell("RightLowerArm", 1.3)
	shell("LeftUpperLeg", 1.35)
	shell("RightUpperLeg", 1.35)
	shell("LeftLowerLeg", 1.3)
	shell("RightLowerLeg", 1.3)

	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		local helmet = Instance.new("Part")
		helmet.Name = "EVA_Helmet"
		helmet.Shape = Enum.PartType.Ball
		helmet.Size = head.Size * 1.9
		helmet.Color = EVA_WHITE
		helmet.Material = Enum.Material.SmoothPlastic
		helmet.CanCollide = false
		helmet.Massless = true
		helmet.CFrame = head.CFrame
		helmet.Parent = character
		weld(helmet, head)

		local visor = Instance.new("Part")
		visor.Name = "EVA_Shell"
		visor.Shape = Enum.PartType.Ball
		visor.Size = head.Size * 1.6
		visor.Color = Color3.fromRGB(190, 150, 45)
		visor.Material = Enum.Material.Glass
		visor.Transparency = 0.1
		visor.Reflectance = 0.5
		visor.CanCollide = false
		visor.Massless = true
		visor.CFrame = head.CFrame * CFrame.new(0, 0.1, -head.Size.Z * 0.55)
		visor.Parent = character
		weld(visor, head)
	end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local pack = Instance.new("Part")
		pack.Name = "EVA_Shell"
		pack.Size = Vector3.new(2, 2.4, 1)
		pack.Color = EVA_WHITE
		pack.Material = Enum.Material.SmoothPlastic
		pack.CanCollide = false
		pack.Massless = true
		pack.CFrame = torso.CFrame * CFrame.new(0, 0.2, 0.95)
		pack.Parent = character
		weld(pack, torso)
	end
end

function SuitSystem.removeEva(character: Model?)
	if not character then
		return
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "EVA_Shell" or d.Name == "EVA_Helmet") then
			d:Destroy()
		end
	end
end

local function trackPlayer(player: Player)
	player:SetAttribute("HasSuit", false)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("HasSuit", false)
	end)
end

function SuitSystem.start(complex: any)
	local prompt: ProximityPrompt = complex.SuitPrompt
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then
			return
		end
		if player:GetAttribute("HasSuit") then
			notify:FireClient(player, "You're already suited up.")
			return
		end
		applySuit(character)
		player:SetAttribute("HasSuit", true)
		notify:FireClient(player, "🧑‍🚀 Space suit on — head to the rocket!")
	end)

	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
end

return SuitSystem
