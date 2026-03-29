local loader = {}

local config = {
    Path = "Config.json"
}

function loader:SetPath(Path)
    config.Path = Path
end

function loader:LoadConfig()
    if not isfile(config.Path) then
        return
    else
        local jsonData = readfile(config.Path)
        return HttpService:JSONDecode(jsonData)
    end
end

function loader:SaveConfig(Config)
    if not isfolder(config.Path) then
        makefolder(config.Path)
    end

    if not isfile(config.Path) then
        writefile(config.Path, HttpService:JSONEncode({}))
    end
    writefile(config.Path, HttpService:JSONEncode(Config))
end

return loader