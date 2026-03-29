local loader = {}


local config = {
    Path = "Config.json"
}
config.__index = config

function loader:CreateConfig()
    return setmetatable({}, webhook)
end

function config:SetPath(Path)
    self.Path = Path
end

function config:LoadConfig()
    if not isfile(config.Path) then
        return
    else
        local jsonData = readfile(config.Path)
        return HttpService:JSONDecode(jsonData)
    end
end

function config:SaveConfig(Config)
    if not isfolder(config.Path) then
        makefolder(config.Path)
    end

    if not isfile(config.Path) then
        writefile(config.Path, HttpService:JSONEncode({}))
    end
    writefile(config.Path, HttpService:JSONEncode(Config))
end

return loader