local SP = game:GetService("StarterPlayer")
local OwnedUnitsHandler = require(SP.Modules.Gameplay.Units.OwnedUnitsHandler)

local modules = {}

local function GetUnits()
    return OwnedUnitsHandler:GetUnits()
end

function modules:FindUnitByID(ID)
    local Units = GetUnits()

    for _,v in pairs(Units) do
        if (v.Identifier == ID) then
            return v
        end
    end
end

function modules:FindUnitByRarity(Rarity)
    for _,v in pairs(GetUnits()) do
        if (v.UnitData.Rarity == Rarity) then
            return v
        end
    end
end

function modules:FindUnitByName(Name)
    for _,v in pairs(GetUnits()) do
        if (v.UnitData.Name == Name) then
            return v
        end
    end
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
