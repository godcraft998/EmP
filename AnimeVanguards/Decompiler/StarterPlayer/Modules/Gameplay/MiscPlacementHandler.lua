local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local PlacementValidationHandler = require(ReplicatedStorage.Modules.Gameplay.PlacementValidationHandler)
local PathMathHandler = require(ReplicatedStorage.Modules.Shared.PathMathHandler)
local GetBoundingBox = require(ReplicatedStorage.Modules.Utilities.GetBoundingBox)
local Units = require(ReplicatedStorage.Modules.Data.Entities.Units)
local EnemyPathHandler = require(ReplicatedStorage.Modules.Shared.EnemyPathHandler)
local GameHandler = require(ReplicatedStorage.Modules.Gameplay.GameHandler)
local Logger = require(ReplicatedStorage.Modules.Shared.DebugToggleHandler).CreateStructuredLogger("ui")
local ConsoleInputHandler = require(StarterPlayer.Modules.Interface.Loader.ConsoleInputHandler)
local InterfaceHandler = require(StarterPlayer.Modules.Interface.InterfaceHandler)
local FastSignal = require(ReplicatedStorage.Modules.Packages.FastSignal)

local MouseMovementHandler = require(StarterPlayer.Modules.Gameplay.Units.UnitPlacementHandler.MouseMovementHandler)
local ClientUnitHandler = require(StarterPlayer.Modules.Gameplay.Units.ClientUnitHandler)
local ClientEnemyHandler = require(StarterPlayer.Modules.Gameplay.ClientEnemyHandler)

local Network = ReplicatedStorage.Networking
local RequestMiscPlacement = Network.RequestMiscPlacement
local RequestMiscSelection = Network.RequestMiscSelection
local RequestMiscEnemySelection = Network.RequestMiscEnemySelection

local Camera = workspace.CurrentCamera
local PlayerGui = Players.LocalPlayer.PlayerGui

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Include
RayParams.FilterDescendantsInstances = { workspace.Map }

local ActivePlacements = {}
local PlacementUI = nil
local SelectionUI = nil

local PlacementStarted = FastSignal.new()
local PlacementEnded = FastSignal.new()

local Module = {
    PlacementStarted = PlacementStarted,
    PlacementEnded = PlacementEnded
}

local function beginMobileLock() --[[ locks camera + controls on mobile/controller ]]
    local hum = Players.LocalPlayer.Character:FindFirstChild("Humanoid")

    if UserInputService:GetLastInputType() == Enum.UserInputType.Touch
        or ConsoleInputHandler.IsPlayerUsingConsole() then

        ConsoleInputHandler.RemoveSelected()

        Camera.CameraType = Enum.CameraType.Scriptable
        hum.JumpPower = 0
        hum.WalkSpeed = 0

        GuiService.TouchControlsEnabled = false
        ConsoleInputHandler.EnableGamepadCursor(nil)

        InterfaceHandler:TweenCloseMultiple({ "Hotbar", "SideButtons", "Info" })
    end
end

local function endMobileLock() --[[ restores camera + controls ]]
    local hum = Players.LocalPlayer.Character:FindFirstChild("Humanoid")

    if UserInputService:GetLastInputType() == Enum.UserInputType.Touch
        or ConsoleInputHandler.IsPlayerUsingConsole() then

        Camera.CameraType = Enum.CameraType.Custom

        hum.JumpPower = hum:GetAttribute("UseJumpHeight") or 7.2
        hum.WalkSpeed = ConsoleInputHandler.IsPlayerUsingConsole() and hum.WalkSpeed or hum.WalkSpeed

        GuiService.TouchControlsEnabled = true
        ConsoleInputHandler.DisableGamepadCursor()

        InterfaceHandler:TweenOpenMultiple({ "Hotbar", "SideButtons", "Info" })
    end
end

