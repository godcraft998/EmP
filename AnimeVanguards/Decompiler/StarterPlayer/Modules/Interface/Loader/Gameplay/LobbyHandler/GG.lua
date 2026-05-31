--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--------------------------------------------------------------------------------
-- MODULES
--------------------------------------------------------------------------------

local StagesData =
	require(ReplicatedStorage.Modules.Data.StagesData)

local PlayerLobbyDataHandler =
	require(script.Parent.Parent.PlayerLobbyDataHandler)

local ActInfoHandler =
	require(script.Parent.Parent.StageInfo.ActInfoHandler)

local LobbyState =
	require(script.Parent.Parent.LobbyState)

local InterfaceUtils =
	require(ReplicatedStorage.Modules.Interface.InterfaceUtils)

local TextUtils =
	require(ReplicatedStorage.Modules.Utilities.TextUtils)

local FrameUtils =
	require(ReplicatedStorage.Modules.Utilities.FrameUtils)

local Notifications =
	require(StarterPlayer.Modules.Interface.Loader.Notifications)

require(script.Parent.GamemodeTypes)

--------------------------------------------------------------------------------
-- CLASS
--------------------------------------------------------------------------------

local DefaultGamemode = {}
DefaultGamemode.__index = DefaultGamemode

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local ACT_LAYOUT_ORDERS = {
	Infinite = 99,
	Sandbox = -1
}

local DEFAULT_STAGES = {
	Story = "Stage1",
	LegendStage = "Stage2",
	Raid = "Stage1",
	Dungeon = "Stage2"
}

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

local function GetStageProgress(stageType, stageName)

	local completedActs = 0
	local highestInfiniteWave = 0

	local stageData =
		PlayerLobbyDataHandler.GetStageData(
			stageType,
			stageName
		)

	for actName, actData in stageData or {} do

		-- Normal completed acts
		if actName ~= "Infinite"
			and actName ~= "Sandbox"
			and actData.Completed
		then
			completedActs += 1
		end

		-- Infinite progress
		if actName == "Infinite"
			and actData.WavesCompleted
		then
			highestInfiniteWave =
				actData.WavesCompleted
		end
	end

	return {
		CompletedActs = completedActs,
		HighestInfiniteWave = highestInfiniteWave
	}
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

function DefaultGamemode.new(context)

	local self =
		setmetatable({}, DefaultGamemode)

	self.Context = context

	self.SelectedStageFrame = nil
	self.SelectedActFrame = nil

	self.StageFrameMap = {}
	self.ActFrameMap = {}

	return self
end

--------------------------------------------------------------------------------
-- DEFAULT SELECTIONS
--------------------------------------------------------------------------------

function DefaultGamemode.GetDefaultStage(_)

	return DEFAULT_STAGES[LobbyState.StageType]
		or "Stage1"
end

function DefaultGamemode.GetDefaultAct(_, stageName)

	local stageType = LobbyState.StageType

	-- Dungeon special acts
	if stageType == "Dungeon" then

		if stageName == "Stage2" then
			return "AntIsland"
		end

		if stageName == "Stage3" then
			return "FrozenVolcano"
		end

		if stageName == "Stage5" then
			return "Underworld"
		end
	end

	-- Raid special
	if stageType == "Raid"
		and stageName == "Stage3"
	then
		return "Act1"
	end

	return "Act1"
end

--------------------------------------------------------------------------------
-- VISUAL SELECTION
--------------------------------------------------------------------------------

function DefaultGamemode.SelectStageVisual(
	self,
	stageFrame
)

	local oldDarkFrame =
		self.SelectedStageFrame
		and self.SelectedStageFrame:FindFirstChild("DarkFrame")

	if oldDarkFrame then
		oldDarkFrame.Visible = true
	end

	local newDarkFrame =
		stageFrame
		and stageFrame:FindFirstChild("DarkFrame")

	if newDarkFrame then
		newDarkFrame.Visible = false
	end

	self.SelectedStageFrame = stageFrame
end

--------------------------------------------------------------------------------

function DefaultGamemode.SelectActVisual(
	self,
	actFrame
)

	local oldDarkFrame =
		self.SelectedActFrame
		and self.SelectedActFrame:FindFirstChild("DarkFrame")

	if oldDarkFrame then
		oldDarkFrame.Visible = true
	end

	local newDarkFrame =
		actFrame
		and actFrame:FindFirstChild("DarkFrame")

	if newDarkFrame then
		newDarkFrame.Visible = false
	end

	self.SelectedActFrame = actFrame
