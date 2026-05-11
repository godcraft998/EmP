local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "NotifyUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 350, 1, 0)
container.Position = UDim2.new(1, -355, 0, 7.5)
container.BackgroundTransparency = 1
container.Parent = gui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = container

local function notify(text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 15)
    label.Position = UDim2.new(0.5, 0, 0.5, 0)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = frame

    task.delay(3, function()
        frame:Destroy()
    end)
end

notify("Card Selected: Lovers - Epic")
task.wait(2.5)
notify("Card Selected: Lovers - Rare")