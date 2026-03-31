-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Modules
local InterfaceUtils = require(ReplicatedStorage.Modules.Interface.InterfaceUtils)
local TextUtils = require(ReplicatedStorage.Modules.Utilities.TextUtils)
local PopupHandler = require(StarterPlayer.Modules.Interface.Loader.Misc.PopupHandler)

-- Lazy-loaded modules
local LobbyListHandler
local LobbySceneHandler
local LobbyHandler

-- Networking
local Networking = ReplicatedStorage.Networking
local PublicLobbyStatus = Networking.PublicLobbyStatus

-- UI references
local MatchStatusUI
local WaitingUI

----------------------------------------------------------------
-- Create waiting UI when joining lobby
----------------------------------------------------------------
local function createWaitingUI(lobbyData)
    -- Cleanup old UI
    if WaitingUI then
        WaitingUI:Destroy()
        WaitingUI = nil
    end

    -- Load modules if needed
    LobbyListHandler = LobbyListHandler or require(script.Parent.PublicLobbyListHandler)
    LobbySceneHandler = LobbySceneHandler or require(
        StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.LobbySceneHandler
    )
    LobbyHandler = LobbyHandler or require(
        StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.LobbyHandler
    )

    -- Close lobby list
    LobbyListHandler.CloseInterface()

    -- Setup scene
    LobbySceneHandler.DestroyScene()
    LobbySceneHandler.CreateScene(lobbyData.StageType)

    -- Add players
    for _, playerId in lobbyData.Players or {} do
        if playerId == LocalPlayer.UserId then
            LobbySceneHandler.AddPlayer(LocalPlayer)
        else
            LobbySceneHandler.AddPlayer(playerId)
        end
    end

    ----------------------------------------------------------------
    -- UI Creation
    ----------------------------------------------------------------
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CrossServerWaitingUI"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Name = "WaitingFrame"
    frame.Size = UDim2.new(0, 400, 0, 120)
    frame.Position = UDim2.new(0.5, -200, 0.85, -60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(100, 100, 150)
    stroke.Thickness = 2

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0.4, 0)
    title.Position = UDim2.new(0, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.Text = ("Joined %s's Lobby"):format(lobbyData.HostName or "Unknown")
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    -- Status
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, 0, 0.3, 0)
    status.Position = UDim2.new(0, 0, 0.5, 0)
    status.BackgroundTransparency = 1
    status.Text = "Waiting for host to start..."
    status.TextColor3 = Color3.fromRGB(180, 180, 200)
    status.TextSize = 16
    status.Font = Enum.Font.Gotham
    status.Parent = frame

    -- Leave button
    local leaveBtn = Instance.new("TextButton")
    leaveBtn.Name = "Leave"
    leaveBtn.Size = UDim2.new(0.4, 0, 0.25, 0)
    leaveBtn.Position = UDim2.new(0.3, 0, 0.7, 0)
    leaveBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    leaveBtn.Text = "Leave Lobby"
    leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    leaveBtn.TextSize = 14
    leaveBtn.Font = Enum.Font.GothamBold
    leaveBtn.Parent = frame

    Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 8)

    ----------------------------------------------------------------
    -- Leave logic
    ----------------------------------------------------------------
    leaveBtn.Activated:Connect(function()
        if WaitingUI then
            WaitingUI:Destroy()
            WaitingUI = nil
        end

        LobbySceneHandler.DestroyScene()
        LobbyHandler.LeaveLobby()

        local event = Networking:FindFirstChild("LobbyEvent")
        if event then
            event:FireServer("LeavePublicMatch", lobbyData.HostId)
        end
    end)

    screenGui.Parent = PlayerGui
    WaitingUI = screenGui

    LobbyHandler.IsInLobby = true
end

----------------------------------------------------------------
-- Event Listener
----------------------------------------------------------------
task.spawn(function()
    PublicLobbyStatus.OnClientEvent:Connect(function(action, data)

        ----------------------------------------------------------------
        -- CREATE
        ----------------------------------------------------------------
        if action == "Create" then
            if not MatchStatusUI then
                local ui = script.MatchStatus:Clone()
                local holder = ui.Holder

                holder.Main.Description.Text = "Please wait while we make your match public..."
                ui.Parent = PlayerGui

                MatchStatusUI = ui

                InterfaceUtils.AnimateInterface(ui)
                TextUtils.ResizeTextByWidth(
                    holder.Main.Description,
                    holder.Main.Description.Text,
                    ui.Holder.UIScale
                )
            end
            return
        end

        ----------------------------------------------------------------
        -- START
        ----------------------------------------------------------------
        if action == "Start" then
            if not MatchStatusUI then
                local ui = script.MatchStatus:Clone()
                local holder = ui.Holder

                holder.Main.Description.Text = "Public match starting..."
                ui.Parent = PlayerGui

                MatchStatusUI = ui

                InterfaceUtils.AnimateInterface(ui)
                TextUtils.ResizeTextByWidth(
                    holder.Main.Description,
                    holder.Main.Description.Text,
                    ui.Holder.UIScale
                )
            end

            if WaitingUI then
                WaitingUI:Destroy()
                WaitingUI = nil
            end
            return
        end

        ----------------------------------------------------------------
        -- CLOSE
        ----------------------------------------------------------------
        if action == "Close" then
            if MatchStatusUI then
                MatchStatusUI:Destroy()
                MatchStatusUI = nil
            end

            if WaitingUI then
                WaitingUI:Destroy()
                WaitingUI = nil

                LobbySceneHandler = LobbySceneHandler or require(
                    StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.LobbySceneHandler
                )
                LobbySceneHandler.DestroyScene()
            end
            return
        end

        ----------------------------------------------------------------
        -- ERRORS
        ----------------------------------------------------------------
        if action == "UnknownHost" then
            if MatchStatusUI then
                MatchStatusUI:Destroy()
                MatchStatusUI = nil
            end

            PopupHandler:ShowPopup(
                "BaseCancelFrame",
                "Unable to find the lobby host. This is likely a Roblox bug!"
            )
            return
        end

        if action == "AlreadyMade" then
            if MatchStatusUI then
                MatchStatusUI:Destroy()
                MatchStatusUI = nil
            end

            PopupHandler:ShowPopup(
                "BaseCancelFrame",
                "You already have a public match made!"
            )
            return
        end

        ----------------------------------------------------------------
        -- JOIN
        ----------------------------------------------------------------
        if action == "JoinedCrossServer" then
            createWaitingUI(data)
            return
        end

        ----------------------------------------------------------------
        -- LOBBY CLOSED
        ----------------------------------------------------------------
        if action == "LobbyClosed" then
            if MatchStatusUI then
                MatchStatusUI:Destroy()
                MatchStatusUI = nil
            end

            if WaitingUI then
                WaitingUI:Destroy()
                WaitingUI = nil
            end

            LobbySceneHandler = LobbySceneHandler or require(
                StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.LobbySceneHandler
            )

            if data ~= LocalPlayer.UserId then
                LobbySceneHandler.DestroyScene(true)

                PopupHandler:ShowPopup(
                    "BaseCancelFrame",
                    "The lobby was closed by the host."
                )
            end
        end
    end)
end)

return {}