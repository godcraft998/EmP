--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

--// UI Framework
local nui = require(ReplicatedStorage.nui)
local vide = nui.vide

local source = vide.source
local mount = vide.mount
local frame = nui.frame

--// UI Modules
local CardLoadoutSelector =
	require(StarterPlayer.Modules.Interface.SpringEvent.CardLoadoutSelector)

local EventProgressPanel =
	require(StarterPlayer.Modules.Interface.SpringEvent.EventProgressPanel)

local SpringShopWindow =
	require(StarterPlayer.Modules.Interface.SpringEvent.SpringShopWindow)

--// Gameplay Modules
local SpringShopClient =
	require(StarterPlayer.Modules.Gameplay.SpringEvent.SpringShopClient)

local WallPlacementClient =
	require(StarterPlayer.Modules.Gameplay.SpringEvent.WallPlacementClient)

--// Shared Modules
local ShopData =
	require(ReplicatedStorage.Modules.Data.SpringEvent.ShopData)

local GameHandler =
	require(ReplicatedStorage.Modules.Gameplay.GameHandler)

local DebugToggleHandler =
	require(ReplicatedStorage.Modules.Shared.DebugToggleHandler)

local Notifications =
	require(StarterPlayer.Modules.Interface.Loader.Notifications)

--// Networking
local Networking = ReplicatedStorage.Networking
local SpringEventNetworking = Networking.SpringEvent

local ProgressUpdateRemote = SpringEventNetworking.ProgressUpdate
local SetLoadoutRemote = SpringEventNetworking.SetLoadout
local ClaimLevelRemote = SpringEventNetworking.ClaimSpringEventLevel
local ClaimAllLevelsRemote = SpringEventNetworking.ClaimAllSpringEventLevels
local ShopRemote = SpringEventNetworking.ShopEvent

local InterfaceEvent = Networking.InterfaceEvent

--// Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// Module
local SpringEventUI = {}

--// Reactive State
local currentExp = source(0)
local currentLevel = source(1)

local unlockedCards = source({})
local claimedLevels = source({})
local selectedLoadout = source({})

local progressVisible = source(false)
local loadoutVisible = source(false)
local shopVisible = source(false)

local shopAvailable = source(false)
local purchases = source({})

local currentWave = source(0)

local matchStarted = source(GameHandler.IsMatchStarted)

--// Match State Tracking
GameHandler.MatchStarted:Connect(function()
	matchStarted(true)
end)

GameHandler.MatchEnded:Connect(function()
	matchStarted(false)
end)

GameHandler.MatchRestarted:Connect(function()
	matchStarted(false)
end)

--// GUI Reference
local screenGui = nil

--// Analytics / Logging
local function logMenuAccess(action, outcome)
	local gameData = GameHandler.GameData

	DebugToggleHandler.LogDecision(
		"ui",
		LocalPlayer,
		"SpringEventMenuAccess",
		{
			action = action,
			outcome = outcome,

			stage_type = gameData and gameData.StageType or nil,
			stage = gameData and gameData.Stage or nil
		}
	)
end

