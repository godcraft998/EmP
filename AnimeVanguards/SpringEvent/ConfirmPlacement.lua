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
local PG = game:GetService("Players").LocalPlayer.PlayerGui

task.spawn(function()
    local WallPlacement PG.HUD.SpringEventHUD.WallPlacementHUD
    while true do
        task.wait(1)

        if WallPlacement and WallPlacement.Visible then
            RS:WaitForChild("Networking"):WaitForChild("SpringEvent"):WaitForChild("ConfirmPlacement"):FireServer()
        end
    end
end)