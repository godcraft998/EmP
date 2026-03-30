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

function modules:TraitReroll(UniqueID)
    local args = {
        [1] = "Reroll",
        [2] = {
            [1] = UniqueID,
            [2] = "Trait"
        }
    }

    local TraitEvent = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Units"):WaitForChild("TraitEvent")
    return Callback(args, TraitEvent, 1.5, function(Name, Data)
        if Name == 'Replicate' then
            return Data
        end
    end)
end

function modules:StatReroll(UniqueID, RollType)
    RollType = RollType or "All"
    local args = {
        [1] = RollType,
        [2] = UniqueID
    }

    local StatRerollEvent = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Units"):WaitForChild("StatRerollEvent")
    return Callback(args, StatRerollEvent, 1.5, function(UnitData)
        return UnitData.Statistics
    end)
end

function modules:GetEventCurrency(Event)
    local args = {
        Event
    }

    local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Events"):WaitForChild("EventCurrencyEvent")
    return Callback(args, RemoteEvent, 1.5, function(Name, Currency)
        return Currency
    end)
end

function modules:PurchaseItem(Shop, Item, Amount)
    local args = {
        [1] = Shop,
        [2] = Item,
        [3] = Amount
    }

    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Shop"):WaitForChild("PurchaseItem"):FireServer(unpack(args))
end

function modules:RequestStock(Shop)
    local RequestStock = game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Shop"):WaitForChild("RequestStock");

    local done = false
    local response

    local conn
    conn = RequestStock.OnClientEvent:Connect(function(name, stocks)
        if name == Shop then
            response = stocks.Stock
            done = true
            conn:Disconnect()
        end
    end)

    RequestStock:FireServer(Shop)

    local timeout = 1.5
    local start = tick()

    repeat
        task.wait()
    until done or (tick() - start >= timeout)

    return response
end

function modules:WinterLTMEvent()
    local args = {
        "Create"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("Winter"):WaitForChild("WinterLTMEvent"):FireServer(unpack(args))
end

function modules:StartMatch()
    local args = {
        "StartMatch"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent"):FireServer(unpack(args))
end

function modules:LeaveMatch()
    local args = {
        "LeaveMatch"
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent"):FireServer(unpack(args))
end

return modules
