--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

--// Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Modules
local Spring = require(ReplicatedStorage.Modules.Packages.Spring)
local Signal = require(ReplicatedStorage.Modules.Packages.FastSignal)

require(ReplicatedStorage.Modules.Utilities.TextUtils)
require(ReplicatedStorage.Modules.Debug.TableToString)

local TopbarHandler = require(StarterPlayer.Modules.Interface.TopbarHandler)
local StageInterface = require(StarterPlayer.Modules.Interface.Loader.Windows.Lobby.StageInterfaceHandler)
local LobbyScene = require(script.Parent.LobbySceneHandler)
local StageSelection = require(script.Parent.StageSelectionHandler)
local MatchList = require(script.Parent.Matchmaking.MatchListHandler)
local PublicLobbyList = require(script.Parent.Matchmaking.PublicLobbies.PublicLobbyListHandler)
local ConsoleInput = require(StarterPlayer.Modules.Interface.Loader.ConsoleInputHandler)
local Tooltip = require(StarterPlayer.Modules.Interface.Loader.ConsoleTooltipHandler)
local Challenges = require(StarterPlayer.Modules.Gameplay.Challenges.ChallengesHandler)
local DialogueCallbacks = require(StarterPlayer.Modules.Interface.Loader.DialogueHandler.Callbacks)

--// Remote
local MatchEvent = ReplicatedStorage.Networking.MatchReplicationEvent

--// State
local LobbyHandler = {
    IsInLobby = false,
    LobbyJoined = Signal.new()
}

local CurrentUI = nil
local DisabledButtons = {}

local LobbyData = {
    Side = "Left",
    IsOwner = true
}

--// Animate text
local function AnimateText(container)
    for _, label in ipairs(container:GetChildren()) do
        if label:IsA("TextLabel") then
            local length = string.len(label.Text)
            label.MaxVisibleGraphemes = 0

            task.delay(0.65, function()
                TweenService:Create(label, TweenInfo.new(0.35), {
                    MaxVisibleGraphemes = length
                }):Play()

                if label.Name ~= "Label" then
                    local originalPos = label.Position
                    label.Position = UDim2.new(0.5, 0, 0, 8)
                    label.TextTransparency = 0.85

                    TweenService:Create(
                        label,
                        TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.In, -1, true),
                        {
                            Position = originalPos,
                            TextTransparency = 0
                        }
                    ):Play()
                end
            end)
        end
    end
end

--// Toggle buttons
local function ToggleUnitButtons(enabled)
    local container = PlayerGui.HUD.Main.Units

    if enabled then
        for _, btn in ipairs(DisabledButtons) do
            btn.Selectable = true
        end
        table.clear(DisabledButtons)
    else
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("TextButton") then
                obj.Selectable = false
                table.insert(DisabledButtons, obj)
            end
        end
    end
end

--// Leave lobby
function LobbyHandler.LeaveLobby()
    LobbyScene.DestroyScene()
    MatchList.CloseInterface()
    StageSelection.CloseInterface()

    if CurrentUI then
        CurrentUI:Destroy()
        CurrentUI = nil
    end

    LobbyHandler.IsInLobby = false
    TopbarHandler.ToggleIcons(true)

    for _, btn in ipairs(DisabledButtons) do
        btn.Selectable = true
    end
    table.clear(DisabledButtons)

    Tooltip.DestroyTooltip()
    Tooltip.CustomBackedBehavior = nil
end

--// Open lobby UI
local function OpenLobbyUI(mode)
    if CurrentUI then return end

    DialogueCallbacks:CancelDialogue()
    mode = mode or "Story"

    local ui = script.LobbyInterface:Clone()
    local holder = ui.Holder
    local buttons = holder.Buttons

    ui.Parent = PlayerGui
    CurrentUI = ui

    -- animation
    Spring.target(ui.GlowFrame, 6, 6, {
        Size = UDim2.new(0, 925, 1, 0)
    })

    -- buttons logic
    buttons.Create.Button.Activated:Connect(function()
        if mode == "Challenges" then
            Challenges.OpenInterface()
        else
            StageSelection.OpenInterface(mode)
        end
    end)

    buttons.PublicLobbies.Button.Activated:Connect(function()
        PublicLobbyList.OpenInterface(mode)
    end)

    buttons.Join.Button.Activated:Connect(function()
        MatchList.OpenInterface(mode)
    end)

    ui.FractureFrame.Leave.Button.Activated:Connect(LobbyHandler.LeaveLobby)

    LobbyHandler.IsInLobby = true
    LobbyHandler.LobbyJoined:Fire()

    AnimateText(ui.FractureFrame)
    ToggleUnitButtons(false)

    task.delay(0.2, function()
        ConsoleInput.Select(buttons)
    end)
