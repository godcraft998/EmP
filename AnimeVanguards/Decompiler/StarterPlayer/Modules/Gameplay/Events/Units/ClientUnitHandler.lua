--// Services
local Camera = workspace.CurrentCamera

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

--// Tween presets
local UNIT_TWEEN_INFO = TweenInfo.new(0.275, Enum.EasingStyle.Linear)
local LOOK_AT_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Linear)

local RANGE_TWEEN_INFO = TweenInfo.new(
	0.25,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local MODEL_TWEEN_INFO = TweenInfo.new(
	0.15,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local HIGHLIGHT_PLACEMENT_INFO = TweenInfo.new(
	0.535,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.Out,
	-1,
	true
)

local RANGE_CIRCLE_INFO = TweenInfo.new(
	15,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.Out,
	-1
)

--// Shared modules
local SkinsData = require(ReplicatedStorage.Modules.Data.SkinsData)
local GetBoundingBox = require(ReplicatedStorage.Modules.Utilities.GetBoundingBox)
local EffectsHandler = require(ReplicatedStorage.Modules.Shared.EffectsHandler)
local GlobalMatchSettings = require(ReplicatedStorage.Modules.Data.GlobalMatchSettings)

local GameHandler = require(ReplicatedStorage.Modules.Gameplay.GameHandler)
local MultiplierHandler = require(ReplicatedStorage.Modules.Shared.MultiplierHandler)
local UnitUpgradeResolver = require(ReplicatedStorage.Modules.Shared.UnitUpgradeResolver)
local PriceResolver = require(ReplicatedStorage.Modules.Shared.PriceResolver)

local UnitAnimator = require(ReplicatedStorage.Modules.Shared.UnitAnimator)
local CollisionHandler = require(ReplicatedStorage.Modules.Shared.CollisionHandler)
local Spring = require(ReplicatedStorage.Modules.Packages.Spring)

local IndicatorHandler = require(ReplicatedStorage.Modules.Gameplay.IndicatorHandler)
local PriorityHandler = require(ReplicatedStorage.Modules.Gameplay.PriorityHandler)

local UnitCollisionHandler = require(ReplicatedStorage.Modules.UnitCollisionHandler)
local HitboxHandler = require(ReplicatedStorage.Modules.Gameplay.HitboxHandler)

--// Client modules
local EnemyHandler = require(StarterPlayer.Modules.Gameplay.ClientEnemyHandler)
local Callbacks = require(script.Callbacks)

local ClientAbilityHandler = require(StarterPlayer.Modules.Gameplay.ClientAbilityHandler)
local ClientGameStateHandler = require(StarterPlayer.Modules.Gameplay.ClientGameStateHandler)

local PassiveInfoHandler = require(StarterPlayer.Modules.Gameplay.PassiveInfoHandler)
local UnitHideHandler = require(StarterPlayer.Modules.Gameplay.Units.UnitHideHandler)

local CutsceneCallbacks = require(
	StarterPlayer.Modules.Visuals.Cutscenes.CutsceneHandler.Callbacks
)

local SkillTreeClient = require(
	StarterPlayer.Modules.Gameplay.ElementalTowers.SkillTreeClient
)

local TraitEffects = require(ReplicatedStorage.Modules.Visuals.TraitEffects)

local UnitBoundaryVisualizer = require(
	StarterPlayer.Modules.Visuals.UnitBoundaryVisualizer
)

local UnitRangeDisplayHandler = require(
	StarterPlayer.Modules.Gameplay.Units.UnitRangeDisplayHandler
)

local SettingsHandler = require(StarterPlayer.Modules.Gameplay.SettingsHandler)

local FamiliarsFollowHandler = require(
	StarterPlayer.Modules.Gameplay.Familiars.FamiliarsFollowHandler
)

local QuickPlacementHandler = require(
	StarterPlayer.Modules.Gameplay.Units.UnitPlacementHandler.QuickPlacementHandler
)

local ConsoleTooltipHandler = require(
	StarterPlayer.Modules.Interface.Loader.ConsoleTooltipHandler
)

local EffectUtils = require(ReplicatedStorage.Modules.Utilities.EffectUtils)

--// Debug & logger
local DebugToggleHandler = require(
	ReplicatedStorage.Modules.Shared.DebugToggleHandler
)

-- logger remove unit
local LogUnitRemoval = DebugToggleHandler.CreateStructuredLogger(
	"clientUnitRemoval"
)

-- logger select unit
local LogUnitSelection = DebugToggleHandler.CreateStructuredLogger(
	"units"
)

-- logger boss targeting
local LogBossTargeting = DebugToggleHandler.CreateStructuredLogger(
	"client_gameplay"
)

local WideEvent = require(ReplicatedStorage.Modules.Shared.WideEventLogger)
local Tracer = require(ReplicatedStorage.Modules.Shared.Tracer)

--// Events / types
local Events = require(script.Events)
local Types = require(script.Types)

--// Networking
local Networking = ReplicatedStorage.Networking

local UnitEvent = Networking.UnitEvent
local AutoAbilityEvent = Networking.ClientListeners.Units.AutoAbilityEvent

local RemoveSellValueEvent = Networking.Units.RemoveUnitSellValue
local OverrideUnitPriceEvent = Networking.Units.OverrideUnitPrice

local UnitPriceRefreshEvent = Networking.Units.UnitPriceRefresh
local UnitPriceBuffsEvent = Networking.Units.ReplicateUnitPriceBuffs

--// Workspace references
local Map = workspace:WaitForChild("Map")
local UnitCirclesFolder = workspace.UnitVisuals.UnitCircles

--// Raycast dùng để raycast map
local MapRaycastParams = RaycastParams.new()
MapRaycastParams.FilterType = Enum.RaycastFilterType.Include
MapRaycastParams.FilterDescendantsInstances = { Map }

--// Raycast dùng để raycast unit/hitbox
local UnitRaycastParams = RaycastParams.new()
UnitRaycastParams.FilterType = Enum.RaycastFilterType.Include
UnitRaycastParams.FilterDescendantsInstances = {
	workspace.Units,
	workspace.UnitHitboxes
}

--// Local player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- CLIENT UNIT HANDLER
--------------------------------------------------------------------------------

local ClientUnitHandler = {

	-- giá upgrade toàn cục
	GlobalUpgradeCost = nil,

	-- unit đang được chọn
	CurrentlySelectedUnit = nil,

	-- unit click gần nhất
	LastClickedUnit = nil,

	-- đang đặt unit hay không
	IsPlacingUnit = false,

	-- thời gian cancel gần nhất
	LastCancel = 0,

	-- có cho phép select unit không
	CanSelectUnits = true,

	-- danh sách toàn bộ unit client
	_ActiveUnits = {},

	-- danh sách hitbox unit
	_ActiveHitboxes = {},

	-- unit bị stun
	StunnedUnits = {},

	--------------------------------------------------------------------
	-- EVENTS
	--------------------------------------------------------------------

	OnUnitPlaced = Events.OnUnitPlaced,
	OnUnitSelected = Events.OnUnitSelected,
	OnUnitDeselected = Events.OnUnitDeselected,

	ClickedOnUnit = Events.ClickedOnUnit,

	OnUnitUpgraded = Events.OnUnitUpgraded,
	OnUnitPriorityChanged = Events.OnUnitPriorityChanged,
	OnUnitStatChanged = Events.OnUnitStatChanged,

	OnUnitSellValueRemoved = Events.OnUnitSellValueRemoved,
	UnitRemoved = Events.UnitRemoved
}

--------------------------------------------------------------------------------
-- CONTEXT TABLE
-- truyền toàn bộ dependency vào controller modules
--------------------------------------------------------------------------------

local Context = {

	--------------------------------------------------------------------
	-- SERVICES
	--------------------------------------------------------------------

	Camera = Camera,
	Players = Players,
	TweenService = TweenService,
	RunService = RunService,
	UserInputService = UserInputService,
	Debris = Debris,
	ReplicatedStorage = ReplicatedStorage,
	StarterPlayer = StarterPlayer,
	CollectionService = CollectionService,

	--------------------------------------------------------------------
	-- TWEEN INFOS
	--------------------------------------------------------------------

	UnitTweenInfo = UNIT_TWEEN_INFO,
	LookAtTweenInfo = LOOK_AT_TWEEN_INFO,
	RangeTweenInfo = RANGE_TWEEN_INFO,
	ModelTweenInfo = MODEL_TWEEN_INFO,

	HighlightPlacementInfo = HIGHLIGHT_PLACEMENT_INFO,
	RANGE_CIRCLE_INFO = RANGE_CIRCLE_INFO,

	--------------------------------------------------------------------
	-- MODULES
	--------------------------------------------------------------------

	SkinsData = SkinsData,
	GetBoundingBox = GetBoundingBox,

	EffectsHandler = EffectsHandler,
	GlobalMatchSettings = GlobalMatchSettings,

	GameHandler = GameHandler,
	MultiplierHandler = MultiplierHandler,

	UnitUpgradeResolver = UnitUpgradeResolver,
	PriceResolver = PriceResolver,

	UnitAnimator = UnitAnimator,
	CollisionHandler = CollisionHandler,

	Spring = Spring,

	IndicatorHandler = IndicatorHandler,
	PriorityHandler = PriorityHandler,

	UnitCollisionHandler = UnitCollisionHandler,
	HitboxHandler = HitboxHandler,

	EnemyHandler = EnemyHandler,

	Callbacks = Callbacks,

	ClientAbilityHandler = ClientAbilityHandler,
	ClientGameStateHandler = ClientGameStateHandler,

	PassiveInfoHandler = PassiveInfoHandler,
	UnitHideHandler = UnitHideHandler,

	CutsceneHandlerCallbacks = CutsceneCallbacks,

	SkillTreeClient = SkillTreeClient,

	TraitEffects = TraitEffects,

	UnitBoundaryVisualizer = UnitBoundaryVisualizer,
	UnitRangeDisplayHandler = UnitRangeDisplayHandler,

	SettingsHandler = SettingsHandler,

	FamiliarsFollowHandler = FamiliarsFollowHandler,
	QuickPlacementHandler = QuickPlacementHandler,

	ConsoleTooltipHandler = ConsoleTooltipHandler,

	EffectUtils = EffectUtils,

	DebugToggleHandler = DebugToggleHandler,

	--------------------------------------------------------------------
	-- LOGGERS
	--------------------------------------------------------------------

	LogUnitRemoval = LogUnitRemoval,
	LogUnitSelection = LogUnitSelection,
	LogBossTargeting = LogBossTargeting,

	--------------------------------------------------------------------
	-- DEBUG / TRACING
	--------------------------------------------------------------------

	WideEvent = WideEvent,
	Tracer = Tracer,

	--------------------------------------------------------------------
	-- EVENTS / TYPES
	--------------------------------------------------------------------

	Events = Events,
	Types = Types,

	--------------------------------------------------------------------
	-- NETWORKING
	--------------------------------------------------------------------

	Networking = Networking,

	UnitEvent = UnitEvent,
	AutoAbilityEvent = AutoAbilityEvent,

	RemoveSellValueEvent = RemoveSellValueEvent,
	OverrideUnitPriceEvent = OverrideUnitPriceEvent,

	UnitPriceRefreshEvent = UnitPriceRefreshEvent,
	UnitPriceBuffsEvent = UnitPriceBuffsEvent,

	--------------------------------------------------------------------
	-- CONSTANTS
	--------------------------------------------------------------------

	RAYCAST_RANGE = 250,

	-- offset indicator dưới chân unit
	INDICATOR_OFFSET = Vector3.new(0, -1, 0),

	-- vector dùng để ignore Y axis
	XZ_PLANE = Vector3.new(1, 0, 1),

	--------------------------------------------------------------------
	-- MAP / WORLD
	--------------------------------------------------------------------

	Map = Map,
	UnitCirclesFolder = UnitCirclesFolder,

	RaycastParameters = MapRaycastParams,
	RaycastUnits = UnitRaycastParams,

	--------------------------------------------------------------------
	-- PLAYER
	--------------------------------------------------------------------

	LocalPlayer = LocalPlayer,
	PlayerGui = PlayerGui,

	--------------------------------------------------------------------
	-- PRIORITY LIST
	--------------------------------------------------------------------

	PRIORITIES = {
		"First",
		"Closest",
		"Last",
		"Strongest",
		"Weakest",
		"Bosses"
	},

	--------------------------------------------------------------------
	-- UNIT KHÔNG CHO SELECT
	--------------------------------------------------------------------

	NON_SELECTABLE_UNITS = {
		["Rogita (Super 4) (Clone)"] = true,
		["Valentine (AU)"] = true,
		["Vigil (Doppelganger)"] = true
	},

	--------------------------------------------------------------------
	-- MAIN HANDLER
	--------------------------------------------------------------------

	ClientUnitHandler = ClientUnitHandler,

	--------------------------------------------------------------------
	-- CACHE EFFECT / UI
	--------------------------------------------------------------------

	SelectionAssets = {
		Highlights = {},
		RangeModels = {},
		Interfaces = {},
		TargetIndicators = {},
		Connections = {}
	},

	--------------------------------------------------------------------
	-- IGNORE AUTO CANCEL UPGRADE
	--------------------------------------------------------------------

	IGNORE_UPGRADE_CANCEL = {
		["Conqueror vs Invulnerable"] = true,
		["Rideon vs Samuel"] = true,
		["Rideon vs Samuel (Duel)"] = true
	},

	--------------------------------------------------------------------
	-- CLONE EFFECT MAPPING
	--------------------------------------------------------------------

	CLONE_TRAIT_EFFECT_UNIT_NAMES = {
		["Rogita (Super 4) (Clone)"] = "Rogita (Super 4)"
	},

	--------------------------------------------------------------------
	-- LOGGERS
	--------------------------------------------------------------------

	LogUpgradeVisual = DebugToggleHandler.CreateStructuredLogger(
		"clientUnitUpgradeVisual"
	),

	LogUpgradePrice = DebugToggleHandler.CreateStructuredLogger(
		"clientUnitUpgradePrice"
	),

	--------------------------------------------------------------------
	-- RUNTIME TABLES
	--------------------------------------------------------------------

	MovingRigParts = {},
	MovingRigCFrames = {},
	MovingUnitCircles = {},

	CallbackThreads = {},

	-- override giá unit
	PriceOverrides = {},

	-- buff giá unit
	UnitPriceBuffs = {},

	--------------------------------------------------------------------
	-- ROOT SCRIPT
	--------------------------------------------------------------------

	RootScript = script,

	--------------------------------------------------------------------
	-- SPECTATE
	--------------------------------------------------------------------

	SpectatingUnit = nil
}

--------------------------------------------------------------------------------
-- CALLBACKS
--------------------------------------------------------------------------------

-- trả về toàn bộ active units
function Callbacks.GetActiveUnits()
	return ClientUnitHandler._ActiveUnits
end

--------------------------------------------------------------------------------
-- LOAD CONTROLLERS
--------------------------------------------------------------------------------

-- xử lý giá unit
require(script.PriceController)(Context)

-- xử lý target / priority
require(script.TargetingController)(Context)

-- xử lý select unit
require(script.SelectionController)(Context)

-- xử lý movement unit
require(script.UnitMovementController)(Context)

-- xử lý create/remove unit
require(script.UnitLifecycle)(Context)

-- render visual unit
require(script.UnitRenderer)(Context)

-- helper tìm unit
require(script.UnitLookup)(Context)

-- spectate unit
require(script.SpectateController)(Context)

-- networking replication
require(script.UnitNetworkController)(Context)

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

task.spawn(ClientUnitHandler.Init)

return ClientUnitHandler