-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Player
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Modules
local StagesData = require(ReplicatedStorage.Modules.Data.StagesData)
local FastSignal = require(ReplicatedStorage.Modules.Packages.FastSignal)
local UIResizeHandler = require(ReplicatedStorage.Modules.Interface.UIResizeHandler)
local InterfaceUtils = require(ReplicatedStorage.Modules.Interface.InterfaceUtils)

local ActInfoHandler = require(script.Parent.Parent.StageInfo.ActInfoHandler)
local FiltersHandler = require(StarterPlayer.Modules.Interface.Loader.FiltersHandler)
local TooltipHandler = require(StarterPlayer.Modules.Interface.Loader.ConsoleTooltipHandler)

-- Networking
local Networking = ReplicatedStorage.Networking
local LobbyEvent = Networking.LobbyEvent
local MatchReplicationEvent = Networking.MatchReplicationEvent
local PortalEvent = Networking.Portals.PortalEvent

----------------------------------------------------------------
-- Public API (signals)
----------------------------------------------------------------
local MatchListHandler = {
    MatchAdded = FastSignal.new(),
    MatchRemoved = FastSignal.new(),
    MatchCountChanged = FastSignal.new()
}

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local Matches = {}          -- GUID -> match data (raw từ server)
local MatchFrames = {}      -- GUID -> UI + metadata
local MatchesUI = nil
local ActiveMatchCount = 0

----------------------------------------------------------------
-- API
----------------------------------------------------------------
function MatchListHandler.GetActiveMatchesCount()
    return ActiveMatchCount
end

