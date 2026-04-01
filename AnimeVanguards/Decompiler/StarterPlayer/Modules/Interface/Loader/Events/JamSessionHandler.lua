-- JamSessionClient (đã decompile, đổi tên biến và chú thích tiếng Việt)
-- Mục đích: quản lý giao diện Jam Session / Guitar Minigame client-side,
--          phát nhạc minigame, gửi điểm lên server và hiển thị bảng chọn bài/difficulty.

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Requires (giữ đường dẫn gốc)
local SoundHandler = require(ReplicatedStorage.Modules.Shared.SoundHandler)
local NumberUtils = require(ReplicatedStorage.Modules.Utilities.NumberUtils)
local GuitarMinigame = require(script.GuitarMinigame)

-- Remote events / functions
local JamSessionEvents = ReplicatedStorage.Networking.Events.JamSession
local Remote_UpdateScore = JamSessionEvents.UpdateScore
local Remote_GetScores = JamSessionEvents.GetScores

-- PlayerGui reference
local PlayerGui = Players.LocalPlayer.PlayerGui

-- Module table (public API)
local JamSessionClient = {}

-- Internal state
local guiInstance = nil                -- clone GUI hiện tại (nếu mở)
local cachedScores = nil               -- bảng điểm lấy từ server
local availableSongs = {
    "Skele King's Theme",
    "Vanguards!",
    "Selfish Intentions",
    "Petals Beneath the Ice",
    "Steel Against Flesh",
    "Crown of the Sun"
}
local difficulties = { "Easy", "Medium", "Hard", "Expert" }
local difficultyColors = {
    Easy = Color3.fromRGB(85, 255, 0),
    Medium = Color3.fromRGB(255, 170, 0),
    Hard = Color3.fromRGB(255, 0, 0),
    Expert = Color3.fromRGB(170, 0, 255)
}

-- =========================
-- Helper / Core functions
-- =========================

-- StartMinigame
-- Mục đích: phát nhạc minigame, mở giao diện minigame, chơi chart và gửi kết quả khi kết thúc.
-- Tham số:
--   songName (string) - tên bài hát (phải nằm trong availableSongs)
--   difficulty (string) - "Easy"/"Medium"/...
function JamSessionClient.StartMinigame(songName, difficulty)
    -- Tạo key âm thanh dựa trên index bài
    local soundKey = ("KingOfString%d"):format(table.find(availableSongs, songName))
    local soundInstance = SoundHandler:PlayLocalSound(soundKey)
    if not soundInstance then
        return warn("Could not play the minigame music")
    end

    -- Mở giao diện minigame (module GuitarMinigame chịu trách nhiệm UI/logic)
    GuitarMinigame.Open()

    -- Đợi sound load nếu cần
    if not soundInstance.IsLoaded then
        repeat
            task.wait()
        until soundInstance.IsLoaded
    end

    -- Bắt đầu chơi chart (tham số: songName, difficulty, trackIndex)
    GuitarMinigame.PlayChart(songName, difficulty, 2)

    -- Khởi tạo playback chậm rồi tăng tốc sau 2 giây để đồng bộ hiệu ứng
    soundInstance.PlaybackSpeed = 0
    soundInstance.TimePosition = 0
    task.delay(2, function()
        soundInstance.PlaybackSpeed = 1
    end)

    -- Lắng nghe kết thúc minigame (MinigameEnded:Once)
    GuitarMinigame.MinigameEnded:Once(function(result)
        -- Nếu có kết quả (ví dụ score), gửi lên server
        if result then
            Remote_UpdateScore:FireServer(songName, difficulty, result)
        end

        -- Đóng giao diện minigame, bật lại HUD và dừng nhạc local
        GuitarMinigame.Close()
        if PlayerGui and PlayerGui:FindFirstChild("HUD") then
            PlayerGui.HUD.Enabled = true
        end
        SoundHandler:StopLocalSound(soundKey)
    end)
end

