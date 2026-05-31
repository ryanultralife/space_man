--!strict
-- Simple on-screen toast for server messages.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Notifier = {}

local label: TextLabel? = nil

function Notifier.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpaceManHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.08, 0)
	toast.Size = UDim2.new(0, 540, 0, 50)
	toast.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	toast.BackgroundTransparency = 1
	toast.TextColor3 = Color3.fromRGB(235, 240, 245)
	toast.Font = Enum.Font.GothamMedium
	toast.TextScaled = true
	toast.Text = ""
	toast.TextTransparency = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = toast

	toast.Parent = gui
	label = toast
end

function Notifier.show(message: string)
	local toast = label
	if not toast then
		return
	end
	toast.Text = message
	TweenService:Create(toast, TweenInfo.new(0.2), {
		TextTransparency = 0,
		BackgroundTransparency = 0.2,
	}):Play()

	task.delay(3.5, function()
		if toast.Text == message then
			TweenService:Create(toast, TweenInfo.new(0.4), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

return Notifier
