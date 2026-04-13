local player = game.Players.LocalPlayer

local functionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))()
local GuitarSkip = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/Minigame/GuitarSkip.lua"))
local OnwedUnits = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/OnwedUnits.lua"))

local SP = game:GetService("StarterPlayer")

local CurrencyHandler = require(SP.Modules.Gameplay.CurrencyHandler)

local random = {}
function random.wait(min, max)
    task.wait(math.random() * (max - min) + min)
end

local processing = false

local function loadConfig(config)
    local file = "Nousigi Hub/Config/" .. config
    if not isfile(file) then
        return
    else
        local json = readfile(file)
        return game:GetService("HttpService"):JSONDecode(json);
    end
end

local function loadNousigi(config)
    getgenv().Config = loadConfig(config);

    getgenv().Key = "kca5b6ee67b2bc3054d46849"
    loadstring(game:HttpGet("https://nousigi.com/loader.lua"))()
end

local function GetPresents26()
    return CurrencyHandler.GetCurrencyByName("Presents26");
end

local function WinterProcess()
    random.wait(1, 2)
    functionEvent:WinterLTMEvent()
    random.wait(0.75, 1)
    functionEvent:StartMatch()
end

local function ToggleSettings()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/ToggleSettings.lua"))();
end

local function WinterSummon()
    processing = true

    task.spawn(GuitarSkip)

    task.spawn(function()
        loadNousigi("PianoConfig.json")
    end)
    
    while processing do
        processing = false
    end
end

task.spawn(function()
    local playerLevel = player:GetAttribute("Level")
    local playerExperience = player:GetAttribute("Experience")

    ToggleSettings()

    if not processing and playerLevel < 50 then
        task.spawn(WinterProcess)
        return
    end

    if playerLevel < 50 then
        if not processing then
            task.spawn(WinterProcess)
            return
        end
    else
        if not processing and GetPresents26() > 150 then
            task.spawn(WinterSummon)
            return
        end
    end
end)