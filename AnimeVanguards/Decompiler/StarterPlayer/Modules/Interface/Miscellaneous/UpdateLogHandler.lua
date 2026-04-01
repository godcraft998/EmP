-- UpdateLog UI handler (gộp 1 file, đã đổi tên biến và chú thích)
-- Mục đích: quản lý giao diện Update Log, populate nội dung update, xử lý sự kiện UI và RemoteEvent

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Workspace = workspace

-- Module requires (giữ nguyên đường dẫn gốc)
local GeneralData = require(ReplicatedStorage.Modules.Data.GeneralData)
local TextUtils = require(ReplicatedStorage.Modules.Utilities.TextUtils)
local EventsData = require(ReplicatedStorage.Modules.Data.EventsData)
local ResourceTemplateHandler = require(ReplicatedStorage.Modules.Interface.ResourceTemplateHandler)
local ElementToggleHandler = require(StarterPlayer.Modules.Interface.Classes.ElementToggleHandler)
local PopupHandler = require(StarterPlayer.Modules.Interface.Loader.Misc.PopupHandler)
local EventInfoHandler = require(StarterPlayer.Modules.Gameplay.Events.EventsHandler.EventInfoHandler)
local EventsAnimationHandler = require(StarterPlayer.Modules.Gameplay.Events.EventsHandler.EventsAnimationHandler)
local EventBannersHandler = require(StarterPlayer.Modules.Gameplay.Events.EventsHandler.EventBannersHandler)
local EventsHandler = require(StarterPlayer.Modules.Gameplay.Events.EventsHandler)

-- RemoteEvent
local UpdateLogEvent = ReplicatedStorage.Networking.UpdateLogEvent

-- Public interface returned
local UpdateLogInterface = {
    LastLoggedInUpdate = nil,
    ShowOncePerUpdate = false
}

-- UI templates and clones
local Assets = script.Assets
local Template_Pyseph = Assets.PysephContainer
local Template_CustomHeader = Assets.CustomHeader
local Template_GameModeButton = Assets.GameModeButton
local Template_EventHeader = Assets.EventHeader
local UI_Clone = script.UpdateLogFullScreen:Clone()

local UpdateLogFrame = UI_Clone.Main.Clip.ScrollingFrame.UpdateLog
local RightSide = UpdateLogFrame.RightSide
local NewUnitsContainer = RightSide.NewUnits
local NewItemsContainer = RightSide.NewItems
local Label_UpdateName = UpdateLogFrame.UpdateName
local Label_PatchNotes = UpdateLogFrame.PatchNotesContent
local EventsContainer = UI_Clone.Main.EventOptions.Events
local ClipRoot = UI_Clone.Main.Clip

local CURRENT_UPDATE = GeneralData.CurrentUpdate

-- =========================
-- Helper functions (chú thích rõ ràng)
-- =========================

-- destroyChildrenIf
-- Mục đích: Xóa tất cả con của parent nếu predicate(child) trả về true.
-- Side-effect: Thao tác trực tiếp trên cây UI.
local function destroyChildrenIf(parent, predicate)
    for _, child in ipairs(parent:GetChildren()) do
        if predicate(child) then
            child:Destroy()
        end
    end
end

