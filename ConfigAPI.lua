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
	local folder, file = string.match(self.Path, "(.+)/([^/]+)$")

    if not isfolder(folder) then
        makefolder(folder)
    end
	
    writefile(self.Path, game:GetService("HttpService"):JSONEncode(Config))
end

return loader