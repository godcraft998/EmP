local player = game.Players.LocalPlayer

local function printObject(instance, title)
    local count = 1;
    warn(title and title or "--- ᴘʀɪɴᴛ ᴏʙᴊᴇᴄᴛ ---")
    if typeof(instance) == 'table' then
        for k, v in pairs(instance) do
            warn(count .. ":", k, "-", v)
            count += 1;
        end
    else
        warn(instance)
    end
end

function CreateMatch(data)
    local args = {
        "AddMatch",
        {
            Difficulty = data.Difficulty,
            Act = data.Act,
            StageType = data.StageType,
            Stage = data.Stage,
            FriendsOnly = data.FriendsOnly or false
        }
    }

    local LobbyEvent = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent")
    local MatchEvent = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("MatchReplicationEvent")

    local done = false
    local response

    local conn
    conn = MatchEvent.OnClientEvent:Connect(function(action, data)
        if action and action == "AddMatch" and data and data.Host == player then
            done = true
            response = data
            conn:Disconnect()
        end
    end)

    LobbyEvent:FireServer(unpack(args))

    local start = tick()
    repeat
        task.wait()
    until done or (tick() - start >= 2.5)

    if conn then
        conn:Disconnect()
    end

    return response
end

local function GetSession()
    local sessionDuration = 5 * 60 -- 5 phút = 300 giây
    return math.floor(tick() / sessionDuration)
end

local ConfigAPI = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/ConfigAPI.lua"))();

task.spawn(function()
    

    local JobId = "694752a3-57f7-46fc-99d3-0f7890790f0f"
    print(game.JobId)
    if game.JobId ~= JobId then
        --game:GetService("TeleportService"):TeleportToPlaceInstance(16146832113, JobId)
    end
)