--// Create UI
local function createUI()
	if screenGui then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpringEventMenu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 19
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = PlayerGui

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = screenGui
	uiScale:SetAttribute("MaxScale", 1)
	uiScale:AddTag("UIScale")

	mount(function()
		return frame({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			----------------------------------------------------------------
			-- Progress Panel
			----------------------------------------------------------------
			EventProgressPanel({
				Visible = progressVisible,

				Exp = currentExp,
				Level = currentLevel,

				UnlockedCards = unlockedCards,
				ClaimedLevels = claimedLevels,

				OnOpenLoadout = function()
					progressVisible(false)
					loadoutVisible(true)
				end,

				OnClaim = function(level)
					ClaimLevelRemote:FireServer(level)
				end,

				OnClaimAll = function()
					ClaimAllLevelsRemote:FireServer()
				end,

				OnClose = function()
					progressVisible(false)
				end
			}),

			----------------------------------------------------------------
			-- Loadout Selector
			----------------------------------------------------------------
			CardLoadoutSelector({
				Visible = loadoutVisible,

				UnlockedCards = unlockedCards,
				Locked = matchStarted,

				InitialLoadout = function()
					local loadout = selectedLoadout()

					local cloned = table.create(#loadout)

					for _, card in loadout do
						table.insert(cloned, card)
					end

					return cloned
				end,

				OnSave = function(loadout)
					SetLoadoutRemote:FireServer(loadout)
				end,

				OnClose = function()
					loadoutVisible(false)
				end
			}),

			----------------------------------------------------------------
			-- Shop Window
			----------------------------------------------------------------
			SpringShopWindow({
				Visible = shopVisible,

				Purchases = purchases,
				CurrentWave = currentWave,

				EligibilityVersion = SpringShopClient.EligibilityVersion,
				GetEligibleUnitCount =
					SpringShopClient.GetEligibleUnitCountForTrait,

				IsPlacementPhase = function()
					return WallPlacementClient.Phase() == "Placement"
				end,

				OnPurchase = function(itemId)
					local itemData = ShopData.GetItem(itemId)

					-- Close shop when selecting trait target
					if itemData and itemData.Kind == "Trait" then
						shopVisible(false)
					end

					ShopRemote:FireServer("Purchase", itemId)
				end,

				OnClose = function()
					shopVisible(false)
				end
			})
		})
	end, screenGui)
end

----------------------------------------------------------------
-- Open Progress Panel
----------------------------------------------------------------
function SpringEventUI.OpenProgressPanel()
	local gameData = GameHandler.GameData

	local isSpringStage =
		gameData
		and gameData.StageType == "LTM"
		and gameData.Stage == "Spring"

	if not isSpringStage then
		logMenuAccess("open_progress", "blocked_non_spring_stage")
		SpringEventUI.CloseAll()
		return
	end

	createUI()

	progressVisible(true)
	loadoutVisible(false)
	shopVisible(false)

	logMenuAccess("open_progress", "success")
end

----------------------------------------------------------------
-- Open Loadout Selector
----------------------------------------------------------------
function SpringEventUI.OpenLoadoutSelector()
	local gameData = GameHandler.GameData

	local isSpringStage =
		gameData
		and gameData.StageType == "LTM"
		and gameData.Stage == "Spring"

	if not isSpringStage then
		logMenuAccess("open_loadout", "blocked_non_spring_stage")
		SpringEventUI.CloseAll()
		return
	end

	createUI()

	loadoutVisible(true)
	progressVisible(false)
	shopVisible(false)

	logMenuAccess("open_loadout", "success")
end

----------------------------------------------------------------
-- Open Shop
----------------------------------------------------------------
function SpringEventUI.OpenShop()
	if not shopAvailable() then
		Notifications:CreateNotification({
			Name = "Failure",
			Text = "The shop only opens during the Eternal Tyrant match."
		})

		return
	end

	createUI()

	shopVisible(true)
	progressVisible(false)
	loadoutVisible(false)

	ShopRemote:FireServer("RequestState")
end

----------------------------------------------------------------
-- Close Everything
----------------------------------------------------------------
function SpringEventUI.CloseAll()
	progressVisible(false)
	loadoutVisible(false)
	shopVisible(false)
end

----------------------------------------------------------------
-- Shop Availability
----------------------------------------------------------------
function SpringEventUI.IsShopAvailable()
	return shopAvailable()
end

----------------------------------------------------------------
-- Wave Updates
----------------------------------------------------------------
InterfaceEvent.OnClientEvent:Connect(function(eventName, data)
	if eventName ~= "Wave" then
		return
	end

	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.Waves) == "number" then
		currentWave(data.Waves)
	end
end)

