-- Cutscene Sequencer (đã decompile, đổi tên và chú thích tiếng Việt)
-- Mục đích: quản lý sequence các "shot" camera (linear/bezier), fade in/out, hide HUD, skip button, và các signal sự kiện.

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Module table
local Sequencer = {}
Sequencer.__index = Sequencer

-- Các hàm easing có sẵn (tên dễ hiểu)
local EASINGS = {
    Linear = function(t) return t end,
    SineInOut = function(t)
        local x = math.pi * t
        return -(math.cos(x) - 1) / 2
    end,
    QuadIn = function(t) return t * t end,
    QuadOut = function(t) return 1 - (1 - t) * (1 - t) end,
    QuadInOut = function(t)
        if t < 0.5 then
            return t * 2 * t
        else
            return 1 - (t * -2 + 2) ^ 2 / 2
        end
    end
}

-- Tạo signal đơn giản dựa trên BindableEvent (fallback nếu không có Signal module)
local function createBindableSignal()
    local be = Instance.new("BindableEvent")
    return {
        Fire = function(_, ...) be:Fire(...) end,
        Connect = function(_, fn) return be.Event:Connect(fn) end,
        Wait = function() return be.Event:Wait() end,
        Destroy = function() be:Destroy() end
    }
end

-- Lấy constructor signal: nếu options cung cấp SignalModule thì dùng, ngược lại dùng bindable
local function makeSignalCtor(options)
    local opts = options or {}
    local signalModule = opts.signalCtor or opts.SignalModule
    if signalModule and type(signalModule) == "table" then
        local newFn = signalModule.new
        if type(newFn) == "function" then
            return function() return signalModule.new() end
        end
    end
    return function() return createBindableSignal() end
end

-- Tạo/đảm bảo tồn tại GUI fade trong PlayerGui, trả về Frame fade
local function ensureFadeFrame(playerGui)
    local root = playerGui:FindFirstChild("CutsceneFadeGui")
    if not root then
        root = Instance.new("ScreenGui")
        root.Name = "CutsceneFadeGui"
        root.IgnoreGuiInset = true
        root.ResetOnSpawn = false
        root.DisplayOrder = 10000
        root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        root.Parent = playerGui
    end

    local fade = root:FindFirstChild("Fade")
    if not fade then
        fade = Instance.new("Frame")
        fade.Name = "Fade"
        fade.Size = UDim2.fromScale(1, 1)
        fade.Position = UDim2.fromScale(0, 0)
        fade.BackgroundColor3 = Color3.new(0, 0, 0)
        fade.BackgroundTransparency = 1
        fade.BorderSizePixel = 0
        fade.ZIndex = 10000
        fade.Parent = root
    end

    return fade
end

-- Tạo tween để thay đổi BackgroundTransparency của frame (dùng TweenService)
local function tweenFade(frame, targetTransparency, duration)
    local dur = math.max(0, duration)
    local tween = TweenService:Create(frame, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
        BackgroundTransparency = targetTransparency
    })
    tween:Play()
    return tween
end

-- Constructor: Sequencer.new(player, sequenceTable, options)
-- player: Player object; sequenceTable: array of shot definitions; options: table
function Sequencer.new(player, sequence, options)
    local self = setmetatable({}, Sequencer)
    self.Player = player
    self.Sequence = sequence
    self.Camera = workspace.CurrentCamera
    self._options = options or {}
    self._running = false
    self._stopFlag = false
    self._playingThread = nil
    self._bypassWaitForIndex = {}

    local signalCtor = makeSignalCtor(self._options)
    -- Các signal sự kiện public
    self.Started = signalCtor()
    self.Completed = signalCtor()
    self.Stopped = signalCtor()
    self.Errored = signalCtor()
    self.ShotStarted = signalCtor()
    self.ShotEnded = signalCtor()
    self.ShotProgress = signalCtor()
    self.Waiting = signalCtor()
    self._continueSignal = signalCtor()

    -- internal state
    self._pendingAny = false
    self._pendingTags = {}
    self._oldType = nil
    self._oldSubject = nil
    self._oldCFrame = nil
    self._oldFov = nil
    self._currentIndex = 0
    self._currentShot = nil
    self._hudHidden = false
    self._hudGui = nil
    self._hudFrameVis = {}
    self._skipClone = nil
    self._skipConn = nil

    return self
end

-- Trả về trạng thái đang chạy hay không
function Sequencer.IsPlaying(self)
    return self._running
