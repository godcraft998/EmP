local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = ReplicatedStorage.Networking
local MatchReplicationEvent = Networking.MatchReplicationEvent

-- Receive updates

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

local conn
conn = MatchReplicationEvent.OnClientEvent:Connect(function(action, data)
    if action == "LoadMatches" then
		for guid, match in pairs(data) do
            printObject(match)
        end
	end
end)

MatchReplicationEvent:FireServer("RetrieveMatches")

wait(2.5)
conn:Disconnect()