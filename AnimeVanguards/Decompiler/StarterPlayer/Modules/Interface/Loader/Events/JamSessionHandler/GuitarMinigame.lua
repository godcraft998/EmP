-- GuitarMinigame.lua
-- Mục đích: xử lý minigame Guitar (tạo note, render conveyor, xử lý input, tính điểm, phát hiệu ứng)
-- Trả về: bảng sự kiện public (MinigameEnded)

-- Services
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Packages / modules
local FastSignal = require(ReplicatedStorage.Modules.Packages.FastSignal)
local BeatMapFormatter = require(script.BeatMapFormatter)
local NoteHandler = require(script.NoteHandler)
local ScoreHandler = require(script.ScoreHandler)
local ImageUtils = require(script.ImageUtils)
local KeybindsData = require(StarterPlayer.Modules.Gameplay.Keybinds.KeybindsDataHandler)

-- Public events
local Events = {
    MinigameEnded = FastSignal.new()
}

-- Color palette cho các nút
local BUTTON_COLORS = {
    Color3.new(0.6, 0, 1),
    Color3.new(1, 0, 0.6),
    Color3.new(0, 0.6, 1),
    Color3.new(0, 1, 0.6),
    Color3.new(1, 0.6, 0),
    Color3.new(1, 1, 1)
}

-- Pool cache cho note UI (tái sử dụng)
local notePool = table.create(6, 1)

-- Mapping cho pattern detection (dùng khi check multi-press)
local PATTERN_TABLE = {
    {1, 2, 3},
    {2, 3},
    {3, 2, 1}
}

-- Active note instances by id (string id -> Instance)
local activeNotesById = {}

-- Local player / gui refs
local LocalPlayer = Players.LocalPlayer
local heartbeatConn = nil
local guiRoot = nil
local Assets = script.Assets

-- Internal state for button press values (1 = idle, 3 = pressed, etc.)
local buttonStates = {0, 0, 0, 0, 0, 0}

-- =========================
-- Initialization helpers
-- =========================

-- _Init: chuẩn bị hiệu ứng cho các nút (clone effect frames vào mỗi ImageButton)
-- Side-effect: thay đổi các ImageButton trong GUI template (script.GuitarMinigame.Page.Main.Bottom)
function Events._Init()
    local bottom = script.GuitarMinigame.Page.Main.Bottom
    for _, imgBtn in bottom:QueryDescendants(">ImageButton") do
        local color = BUTTON_COLORS[imgBtn.LayoutOrder]
        imgBtn.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)

        local pressEffect = Assets.PressEffect:Clone()
        pressEffect.Size = UDim2.fromScale(2, 2)
        pressEffect.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.75)
        pressEffect.Visible = false
        pressEffect.Parent = imgBtn

        local perfectEffect = Assets.PerfectEffect:Clone()
        perfectEffect.Size = UDim2.fromScale(2, 2)
        perfectEffect.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.75)
        perfectEffect.Visible = false
        perfectEffect.Parent = imgBtn

        local holdEffect = Assets.NoteHoldEffect:Clone()
        holdEffect.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.75)
        holdEffect.Visible = false
        holdEffect.Parent = imgBtn
    end
end

-- =========================
-- Public API: Open / Close / IsActive
-- =========================

-- IsActive: trả về true nếu GUI đang mở
function Events.IsActive()
    return guiRoot ~= nil
end

-- Open: clone GUI, bind close handlers, bind score UI
-- Side-effect: tạo guiRoot, bind Destroying cleanup
function Events.Open()
    if guiRoot then return end

    guiRoot = script.GuitarMinigame:Clone()
    guiRoot.Parent = LocalPlayer.PlayerGui
    guiRoot.Enabled = true

    guiRoot.Close.Activated:Connect(function()
        Events.Cleanup()
    end)
    guiRoot.Exit.Button.Activated:Connect(function()
        Events.Cleanup()
    end)

    local unbindButtons = Events.HandleButtons()
    guiRoot.Destroying:Connect(function()
        unbindButtons()
        ScoreHandler.UnbindFromUi()
        ScoreHandler.Reset()
    end)

    ScoreHandler.BindToUi(guiRoot)
end

-- Close: destroy GUI and reset buttonStates
function Events.Close()
    if guiRoot then
        guiRoot:Destroy()
        guiRoot = nil
        for i = 1, 6 do
            buttonStates[i] = 0
        end
    end
end

-- =========================
-- Input & UI handling
-- =========================