end

-- Tiếp tục sequence: nếu tag được truyền thì mark tag, ngược lại mark pendingAny
-- Nếu đang chạy và có currentIndex, cho phép bypass wait cho index hiện tại
function Sequencer.Continue(self, tag)
    if tag then
        self._pendingTags[tag] = true
        self._continueSignal:Fire(tag)
    else
        self._pendingAny = true
        if self._running and (self._currentIndex and self._currentIndex > 0) then
            self._bypassWaitForIndex[self._currentIndex] = true
        end
        self._continueSignal:Fire(nil)
    end
end

-- Tiêu thụ pending (pendingAny hoặc pendingTags[tag])
function Sequencer._consumePending(self, tag)
    if self._pendingAny then
        self._pendingAny = false
        return true
    end
    if not (tag and self._pendingTags[tag]) then
        return false
    end
    self._pendingTags[tag] = nil
    return true
end

-- Lưu trạng thái camera hiện tại để restore sau cutscene
function Sequencer._saveCamera(self)
    local cam = self.Camera
    self._oldType = cam.CameraType
    self._oldSubject = cam.CameraSubject
    self._oldCFrame = cam.CFrame
    self._oldFov = cam.FieldOfView
end

-- Khôi phục camera về trạng thái trước khi cutscene
function Sequencer._restoreCamera(self)
    local cam = self.Camera
    if self._oldType ~= nil then cam.CameraType = self._oldType end
    if self._oldSubject ~= nil then cam.CameraSubject = self._oldSubject end
    if self._oldCFrame ~= nil then cam.CFrame = self._oldCFrame end
    if self._oldFov ~= nil then cam.FieldOfView = self._oldFov end
end

-- Đặt camera sang Scriptable để điều khiển thủ công
function Sequencer._setScripted(self)
    self.Camera.CameraType = Enum.CameraType.Scriptable
end

-- Thử lấy PlayerGui trong khoảng timeout giây; trả về PlayerGui hoặc nil
function Sequencer._tryGetPlayerGui(self, timeout)
    local start = os.clock()
    while os.clock() - start < timeout do
        local pg = self.Player:FindFirstChildOfClass("PlayerGui")
        if pg then return pg end
        RunService.Heartbeat:Wait()
    end
    return nil
end

-- Fade helper: tìm frame fade trong PlayerGui và tạo tween thay đổi transparency
-- p50 true = fade out (target 0), false = fade in (target 1)
function Sequencer._fade(self, fadeOut, duration)
    local playerGui = self:_tryGetPlayerGui(0.5)
    if playerGui then
        local fadeFrame = ensureFadeFrame(playerGui)
        local target = fadeOut and 0 or 1
        return tweenFade(fadeFrame, target, duration)
    else
        return nil
    end
end

