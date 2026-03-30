local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- UI
local HUD = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("HUD")
local Main = HUD:WaitForChild("Main")
local CurrencyContainer = Main:WaitForChild("Currencies")

-- Modules
local CurrencyData = require(ReplicatedStorage.Modules.Data.CurrencyData)
local NumberUtils = require(ReplicatedStorage.Modules.Utilities.NumberUtils)
local TextUtils = require(ReplicatedStorage.Modules.Utilities.TextUtils)
local UIUtils = require(ReplicatedStorage.Modules.Interface.InterfaceUtils)
local HoverHandler = require(StarterPlayer.Modules.Miscellaneous.HoverHandler)
local CurrencyDisplay = require(StarterPlayer.Modules.Gameplay.Currencies.CurrencyDisplayDataHandler)

-- Storage
local frames = {}

-- =========================
-- 🪙 Update currency text
-- =========================
local function bindCurrency(currencyName, frame)
    local label = frame.Amount

    -- update lần đầu
    local value = LocalPlayer:GetAttribute(currencyName)
    if value then
        label.Text = NumberUtils:CommaValue(value)
    end

    -- update khi thay đổi
    LocalPlayer:GetAttributeChangedSignal(currencyName):Connect(function()
        local newValue = LocalPlayer:GetAttribute(currencyName)

        label.Text = NumberUtils:CommaValue(newValue)
        TextUtils.ResizeTextByWidth(label, label.Text)

        HoverHandler.UpdateFooter(frame, "You own: " .. label.Text)
    end)
end

-- =========================
-- 🧱 Tạo UI currency
-- =========================
function CreateCurrencyFrame(name)
    local data = CurrencyData:GetCurrencyDataFromName(name)

    local frame = script.CurrencyFrame:Clone()
    frame.Icon.Image = data.Image
    frame.Parent = CurrencyContainer

    -- hover info
    HoverHandler.CreateHoverFrame(frame, {
        Header = name,
        Description = data.Description,
        Footer = "You own: 0"
    })

    bindCurrency(name, frame)

    frames[name] = frame
end

-- =========================
-- ❌ Xóa UI
-- =========================
function RemoveCurrencyFrame(name)
    if frames[name] then
        frames[name]:Destroy()
        frames[name] = nil
    end
end

-- =========================
-- 👁️ Hiện currency mặc định
-- =========================
function ShowDefaultCurrencies()
    local displayed = CurrencyDisplay.GetCurrenciesDisplayed()

    for name, frame in pairs(frames) do
        frame.Visible = displayed[name] ~= nil
    end
end

-- =========================
-- 🚀 INIT
-- =========================
task.spawn(function()
    -- tạo UI
    for name in CurrencyDisplay.GetCurrenciesDisplayed() do
        CreateCurrencyFrame(name)
    end

    -- update khi danh sách currency thay đổi
    CurrencyDisplay.CurrenciesUpdated:Connect(function()
        local displayed = CurrencyDisplay.GetCurrenciesDisplayed()

        -- remove
        for name in pairs(frames) do
            if not displayed[name] then
                RemoveCurrencyFrame(name)
            end
        end

        -- add
        for name in displayed do
            if not frames[name] then
                CreateCurrencyFrame(name)
            end
        end
    end)

    ShowDefaultCurrencies()

    -- =========================
    -- ⭐ LEVEL SYSTEM
    -- =========================
    local levelUI = Main.Level
    local progressBar = levelUI.Progress
    local levelText = levelUI.Level

    LocalPlayer:GetAttributeChangedSignal("Experience"):Connect(function()
        local level = LocalPlayer:GetAttribute("Level")
        local exp = LocalPlayer:GetAttribute("Experience")

        local maxExp = 350 + 100 * (level - 1)
        local percent = exp / maxExp

        levelText.Text = ("Level %d (%d/%d)"):format(level, exp, maxExp)

        TweenService:Create(progressBar, TweenInfo.new(0.2), {
            Size = UDim2.fromScale(percent, 1)
        }):Play()
    end)
end)