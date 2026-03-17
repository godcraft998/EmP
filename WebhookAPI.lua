local modules = {}

local HttpService = game:GetService("HttpService");

local webhook = {}
webhook.__index = webhook

local embeds = {}
embeds.__index = embeds

local field = {}
field.__index = field

function deepCopyNoFunc(original, seen)
    if type(original) ~= "table" then
        return original
    end

    -- chống loop (circular reference)
    seen = seen or {}
    if seen[original] then
        return seen[original]
    end

    local copy = {}
    seen[original] = copy

    for k, v in pairs(original) do
        -- bỏ qua function
        if type(v) ~= "function" then
            local newKey = deepCopyNoFunc(k, seen)
            local newValue = deepCopyNoFunc(v, seen)
            copy[newKey] = newValue
        end
    end

    return copy
end

function modules.createWebhook()
    return setmetatable({}, webhook)
end

function webhook:Send(url)
    local request = {
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(deepCopyNoFunc(self))
    }

    return request(request);
end

function webhook:setContent(content)
    self.content = content;
    return self
end

function webhook:getContent()
    return self.content or ""
end

function webhook:setUsername(username)
    self.username = username;
    return self
end

function webhook:getUsername()
    return self.username or ""
end

function webhook:setAvatarUrl(avatar_url)
    self.avatar_url = avatar_url;
    return self
end

function webhook:getAvatarUrl()
    return self.avatar_url or ""
end

function webhook:getEmbeds()
    self.embeds = self.embeds or {}
    return self.embeds
end

function webhook:addEmbeds()
    local obj = setmetatable({}, embeds)
    self.embeds = self.embeds or {}
    table.insert(self.embeds, obj)
    return obj
end

function embeds:setTitle(title)
    self.title = title
    return self
end

function embeds:setDescription(description)
    self.description = description
    return self
end

function embeds:setColor(color)
    self.color = color
    return self
end

function embeds:setTimestamp(timestamp)
    self.timestamp = timestamp
    return self
end

function embeds:setAuthor(name, url, icon_url)
    self.authors = self.authors or {}
    self.authors.name = name
    self.authors.url = url
    self.authors.icon_url = icon_url
    return self
end

function embeds:setThumbnail(url)
    self.thumbnail = self.thumbnail or {}
    self.thumbnail.url = url
    return self
end

function embeds:setFooter(text, icon_url)
    self.footer = self.footer or {}
    self.footer.text = text
    self.footer.icon_url = icon_url
    return self
end

function embeds:setImage(url)
    self.image = self.image or {}
    self.image.url = url
    return self
end

function embeds:addField(...)
    local obj = setmetatable({}, field)
    self.fields = self.fields or {}
    obj.name, obj.value, obj.inline = ...
    table.insert(self.fields, obj)
    return obj
end

function field:setName(name)
    self.name = name
    return self
end

function field:setValue(value)
    self.value = value
    return self
end

function field:setInline(inline)
    self.inline = inline;
    return self
end

return modules