-- clearUI
-- Mục đích: Reset giao diện UpdateLog về trạng thái mặc định, xóa các mục tạm thời.
-- Tham số: keepElement (optional) - nếu truyền, giữ phần tử đó (ví dụ highlight đang mở).
-- Side-effect: ẩn/hiện các phần UI, xóa clone, reset text.
local function clearUI(keepElement)
    -- Xóa frame trong NewUnits/NewItems
    destroyChildrenIf(NewUnitsContainer, function(c) return c.ClassName == "Frame" end)
    destroyChildrenIf(NewItemsContainer, function(c) return c.ClassName == "Frame" end)

    -- Xóa các entry Event/Update trừ phần tử đang giữ
    destroyChildrenIf(EventsContainer, function(c)
        if c == keepElement then return false end
        return c.Name == "Event"
    end)
    destroyChildrenIf(EventsContainer, function(c)
        if c == keepElement then return false end
        return c.Name == "Update"
    end)

    -- Xóa custom headers và gamemode buttons cũ
    destroyChildrenIf(RightSide, function(c) return c.Name == "CustomHeader" end)
    destroyChildrenIf(RightSide, function(c) return c.Name == "GameModeButton" end)

    -- Reset labels và visuals
    Label_UpdateName.Text = ""
    Label_PatchNotes.Text = ""
    UI_Clone.Background.Image = "rbxassetid://71352463233612"
    ClipRoot.Visible = false
    UI_Clone.Main.EventOptions.Events.Divider.Visible = false
    UI_Clone.Main.Proceed.Visible = false

    local showOnce = UI_Clone.Main:FindFirstChild("ShowOncePerUpdate")
    if showOnce then showOnce:Destroy() end
end

-- getEventStatusInfo
-- Mục đích: Tính trạng thái hiển thị của một event (Removed, Permanent, Until X, Remaining countdown).
-- Trả về: textColor, statusText, bgImage, bucketIndex
-- Side-effect: Nếu event có ActiveDuring, hàm sẽ kết nối RenderStepped để cập nhật countdown và tự disconnect khi UI element bị Destroy.
local function getEventStatusInfo(eventData, uiClone)
    if not eventData then
        return Color3.fromRGB(0, 255, 30), "Removed", "rbxassetid://81940157567865", 1
    end

    local bgImage, bucketIndex
    if eventData.IsRecurring then
        bgImage = "rbxassetid://87537809878286"
        bucketIndex = 2
    elseif eventData.IsPermanent then
        bgImage = "rbxassetid://119939583937591"
        bucketIndex = 3
    else
        bgImage = "rbxassetid://81940157567865"
        bucketIndex = 1
    end

    if eventData.IsPermanent then
        return Color3.fromRGB(0, 255, 30), "Permanent", bgImage, bucketIndex
    end

    if eventData.ActiveUntilUpdate then
        return Color3.fromRGB(0, 255, 30), "Until " .. eventData.ActiveUntilUpdate:gsub("_", " "), bgImage, bucketIndex
    end

    if eventData.ActiveDuringUpdate then
        return Color3.fromRGB(0, 255, 30), eventData.ActiveDuringUpdate:gsub("_", " "), bgImage, bucketIndex
    end

    -- Parse ActiveDuring "d/m/y"
    local d, m, y = eventData.ActiveDuring:match("^(%d+)/(%d+)/(%d+)$")
    local day = tonumber(d)
    local month = tonumber(m)
    local year = tonumber(y)
    local startUnix = DateTime.fromUniversalTime(year, month, day).UnixTimestamp
    local endUnix = startUnix + (eventData.ActiveTimeInDays * 86400)

    -- Kết nối RenderStepped để cập nhật countdown
    local conn = RunService.RenderStepped:Connect(function()
        local now = Workspace:GetServerTimeNow()
        if now < startUnix then
            local diff = startUnix - now
            local days = math.floor(diff / 86400)
            local hours = math.floor((diff % 86400) / 3600)
            local mins = math.floor((diff % 3600) / 60)
            uiClone.Pyseph.EventDate.Text = TextUtils.RecolorNumbersInString(("Begins in: %*d %*h %*m"):format(days, hours, mins))
            return
        else
            local remaining = endUnix - now
            if remaining > 0 then
                local days = math.floor(remaining / 86400)
                local hours = math.floor((remaining % 86400) / 3600)
                local mins = math.floor((remaining % 3600) / 60)
                uiClone.Pyseph.EventDate.Text = TextUtils.RecolorNumbersInString(("Remaining: %*d %*h %*m"):format(days, hours, mins))
            end
        end
    end)

    -- Disconnect khi UI element bị Destroy
    uiClone.Destroying:Connect(function()
        conn:Disconnect()
    end)

    return nil, nil, bgImage, bucketIndex
