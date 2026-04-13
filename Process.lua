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

local SummonEvent = RS.Networking.Units.SummonEvent
local UnitsEvent = RS.Networking.Units.UnitsEvent

local Event = UnitsEvent

local done = false

local conn
conn = Event.OnClientEvent:Connect(function(...)
    printObject(...)

    done = true
end)


local start = tick()
repeat
    task.wait()
until done or (tick() - start >= 2.5)

if conn then
    conn:Disconnect()

    print("OnClientEvent: timeout")
end