end

--// Toggle UI visibility
function LobbyHandler.ToggleInterface(enabled)
    if CurrentUI then
        CurrentUI.Holder.Visible = enabled
        CurrentUI.FractureFrame.Visible = enabled
    end
end

--// Enter lobby
function LobbyHandler.EnterLobby(mode)
    if LocalPlayer:GetAttribute("IsTrading") then
        error("Player is trading!")
    end

    OpenLobbyUI(mode)

    LobbyScene.CreateScene(mode)
    LobbyScene.AddPlayer(LocalPlayer)

    TopbarHandler.ToggleIcons(false)

    task.delay(0.2, function()
        Tooltip.CreateTooltip()
    end)
end

--// Back button behavior
Tooltip.BackedEvent:Connect(function()
    if not CurrentUI then return end

    for _, name in ipairs({
        "MatchmakingInterface",
        "Matches",
        "MatchStatus",
        "Lobby"
    }) do
        if PlayerGui:FindFirstChild(name) then
            task.wait(0.075)
            ConsoleInput.Select(CurrentUI.Holder.Buttons)
            return
        end
    end

    LobbyHandler.LeaveLobby()
end)

--// Remote handling
MatchEvent.OnClientEvent:Connect(function(action, data)
    if action == "ConfirmMatch" then
        if CurrentUI then
            CurrentUI:Destroy()
            CurrentUI = nil
        end

        StageSelection.CloseInterface()
        MatchList.CloseInterface()

        LobbyData.IsOwner = true
        StageInterface:Open(data, LobbyData)

    elseif action == "CloseMatch" then
        if data.ForceClose or data.StageType == "LTM" then
            LobbyHandler.LeaveLobby()
        else
            StageInterface:Close()
            OpenLobbyUI(data.StageType)

            LobbyScene.RemoveAllPlayers()
            LobbyScene.AddPlayer(LocalPlayer)
        end

    elseif action == "JoinMatch" then
        PublicLobbyList.CloseInterface()

        if not LobbyHandler.IsInLobby then
            LobbyHandler.IsInLobby = true
            LobbyScene.CreateScene(data.StageType)
            LobbyScene.AddPlayer(LocalPlayer)
            TopbarHandler.ToggleIcons(false)
        end

        LobbyScene.AddAllPlayers(data.Players)

        StageSelection.CloseInterface()
        MatchList.CloseInterface()

        if CurrentUI then
            CurrentUI:Destroy()
            CurrentUI = nil
        end

        LobbyData.IsOwner = false
        StageInterface:Open(data, LobbyData)

        LobbyHandler.LobbyJoined:Fire()

    elseif action == "LoadScene" then
        LobbyHandler.IsInLobby = true
        LobbyHandler.LobbyJoined:Fire()

        LobbyScene.CreateScene()
        LobbyScene.AddPlayer(LocalPlayer)

    elseif action == "AddPlayer" then
        LobbyScene.AddPlayer(data)
        StageInterface:AddPlayer(data)

    elseif action == "UpdatePlayerList" then
        LobbyScene.RemoveAllPlayers()
        StageInterface:RemoveAllPlayers()

        for _, player in ipairs(data) do
            LobbyScene.AddPlayer(player)
            StageInterface:AddPlayer(player)
        end

    elseif action == "RemovePlayer" then
        LobbyScene.RemovePlayer(data)
        StageInterface:RemovePlayer(data)

    elseif action == "LobbyClosed" then
        if data.ForceClose then
            LobbyHandler.LeaveLobby()
        else
            StageInterface:Close()
            OpenLobbyUI()

            LobbyScene.RemoveAllPlayers()
            LobbyScene.AddPlayer(LocalPlayer)
        end
    end
end)

return LobbyHandler