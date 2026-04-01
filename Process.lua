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


local SP = game:GetService("StarterPlayer")

local RS = game:GetService("ReplicatedStorage")
local Handler = require(SP.Modules.Interface.Loader.Events.JamSessionHandler)

local JamSessionEvents = RS.Networking.Events.JamSession
local Remote_GetScores = JamSessionEvents.GetScores

-- lấy dữ liệu của các bài đã chơi
printObject(Handler)

local DataHandler = require(RS.Modules.Data.EventsData)

--Skele King's Jam Session