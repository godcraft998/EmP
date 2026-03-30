local args = {
	"AddMatch",
	{
		Difficulty = "Nightmare",
		Act = "Act1",
		StageType = "LegendStage",
		Stage = "Stage2",
		FriendsOnly = false
	}
}
game:GetService("ReplicatedStorage"):WaitForChild("Networking"):WaitForChild("LobbyEvent"):FireServer(unpack(args))


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

-- sự kiện lobby của server
game:GetService("ReplicatedStorage").Networking.MatchReplicationEvent.OnClientEvent:Connect(function(action, data)
	print(action)
	printObject(data)
end)