end

-- populateUpdateLog
-- Mục đích: Điền nội dung chi tiết cho một update cụ thể (units, items, events, gamemodes, headers, patch notes).
-- Tham số: updateData (table), uiElement (clone tương ứng để giữ highlight/countdown)
-- Side-effect: clone UI, kết nối sự kiện click, cập nhật CanvasSize
local function populateUpdateLog(updateData, uiElement)
    clearUI(uiElement)

    local pyseph = uiElement.Pyseph
    EventsAnimationHandler.AnimateArrow(pyseph)
    EventsAnimationHandler.AnimateBannerPress(pyseph, true)

    UI_Clone.Main.Proceed.Visible = true
    UpdateLogInterface.HandleShowOncePerUpdateButton()

    -- Units
    for _, unitName in ipairs(updateData.Units) do
        ResourceTemplateHandler.Create({
            ResourceData = { Type = "Unit", Name = unitName },
            FrameData = { Name = unitName, Parent = NewUnitsContainer, Size = UDim2.new(0, 96, 0, 96) },
            ExtraData = { ShowName = false }
        })
    end

    -- Items
    if next(updateData.Items) == nil then
        RightSide.NewItems.Visible = false
        RightSide.Title_NewItems.Visible = false
    else
        for _, itemName in ipairs(updateData.Items) do
            ResourceTemplateHandler.Create({
                ResourceData = { Type = "Item", Name = itemName },
                FrameData = { Name = itemName, Parent = NewItemsContainer, Size = UDim2.new(0, 96, 0, 96) },
                ExtraData = { ShowName = false }
            })
        end
        RightSide.NewItems.Visible = true
        RightSide.Title_NewItems.Visible = true
    end

    -- Events: phân bucket để sắp xếp (1 normal, 2 recurring, 3 permanent)
    local bucketCounts = {0, 0, 0}
    for _, eventInfo in ipairs(updateData.Events) do
        local eventName = eventInfo.Name
        local customHeaderText = eventInfo.CustomHeader
        local eventData = EventsData.GetEventData(eventName)

        -- Click handler cho event entry
        local function onEventActivated()
            if EventsData:GetCurrentEvents()[eventName] then
                local eventType = EventInfoHandler.GetEventType(eventName)
                UpdateLogInterface.CloseInterface()
                EventsHandler.OpenInterface()
                EventBannersHandler.CreateAllFrames({}, eventType)
                EventsHandler.HandleSelectEvent(eventName)
            else
                PopupHandler:ShowPopup("BaseCancelFrame", "This Event is no longer active.")
            end
        end

        local entry = Template_Pyseph:Clone()
        entry.Pyseph.EventTitle.Text = eventName
        entry.Pyseph.EventDate.Text = ""
        entry.Pyseph.Activated:Connect(onEventActivated)

        if customHeaderText then
            local header = Template_EventHeader:Clone()
            header.Text = customHeaderText
            header.Parent = entry.Pyseph
            entry.Pyseph.EventTitle.Position = UDim2.fromScale(0.419, 0.34)
            entry.Pyseph.EventDate.Position = UDim2.fromScale(0.419, 0.66)
        end

        local color, statusText, bgImage, bucketIndex = getEventStatusInfo(eventData, entry)
        bucketCounts[bucketIndex] = bucketCounts[bucketIndex] + 1
        entry.Pyseph.TextLabel.Visible = true
        entry.Pyseph.TextLabel.Text = bucketCounts[bucketIndex]

        if statusText and color then
            entry.Pyseph.EventDate.Text = statusText
            entry.Pyseph.EventDate.TextColor3 = color
        end
        if bgImage then
            entry.Pyseph.BG.Image = bgImage
        end

        entry.Name = "Event"
        entry.LayoutOrder = 100 * bucketIndex
        entry.Parent = EventsContainer
    end

    -- Gamemodes
    for _, gm in ipairs(updateData.Gamemodes) do
        local headerText = gm.Header
        local title = gm.Title
        local description = gm.Description
        local image = gm.Image
        local buttonText = gm.ButtonText
        local buttonColor = gm.ButtonColor
        local callback = gm.ButtonCallback

        local header = Template_CustomHeader:Clone()
        header.LayoutOrder = 5
        header.Text.Text = headerText
        header.Parent = RightSide

        local modeButton = Template_GameModeButton:Clone()
        modeButton.ModeDescription.Text = description
        modeButton.ModeName.Text = title
        modeButton.Fade.Background.Image = image or "rbxassetid://94275343457322"

        local bg = buttonColor and Color3.new(buttonColor.R * 0.6, buttonColor.G * 0.6, buttonColor.B) or Color3.fromRGB(0, 177, 27)
        local inner = buttonColor or Color3.fromRGB(0, 255, 42)
        modeButton.Button.BackgroundColor3 = bg
        modeButton.Button.Inner.BackgroundColor3 = inner
        modeButton.Button.Label.Text = buttonText or "Play!"
        modeButton.Button.Button.Activated:Connect(function()
            if callback then
                callback(UpdateLogInterface)
            else
                print(("GameMode button activation for %s caught!"):format(title))
            end
        end)
        modeButton.Parent = RightSide
    end

    -- Headers
    for _, headerText in ipairs(updateData.Headers) do
        local header = Template_CustomHeader:Clone()
        header.LayoutOrder = 7
        header.Text.Text = headerText
        header.Parent = RightSide
    end

    -- Update name and patch notes
    Label_UpdateName.Text = "Update " .. updateData.UpdateName
    Label_PatchNotes.Text = updateData.TextContent

    ClipRoot.Visible = true
    UI_Clone.Main.EventOptions.Events.Divider.Visible = true
    UI_Clone.Background.Image = updateData.BackgroundImage

    -- Adjust canvas sizes
    EventsContainer.CanvasSize = UDim2.fromOffset(0, EventsContainer.UIListLayout.AbsoluteContentSize.Y)
    ClipRoot.ScrollingFrame.CanvasSize = UDim2.fromOffset(0, ClipRoot.ScrollingFrame.UIListLayout.AbsoluteContentSize.Y)
