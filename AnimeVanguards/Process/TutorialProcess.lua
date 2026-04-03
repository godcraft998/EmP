if not game:IsLoaded() then
    game.Loaded:Wait()
end

local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local PlaceId = {
    Lobby = 16146832113,
    Game = 16277809958
}

local random = {}
function random.wait(min, max)
    task.wait(math.random() * (max - min) + min)
end

local features = {}
function features.AntiAFK()
    for _, connection in pairs(getconnections(game.Players.LocalPlayer.Idled)) do
        if connection["Disable"] then
            connection["Disable"](connection)
        elseif connection["Disconnect"] then
            connection["Disconnect"](connection)
        end
    end
end

local LoadingScreenHandler = require(SP.Modules.Interface.LoadingScreens.LoadingScreenHandler)
function features.IsLoaded()
    return LoadingScreenHandler.IsFinishedLoading
end

task.spawn(function()
    while not features.IsLoaded() do
        print('wait screen loaded')
        random.wait(1, 1.5)
    end
    features.AntiAFK()
    
    print("loaded")

    if game.PlaceId == PlaceId.Lobby then 
        
        random.wait(1.5, 3)
        local DailyRewardsUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('DailyRewards')
        if DailyRewardsUI then
            local Handler = require(SP.Modules.Gameplay.DailyRewards.DailyRewardsHandler)
            random.wait(0.5, 1.5)
            Handler:CloseInterface()
        end
        random.wait(0.25, 0.75)
        
        local NewPlayersUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('NewPlayers')
        if NewPlayersUI then
            local Handler = require(SP.Modules.Gameplay.DailyRewards.NewPlayer.NewPlayerHandler)
            random.wait(0.5, 1.5)
            Handler:CloseInterface()
        end
        random.wait(0.25, 0.75)

        local UpdateLogUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('UpdateLogFullScreen')
        if UpdateLogUI then
            local Handler = require(SP.Modules.Miscellaneous.UpdateLogHandler)
            random.wait(0.5, 1.5)
            Handler:CloseInterface()
        end
        random.wait(0.5, 1.5)

        local TutorialHandler = require(SP.Modules.Gameplay.ClientTutorialHandler)
        if TutorialHandler.IsInTutorial then
            random.wait(2.5, 5)
            
            local args = {
                "PartTwo",
                "Skip"
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("ClientListeners"):WaitForChild("NEWTutorialEvent"):FireServer(unpack(args))
        else 
            loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/Process/LobbyProcess.lua"))()
        end
    elseif game.PlaceId == PlaceId.Game then
        local TutorialHandler = require(SP.Modules.Gameplay.Tutorial.ClientTutorialHandler)

        if TutorialHandler and TutorialHandler.IsInTutorial then
            random.wait(2.5, 5)

            local args = {
                "PartOne",
                "Skip"
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("ClientListeners"):WaitForChild("NEWTutorialEvent"):FireServer(unpack(args))
        else
            loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/Process/GameProcess.lua"))()
        end
    end
end)