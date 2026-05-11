local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("UpgradeInterfaces")

-- Modules
local Spring = require(ReplicatedStorage.Modules.Packages.Spring)
local Logger = require(ReplicatedStorage.Modules.Shared.DebugToggleHandler)
    .CreateStructuredLogger("interface")

local ClientUnitHandler = require(StarterPlayer.Modules.Gameplay.Units.ClientUnitHandler)
local UnitHideHandler = require(StarterPlayer.Modules.Gameplay.Units.UnitHideHandler)
local ClientUnitDataHandler = require(StarterPlayer.Modules.Gameplay.Units.ClientUnitDataHandler)

local AutoUpgradeDataHandler = require(StarterPlayer.Modules.Gameplay.UnitManager.AutoUpgrade.AutoUpgradeDataHandler)

local KeybindsDataHandler = require(
    StarterPlayer.Modules.Gameplay.Keybinds.KeybindsDataHandler
)

local GlobalMatchSettings = require(
    ReplicatedStorage.Modules.Data.GlobalMatchSettings
)

local SkillTreeClient = require(
    StarterPlayer.Modules.Gameplay.ElementalTowers.SkillTreeClient
)

local Vide = require(ReplicatedStorage.nui).vide

-- Networking
local Networking = ReplicatedStorage.Networking

local AutoAbilityEvent =
    Networking.ClientListeners.Units.AutoAbilityEvent

local UpdateUnitElements =
    Networking.Units.UpdateUnitElements

-- Managers
local UICreationManager = require(script.Managers.UICreationManager)
local DisplaysManager = require(script.Managers.DisplaysManager)
local InputManager = require(script.Managers.InputManager)
local ButtonsManager = require(script.Managers.ButtonsManager)
local AbilitiesManager = require(script.Managers.AbilitiesManager)

local Events = require(script.Events)

-- Public API
local UpgradeInterface = {
    UpgradeInterfaceShown = Events.UpgradeInterfaceShown,
    UpgradeInterfaceHidden = Events.UpgradeInterfaceHidden
}

-- State
local Connections = {}
local ActiveInterface = nil
local SelectedUnitGUID = nil
local ActiveTemplate = nil
local CachedData = {}

-- Close Interface
local function CloseUpgradeInterface(unit)
    if not ActiveInterface then
        return
    end

    if unit and SelectedUnitGUID ~= unit.UniqueIdentifier then
        return
    end

    UpgradeInterface.UpgradeInterfaceHidden:Fire()

    Spring.target(ActiveInterface, 0.55, 5, {
        Position = ActiveInterface.Position - UDim2.fromScale(0.4, 0)
    })

    Debris:AddItem(ActiveInterface, 0.4)

    ActiveInterface = nil
    SelectedUnitGUID = nil
    ActiveTemplate = nil

    for _, connection in Connections do
        connection:Disconnect()
    end

    table.clear(Connections)
    table.clear(CachedData)
end

-- Open Interface
local function OpenUpgradeInterface(unit)
    local hadPreviousInterface = ActiveInterface ~= nil

    CloseUpgradeInterface()

    if hadPreviousInterface then
        Logger(nil, "upgrade_ui_stale_close", {
            outcome = "success",
            unit_guid = unit.UniqueIdentifier,
            unit_name = unit.Name
        })
    end

    SelectedUnitGUID = unit.UniqueIdentifier

    ActiveInterface =
        UICreationManager.CreateUpgradeInterface(unit)

    UpgradeInterface.UpgradeInterfaceShown:Fire(
        ActiveInterface,
        unit.Data or unit.UnitData,
        unit
    )

    for _, connection in Connections do
        connection:Disconnect()
    end

    table.clear(Connections)

    DisplaysManager.UpdateAllDisplays(
        unit,
        ActiveInterface,
        Connections
    )

    ButtonsManager.SetupAllButtons(
        unit,
        ActiveInterface,
        Connections,
        CachedData
    )

    AbilitiesManager.HandleAbilities(
        unit,
        ActiveInterface,
        function()
            CloseUpgradeInterface()
        end
    )

    ActiveTemplate = UICreationManager.GetActiveTemplate()

    local inputConnection = InputManager.SetupUnitInputs(
        unit,
        SelectedUnitGUID,
        ActiveInterface,
        CachedData
    )

    table.insert(Connections, inputConnection)
end

-- API Methods
function UpgradeInterface.HandleUpgrade(unit)
    return ButtonsManager.HandleUpgrade(unit)
end

function UpgradeInterface.CloseInterface()
    return CloseUpgradeInterface()
end

function UpgradeInterface.GetInterface()
    return ActiveInterface
end

UpgradeInterface.GetUpgradePrice =
    ButtonsManager.GetUpgradePrice

