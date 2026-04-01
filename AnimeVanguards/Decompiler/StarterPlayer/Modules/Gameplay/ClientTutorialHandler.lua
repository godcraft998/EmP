-- Tutorial Client Handler (gộp 1 file, đã đổi tên biến và chú thích)
-- Mục đích: lắng nghe sự kiện tutorial từ server, điều phối các phần (PartOne/PartTwo/PartThree),
--          hiển thị popup/option, và gọi các callback tương ứng.

-- Services
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Yêu cầu module / packages
require(ReplicatedStorage.Modules.Packages.FastSignal) -- giữ require gốc nếu module side-effect cần thiết
local PopupHandler = require(StarterPlayer.Modules.Interface.Loader.Misc.PopupHandler)
local OptionsHandler = require(StarterPlayer.Modules.Interface.Loader.OptionsHandler)

-- Local callbacks module (script.Callbacks)
local Callbacks = require(script.Callbacks)

-- RemoteEvent từ ReplicatedStorage
local NEWTutorialEvent = ReplicatedStorage.Networking.ClientListeners.NEWTutorialEvent

-- Bảng ánh xạ tên module con (tên module => module table)
local PartModules = {}

-- Bảng tên log context để in log theo module gọi
local LOG_CONTEXTS = {
    ["ClientTutorialHandler"] = "[TUTORIAL] | MAIN",
    ["PartOne"] = "[TUTORIAL] | PART_ONE",
    ["PartTwo"] = "[TUTORIAL] | PART_TWO",
    ["PartThree"] = "[TUTORIAL] | PART_THREE"
}

-- Log level enum
local LOG_LEVEL = {
    Print = 0,
    Warn = 1,
    Error = 2
}

-- LocalPlayer ref
local LocalPlayer = Players.LocalPlayer

-- Helper: thông báo/log có context tự động (lấy tên file gọi)
-- level: LOG_LEVEL, msg: string
local function Announce(level, msg)
    -- Lấy tên hàm gọi ở stack level 2, rồi lấy phần cuối sau dấu chấm
    local caller = debug.info(2, "s"):match("([^%.]+)$")
    local context = LOG_CONTEXTS[caller] or "TUTORIAL"

    if level == LOG_LEVEL.Error then
        error(("%s | ERROR: %s"):format(context, msg))
    elseif level == LOG_LEVEL.Warn then
        warn(("%s | WARN: %s"):format(context, msg))
    else
        print(("%s | PRINT: %s"):format(context, msg))
    end
end

-- Tự động require tất cả ModuleScript con trong folder script có tên khớp LOG_CONTEXTS
for _, moduleScript in ipairs(script:QueryDescendants("> ModuleScript")) do
    if LOG_CONTEXTS[moduleScript.Name] then
        local ok, mod = pcall(require, moduleScript)
        if ok and mod then
            PartModules[moduleScript.Name] = mod
        else
            Announce(LOG_LEVEL.Warn, ("Không thể require module %s"):format(moduleScript.Name))
        end
    end
end

-- Public interface trả về
local TutorialClient = {
    IsInTutorial = false,
    Annc = Announce
}

-- Lắng nghe RemoteEvent từ server (bất đồng bộ)
task.spawn(function()
    NEWTutorialEvent.OnClientEvent:Connect(function(partName, stepName, ...)
        -- Khi nhận event, đánh dấu đang trong tutorial
        if not TutorialClient.IsInTutorial then
            TutorialClient.IsInTutorial = true
        end

        -- Log bắt được event
        Announce(LOG_LEVEL.Print, ("%s Caught, Part: %s, StepName: %s"):format(tostring(LocalPlayer), tostring(partName), tostring(stepName)))

        local partModule = PartModules[partName]
        if partModule then
            -- Nếu module chưa init và có Init function thì gọi Init
            if not partModule.MainHandler and partModule.Init then
                -- Truyền interface (TutorialClient) để module con có thể thao tác
                partModule.Init(TutorialClient)
            end

            -- Tìm handler tương ứng với stepName trong module con
            local stepHandler = partModule[stepName]
            if stepHandler then
                -- Gọi handler với các tham số bổ sung
                stepHandler(...)
            else
                Announce(LOG_LEVEL.Warn, (("%s has no %s handler."):format(partName, stepName)))
            end
        else
            Announce(LOG_LEVEL.Error, (("INCORRECT PART HANDLER! %s"):format(tostring(partName))))
            return
        end
    end)
end)

-- Kiểm tra trạng thái active của một phần tutorial (dùng bởi Callbacks hoặc module khác)
-- Trả về true nếu module tồn tại và có MainHandler truthy
function TutorialClient.IsActive(partName)
    local mod = PartModules[partName]
    if mod then
        return (mod.MainHandler and true) or false
    end
    Announce(LOG_LEVEL.Warn, (("Incorrect %s passed to check status of."):format(tostring(partName))))
    return false
end

-- Gắn hàm IsActive vào module Callbacks (giữ tương thích với code gốc)
Callbacks.IsActive = TutorialClient.IsActive

-- Mở giao diện chọn phần tutorial để replay (gọi từ UI hoặc command)
function TutorialClient.OpenInterface()
    if TutorialClient.IsInTutorial then
        PopupHandler:ShowPopup("BaseCancelFrame", "You're already in a tutorial!")
        return
    end

    -- Các option để hiển thị (title => { Color, Callback })
    local options = {
        ["Part One"] = {
            Color = Color3.fromRGB(24, 255, 43),
            Callback = function()
                Announce(LOG_LEVEL.Print, "Part one chosen.")
                NEWTutorialEvent:FireServer("Replay", "PartOne")
            end
        },
        ["Part Two"] = {
            Color = Color3.fromRGB(93, 179, 255),
            Callback = function()
                Announce(LOG_LEVEL.Print, "Part two chosen.")
                NEWTutorialEvent:FireServer("Replay", "PartTwo")
            end
        }
        -- Nếu cần thêm PartThree, có thể thêm vào đây tương tự
    }

    -- Hiển thị options (OptionsHandler.CreateOptions(title, optionsTable, orderList))
    OptionsHandler.CreateOptions("Which Tutorial part would you like to replay from?", options, { "Part One", "Part Two" })
end

-- Gắn OpenInterface vào Callbacks để có thể gọi từ nơi khác
Callbacks.OpenInterface = TutorialClient.OpenInterface

-- Trả về interface public
return TutorialClient
