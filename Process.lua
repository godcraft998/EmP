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

local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local Handler = require(SP.Modules.Interface.Loader.Gameplay.Raids.RaidShopDataHandler)

printObject(Handler.GetRaidShopData("Stage4").ShopData)

local CurrencyHandler = require(SP.Modules.Gameplay.CurrencyHandler)
print(CurrencyHandler.GetCurrencyByName("HAPPYCoin"))

local RaidsShopEvent = RS.Networking.Raids.RaidsShopEvent
--RaidsShopEvent:FireServer("Purchase", { "Stage4", "Stat Chip", 400 })
--GetAllRaidCurrencies()["Stage4"] == HAPPYCoin