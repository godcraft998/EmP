local SP = game:GetService("StarterPlayer")
local PlayerModules = SP.Modules

local OwnedUnits = require(PlayerModules.Gameplay.Units.OwnedUnitsHandler)
local OwnedItems = require(PlayerModules.Data.Items.OwnedItemsHandler)

local function printObject(instance)
    local count = 1;
    warn("--- ᴘʀɪɴᴛ ᴏʙᴊᴇᴄᴛ ---")
    if typeof(instance) == 'table' then
        for k, v in pairs(instance) do
            warn(count .. ":", k, "-", v)
            count += 1;
        end
    else
        warn(instance)
    end
end

local function getStatChip()
    for _,v in pairs(OwnedItems:GetItems()) do
        if v.ID == 9 then
            return v.Amount
        end
    end
    return 0
end

local function getData(unit, count)
    warn(count .. ":", unit.Data.Name, "[" .. unit.Data.ID .. "]")
    warn(" - UniqueId:", unit.UniqueIdentifier)
    warn(" - Name:", unit.Data.Name)
    warn(" - Rarity:", unit.Data.Rarity)
    warn(" - Stats:")
    warn("   + Damage:", unit.Statistics.Damage.Tier)
    warn("   + SPA:", unit.Statistics.SPA.Tier)
    warn("   + Range:", unit.Statistics.Range.Tier)
end

local function statReroll(UniqueId)
    local args = {
        "All",
        UniqueId
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Units"):WaitForChild("StatRerollEvent"):FireServer(unpack(args))
end

local state = {
    StatReroll = {
        running = false,
        selected = nil,
        rerollQueue = {
            Vanguard = {},
            Exclusive = {},
            Mythic = {}
        },
        history = {}
    },
    WebHook = {
        spend = false
    }
}

local function canRerollStats(unit)
    local Rarities = {
        Vanguard = true, 
        Exclusive = true, 
        Mythic = true
    }
    if Rarities[unit.UnitData.Rarity] then
        local Stats = unit.Statistics;
        if Stats.Damage.Tier ~= '神' and Stats.SPA.Tier ~= '神' and Stats.Range.Tier ~= '神' then
            return true
        end
    end
    return false
end

local function findUnit()
    for _, category in ipairs({"Vanguard", "Exclusive", "Mythic"}) do
        local id = state.StatReroll.rerollQueue[category][1]
        if id then
            state.StatReroll.selected = id
            return id
        end
    end
end

local function rollUnit()
    state.StatReroll.running = true

    local spend = 0

    while(task.wait(0.4)) do
        if getStatChip() <= 0 then
            print('Spend a total', spend ,'Stat Chip')
            break
        end
        local Unit = OwnedUnits:GetUnits()[state.StatReroll.selected]
        local Stats = Unit.Statistics;
        if Stats.Damage.Tier == '神' or Stats.SPA.Tier == '神' or Stats.Range.Tier == '神' then
            if (spend <= 0) then break end
            warn(Unit.UnitData.Name, "has been 神 stat")
            print('Spend a total', spend ,'Stat Chip')
            table.remove(state.StatReroll.rerollQueue[Unit.UnitData.Rarity], 1)
            state.StatReroll.history[Unit.UniqueIdentifier] = spend
            state.StatReroll.selected = nil
            break;
        end
        warn('Reroll', Unit.UnitData.Name, "stats, before stats:", Stats.Damage.Tier, Stats.SPA.Tier, Stats.Range.Tier)
        statReroll(Unit.UniqueIdentifier)
        spend += 1
    end

    state.StatReroll.running = false
end

local function sendWebhook()
    local HttpService = game:GetService("HttpService")

    local emoji = {
        ['Ice Queen (Release)'] = "<:av_ice_queen_release:1479374524926398545>",
        ['Manipulator'] = "<:av_manipulator:1482254513376202784>",
        ['Arbiter'] = "<:av_arbiter:1482254458908971250>",

        stat_chip = "<:av_stat_chip:1479370868894339173>",
        damage = "<:av_stat_damage:1479362894557872128>",
        spa = "<:av_stat_spa:1479363242227929200>",
        range = "<:av_stat_range:1479363320413683723>"
    }

    local body = {
        embeds = {{
            title = "ᴀɴɪᴍᴇ ᴠᴀɴɢᴜᴀʀᴅs ─ sᴛᴀᴛs ʀᴇʀᴏʟʟ",
            color = 3498098,
            fields = {
                {
                    name = "Player ID: " .. "||" .. game:GetService("Players").LocalPlayer.DisplayName .. "||",
                    value = "",
                    inline = false
                }
            },

            timestamp = DateTime.now():ToIsoDate(),

            footer = {
                text = "EMP Hub"
            }
        }}
    }

    local function addField(Unit, Spend)
        local field = {}
        field.name = emoji[Unit.UnitData.Name] and emoji[Unit.UnitData.Name] .. " " .. Unit.UnitData.Name or Unit.UnitData.Name
        local Stats = Unit.Statistics
        field.value = 
            ("| Spend: " .. Spend .. emoji.stat_chip .. "\n") ..
            " - " .. emoji.damage .. ": " .. Stats.Damage.Tier .. " ─ `" .. Stats.Damage.Percentage .. "%`" .. "\n" ..
            " - " .. emoji.spa .. ": " .. Stats.SPA.Tier .. " ─ `" .. Stats.SPA.Percentage .. "%`" .. "\n" ..
            " - " .. emoji.range .. ": " .. Stats.Range.Tier .. " ─ `" .. Stats.Range.Percentage .. "%`" .. "\n" ..
            "─────────────────"
        field.inline = true
        table.insert(body.embeds[1].fields, field);
    end

    local index = 1;

    for k,v in pairs(state.StatReroll.history) do
        local Unit = OwnedUnits:GetUnits()[k]

        if Unit then 
            addField(Unit, v)
            index += 1
        end
    end

    local res = request({
        Url = "https://discord.com/api/webhooks/1479376801112522883/leVv7jYgn4GoudXs13tZBtAz98nX8MmkDfKMooqgZvPQnVpPxOKXbenshr3YgUu6CG9x",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(body)
    })
end

task.spawn(function()
    local count = 1;
    for uuid,unit in pairs(OwnedUnits:GetUnits()) do
        --getData(unit, count)
        if canRerollStats(unit) then
            table.insert(state.StatReroll.rerollQueue[unit.UnitData.Rarity], unit.UniqueIdentifier)
        end
        count+=1
    end

    while(task.wait(0.25)) do
        if not state.StatReroll.selected then
            pcall(findUnit)
        end

        if not state.StatReroll.running and state.StatReroll.selected then
            if getStatChip() > 0 then
                task.spawn(rollUnit)
            end
        end

        if getStatChip() <= 0 and not state.WebHook.spend then
            state.WebHook.spend = true
            wait(2.5)
            task.spawn(sendWebhook)
        end
    end
end)
