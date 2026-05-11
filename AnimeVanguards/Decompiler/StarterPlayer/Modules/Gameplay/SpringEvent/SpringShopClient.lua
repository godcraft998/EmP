--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--// Modules
local FastSignal = require(ReplicatedStorage.Modules.Packages.FastSignal)
local ShopData = require(ReplicatedStorage.Modules.Data.SpringEvent.ShopData)
local GameHandler = require(ReplicatedStorage.Modules.Gameplay.GameHandler)
local GlobalMatchSettings = require(ReplicatedStorage.Modules.Data.GlobalMatchSettings)
local PlacementCapHooks = require(ReplicatedStorage.Modules.Shared.PlacementCapHooks)
local ClientUnitHandler = require(StarterPlayer.Modules.Gameplay.Units.ClientUnitHandler)

local source = require(ReplicatedStorage.nui).vide.source

--// Player & Remote
local LocalPlayer = Players.LocalPlayer
local ShopRemote = ReplicatedStorage.Networking.SpringEvent.ShopEvent

--// Main controller
local SpringShopController = {
    Changed = FastSignal.new(),

    PurchasesSource = source({}),
    EligibilityVersion = source(0),
}

--////////////////////////////////////////////////////////////
--// Trait Eligibility
--////////////////////////////////////////////////////////////

function SpringShopController.GetEligibleUnitCountForTrait(traitName)
    if not traitName then
        return 0
    end

    local eligible = 0

    for _, unit in ClientUnitHandler._ActiveUnits do
        if unit.Player == LocalPlayer then
            local currentTrait = unit.Trait and unit.Trait.Name

            -- unit chưa có trait này
            if currentTrait ~= traitName then
                eligible += 1
            end
        end
    end

    return eligible
end

--////////////////////////////////////////////////////////////
--// Refresh eligibility version
--////////////////////////////////////////////////////////////

local function refreshEligibility()
    SpringShopController.EligibilityVersion(
        SpringShopController.EligibilityVersion() + 1
    )
end

ClientUnitHandler.OnUnitPlaced:Connect(refreshEligibility)
ClientUnitHandler.UnitRemoved:Connect(refreshEligibility)
GlobalMatchSettings.SettingsUpdated:Connect(refreshEligibility)

--////////////////////////////////////////////////////////////
--// State
--////////////////////////////////////////////////////////////

local state = {
    Active = false,
    Purchases = {}
}

-- slot => extra placements
local extraPlacementCache = {}

--////////////////////////////////////////////////////////////
--// Rebuild placement cache
--////////////////////////////////////////////////////////////

local function rebuildPlacementCache()
    table.clear(extraPlacementCache)

    for itemId, amount in state.Purchases do
        if amount > 0 then
            local itemData = ShopData.GetItem(itemId)

            if itemData and itemData.Kind == "ExtraPlacementSlot" then
                local slot = itemData.Slot

                if slot then
                    extraPlacementCache[slot] =
                        (extraPlacementCache[slot] or 0) + amount
                end
            end
        end
    end
end

--////////////////////////////////////////////////////////////
--// Helpers
--////////////////////////////////////////////////////////////

local function isSpringEvent()
    if not GameHandler.IsGameLoaded then
        return false
    end

    local gameData = GameHandler.GameData

    return gameData
        and gameData.StageType == "LTM"
        and gameData.Stage == "Spring"
end

--////////////////////////////////////////////////////////////
--// Public API
--////////////////////////////////////////////////////////////

function SpringShopController.GetExtraPlacementsForSlot(slot)
    if not isSpringEvent() then
        return 0
    end

    return extraPlacementCache[slot] or 0
end

function SpringShopController.Snapshot()
    return {
        Purchases = state.Purchases,
        Active = state.Active
    }
end

function SpringShopController.IsActive()
    return state.Active
end

function SpringShopController.OnChanged(callback)
    return SpringShopController.Changed:Connect(callback)
end

--////////////////////////////////////////////////////////////
--// Remote events
--////////////////////////////////////////////////////////////

ShopRemote.OnClientEvent:Connect(function(action, data)

    --==============================
    -- Open shop
    --==============================
    if action == "Open" then
        state.Active = true

        if typeof(data) == "table" then

            if typeof(data.Active) == "boolean" then
                state.Active = data.Active
            end

            if typeof(data.Purchases) == "table" then
                state.Purchases = data.Purchases

                rebuildPlacementCache()

                SpringShopController.PurchasesSource(data.Purchases)
                SpringShopController.Changed:Fire()

                return
            end
        end

        SpringShopController.Changed:Fire()

    --==============================
    -- Update snapshot
    --==============================
    elseif action == "Snapshot" then

        if typeof(data) == "table"
            and typeof(data.Purchases) == "table" then

            state.Purchases = data.Purchases

            rebuildPlacementCache()

            SpringShopController.PurchasesSource(data.Purchases)
            SpringShopController.Changed:Fire()

            return
        end

    --==============================
    -- Close shop
    --==============================
    elseif action == "Close" then

        state.Active = false
        state.Purchases = {}

        rebuildPlacementCache()

        SpringShopController.PurchasesSource({})
        SpringShopController.Changed:Fire()
    end
end)

--////////////////////////////////////////////////////////////
--// Initial sync
--////////////////////////////////////////////////////////////

task.spawn(function()

    if not GameHandler.IsGameLoaded then
        GameHandler.GameLoaded:Wait()
    end

    if isSpringEvent() then
        ShopRemote:FireServer("RequestState")
    end
end)

--////////////////////////////////////////////////////////////
--// Match started sync
--////////////////////////////////////////////////////////////

GameHandler.MatchStarted:Connect(function()

    if isSpringEvent() then
        ShopRemote:FireServer("RequestState")
    end
end)

--////////////////////////////////////////////////////////////
--// Placement cap hook
--////////////////////////////////////////////////////////////

PlacementCapHooks.Hooks:AddGlobal(function(_, slot)

    if not slot then
        return nil
    end

    local extraSlots =
        SpringShopController.GetExtraPlacementsForSlot(slot)

    if extraSlots > 0 then
        return {
            BypassMonarchCap = false,
            ExtraSlots = extraSlots
        }
    end

    return nil
end)

return SpringShopController