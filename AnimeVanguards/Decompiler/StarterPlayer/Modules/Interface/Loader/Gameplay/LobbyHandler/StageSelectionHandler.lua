--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--// Player
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

--// Modules
local StagesData = require(ReplicatedStorage.Modules.Data.StagesData)
local PlaceIdData = require(ReplicatedStorage.Modules.Data.PlaceIdData)

local FastSignal = require(ReplicatedStorage.Modules.Packages.FastSignal)

local InterfaceUtils = require(ReplicatedStorage.Modules.Interface.InterfaceUtils)
local FrameUtils = require(ReplicatedStorage.Modules.Utilities.FrameUtils)
local UIResizeHandler = require(
	ReplicatedStorage.Modules.Interface.UIResizeHandler
)

local ElementalTowersClient = require(
	StarterPlayer.Modules.Gameplay.ElementalTowers.ElementalTowersClient
)

local ActInfoHandler = require(
	script.Parent.StageInfo.ActInfoHandler
)

local LobbyState = require(
	StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.LobbyState
)

local MatchmakingOptionsHandler = require(
	StarterPlayer.Modules.Interface.Loader.Gameplay.LobbyHandler.Options.MatchmakingOptionsHandler
)

local TooltipHandler = require(
	StarterPlayer.Modules.Interface.Loader.ConsoleTooltipHandler
)

local HoverHandler = require(
	StarterPlayer.Modules.Miscellaneous.HoverHandler
)

local ActSelectionHandler = require(
	StarterPlayer.Modules.Gameplay.Selection.ActSelectionHandler
)

local SelectionHandler = require(
	StarterPlayer.Modules.Gameplay.Selection.SelectionHandler
)

--// Gamemodes
local DefaultGamemode = require(
	script.Parent.Gamemodes.DefaultGamemode
)

local ElementalTowersGamemode = require(
	script.Parent.Gamemodes.ElementalTowersGamemode
)

--// Networking
local Networking = ReplicatedStorage.Networking

local LobbyEvent = Networking.LobbyEvent

local RerollFloorMap = Networking.ElementalTowers:FindFirstChild(
	"RerollFloorMap"
)

--------------------------------------------------------------------------------
-- MODULE
--------------------------------------------------------------------------------

