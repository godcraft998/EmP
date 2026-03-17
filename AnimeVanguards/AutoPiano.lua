local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Gui = LP.PlayerGui
local UIS = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

local ConfigLoader = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/ConfigLoader.lua"))();

local ScriptConfig = {
    Scores = {
        ['Petals Beneath the Ice'] = {Easy=0, Medium=0, Hard=0, Expert=0},
        ['Steel Against Flesh']   = {Easy=0, Medium=0, Hard=0, Expert=0},
        ['Crown of the Sun']      = {Easy=0, Medium=0, Hard=0, Expert=0}
    },
    Settings = {
        Toogle = false7
    },
    Webhook = {
        url = ""
    }
}

local Config = {
    Running = true
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

    -- OPEN EVENTS UI
    local HUD = WaitFor(function() return Gui:FindFirstChild("HUD") end)
    Fire(HUD.RightButtons.Events.Button)
    task.wait(1)

    local Holder = WaitFor(function() return Gui.Events.Holder end)
    local OptionsHolder = Holder.EventOptions.OptionsHolder
    local Filters = OptionsHolder.EventsFilters
    local Events = OptionsHolder.Events

    -- FIND EVENT BUTTON
    local function FindEvent()
        for _,v in pairs(Events:GetChildren()) do
            if v:IsA("Frame") and v:FindFirstChild(v.Name) then
                local f = v[v.Name]
                if f.EventTitle.Text == EVENT_NAME then
                    return f.Button
                end
            end
        end
    end

    local PianoButton = FindEvent()
    if not PianoButton then
        Fire(Filters.Regular.Button)
        task.wait(0.5)
        PianoButton = FindEvent()
    end
    if not PianoButton then return warn("Không tìm thấy event!") end

    -- ENTER EVENT
    Fire(PianoButton)
    task.wait(1)

    
    local EventInfo = Holder.EventInfoFrame

    -- CLICK PLAY
    for _,v in pairs(EventInfo.Buttons:GetChildren()) do
        if v:IsA("Frame") and v.Label.Text == "Play" then
            Fire(v.Button)
            break
        end
    end
    task.wait(1)

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
    local currency = 255

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

        if not Gui:FindFirstChild("GuitarMinigame") then
            pcall(function()
                StartJamSession()
                print('Script Running')
            end)
        end
    end

    print('Script end!!')
end)
