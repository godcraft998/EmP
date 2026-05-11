local VirtualUser = game:GetService("VirtualUser")

local Player = game:GetService("Players").LocalPlayer
local GameUI = Player.PlayerGui.GameUI

local function FakeAction()
    VirtualUser:CaptureController()

    if math.random() < 0.5 then
        VirtualUser:ClickButton1(Vector2.new())
    else
        VirtualUser:ClickButton2(Vector2.new())
    end
end

local function AntiAFK()
    while true do
        task.spawn(FakeAction)
        task.wait(math.random(60, 120))
    end
end

local prioritize = {
    Magician = 5,
    Lovers = 4,
    Fortune = 3,
    Death = 2,
    Emperor = 1
}

local rarities = {
    Path = 5,
    Mythic = 4,
    Legendary = 3,
    Epic = 2,
    Rare = 1
}

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

local function GetCardInfo(frame)
    local info = {}

    info.Type = frame.TopTitle.Text.Text:gsub("[%[%]]", "")
    info.Rarity = frame.Rarity.Text:gsub("[%[%]]", "")
    info.Name = frame.Title.Text
    info.Effect = frame.Text.Text
    info.Hitbox = frame.Hitbox

    return info
end

local function GetCards()
    local cards = {}

    for _, card in pairs(GameUI.Paths.PathSelection.Cards:GetChildren()) do
        if card:IsA("Frame") then
            table.insert(cards, GetCardInfo(card))
        end
    end

    return cards
end

local function PickCard()
    -- table chứa các card
    local cards = GetCards()

    local best = nil

    for _, card in ipairs(cards) do
        if not best then
            best = card
        else
            local pa = prioritize[card.Type] or 0
            local pb = prioritize[best.Type] or 0

            if pa > pb then
                best = card
            elseif pa == pb then
                local ra = rarities[card.Rarity] or 0
                local rb = rarities[best.Rarity] or 0

                if ra > rb then
                    best = card
                end
            end
        end
    end

    firesignal(best.Hitbox.Activated)
    notify("Pick Card: " .. best.Type .. " - " .. best.Rarity)
end

local function FormatTime(t)
    local m = math.floor(t / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d", m, s)
end

local function Init()
    while task.wait(1) do
        if GameUI.Paths.Enabled then
            task.spawn(PickCard)
        end
    end
end

task.spawn(Init)
task.spawn(AntiAFK)