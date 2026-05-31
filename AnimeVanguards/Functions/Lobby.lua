local modules = {}

local function Callback(args, RemoteEvent, timeout, callback)
    local done = false
    local response

    local conn
    conn = RemoteEvent.OnClientEvent:Connect(function(...)
        local result = callback(...)
        if result then
            response = result
            done = true
            conn:Disconnect()
        end
    end)

    RemoteEvent:FireServer(unpack(args))

    local start = tick()
    repeat
        task.wait()
    until done or (tick() - start >= timeout)

    if conn then
        conn:Disconnect()
    end

    return response
end

return modules