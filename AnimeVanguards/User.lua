local Player = game.Players.LocalPlayer

local modules = {}

function modules:GetAttribute(id)
    return Player:GetAttribute(id)
end

function modules:GetLevel()
    return modules:GetAttribute("Level")
end

return modules