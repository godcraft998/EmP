local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "BlackScreenUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

-- Màn hình đen
local black = Instance.new("Frame")
black.Size = UDim2.new(1.5, 0, 1.5, 0)
black.Position = UDim2.new(0.5, 0, 0.5, 0)
black.AnchorPoint = Vector2.new(0.5, 0.5)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 1 -- ban đầu tắt
black.Visible = true
black.Parent = gui

-- Nút toggle
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 300, 0, 30)
button.Position = UDim2.new(0.5, 0, 0, -50)
button.AnchorPoint = Vector2.new(0.5, 0)
button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
button.TextColor3 = Color3.new(1, 1, 1)
button.Parent = gui

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 0, 15)
text.Position = UDim2.new(0.5, 0, 0.5, 0)
text.AnchorPoint = Vector2.new(0.5, 0.5)
text.BackgroundTransparency = 1
text.TextColor3 = Color3.new(1, 1, 1)
text.Text = "Toggle BlackScreen"
text.TextScaled = true
text.Font = Enum.Font.FredokaOne
text.Parent = button

local corner = Instance.new("UICorner")
corner.Parent = button

-- trạng thái
local enabled = false

button.Activated:Connect(function()
    enabled = not enabled

    if enabled then
        black.BackgroundTransparency = 0
    else
        black.BackgroundTransparency = 1
    end
end)