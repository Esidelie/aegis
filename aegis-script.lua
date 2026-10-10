-- Aegis Solutions | Free Version
-- credits: _.ingnix._
-- built for those who never miss.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aegis | Free",
    LoadingTitle = "Aegis",
    LoadingSubtitle = "free edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local ESPTab = Window:CreateTab("ESP", 4483362458)
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local Config = {
    ESPEnabled = true,
    Box = true, Name = true, Health = false,
    Distance = false, Tracer = false, HeadDot = false,
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    ESPTeamCheck = false,
    MaxDistance = 4920,

    AimbotEnabled = true,
    AimbotTeamCheck = false,
    AimbotWallCheck = true,
    AimbotFOV = 55,
    AimbotShowFOV = true,
    AimbotSmoothness = 2,
    AimbotTargetPart = "Head",
    AimbotKey = Enum.UserInputType.MouseButton2,
    AimbotKeyHeld = false,
    AimbotMaxDistance = 500,
    AimbotActivation = "Hold Key",
    AimbotTouchHeld = false,
    AimbotTargetLock = true,
    AimbotSwitchDelay = 0.2,
    AimbotCycleKey = Enum.KeyCode.Q,
    AimbotLastSwitch = 0,
    AimbotLockedTarget = nil,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Aegis] " .. tostring(err)) end
    end
end

-- ============================================================
-- ESP
-- ============================================================
local espCache = {}
local renderConnection, playerAddedConn, playerRemovingConn
local charAddedConnections = {}

local function createESP(player)
    if espCache[player] then return end
    local data = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        HeadDot = Drawing.new("Circle"),
    }
    data.Box.Visible = false; data.Box.Filled = false
    data.BoxOutline.Visible = false; data.BoxOutline.Filled = false
    data.HealthBar.Visible = false; data.HealthBar.Filled = true
    data.HealthBarOutline.Visible = false; data.HealthBarOutline.Filled = true
    data.Name.Visible = false; data.Name.Outline = true; data.Name.Center = true; data.Name.TextSize = 14
    data.Distance.Visible = false; data.Distance.Outline = true; data.Distance.Center = true; data.Distance.TextSize = 14
    data.Tracer.Visible = false
    data.HeadDot.Visible = false; data.HeadDot.Filled = true
    espCache[player] = data
end

local function removeESP(player)
    local data = espCache[player]
    if data then
        for _, v in pairs(data) do
            if type(v) == "userdata" and v.Remove then v:Remove() end
        end
        espCache[player] = nil
    end
    if charAddedConnections[player] then
        charAddedConnections[player]:Disconnect()
        charAddedConnections[player] = nil
    end
end

local function hide(data)
    data.Box.Visible = false; data.BoxOutline.Visible = false
    data.Name.Visible = false; data.HealthBar.Visible = false
    data.HealthBarOutline.Visible = false; data.Distance.Visible = false
    data.Tracer.Visible = false; data.HeadDot.Visible = false
end

local function updateESP(player, data)
    if Config.ESPTeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        hide(data) return
    end

    local char = player.Character
    if not char then hide(data) return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not humanoid or not root or not head or humanoid.Health <= 0 then hide(data) return end

    local headPos = Camera:WorldToViewportPoint(head.Position)
    local rootPos = Camera:WorldToViewportPoint(root.Position)
    if headPos.Z <= 0 or rootPos.Z <= 0 then hide(data) return end

    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    if distance > Config.MaxDistance then hide(data) return end

    local height = math.abs(headPos.Y - rootPos.Y) * 2.0
    local width = height * 0.65
    local x = headPos.X - width / 2
    local y = headPos.Y - height * 0.2

    if Config.Box then
        data.BoxOutline.Visible = true
        data.BoxOutline.Size = Vector2.new(width + 2, height + 2)
        data.BoxOutline.Position = Vector2.new(x - 1, y - 1)
        data.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
        data.BoxOutline.Thickness = 3

        data.Box.Visible = true
        data.Box.Size = Vector2.new(width, height)
        data.Box.Position = Vector2.new(x, y)
        data.Box.Color = Color3.fromRGB(255, 255, 255)
        data.Box.Thickness = 1
    else
        data.Box.Visible = false; data.BoxOutline.Visible = false
    end

    if Config.Name then
        data.Name.Visible = true
        data.Name.Text = player.DisplayName or player.Name
        data.Name.Position = Vector2.new(headPos.X, y - 18)
        data.Name.Color = Color3.fromRGB(255, 255, 255)
    else data.Name.Visible = false end

    data.Distance.Visible = false
    data.HealthBar.Visible = false; data.HealthBarOutline.Visible = false
    data.Tracer.Visible = false
    data.HeadDot.Visible = false
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    createESP(player)
    charAddedConnections[player] = player.CharacterAdded:Connect(function()
        task.wait(0.1)
        if espCache[player] then hide(espCache[player]) end
    end)