end

--------------------------------------------------------------------------------
-- STAGES
--------------------------------------------------------------------------------

function DefaultGamemode.CreateStageFrame(
	self,
	stageInfo
)

	local stageData = stageInfo.StageData

	local stageName = stageData.Name
	local stageIndex = stageInfo.StageIndex
	local background = stageData.Background

	local stageType = LobbyState.StageType

	local progress =
		GetStageProgress(stageType, stageIndex)

	local layoutOrder =
		TextUtils.GetNumberFromString(stageIndex)

	local isUnlocked =
		PlayerLobbyDataHandler.GetStageData(
			stageType,
			stageIndex
		) ~= nil

	--------------------------------------------------------------------------
	-- Create UI
	--------------------------------------------------------------------------

	local frame =
		self.Context.Templates.StageTemplate:Clone()

	frame.Name = stageIndex

	frame.AreaLabel.Text = stageName
	frame.Image.Image = background
	frame.LayoutOrder = layoutOrder

	--------------------------------------------------------------------------
	-- Progress
	--------------------------------------------------------------------------

	local totalActs =
		stageInfo.TotalActs
		or stageData.TotalActs

	frame.Info.LevelsCleared.Amount.Text =
		("%s/%s"):format(
			math.min(progress.CompletedActs, totalActs),
			totalActs
		)

	frame.Info.HighestWave.Amount.Text =
		progress.HighestInfiniteWave

	--------------------------------------------------------------------------
	-- Parent
	--------------------------------------------------------------------------

	frame.Parent =
		self.Context.LobbyInterface.Holder.Stages

	table.insert(
		self.Context.StageFrames,
		frame
	)

	self.StageFrameMap[stageIndex] = frame

	--------------------------------------------------------------------------
	-- Locked state
	--------------------------------------------------------------------------

	if isUnlocked then
		FrameUtils.CreateDarkFrame(frame)
	else
		FrameUtils.CreateLockedFrame(frame)
	end

	--------------------------------------------------------------------------
	-- Click event
	--------------------------------------------------------------------------

	frame.Button.Activated:Connect(function()
		self:SelectStage(stageIndex)
	end)
end

--------------------------------------------------------------------------------

function DefaultGamemode.LoadStages(self)

	for _, stageInfo in
		StagesData:GetAllStages(LobbyState.StageType)
	do

		if not stageInfo.StageData.HideStage then
			self:CreateStageFrame(stageInfo)
		end
	end
end

--------------------------------------------------------------------------------
-- ACTS
--------------------------------------------------------------------------------

function DefaultGamemode.CreateActFrame(
	self,
	actData,
	stageData
)

	local background = stageData.Background

	local actName = actData.ActName
	local actIndex = actData.ActIndex

	local stageType = LobbyState.StageType
	local selectedStage = LobbyState.Stage

	local layoutOrder =
		TextUtils.GetNumberFromString(actIndex)

	local isUnlocked =
		PlayerLobbyDataHandler.GetActData(
			stageType,
			selectedStage,
			actIndex
		) ~= nil

	local isViewOnly = actData.ViewOnly

	--------------------------------------------------------------------------
	-- Create frame
	--------------------------------------------------------------------------

	local frame =
		self.Context.Templates.ActsTemplate:Clone()

	frame.Name = actIndex

	--------------------------------------------------------------------------
	-- Act title
	--------------------------------------------------------------------------

	local actNumber =
		TextUtils.GetNumberFromString(actIndex)

	if actNumber and actIndex ~= "Infinite" then
		frame.ActIndex.Text =
			("Act %s"):format(actNumber)
	else
		frame.ActIndex.Text =
			string.gsub(
				actIndex,
				"(%l)(%u)",
				"%1 %2"
			)
	end

	--------------------------------------------------------------------------
	-- Display name
	--------------------------------------------------------------------------

	frame.ActLabel.Text =
		actName == "OccultHunt"
		and "Occult Hunt"
		or string.gsub(
			actName,
			"(%l)(%u)",
			"%1 %2"
		)

	frame.Image.Image = background

	frame.LayoutOrder =
		ACT_LAYOUT_ORDERS[actIndex]
		or layoutOrder

	frame.Parent =
		self.Context.LobbyInterface.Holder.Acts

	self.ActFrameMap[actIndex] = frame

	--------------------------------------------------------------------------
	-- Frame state
	--------------------------------------------------------------------------

	if isViewOnly then
		FrameUtils.CreateQuestionFrame(frame)

	elseif isUnlocked then
		FrameUtils.CreateDarkFrame(frame)

	else
		FrameUtils.CreateLockedFrame(frame)
	end

	--------------------------------------------------------------------------
	-- Click
	--------------------------------------------------------------------------

	frame.Button.Activated:Connect(function()
		self:SelectAct(actIndex)
	end)

	table.insert(
		self.Context.ActFrames,
		frame
	)