local StageSelectionHandler = {
	StageSelected = FastSignal.new()
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local LobbyUI = nil

local StageFrames = {}
local ActFrames = {}

local CurrentGamemode = nil

local SelectedStageTypeFrame = nil
local SelectedDifficultyFrame = nil

local StageTypeFrames = {}
local DifficultyFrames = {}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function clearFrames(frames)
	for _, frame in ipairs(frames) do
		frame:Destroy()
	end

	table.clear(frames)
end

local function getContext()
	return {
		LobbyInterface = LobbyUI,

		StageFrames = StageFrames,
		ActFrames = ActFrames,

		Templates = {
			StageTemplate = script.StageTemplate,
			ActsTemplate = script.ActsTemplate
		},

		ClearActs = function()
			clearFrames(ActFrames)
		end
	}
end

--------------------------------------------------------------------------------
-- STAGE TYPES
--------------------------------------------------------------------------------

local function setupStageTypes(defaultType)

	local container = LobbyUI.Holder.StageTypes

	table.clear(StageTypeFrames)

	SelectedStageTypeFrame = nil

	for _, frame in ipairs(container:GetChildren()) do

		if not frame:IsA("Frame") then
			continue
		end

		local stageType = frame.Name

		if stageType ~= "Story"
			and stageType ~= "LegendStage" then
			continue
		end

		FrameUtils.CreateDarkFrame(frame)

		StageTypeFrames[stageType] = frame

		frame.Button.Activated:Connect(function()

			if SelectedStageTypeFrame then
				local dark =
					SelectedStageTypeFrame:FindFirstChild("DarkFrame")

				if dark then
					dark.Visible = true
				end
			end

			local dark = frame:FindFirstChild("DarkFrame")

			if dark then
				dark.Visible = false
			end

			SelectedStageTypeFrame = frame

			StageSelectionHandler.SetupInterface(stageType)
		end)
	end

	if defaultType then
		local frame = StageTypeFrames[defaultType]

		if frame then
			local dark = frame:FindFirstChild("DarkFrame")

			if dark then
				dark.Visible = false
			end

			SelectedStageTypeFrame = frame
		end
	end
end

--------------------------------------------------------------------------------
-- DIFFICULTY
--------------------------------------------------------------------------------

local function setupDifficultyButtons()

	local difficulties =
		LobbyUI.Holder.ActInfo.Difficulties

	table.clear(DifficultyFrames)

	DifficultyFrames.Normal = difficulties.Normal
	DifficultyFrames.Nightmare = difficulties.Nightmare

	for _, frame in ipairs(difficulties:GetChildren()) do

		if not frame:IsA("Frame") then
			continue
		end

		if frame:HasTag("IgnoreFrame") then
			continue
		end

		FrameUtils.CreateDarkFrame(frame)

		frame.Button.Activated:Connect(function()

			local difficulty = frame.Name

			LobbyState.SetDifficulty(difficulty)

			if SelectedDifficultyFrame then
				local dark =
					SelectedDifficultyFrame:FindFirstChild("DarkFrame")

				if dark then
					dark.Visible = true
				end
			end

			local dark = frame:FindFirstChild("DarkFrame")

			if dark then
				dark.Visible = false
			end

			SelectedDifficultyFrame = frame
		end)
	end

	SelectedDifficultyFrame = DifficultyFrames.Normal

	local dark =
		SelectedDifficultyFrame:FindFirstChild("DarkFrame")

	if dark then
		dark.Visible = false
	end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

local function closeInterface()

	if not LobbyUI then
		return
	end

	LobbyUI:Destroy()
	LobbyUI = nil

	clearFrames(StageFrames)
	clearFrames(ActFrames)

	LobbyState.Reset()

	if CurrentGamemode and CurrentGamemode.Cleanup then
		CurrentGamemode:Cleanup()
	end

	CurrentGamemode = nil

	SelectedStageTypeFrame = nil
	SelectedDifficultyFrame = nil

	table.clear(StageTypeFrames)
	table.clear(DifficultyFrames)
end

StageSelectionHandler.CloseInterface = closeInterface

--------------------------------------------------------------------------------
-- SELECT API
--------------------------------------------------------------------------------

function StageSelectionHandler.SelectStage(stage)
	if CurrentGamemode and CurrentGamemode.SelectStage then
		CurrentGamemode:SelectStage(stage)
	end
end

function StageSelectionHandler.SelectAct(act)
	if CurrentGamemode and CurrentGamemode.SelectAct then
		CurrentGamemode:SelectAct(act)
	end
end

function StageSelectionHandler.SelectTowerFloor(...)
	if CurrentGamemode and CurrentGamemode.SelectTowerFloor then

		CurrentGamemode:SelectTowerFloor(...)
	end
end

--------------------------------------------------------------------------------
-- SETUP INTERFACE
--------------------------------------------------------------------------------

function StageSelectionHandler.SetupInterface(stageType)

	stageType = stageType or "Story"

	LobbyState.SetStageType(stageType)
	LobbyState.SetDifficulty("Normal")
	LobbyState.SetFriendsOnly(false)

	clearFrames(StageFrames)
	clearFrames(ActFrames)

	if CurrentGamemode and CurrentGamemode.Cleanup then
		CurrentGamemode:Cleanup()
	end

	local context = getContext()

	----------------------------------------------------------------
	-- ELEMENTAL TOWERS
	----------------------------------------------------------------

	if stageType == "ElementalTowers" then

		CurrentGamemode =
			ElementalTowersGamemode.new(context)

		CurrentGamemode:LoadStages()

	----------------------------------------------------------------
	-- DEFAULT
	----------------------------------------------------------------

	else

		CurrentGamemode =
			DefaultGamemode.new(context)

		local defaultStage =
			CurrentGamemode:GetDefaultStage()

		LobbyState.SetStage(defaultStage)

		LobbyState.SetAct(
			CurrentGamemode:GetDefaultAct(defaultStage)
		)

		CurrentGamemode:LoadStages()
		CurrentGamemode:LoadActs(defaultStage)

		StageSelectionHandler.SelectStage(defaultStage)
	end

	InterfaceUtils.SpringList(
		LobbyUI.Holder.Stages,
		{
			SizeOffset = 25
		}
	)
end

--------------------------------------------------------------------------------
-- OPEN INTERFACE
--------------------------------------------------------------------------------

function StageSelectionHandler.OpenInterface(stageType)

	if LobbyUI then
		return
	end

	local ui = script.Lobby:Clone()

	ui.Enabled = true
	ui.Parent = PlayerGui

	LobbyUI = ui

	local holder = ui.Holder
	local stageTypes = holder.StageTypes

	----------------------------------------------------------------
	-- STAGE TYPES
	----------------------------------------------------------------

	if stageType == "Story"
		or stageType == "LegendStage" then

		setupStageTypes(stageType)

	else
		stageTypes.Visible = false
	end

	----------------------------------------------------------------
	-- DIFFICULTY
	----------------------------------------------------------------

	setupDifficultyButtons()

	----------------------------------------------------------------
	-- BUTTONS
	----------------------------------------------------------------

	holder.Buttons.Leave.Button.Activated:Connect(
		closeInterface
	)

	holder.Buttons.Start.Button.Activated:Connect(function()

		local data = LobbyState.Get()

		if PlaceIdData.IsMatch() then
			LobbyEvent:FireServer("StartMatch", data)

		elseif PlaceIdData.IsLobby() then
			LobbyEvent:FireServer("AddMatch", data)
		end

		StageSelectionHandler.StageSelected:Fire(data)

		closeInterface()
	end)

	----------------------------------------------------------------
	-- FIND MATCH
	----------------------------------------------------------------

	if not PlaceIdData.IsMatch() then

		holder.Buttons.FindMatch.Button.Activated:Connect(function()

			MatchmakingOptionsHandler.StartChooseOptions(
				LobbyState.Get()
			)
		end)
	end

	----------------------------------------------------------------
	-- REROLL MAP
	----------------------------------------------------------------

	local rerollButton =
		holder.Buttons:FindFirstChild("RerollMap")

	if rerollButton and RerollFloorMap then

		rerollButton.Visible =
			stageType == "ElementalTowers"

		local button =
			rerollButton:FindFirstChild("Button")

		if button and button:IsA("GuiButton") then

			button.Activated:Connect(function()

				if LobbyState.StageType
					~= "ElementalTowers" then
					return
				end

				local stage = LobbyState.Stage
				local floor = tonumber(LobbyState.Act)

				if stage and floor then
					RerollFloorMap:FireServer(stage, floor)
				end
			end)
		end
	end

	----------------------------------------------------------------
	-- FINAL SETUP
	----------------------------------------------------------------

	InterfaceUtils.AnimateInterface(ui)

	StageSelectionHandler.SetupInterface(stageType)

	UIResizeHandler.ScaleCanvasSize(
		ui.Holder.Acts,
		ui.UIScale,
		18
	)

	UIResizeHandler.ScaleCanvasSize(
		ui.Holder.Stages,
		ui.UIScale,
		18
	)

	if PlaceIdData.IsMatch() then

		holder.Buttons.FindMatch.Visible = false
		holder.FriendsOnly.Visible = false
		holder.MaxPlayers.Visible = false
	end
end

--------------------------------------------------------------------------------
-- EVENTS
--------------------------------------------------------------------------------

task.spawn(function()

	TooltipHandler.BackedEvent:Connect(function()
		task.delay(0.1, closeInterface)
	end)

	LobbyState.DifficultyChanged:Connect(function(difficulty)

		local frame = DifficultyFrames[difficulty]

		if frame then

			if SelectedDifficultyFrame then
				local dark =
					SelectedDifficultyFrame:FindFirstChild("DarkFrame")

				if dark then
					dark.Visible = true
				end
			end

			local dark = frame:FindFirstChild("DarkFrame")

			if dark then
				dark.Visible = false
			end

			SelectedDifficultyFrame = frame
		end

		ActInfoHandler.DifficultyChanged:Fire(
			difficulty
		)
	end)
end)

return StageSelectionHandler