-- HandleButtons: bind input actions and mobile/touch handlers
-- Returns: function to unbind all actions (call on cleanup)
function Events.HandleButtons()
    if not guiRoot then
        return function() end
    end

    local mobileUI = guiRoot.MobileUI
    local bottom = guiRoot.Page.Main.Bottom

    -- internal handler for button press/release
    local function onButtonInput(buttonName, inputState)
        local isBegin = inputState == Enum.UserInputState.Begin
        local lastChar = string.sub(buttonName, -1, -1)
        local idx = tonumber(lastChar)
        local color = BUTTON_COLORS[idx]
        buttonStates[idx] = isBegin and 3 or 1

        local btnFrame = bottom:FindFirstChild(buttonName)
        if btnFrame then
            TweenService:Create(btnFrame, TweenInfo.new(isBegin and 0 or 0.1), {
                ImageColor3 = isBegin and color:Lerp(Color3.new(), 0.35) or color:Lerp(Color3.new(1, 1, 1), 0.35)
            }):Play()

            if not isBegin then
                ImageUtils.StopImage(btnFrame.NoteHoldEffect, 0.25)
            end
        end
    end

    local usingGamepad = UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1
    local usingTouch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch

    -- controller keycodes fallback (for controller icons)
    local controllerKeys = {
        Enum.KeyCode.ButtonL2,
        Enum.KeyCode.ButtonL1,
        Enum.KeyCode.ButtonR1,
        Enum.KeyCode.ButtonR2,
        Enum.KeyCode.ButtonY
    }

    -- map keybinds to context actions
    local binds = {
        { KeybindsData.GetBind("GuitarHero1"), controllerKeys[1] },
        { KeybindsData.GetBind("GuitarHero2"), controllerKeys[2] },
        { KeybindsData.GetBind("GuitarHero3"), controllerKeys[3] },
        { KeybindsData.GetBind("GuitarHero4"), controllerKeys[4] },
        { KeybindsData.GetBind("GuitarHero5"), controllerKeys[5] }
    }

    -- Bind actions and setup UI callbacks
    for i = 1, 5 do
        local actionName = "Button" .. i
        local priority = Enum.ContextActionPriority.High.Value + 100
        ContextActionService:BindActionAtPriority(actionName, onButtonInput, false, priority, unpack(binds[i]))

        local btnFrame = bottom:FindFirstChild(actionName)
        if btnFrame then
            btnFrame.BiggerButton.MouseButton1Down:Connect(function()
                onButtonInput(actionName, Enum.UserInputState.Begin)
            end)
            btnFrame.BiggerButton.MouseButton1Up:Connect(function()
                onButtonInput(actionName, Enum.UserInputState.End)
            end)
        end

        local mobileBtn = mobileUI:FindFirstChild(i)
        if usingTouch and mobileBtn then
            local touchBtn = mobileBtn.Button
            touchBtn.MouseButton1Down:Connect(function()
                mobileBtn.Gradient.Enabled = false
                onButtonInput(actionName, Enum.UserInputState.Begin)
            end)
            touchBtn.MouseButton1Up:Connect(function()
                mobileBtn.Gradient.Enabled = true
                onButtonInput(actionName, Enum.UserInputState.End)
            end)
            touchBtn.MouseButton1Down:Once(function()
                mobileBtn.Number.Visible = false
            end)
        end

        local keybind = binds[i][1]
        local keybindLabel = btnFrame and btnFrame.Keybind
        if keybindLabel then
            keybindLabel.Text = usingTouch and tostring(i) or (keybind and keybind.Name or keybindLabel.Text)
            keybindLabel.Visible = not usingGamepad
        end

        local controllerIcon = btnFrame and btnFrame:FindFirstChild("ControllerButton")
        if controllerIcon then
            controllerIcon.Visible = usingGamepad
        end

        if usingGamepad and not controllerIcon and btnFrame then
            local img = Instance.new("ImageLabel")
            img.Image = UserInputService:GetImageForKeyCode(controllerKeys[i])
            img.BackgroundTransparency = 1
            img.AnchorPoint = keybindLabel.AnchorPoint
            img.Position = keybindLabel.Position
            img.Size = keybindLabel.Size
            img.Parent = btnFrame
        end
    end

    -- Return unbind function
    return function()
        for i = 1, 6 do
            ContextActionService:UnbindAction("Button" .. i)
        end
    end
end

-- =========================
-- Note pooling / creation
-- =========================

-- _TestNote: debug helper tạo 1 note và tween xuống conveyor
function Events._TestNote(index)
    local note = Assets.Note:Clone()
    note.ImageColor3 = BUTTON_COLORS[index]
    note.Position = UDim2.fromScale(0.5, 0)
    note.Parent = guiRoot.Page.Main.Bottom[("Button%d"):format(index)].Conveyor

    TweenService:Create(note, TweenInfo.new(1, Enum.EasingStyle.Linear), {
        Position = UDim2.fromScale(0.5, 1)
    }):Play()

    task.delay(1, note.Destroy, note)
