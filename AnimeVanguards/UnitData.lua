local SP = game:GetService("StarterPlayer")
local OwnedUnitsHandler = require(SP.Modules.Gameplay.Units.OwnedUnitsHandler)

local modules = {}

local function GetUnits()
    return OwnedUnitsHandler:GetUnits()
end

function modules:GetName(UniqueID)
    local Unit = GetUnits()[UniqueID]
    if Unit then
        return Unit.UnitData.Name
    end
end

function modules:GetID(UniqueID)
    local Unit = GetUnits()[UniqueID]
    if (Unit) then
        return Unit.UnitData.ID
    end
end

function modules:GetTrait(UniqueID)
    local Unit = GetUnits()[UniqueID]
    if (Unit) then
        return Unit.Trait.Name
    end
end

function modules:GetRarity(UniqueID)
    local Unit = GetUnits()[UniqueID]
    if (Unit) then
        return Unit.UnitData.Rarity
    end
end

function modules:GetStatistic(UniqueID)
    local Unit = GetUnits()[UniqueID]
    if (Unit) then
        return Unit.Statistic
    end
end

return modules
