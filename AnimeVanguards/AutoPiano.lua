local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Gui = LP.PlayerGui
local UIS = game:GetService("UserInputService")

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

local function CheckScores()
    for _, difficulties in pairs(ScriptConfig.Scores) do
        if difficulties.Easy   <= 2000 then return false end
        if difficulties.Medium <= 10000 then return false end
        if difficulties.Hard   <= 20000 then return false end
        if difficulties.Expert <= 30000 then return false end
    end
    return true
end

-- ========== SCRIPT CHÍNH ==========
local function StartJamSession()
    -- CONFIG
    local TARGET_SCORE = 10000
    local EVENT_NAME = "Skele King's Jam Session"

    -- UTILS
    local function WaitFor(path, timeout)
        local t = tick()
        repeat
            local obj = path()
            if obj then return obj end
            task.wait(0.1)
        until tick() - t > (timeout or 10)
    end

    local function Fire(btn)
        if btn and btn:IsA("GuiButton") then
            firesignal(btn.Activated)
            return true
        end
    end

    local function HasMissing(tbl)
        for _,v in pairs(tbl) do
            if v == 0 then return true end
        end
        return false
    end

    local function ParseScore(text)
        if not text or text == "" then return 0 end

        text = text:gsub(",", ""):upper()

        local num = tonumber(text:match("[%d%.]+"))
        if not num then return 0 end

        if text:find("K") then
            return num * 1e3
        elseif text:find("M") then
            return num * 1e6
        elseif text:find("B") then
            return num * 1e9
        else
            return num
        end
    end

    local SP = game:GetService("StarterPlayer")
    local Handler = require(SP.Modules.Interface.Loader.Events.JamSessionHandler)
    
    Handler:OpenGui()

    wait(2.5)

    -- JAM SESSION GUI
    local JamSessionGui = WaitFor(function() return Gui:FindFirstChild("JamSessionGui") end, 5)
    if not JamSessionGui then return warn("Không load được JamSessionGui") end

    local Songs = JamSessionGui.Main.Songs

    -- JAM SESSION GUI
    local JamSessionGui = WaitFor(function() return Gui:FindFirstChild("JamSessionGui") end, 5)
    if not JamSessionGui then return warn("Không load được JamSessionGui") end

    local Songs = JamSessionGui.Main.Songs

    -- MAIN LOOP
    for _,songBtn in pairs(Songs:GetChildren()) do
        if songBtn:IsA("ImageButton") and ScriptConfig.Scores[songBtn.Name] then
            if HasMissing(ScriptConfig.Scores[songBtn.Name]) then
                Fire(songBtn)
                task.wait(0.5)

                local SongInfo = JamSessionGui.Main.SongDisplay

                for i = 1, 4 do
                    local diff = SongInfo.Difficulty.Label.Text
                    local scoreText = SongInfo.Scores.BestScoreValue.Text
                    local score = ParseScore(scoreText) or 0

                    if score < TARGET_SCORE then
                        Fire(SongInfo.Play.Button)
                        return
                    else
                        ScriptConfig.Scores[songBtn.Name][diff] = score
                        Fire(SongInfo.Difficulty.Button)
                        task.wait(1)
                    end
                end
            end
        end
    end

    Fire(JamSessionGui.Main.Cancel.Button);
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

Players.PlayerRemoving:Connect(function(player: Player)  
    if (player == Players.LocalPlayer) then
        ConfigLoader.saveConfig(ScriptConfig);
    end
end)

local function loadConfig()
    local loaded = ConfigLoader.loadConfig()
    if loaded then
        ScriptConfig = loaded;
    end
    warn("EMP Hub: Loaded Config")
end

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
    pcall(loadConfig)
    local count = 0;
    while task.wait(10) and Config.Running do
        if (CheckScores()) then
            pcall(startBuyChips);
            break;
        end

        if not Config.Buyed.Winter26.TraitRerolls then
            task.spawn(BuyTraitRerolls)
        end

        if Config.Buyed.Winter26.TraitRerolls and not State.TrailRerolls.rolling then
            task.spawn(MonarchReroll)
        end

        if not Gui:FindFirstChild("GuitarMinigame") then
            pcall(function()
                StartJamSession()
                print('Script Running')
            end)
        end
    end

    print('Script end!!')
end)