----------------------------------------------------------------
-- Progress Updates
----------------------------------------------------------------
ProgressUpdateRemote.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.Exp) == "number" then
		currentExp(data.Exp)
	end

	if typeof(data.Level) == "number" then
		currentLevel(data.Level)
	end

	if typeof(data.UnlockedCards) == "table" then
		unlockedCards(data.UnlockedCards)
	end

	if typeof(data.ClaimedLevels) == "table" then
		claimedLevels(data.ClaimedLevels)
	end

	if typeof(data.Loadout) == "table" then
		selectedLoadout(data.Loadout)
	end
end)

----------------------------------------------------------------
-- Shop Events
----------------------------------------------------------------
ShopRemote.OnClientEvent:Connect(function(action, data)

	------------------------------------------------------------
	-- Open Shop
	------------------------------------------------------------
	if action == "Open" then
		shopAvailable(true)

		if typeof(data) == "table" then

			if typeof(data.Purchases) == "table" then
				purchases(data.Purchases)
			end

			if typeof(data.Active) == "boolean" then
				shopAvailable(data.Active)
			end
		end

		return
	end

	------------------------------------------------------------
	-- Close Shop
	------------------------------------------------------------
	if action == "Close" then
		shopAvailable(false)
		shopVisible(false)
		purchases({})

		return
	end

	------------------------------------------------------------
	-- Snapshot Update
	------------------------------------------------------------
	if action == "Snapshot" then
		if typeof(data) == "table"
			and typeof(data.Purchases) == "table"
		then
			purchases(data.Purchases)
		end

		return
	end

	------------------------------------------------------------
	-- Purchase Result
	------------------------------------------------------------
	if action ~= "PurchaseResult" then
		return
	end

	if typeof(data) ~= "table" then
		return
	end

	------------------------------------------------------------
	-- Successful Purchase
	------------------------------------------------------------
	if data.Ok then

		local itemId = data.ItemId

		local itemData =
			typeof(itemId) == "string"
			and ShopData.GetItem(itemId)
			or nil

		-- Trait purchases handled elsewhere
		if itemData and itemData.Kind == "Trait" then
			return
		end

		Notifications:CreateNotification({
			Name = "Success",
			Text = "Purchase complete."
		})

		return
	end

	------------------------------------------------------------
	-- Failed Purchase
	------------------------------------------------------------
	local reason = data.Reason or "Failed"

	-- Ignore silent errors
	if reason == "SelectionCancelled"
		or reason == "InvalidTarget"
		or reason == "AlreadyHasTrait"
	then
		return
	end

	local errorMessage =
		reason == "InsufficientYen" and "Not enough Yen."
		or reason == "MaxPurchases" and "Already at purchase limit."
		or reason == "ShopUnavailable" and "Shop is closed."
		or reason == "UnknownItem" and "Unknown shop item."
		or reason == "AlreadySelecting" and "Finish your current selection first."
		or reason == "NoEligibleUnits" and "No eligible units to apply this trait to."
		or reason == "PlacementActive" and "Confirm placement first."
		or reason == "WaveCapReached" and "This boost is unavailable past wave 120."
		or "Purchase failed."

	Notifications:CreateNotification({
		Name = "Failure",
		Text = errorMessage
	})
end)

----------------------------------------------------------------
-- Keyboard Shortcuts
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	------------------------------------------------------------
	-- Toggle Menu (L)
	------------------------------------------------------------
	if input.KeyCode == Enum.KeyCode.L then

		if progressVisible()
			or loadoutVisible()
			or shopVisible()
		then
			SpringEventUI.CloseAll()
		else
			SpringEventUI.OpenProgressPanel()
		end

		return
	end

	------------------------------------------------------------
	-- Escape Handling
	------------------------------------------------------------
	if input.KeyCode == Enum.KeyCode.Escape then

		if shopVisible() then
			shopVisible(false)
			return
		end

		if loadoutVisible() then
			loadoutVisible(false)
			progressVisible(true)
			return
		end

		if progressVisible() then
			progressVisible(false)
		end
	end
end)

return SpringEventUI