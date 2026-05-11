--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--// Framework
local Nui = require(ReplicatedStorage.nui)

local vide = Nui.vide

local source = vide.source
local derive = vide.derive
local create = vide.create
local action = vide.action

--// UI Components
local Text = Nui.text
local Button = Nui.button
local CardBackground = Nui.cardBackground
local InfoTag = Nui.infoTag
local ScrollView = Nui.scrollView
local SectionDivider = Nui.sectionDivider

--// Modules
local SpringEventWindow =
	require(StarterPlayer.Modules.Interface.SpringEvent.SpringEventWindow)

local SpringEventScrollbar =
	require(StarterPlayer.Modules.Interface.SpringEvent.SpringEventScrollbar)

local PlayerYenHandler =
	require(StarterPlayer.Modules.Gameplay.PlayerYenHandler)

local Notifications =
	require(StarterPlayer.Modules.Interface.Loader.Notifications)

local SoundHandler =
	require(ReplicatedStorage.Modules.Shared.SoundHandler)

local ShopData =
	require(ReplicatedStorage.Modules.Data.SpringEvent.ShopData)

--// Sounds
local SOUND_GROUP = {
	"General",
	"Miscellaneous"
}

--// Colors
local COLOR_BLUE = Color3.fromRGB(120, 180, 255)
local COLOR_GREEN = Color3.fromRGB(0, 230, 118)
local COLOR_ORANGE = Color3.fromRGB(220, 130, 80)
local COLOR_GRAY = Color3.fromRGB(80, 85, 100)

local COLOR_SLOT_T1 = Color3.fromRGB(150, 200, 255)
local COLOR_SLOT_T2 = Color3.fromRGB(220, 170, 255)

--// Boost IDs
local BOOST_IDS = {
	"SkipWaves5",
	"ExtraWall",
	"MonarchTrait",
	"FortuneTrait"
}

--// Hover Configs
local CARD_HOVER = {
	Scale = {
		Default = 1,
		Hovered = 1.015
	},

	StrokeThickness = {
		Default = 2,
		Hovered = 4
	}
}

local SLOT_HOVER = {
	Scale = {
		Default = 1,
		Hovered = 1.025
	},

	StrokeThickness = {
		Default = 2,
		Hovered = 4
	}
}

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

local function playButtonSound()
	pcall(function()
		SoundHandler:PlayLocalSound(
			SOUND_GROUP,
			"ButtonPress",
			{
				Destroy = true
			}
		)
	end)
end

local function formatYen(amount)
	if amount >= 1_000_000 then
		return string.format("%.2fM", amount / 1_000_000)
	elseif amount >= 10_000 then
		return string.format("%.1fK", amount / 1_000)
	end

	return tostring(amount)
end

--------------------------------------------------------------------------------
-- Description Builder
--------------------------------------------------------------------------------

local function buildItemDescription(item)

	if item.Kind == "SkipWaves" then
		local growth = math.floor(item.CostGrowth * 100 + 0.5)

		return (
			"Jump forward %d waves. Repeatable; cost grows %d%% per use."
		):format(
			item.WavesToSkip,
			growth
		)
	end

	if item.Kind == "ExtraWall" then
		local growth = math.floor(item.CostGrowth * 100 + 0.5)

		return (
			"+%d wall in the next placement phase. Repeatable; cost grows %d%% per use."
		):format(
			item.WallCount,
			growth
		)
	end

	if item.Kind ~= "Trait" then
		return item.Description
	end

	if item.CostGrowth <= 0 then
		return (
			"Apply the %s trait to a placed unit you own. Flat cost, repeatable."
		):format(item.TraitName)
	end

	local growth = math.floor(item.CostGrowth * 100 + 0.5)

	return (
		"Apply the %s trait to a placed unit you own. Cost grows %d%% per use."
	):format(
		item.TraitName,
		growth
	)
end