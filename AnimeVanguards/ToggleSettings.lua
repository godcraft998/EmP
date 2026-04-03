local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local Handler = require(SP.Modules.Gameplay.SettingsHandler)

local ToggleConfig = {
    AutoSkipWaves = true,
    DisableMatchEndRewardsView = true,
    SelectUnitOnPlacement = false,
    HideOthersUnits = true,
    DisableStatMultiplierPopups = true,
    DisableVisualEffects = true,
    DisableDamageIndicators = true,
    DisableEnemyTags = true,
    SimplifiedEnemyGui = true,
    DisableCameraShake = true,
    DisableDepthOfField = true,
    LowDetailMode = true,
    HideFamiliars = true,
    DisableViewCutscenes = true,
    SkipSummonAnimation = true,
    DisableGlobalMessages = true,
    AutoSellUnitsWithTraits = true,
    AutoFuseUnitsWithTraits = true,
    SummonMaxAffordable = true
}

local function ToggleSetting(setting, toggle)
    if Handler:GetSetting(setting) ~= toggle then
        local args = {
            "Toggle",
            setting
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Settings"):WaitForChild("SettingsEvent"):FireServer(unpack(args))
    end
end


while not Handler.SettingsLoaded do
    task.wait(1)
end

warn("EmP: Disable Settings")

for setting, toggle in pairs(ToggleConfig) do
    ToggleSetting(setting, toggle)
    wait(0.35)
end