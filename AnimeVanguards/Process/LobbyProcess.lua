local player = game.Players.LocalPlayer

local functionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))()

local random = {}
function random.wait(min, max)
    task.wait(math.random() * (max - min) + min)
end

local processing = false

local function WinterProcess()
    random.wait(1, 2)
    functionEvent:WinterLTMEvent()
    random.wait(0.75, 1)
    functionEvent:StartMatch()
end

local function ToggleSettings()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/ToggleSettings.lua"))();
end

task.spawn(function()
    local playerLevel = player:GetAttribute("Level")
    local playerExperience = player:GetAttribute("Experience")

    ToggleSettings()

    if not processing and playerLevel < 50 then
        task.spawn(WinterProcess)
        return
    end
end)