local function getContextText(ctx) --[[ UI instruction text mapper ]]
    local map = {
        EquipForgeWeapon = "Select a unit to equip the weapon",
        FriranStart = "Select where on the track Friran will begin her journey",
        FriranEnd = "Select where on the track Friran will stop her journey",
        SaberEvent = "Select where to use your summon",
        Ability = "Select where to use your ability",
        Rogita = "Select where to teleport Rogita",
        Dabo81 = "Select where on the track to place Dabo 81",
        Berserker = "Select where on the track to spawn Berserker",
        CustomSpawn = "Select where to have enemies spawn",
        VanguardsVsSkeletons = "Select a track node to place a unit",
        PathSelection = "Select a path for summons to spawn on",
        LichChooseUnits = "Select the units you want to move",
        LichChoosePosition = "Choose a position to move the units to",
        SoulShiftSelectUnit = "Select a unit to Soul Shift",
        SoulShiftSelectPosition = "Choose a new position for the unit",
        NinjutsuSelection = "Select a ninjutsu unit to sell",
        SelectUnit = "Select a unit...",
        Default = "Select where to place..."
    }

    return map[ctx] or map.Default
end

function Module.StartPlacement(params)
    local range = params.Range or 4
    local trackOnly = params.TrackOnly
    local usesBounds = params.UsesBounds

    local model = Instance.new("Model")
    model.Name = "Placer"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Anchored = true
    root.CanCollide = false
    root.Size = Vector3.new(5, 5, 5)
    root.Transparency = 1
    root.Parent = model

    model.PrimaryPart = root
    model.Parent = workspace.Ignore

    local indicator = script.Indicator:Clone()
    indicator.Size = Vector3.new(range, 0.3, range)
    indicator.Parent = workspace.Ignore

    local id = params.GUID or HttpService:GenerateGUID(false)
    local bindName = ("MiscPlacement_%s"):format(id)

    ActivePlacements[id] = {
        Thread = coroutine.running(),
        Model = model
    }

    MouseMovementHandler.UpdateMouseLocation()
    PlacementStarted:Fire()

    if not PlacementUI then
        PlacementUI = script.MiscPlacementNotification:Clone()
        PlacementUI.Container.TextLabel.Text = (getContextText(params.Context) .. " - Q to cancel")
        PlacementUI.Parent = PlayerGui
    end

    MouseMovementHandler.IsActive = true

    local lastTouch = 0

    local inputConn = UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType == Enum.UserInputType.Touch and gp then
            lastTouch = os.clock()
        end
    end)

    RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value, function()
        if os.clock() - lastTouch < 0.25 then return end

        local mouse = MouseMovementHandler.UpdateMouseLocation()
        local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)

        RayParams.FilterDescendantsInstances = { workspace.Map }

        local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, RayParams)
        if not hit then return end

        local pos = hit.Position

        model:PivotTo(CFrame.new(pos))
        indicator:PivotTo(model:GetPivot() * CFrame.Angles(0, os.clock() * 3, 0))
    end)

    local result = coroutine.yield()

    MouseMovementHandler.IsActive = false
    RunService:UnbindFromRenderStep(bindName)
    inputConn:Disconnect()

    model:Destroy()
    indicator:Destroy()

    if PlacementUI then
        PlacementUI:Destroy()
        PlacementUI = nil
    end

    if result == nil then
        PlacementEnded:Fire()
    end

    return result
end

function Module.StartSelection(params)
    local exclude = params.ExcludeUnits or {}
    local excludeMap = {}

    for _, id in exclude do
        excludeMap[id] = true
    end

    local id = params.GUID or HttpService:GenerateGUID(false)
    local thread = coroutine.running()

    ActivePlacements[id] = { Thread = thread }

    MouseMovementHandler.UpdateMouseLocation()
    PlacementStarted:Fire()

    if not PlacementUI then
        PlacementUI = script.MiscPlacementNotification:Clone()
        PlacementUI.Container.TextLabel.Text =
            (getContextText(params.Context) .. " - Q to cancel")
        PlacementUI.Parent = PlayerGui
    end

    MouseMovementHandler.IsActive = true

    local conn = ClientUnitHandler.OnUnitSelected:Connect(function(_, unit)
        if not excludeMap[unit.UniqueIdentifier] then
            coroutine.resume(thread, unit.UniqueIdentifier, unit)
        end
    end)

    local a, b = coroutine.yield()

    conn:Disconnect()
    ActivePlacements[id] = nil

    MouseMovementHandler.IsActive = false

    if not next(ActivePlacements) then
        endMobileLock()
        PlacementEnded:Fire()
    end

    if PlacementUI then
        PlacementUI:Destroy()
        PlacementUI = nil
    end

    return a, b
end