end

local function startESP()
    if renderConnection then return end
    for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
    playerAddedConn = Players.PlayerAdded:Connect(trackPlayer)
    playerRemovingConn = Players.PlayerRemoving:Connect(removeESP)
    renderConnection = RunService.RenderStepped:Connect(safe(function()
        for player, data in pairs(espCache) do updateESP(player, data) end
    end))
end

local function stopESP()
    if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
    if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end
    if playerRemovingConn then playerRemovingConn:Disconnect(); playerRemovingConn = nil end
    for player, _ in pairs(espCache) do removeESP(player) end
    espCache = {}
end

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Visible=false; fovCircle.Thickness=1
fovCircle.Color=Color3.fromRGB(255,255,255); fovCircle.Filled=false; fovCircle.NumSides=64

RunService.RenderStepped:Connect(safe(function()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if Config.AimbotShowFOV and Config.AimbotEnabled then
        fovCircle.Visible = true
        fovCircle.Radius = Config.AimbotFOV
        fovCircle.Position = center
    else fovCircle.Visible = false end
end))

-- ============================================================
-- TARGETING
-- ============================================================
local function hasLineOfSight(part)
    local origin = Camera.CFrame.Position
    local ray = Ray.new(origin, part.Position - origin)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    if hit then
        return part:IsDescendantOf(hit.Parent) or hit:IsDescendantOf(part.Parent)
    end
    return true
end

local function getValidTargets(fov, teamCheck, wallCheck, maxDist, targetPart)
    local list = {}
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if teamCheck and player.Team == LocalPlayer.Team then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then continue end
        local dist = (Camera.CFrame.Position - root.Position).Magnitude
        if dist > maxDist then continue end
        local part = char:FindFirstChild(targetPart) or root
        local sp = Camera:WorldToViewportPoint(part.Position)
        if sp.Z <= 0 then continue end
        local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if sd > fov then continue end
        if wallCheck and not hasLineOfSight(part) then continue end
        table.insert(list, {player=player, part=part, screenDist=sd})
    end
    table.sort(list, function(a,b) return a.screenDist < b.screenDist end)
    return list
end

-- ============================================================
-- AIMBOT
-- ============================================================
local aimbotConnection

local function isAimbotActive()
    if not Config.AimbotEnabled then return false end
    if Config.AimbotActivation == "Always On" then return true end
    if Config.AimbotActivation == "Touch" then return Config.AimbotTouchHeld end
    return Config.AimbotKeyHeld
end

local function pickAimbotTarget()
    local now = tick()
    local targets = getValidTargets(Config.AimbotFOV, Config.AimbotTeamCheck, Config.AimbotWallCheck, Config.AimbotMaxDistance, Config.AimbotTargetPart)

    if Config.AimbotLockedTarget then
        for _, t in ipairs(targets) do
            if t.player == Config.AimbotLockedTarget.player then
                Config.AimbotLockedTarget = t
                return t
            end
        end
        Config.AimbotLockedTarget = nil
    end

    if #targets == 0 then return nil end
    if Config.AimbotTargetLock then
        Config.AimbotLockedTarget = targets[1]
        return targets[1]
    end
    if now - Config.AimbotLastSwitch < Config.AimbotSwitchDelay then
        return Config.AimbotLockedTarget or targets[1]
    end
    Config.AimbotLastSwitch = now
    Config.AimbotLockedTarget = targets[1]
    return targets[1]
end

local function cycleAimbotTarget()
    local targets = getValidTargets(Config.AimbotFOV, Config.AimbotTeamCheck, Config.AimbotWallCheck, Config.AimbotMaxDistance, Config.AimbotTargetPart)
    if #targets == 0 then Config.AimbotLockedTarget = nil return end
    local currentPlayer = Config.AimbotLockedTarget and Config.AimbotLockedTarget.player
    local nextTarget = targets[1]
    if currentPlayer then
        for i, t in ipairs(targets) do
            if t.player == currentPlayer then
                nextTarget = targets[i+1] or targets[1]; break
            end
        end
    end
    Config.AimbotLockedTarget = nextTarget
    Config.AimbotLastSwitch = tick()
end

