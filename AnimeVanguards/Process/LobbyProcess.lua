local player = game.Players.LocalPlayer

local functionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))();

local function r_wait(min, max)
    return task.wait(min + math.random() * (max - min))
end

local function processLevel()
    r_wait(1, 2)
    functionEvent:WinterLTMEvent()
    r_wait(2, 3)
    functionEvent:StartMatch()
end

task.spawn(function()
    local playerLevel = player:GetAttribute("Level")
    local playerExperience = player:GetAttribute("Experience")

    if playerLevel < 50 then
        processLevel()
        return
    end

    
end)