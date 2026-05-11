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
local PG = game:GetService("Players").LocalPlayer.PlayerGui

local Handler = require(SP.Modules.Gameplay.SpringEvent.SpringShopClient)

printObject(Handler.Snapshot().Purchases)