local function aimbotStep()
    if not isAimbotActive() then Config.AimbotLockedTarget = nil return end
    local target = pickAimbotTarget()
    if not target or not target.part or not target.part.Parent then return end

    local camCF = Camera.CFrame
    local targetPos = target.part.Position
    local dir = (targetPos - camCF.Position).Unit
    local newCF = CFrame.new(camCF.Position, camCF.Position + dir)

    if Config.AimbotSmoothness > 1 then
        Camera.CFrame = camCF:Lerp(newCF, 1 / Config.AimbotSmoothness)
    else
        Camera.CFrame = newCF
    end
end

local function startAimbot()
    if aimbotConnection then return end
    aimbotConnection = RunService.Heartbeat:Connect(safe(aimbotStep))
end

local function stopAimbot()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    Config.AimbotLockedTarget = nil
end

-- ============================================================
-- INPUT
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Config.AimbotKey then Config.AimbotKeyHeld = true end
    if input.KeyCode == Config.AimbotCycleKey and Config.AimbotEnabled then cycleAimbotTarget() end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimbotKey then Config.AimbotKeyHeld = false end
end)

UserInputService.TouchStarted:Connect(function()
    Config.AimbotTouchHeld = true
end)

UserInputService.TouchEnded:Connect(function()
    Config.AimbotTouchHeld = false
end)

-- ============================================================
-- ESP TAB
-- ============================================================
ESPTab:CreateSection("Main")
ESPTab:CreateToggle({Name="Enable ESP", CurrentValue=true, Flag="ESPEnabled", Callback=function(v)
    Config.ESPEnabled=v; if v then startESP() else stopESP() end
end})

ESPTab:CreateSection("Options")
ESPTab:CreateToggle({Name="Box", CurrentValue=true, Flag="ESPBox", Callback=function(v) Config.Box=v end})
ESPTab:CreateToggle({Name="Name", CurrentValue=true, Flag="ESPName", Callback=function(v) Config.Name=v end})
ESPTab:CreateToggle({Name="Team Check", CurrentValue=false, Flag="ESPTeamCheck", Callback=function(v) Config.ESPTeamCheck=v end})

-- ============================================================
-- AIMBOT TAB
-- ============================================================
AimbotTab:CreateSection("Main")
AimbotTab:CreateToggle({Name="Enable Aimbot", CurrentValue=true, Flag="AimbotEnabled", Callback=function(v)
    Config.AimbotEnabled=v; if v then startAimbot() else stopAimbot() end
end})
AimbotTab:CreateDropdown({Name="Activation Mode", Options={"Hold Key","Always On","Touch"}, CurrentOption={"Hold Key"}, Flag="AimbotActivation",
    Callback=function(o) Config.AimbotActivation=o[1] or "Hold Key"; Config.AimbotLockedTarget=nil end})

AimbotTab:CreateSection("Settings")
AimbotTab:CreateToggle({Name="Team Check", CurrentValue=false, Flag="AimbotTeamCheck", Callback=function(v) Config.AimbotTeamCheck=v end})
AimbotTab:CreateToggle({Name="Wall Check", CurrentValue=true, Flag="AimbotWallCheck", Callback=function(v) Config.AimbotWallCheck=v end})
AimbotTab:CreateToggle({Name="Show FOV Circle", CurrentValue=true, Flag="AimbotShowFOV", Callback=function(v) Config.AimbotShowFOV=v end})
AimbotTab:CreateSlider({Name="FOV", Range={10,100}, Increment=5, Suffix=" px", CurrentValue=55, Flag="AimbotFOV", Callback=function(v) Config.AimbotFOV=v end})
AimbotTab:CreateSlider({Name="Smoothness", Range={1,20}, Increment=1, Suffix="x", CurrentValue=2, Flag="AimbotSmooth", Callback=function(v) Config.AimbotSmoothness=v end})
AimbotTab:CreateSlider({Name="Max Distance", Range={10,500}, Increment=10, Suffix=" studs", CurrentValue=500, Flag="AimbotMaxDist", Callback=function(v) Config.AimbotMaxDistance=v end})
AimbotTab:CreateLabel("Upgrade to Premium for Silent Aim, Hitbox Expander, Trigger Bot")

-- ============================================================
-- SETTINGS TAB
-- ============================================================
SettingsTab:CreateSection("Script")
SettingsTab:CreateButton({
    Name = "Delete Script",
    Callback = function()
        stopESP(); stopAimbot()
        if fovCircle and fovCircle.Remove then fovCircle:Remove() end
        Rayfield:Destroy(); Rayfield = nil
    end,
})

SettingsTab:CreateSection("Credits")
SettingsTab:CreateLabel("made by _.ingnix._")
SettingsTab:CreateLabel("ui: rayfield")

startESP()
startAimbot()