----------------------------------------------------------------
-- Create 1 match UI
----------------------------------------------------------------
local function createMatchFrame(matchData)
    if not MatchesUI then return end

    local guid = matchData.GUID
    local host = matchData.Host
    local players = matchData.Players

    if not (host and host.UserId) then return end

    local stageType = matchData.StageType
    local stage = matchData.Stage
    local act = matchData.Act
    local difficulty = matchData.Difficulty
    local maxPlayers = matchData.MaxPlayers

    local portalData = matchData.PortalData
    local portalGUID = matchData.PortalGUID
    local portalName = matchData.PortalName

    ----------------------------------------------------------------
    -- Resolve stage data
    ----------------------------------------------------------------
    local stageData, actData

    if stageType == "ElementalTowers" then
        local floor = StagesData.GetTowerElementIndex(stage)
        local seedData = StagesData.GetFloorDataForSeed(host.UserId * act + floor * 58)

        local story = StagesData.Story[seedData.Stage]
        stageData = story.StageData
        actData = story.Acts[seedData.Act]

        actData.Rewards = StagesData:GetRewards({
            StageType = stageType,
            ElementalTowersData = { Floor = floor }
        })
    else
        stageData = StagesData:GetStageData(stageType, stage)
        actData = StagesData:GetActData(stageType, stage, act)
    end

    assert(stageData, ("Missing stage data: %s %s"):format(stageType, stage))

    ----------------------------------------------------------------
    -- UI Creation
    ----------------------------------------------------------------
    local frame = script.MatchFrame:Clone()
    frame.Parent = MatchesUI.Holder.MatchList

    frame.Background.Image = stageData.Background

    local stageName = stageData.Name
    local actIndex = actData.ActIndex

    -- Title logic
    local title =
        matchData.LobbyName
        or (portalData and ("[Tier %s] - %s"):format(portalData.Tier, portalName))
        or stageName

    frame.StageInfo.StageName.Text = title
    frame.StageInfo.ActName.Text = ("%s - %s"):format(stageName, actIndex)
    frame.StageInfo.Difficulty.Text = difficulty or "Normal"

    frame.HostFrame.OwnerName.Text = ("@%s"):format(host.Name or host.UserId)
    frame.HostFrame.PlayerAmount.Text = ("Players: (%d/%d)"):format(#players, maxPlayers)

    ----------------------------------------------------------------
    -- Hover (act info)
    ----------------------------------------------------------------
    frame.MouseEnter:Connect(function()
        local actInfoUI = MatchesUI.Holder.ActInfo
        actInfoUI.BaseFrame.Visible = false

        ActInfoHandler.SetupMatchActInfo(
            actInfoUI,
            stageType,
            stageData,
            actData,
            difficulty,
            { PortalData = portalData }
        )
    end)

    ----------------------------------------------------------------
    -- Join logic
    ----------------------------------------------------------------
    frame.Button.Activated:Connect(function()
        if portalData then
            PortalEvent:FireServer("JoinPortal", portalGUID)
        else
            LobbyEvent:FireServer("JoinMatch", guid)
        end
    end)

    ----------------------------------------------------------------
    -- Player count updater
    ----------------------------------------------------------------
    local updateSignal = FastSignal.new()
    updateSignal:Connect(function(count)
        frame.HostFrame.PlayerAmount.Text = ("Players: (%d/%d)"):format(count, maxPlayers)
    end)

    ----------------------------------------------------------------
    -- Store reference
    ----------------------------------------------------------------
    MatchFrames[guid] = {
        Frame = frame,
        UpdatePlayersSignal = updateSignal,
        PortalData = portalData,
        StageType = stageType,

        Remove = function()
            updateSignal:Destroy()
            frame:Destroy()
        end
    }
end

----------------------------------------------------------------
-- Destroy UI
----------------------------------------------------------------
local function destroyInterface()
    if not MatchesUI then return end

    for guid, data in pairs(MatchFrames) do
        data.Remove()
        MatchFrames[guid] = nil
    end

    table.clear(MatchFrames)

    MatchesUI:Destroy()
    MatchesUI = nil
end

----------------------------------------------------------------
-- Open UI
----------------------------------------------------------------
function MatchListHandler.OpenInterface(defaultFilter)
    if MatchesUI then return end

    local ui = script.Matches:Clone()
    ui.Parent = PlayerGui
    MatchesUI = ui

    InterfaceUtils.AnimateInterface(ui)

    -- Load existing matches
    for _, match in pairs(Matches) do
        createMatchFrame(match)
    end

    ----------------------------------------------------------------
    -- Close button
    ----------------------------------------------------------------
    ui.Holder.Close.Button.Activated:Connect(destroyInterface)

    ----------------------------------------------------------------
    -- Filters
    ----------------------------------------------------------------
    FiltersHandler.CreateFilters(
        ui.Holder.Filters,
        { "All", "Story", "Raid", "Challenges", "BossEvent", "Portals" },
        function(filter)
            for _, data in pairs(MatchFrames) do
                local visible = (filter == "All") or (data.StageType == filter)
                data.Frame.Visible = visible
            end

            InterfaceUtils.SpringList(ui.Holder.MatchList, {
                SizeOffset = 25
            })
        end,
        {
            DefaultSelected = defaultFilter or "All",
            TextSize = 22
        }
    )
end

MatchListHandler.CloseInterface = destroyInterface

----------------------------------------------------------------
-- Networking
----------------------------------------------------------------
task.spawn(function()

    -- Close on back
    TooltipHandler.BackedEvent:Connect(function()
        task.delay(0.1, destroyInterface)
    end)

    -- Request data from server
    MatchReplicationEvent:FireServer("RetrieveMatches")

    -- Receive updates
    MatchReplicationEvent.OnClientEvent:Connect(function(action, data)

        ----------------------------------------------------------------
        -- ADD
        ----------------------------------------------------------------
        if action == "AddMatch" then
            Matches[data.GUID] = data
            createMatchFrame(data)
            MatchListHandler.MatchAdded:Fire(data)
            return
        end

        ----------------------------------------------------------------
        -- REMOVE
        ----------------------------------------------------------------
        if action == "RemoveMatch" then
            Matches[data] = nil

            local frameData = MatchFrames[data]
            if frameData then
                frameData.Remove()
                MatchFrames[data] = nil
            end

            MatchListHandler.MatchRemoved:Fire(data)
            return
        end

        ----------------------------------------------------------------
        -- UPDATE PLAYERS
        ----------------------------------------------------------------
        if action == "UpdateMatchPlayers" then
            local guid = data.GUID
            local count = #data.Players

            local frameData = MatchFrames[guid]
            if frameData then
                frameData.UpdatePlayersSignal:Fire(count)
            end

            if Matches[guid] then
                Matches[guid].Players = data.Players
            end
            return
        end

        ----------------------------------------------------------------
        -- LOAD ALL
        ----------------------------------------------------------------
        if action == "LoadMatches" then
            for guid, match in pairs(data) do
                Matches[guid] = match
                createMatchFrame(match)
            end
            return
        end

        ----------------------------------------------------------------
        -- COUNT
        ----------------------------------------------------------------
        if action == "UpdateMatchCount" then
            ActiveMatchCount = data
            MatchListHandler.MatchCountChanged:Fire(data)
        end
    end)
end)

return MatchListHandler