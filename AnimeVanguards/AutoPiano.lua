local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Gui = LP.PlayerGui
local UIS = game:GetService("UserInputService")

local RS = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CurrencyHandler = require(StarterPlayer.Modules.Gameplay.CurrencyHandler)

local WebhookAPI = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/WebhookAPI.lua"))()

local OwnedUnits = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/OwnedUnits.lua"))();
local ConfigLoader = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/ConfigLoader.lua"))();
local FunctionEvent = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))();

local ScriptConfig = {
    Scores = {
        ['Petals Beneath the Ice'] = {Easy=0, Medium=0, Hard=0, Expert=0},
        ['Steel Against Flesh']   = {Easy=0, Medium=0, Hard=0, Expert=0},
        ['Crown of the Sun']      = {Easy=0, Medium=0, Hard=0, Expert=0}
    },
    Settings = {
        Toogle = false
    },
    Stocks = {
        Winter26 = {
            TraitRerolls = 200
        }
    }
}

local Config = {
    Running = true,
    Buyed = {
        Winter26 = {
            TraitRerolls = false
        }
    },
    Rerolling = {
        Trait = false
    },
    Songs = {
        "Petals Beneath the Ice",
        "Steel Against Flesh",
        "Crown of the Sun"
    },
    Difficulty = {
        Easy = 200,
        Medium = 10000,
        Hard = 20000,
        Expert = 30000
    }
}

local State = {
    TrailRerolls = {
        rolling = false,
        selected = nil,
        trait = nil
    },
    TraitStorage = {}
}

local function buyChips(amount)
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

local function startBuyChips()
    local currency = FunctionEvent:GetEventCurrency("Skele King's Jam Session")

    while currency > 0 do
        local amount = currency
        if (currency > 100) then
            amount = 100
        end
        currency = currency - amount;
        buyChips(amount)
        wait(0.5)
    end
end

local JamSessionEvents = RS.Networking.Events.JamSession
local function GetScores()
    return JamSessionEvents.GetScores:InvokeServer() or {}
end

local function CheckScores()
    local scores = GetScores()

    for _,song in pairs(Config.Songs) do
        local data = scores[song]
        if data then
            if data.Easy.BestScore <= 200 then return false, song, "Easy" end
            if data.Medium.BestScore <= 10000 then return false, song, "Medium" end
            if data.Hard.BestScore <= 20000 then return false, song, "Hard" end
            if data.Expert.BestScore <= 30000 then return false, song, "Expert" end
        else
            return false, song
        end
    end

    return true
end

local JamSessionHandler = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/Minigame/JamSessionHandler.lua"))();
local function StartAutoPiano()
    local done, song, difficulty = CheckScores()
    if not done then
        difficulty = difficulty or "Easy"
        
        wait(2.5)

        JamSessionHandler.StartMinigame(song, difficulty)
    else 
        startBuyChips()
    end
end

UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Delete then
        Config.Running = not Config.Running
        if Config.Running then
            warn("▶ EMP Hub: ON")
        else
            warn("⛔ EMP Hub: OFF")
        end
    end
end)

local function BuyTraitRerolls()
    local currency = CurrencyHandler.GetCurrencyByName("Presents26");
    local stock = FunctionEvent:RequestStock("Winter Shop").TraitRerolls;

    if currency > 1500 and stock > 0 then
        if currency >= (stock * 1500) then
            FunctionEvent:PurchaseItem("Winter Shop", "TraitRerolls", stock);
            warn('[WinterShop] Buy ' .. stock .. ' Trait Rerolls')
        else
            FunctionEvent:PurchaseItem("Winter Shop", "TraitRerolls", math.floor(currency / 1500))
            warn('[WinterShop] Buy ' .. math.floor(currency / 1500) .. ' Trait Rerolls')
        end
    else
        Config.Buyed.Winter26.TraitRerolls = true
    end
end

local function SendWebhook(Spend)
    local webhook = WebhookAPI.createWebhook();
    local embeds = webhook:addEmbeds()

    embeds:setTitle('ᴀɴɪᴍᴇ ᴠᴀɴɢᴜᴀʀᴅꜱ ─ ᴛʀᴀɪᴛ ʀᴇʀᴏʟʟ')
    embeds:addField("Player ID: " .. "||" .. game:GetService("Players").LocalPlayer.DisplayName .. "||", "", false)
    embeds:addField("<:av_ice_queen_release:1479374524926398545> Ice Queen (Release)", 
                    " - Spend: " .. Spend .. "<:av_trait_reroll:1484372107327438898>\n" ..
                    " - Trait: <:av_trait_monarch:1484372181772406928>",
                    true)

    webhook:Send('https://discord.com/api/webhooks/1484371917816336416/jDlpbKWi0SGbu2lBLG21d-cfw7NlcSH959OhY4mfaY-eZOOckn6lpiyneUPWYc0RrCYr')
end

local function MonarchReroll()
    State.TrailRerolls.rolling = true

    local Spend = 0

    if CurrencyHandler.GetCurrencyByName("TraitRerolls") > 0 then
        local Unit = OwnedUnits:FindUnitByName("Ice Queen (Release)")
        if Unit then
            State.TrailRerolls.selected = Unit.UniqueIdentifier
            while OwnedUnits:GetTrait(State.TrailRerolls.selected) ~= 'Monarch' and CurrencyHandler.GetCurrencyByName("TraitRerolls") > 0 do
                local Data = FunctionEvent:TraitReroll(State.TrailRerolls.selected)
                if (Data) then
                    Spend+=1
                    State.TrailRerolls.trait = Data[2]
                    warn("[MonarchReroll] Reroll [Ice Queen (Release)] current trait: " .. Data[2])
                    if (Data[2] == 'Monarch') then
                        SendWebhook(Spend)
                        print("Send Webhook")
                    end
                end
                task.wait(math.random() * (0.2 - 0.1) + 0.1)
            end
            State.TrailRerolls.trait = nil
            State.TrailRerolls.selected = nil
        else
            warn("[MonarchReroll] Ice Queen (Release) not found")
        end
    else
        warn("[MonarchReroll] not enough trait reroll")
    end

    State.TrailRerolls.rolling = false
end

-- ========== CHECK LOOP ==========
task.spawn(function()
    warn("EMP Hub: Authenticated")
    local count = 0;
    while task.wait(10) and Config.Running do
        if not Config.Buyed.Winter26.TraitRerolls then
            --task.spawn(BuyTraitRerolls)
        end

        if Config.Buyed.Winter26.TraitRerolls and not State.TrailRerolls.rolling then
            --task.spawn(MonarchReroll)
        end

        if not Gui:FindFirstChild("GuitarMinigame") then
            local error = pcall(function()
                StartAutoPiano()
                print('Script Running')
            end)
        end
    end

    print('Script end!!')
end)
