local function printObject(instance)
    local count = 1;
    print("--- ᴘʀɪɴᴛ ᴏʙᴊᴇᴄᴛ ---")
    if typeof(instance) == 'table' then
        for k, v in pairs(instance) do
            warn(count .. ":", k, "-", v)
            count += 1;
        end
    else
        warn(instance)
    end
end

local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local Functions = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))()

local uilibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kiet1308/tvkhub/main/rac"))()
local window = uilibrary:CreateWindow("EmP", "Anime Vanguards", true)

local ProcessPage = window:CreatePage("Process")

local Config = {
    Process = {
        Story = {},
        Tutorial = {
            SkipTutorial = true
        }
    }
}

local Processing = {
    Process = {
        Story = false
    }
}

local StagesData = {
    Story = {
        ["Planet Namak"] = {
            Index = 1,
            ID = "Stage1"
        },
        ["Sand Villange"] = {
            Index = 2,
            ID = "Stage2"
        },
        ["Double Dungeon"] = {
            Index = 3,
            ID = "Stage3"
        }
    }
}

local function GetStages(type)
    local stages = {}

    for k,v in pairs(StagesData[type]) do
        stages[v.Index] = k
    end

    return stages
end

local Story = ProcessPage:CreateSection("Story")
Story:CreateDropdown("Stage", {
    List = GetStages("Story"),
    Default = "None"
}, function(value)
    Config.Process.Story.Stage = value
end)
Story:CreateDropdown("Act", {
List = {"1", "2", "3", "4", "5", "6", "Infinite"},
    Default = "None"
}, function(value)
    Config.Process.Story.Act = value
end)
Story:CreateSlider("Level Cap", {Min = 1, Max = 100, DefaultValue = 5}, function(value)
    Config.Process.Story.LevelCap = value
end)
Story:CreateToggle("Enable", {Toggled = false, Description = "  Tự động đi map cho đến khi đủ level"}, function(value)
    Config.Process.Story.Enable = value
end)

local Tutorial = ProcessPage:CreateSection("Tutorial")
Tutorial:CreateToggle("Skip Tutorial", {Toggled = true, Description = "  Tự động bỏ qua Tutorial khi có thể"}, function(value)
    Config.Process.Tutorial.SkipTutorial = value
end)

local runable = true

local function PStory()
    if not Config.Process.Story.Stage or not Config.Process.Story.Act then
        task.wait(5)

        Processing.Process.Story = false
        return
    end

    local StageId = StagesData.Story[Config.Process.Story.Stage].ID
    local PlayerData = require(SP.Modules.Interface.Loader.Gameplay.LobbyHandler.PlayerLobbyDataHandler):GetPlayerData()

    local StageData = PlayerData.Story[StageId]

    local selected = "Act" .. Config.Process.Story.Act
	if not (StageData[selected]) then
        local best, max = nil, -1
        for k in pairs(PlayerData.Story[StageId]) do
            local n = tonumber(k:match("%d+")) or -1

            if n > max then
                best, max = k, n
            end
        end

        selected = best
    end

    local room = Functions.CreateMatch({StageType = "Story", Stage = StageId, Act = selected, Difficulty = "Nightmare"})

    if room then
        task.wait(2.5)
        Functions:StartMatch()
    end

    task.wait(10)
    Processing.Process.Story = false
end

task.spawn(function()
    while true do
        if Config.Process.Story.Enable and not Processing.Process.Story then
            Processing.Process.Story = true
            task.spawn(PStory)
        end
        task.wait(0.5)

        if not runable then
            print("Break Script")
            break
        end
    end
end)