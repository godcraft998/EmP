local loader = {}


local config = {
    Path = "Config.json"
}
config.__index = config

function loader:CreateConfig()
    return setmetatable({}, config)
end

function config:SetPath(Path)
    self.Path = Path
end

function config:LoadConfig()
    if not isfile(self.Path) then
        return
    else
        local jsonData = readfile(self.Path)
        return HttpService:JSONDecode(jsonData)
    end
end

function config:SaveConfig(Config)
    if not isfolder(self.Path) then
        makefolder(self.Path)
    end

    if not isfile(self.Path) then
        writefile(self.Path, HttpService:JSONEncode({}))
    end
    writefile(self.Path, HttpService:JSONEncode(Config))
end

return loader