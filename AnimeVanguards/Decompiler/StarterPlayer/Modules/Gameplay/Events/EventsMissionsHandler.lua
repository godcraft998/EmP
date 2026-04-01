-- EventMissionsClient.lua
-- Mục đích: quản lý giao diện Missions cho event (mở/đóng UI, hiển thị thời gian reset, tạo frame nhiệm vụ)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- PlayerGui ref
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Requires (giữ đường dẫn gốc)
local EventsData = require(ReplicatedStorage.Modules.Data.EventsData)
require(ReplicatedStorage.Modules.Data.Challenges.ChallengesData) -- side-effect
local InterfaceUtils = require(ReplicatedStorage.Modules.Interface.InterfaceUtils)
local TextUtils = require(ReplicatedStorage.Modules.Utilities.TextUtils)
require(ReplicatedStorage.Modules.Utilities.NumberUtils)
require(ReplicatedStorage.Modules.Utilities.TableUtils)
require(ReplicatedStorage.Modules.Utilities.FrameUtils)
local DateUtils = require(ReplicatedStorage.Modules.Utilities.DateUtils)

-- Module handlers
local EventMissionFrameHandler = require(script.EventMissionFrameHandler)
local EventsDataHandler = require(StarterPlayer.Modules.Gameplay.Events.EventsDataHandler)

-- Public module table
local EventMissionsClient = {}

-- Internal state
local guiInstance = nil

-- =========================
-- Helper: mở giao diện và khởi tạo nội dung
-- Mục đích: clone GUI, hiển thị thời gian reset nếu cần, tạo mission frames
-- Side-effect: thao tác trực tiếp trên PlayerGui và tạo các connection ngắn hạn
-- =========================
local function openMissionsForEvent(eventId)
    if guiInstance then
        return
    end

    -- Lấy thông tin event và kiểm tra xem objectives có reset hàng ngày không
    local eventData = EventsData.GetEventData(eventId)
    local objectivesResetDaily = eventData and eventData.ObjectivesResetDaily

    -- Clone GUI template
    local guiClone = script.Missions:Clone()
    local holder = guiClone.Holder
    guiClone.Parent = PlayerGui
    guiInstance = guiClone

    -- Nếu objectives reset hàng ngày, thêm label hiển thị thời gian reset
    if objectivesResetDaily then
        -- Lấy ngày reset tiếp theo dựa trên dữ liệu player
        local playerEvents = EventsDataHandler.GetPlayerEventsData()
        local lastResetDay = playerEvents[eventId] and playerEvents[eventId].LastResetDay or 0
        local resetDayIndex = lastResetDay + 1

        local resetLabel = script.ObjectivesReset:Clone()
        resetLabel.Parent = holder

        -- Cập nhật text ban đầu
        local secondsUntil = resetDayIndex * 86400 - DateTime.now().UnixTimestamp
        resetLabel.Text = secondsUntil <= 0 and "Objectives reset!" or TextUtils.RecolorNumbersInString(("Objectives reset daily! Time until reset: %s"):format(DateUtils.TimeStampToDate(secondsUntil)))

        -- Background task cập nhật mỗi giây; tự dừng khi GUI bị hủy
        task.spawn(function()
            while holder.Parent do
                task.wait(1)
                local remaining = resetDayIndex * 86400 - DateTime.now().UnixTimestamp
                resetLabel.Text = remaining <= 0 and "Objectives reset!" or TextUtils.RecolorNumbersInString(("Objectives reset daily! Time until reset: %s"):format(DateUtils.TimeStampToDate(remaining)))
            end
        end)
    end

    -- Hiệu ứng mở giao diện
    InterfaceUtils.AnimateInterface(guiClone)

    -- Tạo mission frames (EventMissionFrameHandler chịu trách nhiệm chi tiết)
    EventMissionFrameHandler.CreateMissionFrames(guiClone, eventId)

    -- Bind nút Back để đóng giao diện
    holder.Back.Button.Activated:Connect(EventMissionsClient.CloseInterface)
end

-- =========================
-- Public API
-- =========================

-- OpenInterface(eventId)
-- Mục đích: mở giao diện missions cho eventId (nếu chưa mở)
function EventMissionsClient.OpenInterface(eventId)
    if not guiInstance then
        openMissionsForEvent(eventId)
    end
end

-- CloseInterface()
-- Mục đích: đóng giao diện nếu đang mở và dọn dẹp state
function EventMissionsClient.CloseInterface()
    if guiInstance then
        guiInstance:Destroy()
        guiInstance = nil
    end
end

-- =========================
-- Return module
-- =========================
return EventMissionsClient