function Module.StartEnemySelection(params)
    local exclude = params.ExcludeEnemies or {}
    local excludeMap = {}

    for _, id in exclude do
        excludeMap[id] = true
    end

    local id = params.GUID or HttpService:GenerateGUID(false)
    local thread = coroutine.running()

    ActivePlacements[id] = { Thread = thread }

    MouseMovementHandler.UpdateMouseLocation()
    PlacementStarted:Fire()

    if not PlacementUI then
        PlacementUI = script.MiscPlacementNotification:Clone()
        PlacementUI.Container.TextLabel.Text =
            (getContextText(params.Context) .. " - Q to cancel")
        PlacementUI.Parent = PlayerGui
    end

    MouseMovementHandler.IsActive = true

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 0.5
    highlight.FillColor = Color3.new(0.16, 0.84, 1)
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.Name = "EnemySelection"
    highlight.Parent = PlayerGui

    local lastTouch = 0

    local inputConn = UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType == Enum.UserInputType.Touch and gp then
            lastTouch = os.clock()
        end
    end)

    local function getClosestEnemy()
        local mouse = MouseMovementHandler.GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)

        local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, RayParams)
        if not hit then return nil end

        local pos = hit.Position

        local closest, dist = nil, math.huge

        for _, enemy in ClientEnemyHandler._ActiveEnemies do
            if not excludeMap[enemy.UniqueIdentifier] then
                local d = (Vector3.new(enemy.Position.X, 0, enemy.Position.Z)
                        - Vector3.new(pos.X, 0, pos.Z)).Magnitude

                if d < dist then
                    closest = enemy
                    dist = d
                end
            end
        end

        return closest
    end

    local clickConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
            or (input.UserInputType == Enum.UserInputType.Gamepad1
                and input.KeyCode == Enum.KeyCode.ButtonA) then

            if input.UserInputType == Enum.UserInputType.Touch
                and os.clock() - lastTouch < 0.25 then
                return
            end

            local enemy = getClosestEnemy()
            if enemy then
                coroutine.resume(thread, enemy.UniqueIdentifier)
            end
        end
    end)

    local hbConn = RunService.Heartbeat:Connect(function()
        local enemy = getClosestEnemy()
        highlight.Adornee = enemy and enemy.Model or nil
    end)

    local result = coroutine.yield()

    clickConn:Disconnect()
    inputConn:Disconnect()
    hbConn:Disconnect()

    highlight:Destroy()

    ActivePlacements[id] = nil
    MouseMovementHandler.IsActive = false

    if not next(ActivePlacements) then
        endMobileLock()
        PlacementEnded:Fire()
    end

    if PlacementUI then
        PlacementUI:Destroy()
        PlacementUI = nil
    end

    return result
end

function Module.Confirm(id)
    local data = ActivePlacements[id]
    if not data then return end

    ActivePlacements[id] = nil
    coroutine.resume(data.Thread, data.Selection and data.Selection.UniqueIdentifier)
end

function Module.Cancel(id)
    local data = ActivePlacements[id]
    if not data then return end

    ActivePlacements[id] = nil
    coroutine.resume(data.Thread, nil)
end

function Module.ConfirmAll()
    for id in pairs(ActivePlacements) do
        Module.Confirm(id)
    end
end

function Module.CancelAll()
    local had = next(ActivePlacements) ~= nil

    for id in pairs(ActivePlacements) do
        Module.Cancel(id)
    end

    if had then
        endMobileLock()
        MouseMovementHandler.IsActive = false
    end
end

task.spawn(function()
    RequestMiscPlacement.OnClientEvent:Connect(function(data)
        local res = Module.StartPlacement(data or { Range = 4 })
        RequestMiscPlacement:FireServer(data.GUID, res)
    end)

    RequestMiscSelection.OnClientEvent:Connect(function(data)
        local res = Module.StartSelection(data or { FarmsDisabled = true })
        RequestMiscSelection:FireServer(data.GUID, res)
    end)

    RequestMiscEnemySelection.OnClientEvent:Connect(function(data)
        local res = Module.StartEnemySelection(data or {})
        RequestMiscEnemySelection:FireServer(data.GUID, res)
    end)

    GameHandler.MatchRestarted:Connect(function()
        Module.CancelAll()
    end)
end)

return Module