end

--------------------------------------------------------------------------------

function DefaultGamemode.LoadActs(
	self,
	stageName
)

	local stageType = LobbyState.StageType

	local stageData =
		StagesData:GetStageData(
			stageType,
			stageName
		)

	local acts =
		StagesData:GetAllActs(
			stageType,
			stageName
		)

	table.clear(self.ActFrameMap)

	self.SelectedActFrame = nil

	for _, actData in acts do
		self:CreateActFrame(actData, stageData)
	end
end

--------------------------------------------------------------------------------
-- SELECT STAGE
--------------------------------------------------------------------------------

function DefaultGamemode.SelectStage(
	self,
	stageName
)

	local stageType = LobbyState.StageType

	--------------------------------------------------------------------------
	-- LOCK CHECK
	--------------------------------------------------------------------------

	if not PlayerLobbyDataHandler.GetStageData(
		stageType,
		stageName
	) then

		return Notifications:CreateNotification({
			Name = "Failure",
			Text = "You don't have this stage unlocked!"
		})
	end

	--------------------------------------------------------------------------
	-- Update state
	--------------------------------------------------------------------------

	LobbyState.SetStage(stageName)

	self:SelectStageVisual(
		self.StageFrameMap[stageName]
	)

	--------------------------------------------------------------------------
	-- Reload acts
	--------------------------------------------------------------------------

	if self.Context.ClearActs then
		self.Context.ClearActs()
	end

	self:LoadActs(stageName)

	InterfaceUtils.SpringList(
		self.Context.LobbyInterface.Holder.Acts,
		{
			SizeOffset = 25
		}
	)

	--------------------------------------------------------------------------
	-- Select default act
	--------------------------------------------------------------------------

	self:SelectAct(
		self:GetDefaultAct(stageName)
	)
end

--------------------------------------------------------------------------------
-- SELECT ACT
--------------------------------------------------------------------------------

function DefaultGamemode.SelectAct(
	self,
	actName
)

	local stageType = LobbyState.StageType
	local stageName = LobbyState.Stage

	--------------------------------------------------------------------------
	-- LOCK CHECK
	--------------------------------------------------------------------------

	if PlayerLobbyDataHandler.GetActData(
		stageType,
		stageName,
		actName
	) == nil then

		return Notifications:CreateNotification({
			Name = "Failure",
			Text = "You don't have this act unlocked!"
		})
	end

	--------------------------------------------------------------------------
	-- Update state
	--------------------------------------------------------------------------

	LobbyState.SetAct(actName)

	self:SelectActVisual(
		self.ActFrameMap[actName]
	)

	--------------------------------------------------------------------------
	-- Load act info
	--------------------------------------------------------------------------

	local stageData =
		StagesData:GetStageData(
			stageType,
			stageName
		)

	local actData =
		StagesData:GetActData(
			stageType,
			stageName,
			actName
		)

	if not actData then
		warn(
			"Missing act data:",
			stageType,
			stageName,
			actName
		)

		return
	end

	ActInfoHandler.ShowActInfo(
		self.Context.LobbyInterface,
		stageType,
		stageData,
		actData,
		stageName
	)
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function DefaultGamemode.Cleanup(self)

	self.SelectedStageFrame = nil
	self.SelectedActFrame = nil

	table.clear(self.StageFrameMap)
	table.clear(self.ActFrameMap)
end

--------------------------------------------------------------------------------
-- RETURN
--------------------------------------------------------------------------------

return DefaultGamemode