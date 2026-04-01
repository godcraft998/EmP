if not game:IsLoaded() then
    game.Loaded:Wait()
end

local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local PlaceId = {
    Lobby = 16146832113,
    Game = 16277809958
}

local function RandomWait(min, max)
    task.wait(Random.new():NextNumber(2.5, 5))
end

task.spawn(function()
    task.wait(5)

    if game.PlaceId == PlaceId.Lobby then 

        local DailyRewardsUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('DailyRewards')
        if DailyRewardsUI then
            local Handler = require(SP.Modules.Gameplay.DailyRewards.DailyRewardsHandler)
            RandomWait(0.5, 1.5)
            Handler:CloseInterface()
        end
        
        local NewPlayersUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('NewPlayers')
        if NewPlayersUI then
            local Handler = require(SP.Modules.Gameplay.DailyRewards.NewPlayer.NewPlayerHandler)
            RandomWait(0.5, 1.5)
            Handler:CloseInterface()
        end

        local UpdateLogUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild('UpdateLogFullScreen')
        if UpdateLogUI then
            local Handler = require(SP.Modules.Miscellaneous.UpdateLogHandler)
            RandomWait(0.5, 1.5)
            Handler:CloseInterface()
        end

        RandomWait(0.5, 1.5)

        local TutorialHandler = require(SP.Modules.Gameplay.ClientTutorialHandler)
        if TutorialHandler.IsInTutorial then
            RandomWait(2.5, 5)

            
            local args = {
                "PartTwo",
                "Skip"
            }
            game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("ClientListeners"):WaitForChild("NEWTutorialEvent"):FireServer(unpack(args))
        else 
            warn('normal lobby')
        end
    elseif game.PlaceId == PlaceId.Game and TutorialHandler.IsInTutorial then
        RandomWait(2.5, 5)

        local args = {
            "PartOne",
            "Skip"
        }
        game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("ClientListeners"):WaitForChild("NEWTutorialEvent"):FireServer(unpack(args))
    else 
        warn('normal in game')
    end
end)