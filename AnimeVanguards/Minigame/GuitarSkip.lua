local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JamSessionEvents = ReplicatedStorage.Networking.Events.JamSession
local Remote_UpdateScore = JamSessionEvents.UpdateScore

local FunctionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))();

local Mission = {
    ['Petals Beneath the Ice'] = {
        Easy = 2000, Medium = 10000, Hard = 20000, Expert = 30000
    },
    ['Steel Against Flesh'] = {
        Easy = 2000, Medium = 10000, Hard = 20000, Expert = 30000
    },
    ['Crown of the Sun'] = {
        Easy = 5000, Medium = 15000, Hard = 30000, Expert = 60000
    }
}

local function Skip(song, diff)
    local score = Difficulty[diff]

    Remote_UpdateScore:FireServer(song, diff, math.random(score, score + (score / 2)))
end

local function BuyChips(amount)
    if amount > 100 then amount = 100 end
    local args = {
        "Purchase",
        {
            "Skele King's Jam Session",
            "Stat Chip",
            amount
        }
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Events"):WaitForChild("EventsShopEvent"):FireServer(unpack(args))
    warn("EMP: Trying Buy", amount ,"Stat Chip")
end

local function StartBuyChips()
    local currency = FunctionEvent:GetEventCurrency("Skele King's Jam Session")

    while currency > 0 do
        local amount = currency
        if (currency > 100) then
            amount = 100
        end
        currency = currency - amount;
        BuyChips(amount)
        wait(0.5)
    end
end

for song, difficulties in pairs(Mission) do
    for difficulty, score in pairs(difficulties) do
        local args = {
            song,
            difficulty,
            math.random(score, score + (score / 2))
        }

        Remote_UpdateScore:FireServer(unpack(args))
        wait(2.5)
    end
    wait(5)
end

StartBuyChips()