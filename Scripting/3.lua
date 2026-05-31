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

local Functions = loadstring(game:HttpGet("https://raw.githubusercontent.com/godcraft998/EMP/refs/heads/main/AnimeVanguards/FunctionEvents.lua"))();

printObject(Functions:RequestStock("World Destroyer Shop"))

local args = {
	"AddMatch",
	{
		Difficulty = "Normal",
		Act = "Act1",
		StageType = "Story",
		Stage = "Stage1",
		FriendsOnly = false
	}
}
game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent"):FireServer(unpack(args))

local args = {
    "StartMatch"
}
game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent"):FireServer(unpack(args))