end

-- populateUpdatesList
-- Mục đích: Tạo danh sách entry cho tất cả updates hoặc chỉ update hiện tại
-- Tham số: singleOnly (boolean) - nếu true chỉ populate update hiện tại
local function populateUpdatesList(singleOnly)
    if singleOnly then
        local updateModule = script.Updates:FindFirstChild(("%*"):format(CURRENT_UPDATE))
        local errMsg = ("Update log for version %s not found!"):format(CURRENT_UPDATE)
        local module = assert(updateModule, errMsg)
        local updateData = require(module)

        local entry = Template_Pyseph:Clone()
        entry.Pyseph.EventTitle.Text = updateData.UpdateName
        entry.Pyseph.EventDate.Text = "Update"
        entry.Pyseph.Activated:Connect(function()
            populateUpdateLog(updateData, entry)
        end)

        entry.Name = "Update"
        entry.LayoutOrder = -100
        if updateData.BackgroundImage then
            entry.Pyseph.UpdateBackground.Image = updateData.BackgroundImage
            entry.Pyseph.UpdateBackground.Visible = true
        end
        entry.Parent = EventsContainer

        populateUpdateLog(updateData, entry)
        EventsAnimationHandler.AnimateArrow(entry.Pyseph)
        EventsAnimationHandler.AnimateBannerPress(entry.Pyseph, true)
    else
        for _, child in ipairs(script.Updates:GetChildren()) do
            local updateData = require(child)
            local entry = Template_Pyseph:Clone()
            entry.Pyseph.EventTitle.Text = updateData.UpdateName
            entry.Pyseph.EventDate.Text = "Update"
            entry.Pyseph.Activated:Connect(function()
                populateUpdateLog(updateData, entry)
            end)
            entry.Name = "Update"

            -- layout order dựa trên tên file "Update_X"
            local index = string.split(child.Name, "Update_")[2]
            entry.LayoutOrder = tonumber(index) * -100

            if updateData.BackgroundImage then
                entry.Pyseph.UpdateBackground.Image = updateData.BackgroundImage
                entry.Pyseph.UpdateBackground.Visible = true
            end
            entry.Parent = EventsContainer
        end
        EventsContainer.CanvasSize = UDim2.fromOffset(0, EventsContainer.UIListLayout.AbsoluteContentSize.Y)
    end
