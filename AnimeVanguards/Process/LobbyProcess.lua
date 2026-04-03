local player = game.Players.LocalPlayer

local functionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))()

local random = {}
function random.wait(min, max)
    task.wait(math.random() * (max - min) + min)
end

local function processLevel()
    random.wait(1, 2)
    functionEvent:WinterLTMEvent()
    random.wait(1, 1.5)
    functionEvent:StartMatch()
end

local function ToggleSettings()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))();
end

task.spawn(function()
    local playerLevel = player:GetAttribute("Level")
    local playerExperience = player:GetAttribute("Experience")

    ToggleSettings()

    random.wait(2.5, 5)

    if playerLevel < 50 then
        processLevel()
        return
    end
end)