-- Event Setup
task.spawn(function()

    ClientUnitHandler.OnUnitSelected:Connect(function(_, unit)
        OpenUpgradeInterface(unit)
    end)

    ClientUnitHandler.OnUnitDeselected:Connect(function(unit)
        CloseUpgradeInterface(unit)
    end)

    ClientUnitHandler.OnUnitUpgraded:Connect(function(unit)
        if SelectedUnitGUID == unit.UniqueIdentifier then
            DisplaysManager.HandleUpgradeDisplay(
                unit,
                ActiveInterface,
                "Upgrade"
            )
        end
    end)

    ClientUnitHandler.OnUnitPriorityChanged:Connect(function(unit)
        if SelectedUnitGUID == unit.UniqueIdentifier then
            DisplaysManager.HandleUnitPriorityLabel(
                unit,
                ActiveInterface
            )
        end
    end)

    ClientUnitHandler.OnUnitStatChanged:Connect(function(unit)
        if SelectedUnitGUID == unit.UniqueIdentifier then
            DisplaysManager.HandleUpgradeDisplay(
                unit,
                ActiveInterface,
                "Upgrade"
            )
        end
    end)

    ClientUnitHandler.OnUnitSellValueRemoved:Connect(function(unit)
        if SelectedUnitGUID == unit.UniqueIdentifier then
            DisplaysManager.HandleUpgradeDisplay(
                unit,
                ActiveInterface
            )
        end
    end)

    UnitHideHandler.UnitHidden:Connect(function(unitGUID)
        if SelectedUnitGUID == unitGUID then
            CloseUpgradeInterface()
        end
    end)

    AutoAbilityEvent.OnClientEvent:Connect(function(
        unitGUID,
        value1,
        value2
    )
        if SelectedUnitGUID == unitGUID then
            AbilitiesManager.AnimateAutoAbilitySlider(
                value1,
                value2,
                ActiveInterface
            )
        end
    end)

    ClientUnitDataHandler.UnitPropertyChanged:Connect(function(unitGUID)
        if SelectedUnitGUID ~= unitGUID then
            return
        end

        local unit =
            ClientUnitHandler._ActiveUnits[unitGUID]

        assert(unit, "No unit object!")

        DisplaysManager.HandleUpgradeDisplay(
            unit,
            ActiveInterface
        )
    end)

    UpdateUnitElements.OnClientEvent:Connect(function(
        unitGUID,
        elements
    )
        local unit =
            ClientUnitHandler._ActiveUnits[unitGUID]

        if not unit then
            warn("UpdateUnitElements failed, unit not found!")
            return
        end

        local updatedPosition = false

        for _, element in elements do
            if typeof(element) == "table"
                and element.Name == "Position"
            then
                updatedPosition = true

                local position = element.Value

                unit.Position = position

                if unit.CFrameValue then
                    local rotation =
                        unit.Rotation
                        and CFrame.Angles(
                            0,
                            math.rad(unit.Rotation),
                            0
                        )
                        or CFrame.identity

                    unit.CFrameValue.Value =
                        CFrame.new(position) * rotation
                end
            end
        end

        if not updatedPosition then
            unit.Data.Elements = elements

            UICreationManager.CreateElementFrames(
                unit,
                ActiveInterface
            )
        end
    end)

    KeybindsDataHandler.KeybindsUpdated:Connect(function()
        if not ActiveInterface then
            return
        end

        local keybinds = ActiveInterface.Keybinds
        local leftSide = ActiveInterface.Main.LeftSide

        local upgradeBind =
            KeybindsDataHandler.GetBind("Upgrade").Name

        local autoUpgradeBind =
            KeybindsDataHandler
                .GetBind("ToggleAutoUpgrade").Name

        keybinds.Upgrade.Keybind.Label.Text =
            upgradeBind

        keybinds.ToggleAutoUpgrade.Keybind.Label.Text =
            autoUpgradeBind

        leftSide.Button.KeybindButton.Keybind =
            upgradeBind
    end)

    AutoUpgradeDataHandler.AutoUpgradeToggled:Connect(
        function(unitGUID, enabled)

            if not ActiveInterface then
                return
            end

            if SelectedUnitGUID ~= unitGUID then
                return
            end

            if enabled then
                ActiveInterface.Keybinds
                    .ToggleAutoUpgrade.Action.TextColor3 =
                    Color3.fromRGB(0, 255, 17)
            else
                ActiveInterface.Keybinds
                    .ToggleAutoUpgrade.Action.TextColor3 =
                    Color3.fromRGB(255, 255, 255)
            end
        end
    )

    GlobalMatchSettings.SettingsUpdated:Connect(function()

        local unit =
            ActiveInterface
            and SelectedUnitGUID
            and ClientUnitHandler._ActiveUnits[SelectedUnitGUID]

        if unit then
            DisplaysManager.HandleUpgradeDisplay(
                unit,
                ActiveInterface
            )
        end
    end)
end)

return UpgradeInterface