end

-- =========================
-- Public API: Open/Close/HandleShowOnce
-- =========================

function UpdateLogInterface.OpenInterface()
    UI_Clone.Enabled = true

    local updateModule = script.Updates:FindFirstChild(("%*"):format(CURRENT_UPDATE))
    local errMsg = ("Update log for version %s not found!"):format(CURRENT_UPDATE)
    local module = assert(updateModule, errMsg)
    local updateData = require(module)

    local entry = Template_Pyseph:Clone()
    entry.Pyseph.EventTitle.Text = updateData.UpdateName
    entry.Pyseph.EventDate.Text = "Update"
    entry.Pyseph.Activated:Connect(function()
        populateUpdateLog(updateData, entry)
    end)

    entry.Name = "Update"
    entry.LayoutOrder = -100
    if updateData.BackgroundImage then
        entry.Pyseph.UpdateBackground.Image = updateData.BackgroundImage
        entry.Pyseph.UpdateBackground.Visible = true
    end
    entry.Parent = EventsContainer

    populateUpdateLog(updateData, entry)
    EventsAnimationHandler.AnimateArrow(entry.Pyseph)
    EventsAnimationHandler.AnimateBannerPress(entry.Pyseph, true)

    return UI_Clone
end

function UpdateLogInterface.CloseInterface()
    UI_Clone.Enabled = false
    clearUI()
end

local showOnceState = false

function UpdateLogInterface.HandleShowOncePerUpdateButton()
    local existing = UI_Clone.Main:FindFirstChild("ShowOncePerUpdate")
    if existing then existing:Destroy() end

    local clone = script.Assets.ShowOncePerUpdate:Clone()
    clone.Parent = UI_Clone.Main
    ElementToggleHandler.Init(clone, showOnceState, function(value)
        UpdateLogEvent:FireServer("Update", value)
    end)
end

-- =========================
-- Initialization
-- =========================

task.spawn(function()
    UpdateLogEvent:FireServer("Initialize")
    UpdateLogEvent.OnClientEvent:Connect(function(action, payload)
        if action == "Update" then
            showOnceState = payload
            UpdateLogInterface.ShowOncePerUpdate = payload
        elseif action == "Initialize" then
            UpdateLogInterface.LastLoggedInUpdate = payload.LastLoggedInUpdate
            UpdateLogInterface.ShowOncePerUpdate = payload.ShowOncePerUpdate
            showOnceState = UpdateLogInterface.ShowOncePerUpdate
        end
    end)

    UI_Clone.Parent = Players.LocalPlayer.PlayerGui

    UI_Clone.Main.Close.Activated:Connect(function()
        UpdateLogInterface.CloseInterface()
    end)
    UI_Clone.Main.Close.SecondaryButton.Activated:Connect(function()
        UpdateLogInterface.CloseInterface()
    end)
    UI_Clone.Main.Proceed.Button.Activated:Connect(function()
        clearUI()
        populateUpdatesList(false)
    end)
end)

return UpdateLogInterface
