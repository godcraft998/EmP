local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local ClientUnitHandler = require(SP.Modules.Gameplay.Units.ClientUnitHandler)

local macro = {
    StartTime = 0,
    Selected = nil,
    IsRecording = false,
    Count = 0,
    Recording = {}
}

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

local function InsertRecording(obj)
    macro.Count += 1
    obj.Time = (time() - macro.StartTime)
    macro.Recording[tostring(macro.Count)] = obj
end

local old

old = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method == "FireServer" and typeof(self) == "Instance" then
		if macro.IsRecording then
			task.spawn(function()
                local REN = self:GetFullName()

                if (REN:find("Networking.SkipWaveEvent")) then
                    local obj = {}

                    obj.Type = "SkipWave"
                    obj.Time = (time() - macro.StartTime)
                    InsertRecording(obj)
                end

                if (REN:find("Networking.AbilityEvent")) then
                    local obj = {}

                    local data = ClientUnitHandler:GetUnitByGUID(args[2])

                    obj.Type = "UseAbility"
                    obj.Unit = data.Data.Name
                    obj.Position = {data.Position.X, data.Position.Y, data.Position.Z}
                    obj.Ability = args[3]

                    InsertRecording(obj)
                end

                if (REN:find("Networking.AutoAbilityEvent")) then
                    local obj = {}

                    local data = ClientUnitHandler:GetUnitByGUID(args[2])

                    obj.Type = "AutoAbility"
                    obj.Status = args[1]
                    obj.Unit = data.Data.Name
                    obj.Position = {data.Position.X, data.Position.Y, data.Position.Z}
                    obj.Ability = args[3]

                    InsertRecording(obj)
                end

				if (REN:find("Networking.UnitEvent")) then
					local state = args[1]
                    local obj = {}

                    if state == "Render" then
                        local data = args[2]

                        obj.Type = "Place"
                        obj.Unit = data[1]
                        obj.Position = {data[3].X, data[3].Y, data[3].Z}
                    elseif state == "Upgrade" then
                        local data = ClientUnitHandler:GetUnitByGUID(args[2])

                        obj.Type = "Upgrade"
                        obj.Unit = data.Data.Name
                        obj.Position = {data.Position.X, data.Position.Y, data.Position.Z}
                    elseif state == "UpgradeMultiple" then
                        local data = ClientUnitHandler:GetUnitByGUID(args[2])

                        obj.Type = "UpgradeMultiple"
                        obj.Unit = data.Data.Name
                        obj.Position = {data.Position.X, data.Position.Y, data.Position.Z}
                        obj.Amount = args[3]
                    elseif state == "Sell" then
                        local data = ClientUnitHandler:GetUnitByGUID(args[2])

                        obj.Type = "Sell"
                        obj.Unit = data.Data.Name
                        obj.Position = {data.Position.X, data.Position.Y, data.Position.Z}
                    end

                    InsertRecording(obj)
				end

                if REN:find("Networking.Units.AutoUpgradeEvent") then
                    local state = args[1]
                end

                if REN:find("Networking.SpringEvent") then
                    local obj = {}

                    if REN:find("PlaceWall") then
                        obj.Type = "PlaceWall"
                        obj.Position = {args[1], args[2]}
                        InsertRecording(obj)
                    elseif REN:find("RemoveWall") then
                        obj.Type = "RemoveWall"
                        InsertRecording(obj)
                    elseif REN:find("ConfirmPlacement") then
                        obj.Type = "ConfirmPlacement"
                        InsertRecording(obj)
                    end

                    if REN:find("ShopEvent") and args[1] == "Purchase" then
                        obj.Type = "SpringShopPurchase"
                        obj.ItemId = args[2]
                        InsertRecording(obj)
                    end
                end
			end)
		end
    end

    return old(self, ...)
end)

local ConfigAPI = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/ConfigAPI.lua"))()



task.spawn(function()
    macro.StartTime = time()
    macro.IsRecording = true

    while true do
        if (time() - macro.StartTime) >= 30 then
            macro.IsRecording = false

            local MacroConfig = ConfigAPI:CreateConfig()
            MacroConfig:SetPath("EmP/AnimeVanguards/Macro/demo.json")
            MacroConfig:SaveConfig(macro.Recording)
			break
        end
		
		print((time() - macro.StartTime))

        wait(0.5)
    end
end)