-- OpenGui
-- Mục đích: mở giao diện Jam Session (chọn bài, difficulty, hiển thị best/last score)
-- Side-effect: clone GUI vào PlayerGui, disable HUD, kết nối nút
function JamSessionClient.OpenGui()
    if guiInstance then
        return
    end

    -- Clone GUI template từ script
    local guiClone = script.JamSessionGui:Clone()
    guiClone.Enabled = true
    guiClone.Parent = PlayerGui
    guiInstance = guiClone

    -- Lấy điểm hiện tại từ server (InvokeServer)
    cachedScores = Remote_GetScores:InvokeServer() or {}

    -- Ẩn HUD chính
    if PlayerGui and PlayerGui:FindFirstChild("HUD") then
        PlayerGui.HUD.Enabled = false
    end

    -- Local state cho GUI
    local selectedDifficulty = "Easy"
    local selectedSong = nil
    local songDisplay = guiClone.Main.SongDisplay

    -- Hàm cập nhật hiển thị thông tin bài/difficulty/score
    local function updateSongDisplay()
        songDisplay.Visible = true
        songDisplay.SongName.Text = selectedSong
        if cachedScores[selectedSong] then
            local entry = cachedScores[selectedSong][selectedDifficulty]
            if entry then
                songDisplay.Scores.BestScoreValue.Text = NumberUtils:AbbreviateNumber(entry.BestScore)
                songDisplay.Scores.LastScoreValue.Text = NumberUtils:AbbreviateNumber(entry.LastScore)
            else
                songDisplay.Scores.BestScoreValue.Text = "nil"
                songDisplay.Scores.LastScoreValue.Text = "nil"
            end
        else
            songDisplay.Scores.BestScoreValue.Text = "nil"
            songDisplay.Scores.LastScoreValue.Text = "nil"
        end
    end

    -- Populate danh sách bài
    local songsContainer = guiClone.Main.Songs
    for _, songName in ipairs(availableSongs) do
        local btn = script.SongButton:Clone()
        btn.Name = songName
        btn.SongName.Text = songName
        btn.Parent = songsContainer

        btn.Activated:Connect(function()
            selectedSong = songName
            updateSongDisplay()
        end)
    end

    -- Difficulty button: vòng lặp qua difficulties
    songDisplay.Difficulty.Button.Activated:Connect(function()
        local idx = table.find(difficulties, selectedDifficulty) or 1
        idx = idx + 1
        if not difficulties[idx] then idx = 1 end
        selectedDifficulty = difficulties[idx]
        songDisplay.Difficulty.Label.Text = selectedDifficulty

        local col = difficultyColors[selectedDifficulty]
        songDisplay.Difficulty.BackgroundColor3 = col
        songDisplay.Difficulty.Inner.BackgroundColor3 = col

        updateSongDisplay()
    end)

    -- Play button: bắt đầu minigame nếu đã chọn bài
    songDisplay.Play.Button.Activated:Connect(function()
        if selectedSong then
            JamSessionClient.CloseGui()
            JamSessionClient.StartMinigame(selectedSong, selectedDifficulty)
        end
    end)

    -- Cancel button: đóng GUI và bật lại HUD
    guiClone.Main.Cancel.Button.Activated:Connect(function()
        if PlayerGui and PlayerGui:FindFirstChild("HUD") then
            PlayerGui.HUD.Enabled = true
        end
        JamSessionClient.CloseGui()
    end)
end

-- CloseGui
-- Mục đích: đóng GUI Jam Session nếu đang mở và dọn dẹp tham chiếu
function JamSessionClient.CloseGui()
    if guiInstance then
        guiInstance:Destroy()
        guiInstance = nil
    end
end

-- IsActive
-- Mục đích: trả về true nếu minigame đang active (GuitarMinigame.IsActive) hoặc GUI đang mở
function JamSessionClient.IsActive()
    return GuitarMinigame.IsActive() or guiInstance ~= nil
end

-- Trả về module public
return JamSessionClient