-- Ẩn HUD và inject nút Skip (nếu options.hideHUD true)
-- Lưu trạng thái Visible của các Frame để restore sau
function Sequencer._hideHudAndInjectSkip(self)
    if not self._options.hideHUD then return end
    if self._hudHidden then return end

    local playerGui = self:_tryGetPlayerGui(0.5)
    if not playerGui then return end

    local hud = playerGui:FindFirstChild("HUD")
    if not (hud and hud:IsA("ScreenGui")) then return end

    self._hudGui = hud
    self._hudHidden = true
    table.clear(self._hudFrameVis)

    -- Ẩn tất cả Frame con và lưu trạng thái
    for _, desc in ipairs(hud:GetDescendants()) do
        if desc:IsA("Frame") then
            self._hudFrameVis[desc] = desc.Visible
            desc.Visible = false
        end
    end

    -- Tìm frame Skip trong script (Skip hoặc SkipFrame), clone vào HUD và kết nối nút
    local skipTemplate = script:FindFirstChild("Skip") or script:FindFirstChild("SkipFrame")
    if skipTemplate and skipTemplate:IsA("Frame") then
        local clone = skipTemplate:Clone()
        clone.Visible = true
        clone.Parent = hud
        self._skipClone = clone

        -- tìm nút (TextButton hoặc ImageButton) trong clone
        local button = nil
        for _, child in ipairs(clone:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("ImageButton") then
                button = child
                break
            end
        end

        if button then
            local conn = nil
            if button.Activated then
                conn = button.Activated:Connect(function() self:Stop() end)
            elseif button.MouseButton1Click then
                conn = button.MouseButton1Click:Connect(function() self:Stop() end)
            end
            self._skipConn = conn
        end
    end
end

-- Khôi phục HUD và gỡ nút Skip
function Sequencer._restoreHudAndRemoveSkip(self)
    if self._hudHidden then
        if self._skipConn then
            self._skipConn:Disconnect()
            self._skipConn = nil
        end
        if self._skipClone then
            self._skipClone:Destroy()
            self._skipClone = nil
        end
        for frame, vis in pairs(self._hudFrameVis) do
            if frame and frame.Parent ~= nil and frame:IsA("Frame") then
                frame.Visible = vis
            end
        end
        table.clear(self._hudFrameVis)
        self._hudHidden = false
        self._hudGui = nil
    end
end

-- Dừng sequence (đánh dấu stop và gửi signal "__stop__")
function Sequencer.Stop(self)
    if self._running then
        self._stopFlag = true
        self._continueSignal:Fire("__stop__")
    end
end

-- Hủy và dọn dẹp toàn bộ signal, restore HUD
function Sequencer.Destroy(self)
    self:Stop()
    self.Started:Destroy()
    self.Completed:Destroy()
    self.Stopped:Destroy()
    self.Errored:Destroy()
    self.ShotStarted:Destroy()
    self.ShotEnded:Destroy()
    self.ShotProgress:Destroy()
    self.Waiting:Destroy()
    self._continueSignal:Destroy()
    self:_restoreHudAndRemoveSkip()
end

-- Áp dụng trạng thái cuối cùng của một shot (đặt camera về to/from cuối cùng ngay lập tức)
-- p68 = index, p69 = shot table
function Sequencer._applyShotFinal(self, index, shot)
    local cam = self.Camera
    local style = (shot.style or "linear"):lower()
    local lookFrom = shot.lookAt and shot.lookAt.from
    local lookTo = shot.lookAt and shot.lookAt.to
    local fovFrom = shot.fov and shot.fov.from or cam.FieldOfView
    local fovTo = shot.fov and shot.fov.to or cam.FieldOfView

    if style == "bezier" then
        -- Tính vị trí cuối cùng theo bezier (t = 1)
        local p0 = shot.p0 or cam.CFrame
        if typeof(p0) == "CFrame" then p0 = p0.Position
        elseif typeof(p0) ~= "Vector3" then error(("Invalid position type: %s"):format(typeof(p0))) end
        local p1 = shot.p1 or p0
        local p2 = shot.p2 or p0
        local p3 = shot.p3 or cam.CFrame
        if typeof(p3) == "CFrame" then p3 = p3.Position
        elseif typeof(p3) ~= "Vector3" then error(("Invalid position type: %s"):format(typeof(p3))) end

        local c0 = shot.p0 or cam.CFrame
        if typeof(c0) ~= "CFrame" then
            if typeof(c0) == "Vector3" then c0 = CFrame.new(c0) else error(("Invalid cframe type: %s"):format(typeof(c0))) end
        end
        local c3 = shot.p3 or cam.CFrame
        if typeof(c3) ~= "CFrame" then
            if typeof(c3) == "Vector3" then c3 = CFrame.new(c3) else error(("Invalid cframe type: %s"):format(typeof(c3))) end
        end

        -- t = 1 => vị trí cuối cùng là p3
        local finalPos = p0 * 0 + p1 * 0 + p2 * 0 + p3 * 1
        local finalCFrame
        if lookFrom and lookTo then
            local look = lookFrom:Lerp(lookTo, 1)
            finalCFrame = CFrame.new(finalPos, look)
        else
            local lerpC = c0:Lerp(c3, 1)
            finalCFrame = CFrame.fromMatrix(finalPos, lerpC.RightVector, lerpC.UpVector, -lerpC.LookVector)
        end
        cam.CFrame = finalCFrame
    else
        -- Linear style: lerp from->to at t=1
        local final = (shot.from or cam.CFrame):Lerp(shot.to or cam.CFrame, 1)
        if lookFrom and lookTo then
            local look = lookFrom:Lerp(lookTo, 1)
            final = CFrame.new(final.Position, look)
        end
        cam.CFrame = final
    end

    cam.FieldOfView = fovFrom + (fovTo - fovFrom) * 1
    self.ShotProgress:Fire(index, shot, 1, 1)
end

-- Kiểm tra và chờ nếu shot yêu cầu wait (waitSignal, waitForContinue, waitTag)
function Sequencer._waitIfNeeded(self, index, shot)
    if self._bypassWaitForIndex[index] then
        self._bypassWaitForIndex[index] = nil
        return
    elseif self._stopFlag then
        return
    elseif shot.waitSignal then
        self.Waiting:Fire(index, shot, shot.waitTag)
        shot.waitSignal:Wait()
        return
    elseif shot.waitForContinue == true or shot.waitTag ~= nil then
        if not self:_consumePending(shot.waitTag) then
            self.Waiting:Fire(index, shot, shot.waitTag)
            while not self._stopFlag do
                local tag = self._continueSignal:Wait()
                if tag == "__stop__" then return end
                if not shot.waitTag then
                    self._pendingAny = false
                    return
                end
                if tag == shot.waitTag or self:_consumePending(shot.waitTag) then
                    return
                end
            end
        end
    else
        return
    end
end

-- Thực thi toàn bộ sequence (chạy từng shot, xử lý easing, bezier/linear, hold, fade)
function Sequencer._run(self)
    local cam = self.Camera
    if not cam then error("workspace.CurrentCamera is nil") end

    -- Lưu camera, set scriptable, ẩn HUD, fade in nếu cần
    self:_saveCamera()
    self:_setScripted()
    self:_hideHudAndInjectSkip()

    local fadeIn = self._options.fadeIn or 0
    local fadeOut = self._options.fadeOut or 0
    local initialBlackGui = (self._options.initialBlack or false) and self:_tryGetPlayerGui(0.5)
    if initialBlackGui then
        ensureFadeFrame(initialBlackGui).BackgroundTransparency = 0
    end

    self.Started:Fire()
    if fadeIn > 0 then
        self:_fade(false, fadeIn)
        task.wait(fadeIn)
    end

    for index, shot in ipairs(self.Sequence) do
        if self._stopFlag then break end
        self._currentIndex = index
        self._currentShot = shot

        self.ShotStarted:Fire(index, shot)
        if shot.onStart then shot.onStart(index, shot) end

        local duration = shot.duration or 2
        local safeDuration = math.max(0.001, duration)
        local hold = math.max(0, shot.hold or 0)
        local easingName = shot.easing
        local easingFn = easingName and (EASINGS[easingName] or EASINGS.SineInOut) or EASINGS.SineInOut
        local style = (shot.style or "linear"):lower()

        -- Nếu đã có pending cho shot (continue trước đó), áp dụng final ngay
        local hasPending = self._pendingAny
        if not hasPending then
            if shot.waitTag == nil then
                hasPending = false
            else
                hasPending = self._pendingTags[shot.waitTag] == true
            end
        end

        if hasPending then
            self:_consumePending(shot.waitTag)
            self:_applyShotFinal(index, shot)
        elseif style == "bezier" then
            -- Bezier interpolation loop
            local p0 = shot.p0 or cam.CFrame
            if typeof(p0) == "CFrame" then p0 = p0.Position
            elseif typeof(p0) ~= "Vector3" then error(("Invalid position type: %s"):format(typeof(p0))) end
            local p1 = shot.p1 or p0
            local p2 = shot.p2 or p0
            local p3 = shot.p3 or cam.CFrame
            if typeof(p3) == "CFrame" then p3 = p3.Position
            elseif typeof(p3) ~= "Vector3" then error(("Invalid position type: %s"):format(typeof(p3))) end

            local c0 = shot.p0 or cam.CFrame
            if typeof(c0) ~= "CFrame" then
                if typeof(c0) == "Vector3" then c0 = CFrame.new(c0) else error(("Invalid cframe type: %s"):format(typeof(c0))) end
            end
            local c3 = shot.p3 or cam.CFrame
            if typeof(c3) ~= "CFrame" then
                if typeof(c3) == "Vector3" then c3 = CFrame.new(c3) else error(("Invalid cframe type: %s"):format(typeof(c3))) end
            end

            local lookFrom = shot.lookAt and shot.lookAt.from
            local lookTo = shot.lookAt and shot.lookAt.to
            local fovFrom = shot.fov and shot.fov.from or cam.FieldOfView
            local fovTo = shot.fov and shot.fov.to or cam.FieldOfView

            local startTime = os.clock()
            while not self._stopFlag do
                if self._pendingAny or (shot.waitTag and self._pendingTags[shot.waitTag]) then
                    self:_consumePending(shot.waitTag)
                    self:_applyShotFinal(index, shot)
                    break
                end

                local t = (os.clock() - startTime) / safeDuration
                local clamped = t < 0 and 0 or (t > 1 and 1 or t)
                local eased = easingFn(clamped)

                -- Bernstein polynomial for cubic bezier
                local inv = 1 - eased
                local e2 = eased * eased
                local i2 = inv * inv
                local b0 = i2 * inv
                local b1 = i2 * 3 * eased
                local b2 = inv * 3 * e2
                local b3 = e2 * eased

                local pos = b0 * p0 + b1 * p1 + b2 * p2 + b3 * p3
                local newCFrame
                if lookFrom and lookTo then
                    local look = lookFrom:Lerp(lookTo, eased)
                    newCFrame = CFrame.new(pos, look)
                else
                    local lerpC = c0:Lerp(c3, eased)
                    newCFrame = CFrame.fromMatrix(pos, lerpC.RightVector, lerpC.UpVector, -lerpC.LookVector)
                end

                cam.CFrame = newCFrame
                cam.FieldOfView = fovFrom + (fovTo - fovFrom) * eased
                self.ShotProgress:Fire(index, shot, clamped, eased)

                if clamped >= 1 then break end
                RunService.RenderStepped:Wait()
            end
        else
            -- Linear interpolation loop
            local from = shot.from or cam.CFrame
            local to = shot.to or cam.CFrame
            local lookFrom = shot.lookAt and shot.lookAt.from
            local lookTo = shot.lookAt and shot.lookAt.to
            local fovFrom = shot.fov and shot.fov.from or cam.FieldOfView
            local fovTo = shot.fov and shot.fov.to or cam.FieldOfView

            local startTime = os.clock()
            while not self._stopFlag do
                if self._pendingAny or (shot.waitTag and self._pendingTags[shot.waitTag]) then
                    self:_consumePending(shot.waitTag)
                    self:_applyShotFinal(index, shot)
                    break
                end

                local t = (os.clock() - startTime) / safeDuration
                local clamped = t < 0 and 0 or (t > 1 and 1 or t)
                local eased = easingFn(clamped)

                local interp = from:Lerp(to, eased)
                if lookFrom and lookTo then
                    local look = lookFrom:Lerp(lookTo, eased)
                    interp = CFrame.new(interp.Position, look)
                end

                cam.CFrame = interp
                cam.FieldOfView = fovFrom + (fovTo - fovFrom) * eased
                self.ShotProgress:Fire(index, shot, clamped, eased)

                if clamped >= 1 then break end
                RunService.RenderStepped:Wait()
            end
        end

        -- Hold (delay) sau shot nếu có, nhưng vẫn có thể bị continue/stop
        if not self._stopFlag and hold > 0 then
            local holdStart = os.clock()
            while os.clock() - holdStart < hold and not self._stopFlag do
                if self._pendingAny or (shot.waitTag and self._pendingTags[shot.waitTag]) then
                    self:_consumePending(shot.waitTag)
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end

        self.ShotEnded:Fire(index, shot)
        if shot.onEnd then shot.onEnd(index, shot) end

        -- Nếu shot yêu cầu chờ (waitSignal / waitForContinue / waitTag) thì xử lý
        self:_waitIfNeeded(index, shot)
    end

    -- Fade out cuối nếu cần
    if not self._stopFlag and fadeOut > 0 then
        self:_fade(true, fadeOut)
        task.wait(fadeOut)
    end
end

-- Bắt đầu phát sequence (spawn thread), xử lý lỗi và restore camera/HUD khi kết thúc
function Sequencer.Play(self)
    if not self._running then
        self._running = true
        self._stopFlag = false
        self._pendingAny = false
        table.clear(self._pendingTags)

        self._playingThread = task.spawn(function()
            local ok, err = xpcall(function() self:_run() end, function(e) return debug.traceback(e) end)

            -- Restore camera ngay cả khi lỗi
            self:_restoreCamera()

            local endFade = self._options.endFadeIn or 0
            if endFade > 0 then
                self:_fade(false, endFade)
                task.wait(endFade)
            else
                self:_fade(false, 0)
            end

            self:_restoreHudAndRemoveSkip()
            self._running = false
            self._currentIndex = 0
            self._currentShot = nil

            if ok then
                if self._stopFlag then
                    self.Stopped:Fire()
                else
                    self.Completed:Fire()
                end
            else
                self.Errored:Fire(err)
                self.Stopped:Fire()
                return
            end
        end)
    end
end

return Sequencer
