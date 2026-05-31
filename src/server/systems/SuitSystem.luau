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