end

-- PullNote: lấy note instance từ pool hoặc clone mới, cấu hình hold/open nếu cần
-- Trả về: Instance note
function Events.PullNote(noteId)
    local noteType = NoteHandler.GetNoteType(noteId)
    local isOpen = noteType == 6
    local color = BUTTON_COLORS[noteType]
    local pooled = table.remove(notePool)

    if pooled then
        if pooled:FindFirstChild("Hold") then pooled.Hold:Destroy() end
        if pooled:FindFirstChild("OpenNote") then pooled.OpenNote:Destroy() end
    else
        pooled = Assets.Note:Clone()
    end

    if isOpen then
        pooled.ImageTransparency = 1
        Assets.OpenNote:Clone().Parent = pooled
        pooled.Parent = guiRoot.Page.Main.Bottom.Button3.Conveyor
    else
        pooled.ImageTransparency = 0
        pooled.Visible = true
        pooled.ImageColor3 = color or warn(("No color for %s"):format(tostring(noteType)))
        pooled.Parent = guiRoot.Page.Main.Bottom[("Button%d"):format(noteType)].Conveyor
    end

    activeNotesById[tostring(noteId)] = pooled

    -- Nếu note có duration (hold), tạo frame Hold
    if NoteHandler.GetNoteDuration(noteId) > 0 and not pooled:FindFirstChild("Hold") then
        local holdFrame = Assets.NoteHold:Clone()
        holdFrame.Name = "Hold"
        local heightUnits = NoteHandler.GetNoteStartAlpha(noteId, 0) - NoteHandler.GetNoteEndAlpha(noteId, 0)
        holdFrame.Size = UDim2.new(0, isOpen and 403 or 20, heightUnits, -25)
        holdFrame.Parent = pooled

        for _, f in holdFrame:QueryDescendants(">Frame") do
            f.BackgroundColor3 = color
        end
    end

    return pooled
end

-- CacheNote: ẩn note và đưa vào pool
function Events.CacheNote(noteInstance)
    noteInstance.Visible = false
    table.insert(notePool, noteInstance)
    for id, inst in next, activeNotesById do
        if noteInstance == inst then
            activeNotesById[id] = nil
            return
        end
    end
end

-- CacheNoteById: ẩn note theo id và đưa vào pool
function Events.CacheNoteById(noteId)
    local key = tostring(noteId)
    local inst = activeNotesById[key]
    if inst then
        inst.Visible = false
        table.insert(notePool, inst)
        activeNotesById[key] = nil
    end
end

-- GetNoteById: trả về instance note nếu có, hoặc tạo mới bằng PullNote
function Events.GetNoteById(noteId)
    return activeNotesById[tostring(noteId)] or Events.PullNote(noteId)
end

-- DestroyAllNotes: dọn pool và active notes
function Events.DestroyAllNotes()
    for _, n in next, notePool do n:Destroy() end
    for _, n in next, activeNotesById do n:Destroy() end
    table.clear(notePool)
    table.clear(activeNotesById)
end

-- =========================
-- Cleanup / End game
-- =========================

-- Cleanup: dọn dẹp heartbeat, fire MinigameEnded (với score nếu có), reset handlers
-- param sendScore (boolean) - nếu true gửi score hiện tại
function Events.Cleanup(sendScore)
    if heartbeatConn then
        local score = nil
        if sendScore then
            score = ScoreHandler.GetCurrentScore()
        end
        Events.MinigameEnded:Fire(score)
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    Events.DestroyAllNotes()
    ScoreHandler.Reset()
    NoteHandler.Reset()
end

-- =========================
-- PlayChart: main loop render + logic
-- =========================

-- PlayChart(songName, difficulty, offsetMs)
-- Side-effect: tạo notes từ chart, bind heartbeat loop, xử lý hit/miss, hiệu ứng
function Events.PlayChart(songName, difficulty, offsetMs)
    Events.Cleanup()

    local bottom = guiRoot.Page.Main.Bottom
    local songModule = require(script.Songs[songName])
    local chart = BeatMapFormatter.FormatChart(songModule)[(difficulty or "Easy") .. "Single"]
    local trackOffset = offsetMs or 0

    -- Validate notes (debug)
    for timeStr, notes in pairs(chart) do
        for _, note in ipairs(notes) do
            if note[2] > 5 then
                print("Weird note at", timeStr, notes)
            end
        end
    end

    -- Create notes in NoteHandler
    for timeStr, notes in pairs(chart) do
        NoteHandler.CreateNote(tonumber(timeStr), notes)
    end

    local lastNoteTime = NoteHandler.GetLastNoteTiming() / 1000
    local elapsed = -trackOffset

    -- Heartbeat loop: cập nhật vị trí note, kiểm tra active/visible, xử lý hit/miss
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt

        if elapsed > lastNoteTime + 2 then
            return Events.Cleanup(true)
        end

        -- Check notes that are no longer visible -> miss
        for idStr, _ in pairs(activeNotesById) do
            if not NoteHandler.IsNoteVisible(tonumber(idStr), elapsed) then
                ScoreHandler.MissNote()
                NoteHandler.MarkNoteInactive(tonumber(idStr))
                Events.CacheNoteById(idStr)
                activeNotesById[idStr] = nil
            end
        end

        -- Determine top active note per lane
        local topPerLane = table.create(6, -1)
        for _, noteId in ipairs(NoteHandler.GetVisibleIds(elapsed)) do
            local inst = Events.GetNoteById(noteId)
            inst.Position = UDim2.fromScale(0.5, NoteHandler.GetNoteStartAlpha(noteId, elapsed))
            if NoteHandler.IsNoteActive(noteId, elapsed) then
                local lane = NoteHandler.GetNoteType(noteId)
                local timing = NoteHandler.GetNoteTiming(noteId)
                if topPerLane[lane] == -1 or timing < NoteHandler.GetNoteTiming(topPerLane[lane]) then
                    topPerLane[lane] = noteId
                end
            end
        end

        -- Process each lane (1..6)
        for lane = 1, 6 do
            local topId = topPerLane[lane]
            local state = buttonStates[lane]

            if topId == -1 then
                if state == 3 then
                    ScoreHandler.MissNote()
                end
            else
                local startAlpha = NoteHandler.GetNoteStartAlpha(topId, elapsed)
                local endAlpha = NoteHandler.GetNoteEndAlpha(topId, elapsed)
                local isHold = startAlpha ~= endAlpha
                local hitType = NoteHandler.IsAlphaActive(startAlpha) and 3 or (isHold and NoteHandler.IsAlphaActive(endAlpha) and 1 or (isHold and 2 or false))
                local anyAlphaActive = NoteHandler.IsAlphaActive(startAlpha) or NoteHandler.IsAlphaActive(endAlpha)

                if state == 3 and not anyAlphaActive then
                    ScoreHandler.MissNote()
                elseif hitType then
                    local invalidPattern = not table.find(PATTERN_TABLE[hitType], state)
                    local shouldMiss
                    if isHold then
                        if hitType < 3 then
                            shouldMiss = NoteHandler.GetNoteState(topId) == 3
                        else
                            shouldMiss = false
                        end
                    else
                        shouldMiss = isHold
                    end

                    if invalidPattern or shouldMiss then
                        ScoreHandler.MissNote()
                        NoteHandler.MarkNoteInactive(topId)
                        Events.CacheNoteById(topId)
                    elseif state == hitType then
                        if hitType ~= 2 then
                            local btnFrame = bottom:FindFirstChild(("Button%d"):format(lane))
                            local isPerfect
                            if hitType == 3 then
                                isPerfect = NoteHandler.IsAlphaPerfect(startAlpha)
                            else
                                isPerfect = NoteHandler.IsAlphaActive(endAlpha)
                            end
                            ScoreHandler.HitNote(isPerfect)
                            if btnFrame then
                                btnFrame.PressEffect.Rotation = math.random() * 360
                                ImageUtils.PlayImage(btnFrame.PressEffect, 4, 0.3)
                                if isPerfect then
                                    btnFrame.PerfectEffect.Rotation = math.random() * 360
                                    ImageUtils.PlayImage(btnFrame.PerfectEffect, 4, 0.3)
                                end
                            end
                            if isHold and hitType == 3 then
                                ImageUtils.LoopImage(btnFrame.NoteHoldEffect, 4, 0.25)
                                task.delay((NoteHandler.GetNoteTiming(topId) + NoteHandler.GetNoteDuration(topId) - elapsed * 1000) / 1000, function()
                                    ImageUtils.StopImage(btnFrame.NoteHoldEffect, 0.25)
                                end)
                            end
                        end

                        if (isHold and state == 1) or (not isHold and state == 3) then
                            NoteHandler.MarkNoteInactive(topId)
                            Events.CacheNoteById(topId)
                        else
                            NoteHandler.MarkNoteHeld(topId)
                            activeNotesById[tostring(topId)].ImageTransparency = 1
                        end
                    end
                end
            end
        end

        -- Clamp buttonStates to max 2
        for i = 1, 6 do
            buttonStates[i] = math.min(buttonStates[i], 2)
        end
    end)
end

-- =========================
-- Return public events table
-- =========================

return Events
