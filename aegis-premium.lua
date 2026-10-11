-- Aegis Solutions | Premium Version
-- credits: _.ingnix._
-- built for those who never miss.
-- PART 1 of 3

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Aegis | Premium",
    LoadingTitle = "Aegis",
    LoadingSubtitle = "premium edition",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local ESPTab = Window:CreateTab("ESP", 4483362458)
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local Config = {
    ESPEnabled = true,
    Box = true, Name = true, Health = true,
    Distance = false, Tracer = true, HeadDot = false,
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
    AimbotMaxDistance = 1000,
    AimbotActivation = "Always On",
    AimbotTouchHeld = false,
    AimbotTargetLock = true,
    AimbotSwitchDelay = 0.2,
    AimbotCycleKey = Enum.KeyCode.Q,
    AimbotLastSwitch = 0,
    AimbotLockedTarget = nil,

    SilentAimEnabled = false,
    SilentAimTeamCheck = true,
    SilentAimWallCheck = true,
    SilentAimFOV = 150,
    SilentAimShowFOV = false,
    SilentAimTargetPart = "Head",
    SilentAimHitChance = 100,
    SilentAimMaxDistance = 1000,

    HitboxEnabled = false,
    HitboxSize = 10,
    HitboxTransparency = 0.7,
    HitboxTeamCheck = true,
    HitboxTargetPart = "HumanoidRootPart",
    HitboxCache = {},

    TriggerBotEnabled = false,
    TriggerBotTeamCheck = true,
    TriggerBotDelay = 0.05,
    TriggerBotKey = Enum.UserInputType.MouseButton2,
    TriggerBotKeyHeld = false,
    TriggerBotLastFire = 0,
    TriggerBotMaxDistance = 500,
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

local function sameTeam(player)
    if not player or player == LocalPlayer then return true end

    local myTeam = LocalPlayer.Team
    local theirTeam = player.Team

    if myTeam and theirTeam then
        if myTeam == theirTeam then return true end
        if myTeam.TeamColor and theirTeam.TeamColor and myTeam.TeamColor == theirTeam.TeamColor then
            return true
        end
        return false
    end

    if myTeam or theirTeam then return false end

    local theirChar = player.Character
    local myChar = LocalPlayer.Character
    if theirChar and myChar then
        local theirColor = theirChar:GetAttribute("TeamColor")
        local myColor = myChar:GetAttribute("TeamColor")
        if not theirColor and theirChar:FindFirstChild("Team") then
            theirColor = theirChar.Team.Value
        end
        if not myColor and myChar:FindFirstChild("Team") then
            myColor = myChar.Team.Value
        end
        if theirColor and myColor and theirColor ~= "" and myColor ~= "" and theirColor == myColor then
            return true
        end
    end

    return false
end

local espCache = {}
local renderConnection, playerAddedConn, playerRemovingConn
local charAddedConnections = {}

local BONE_MAP = {
    R15 = {
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    },
    R6 = {
        {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
        {"Torso","Left Leg"},{"Torso","Right Leg"},
    },
}

local function detectRig(char)
    if char:FindFirstChild("UpperTorso") then return "R15" end
    if char:FindFirstChild("Torso") then return "R6" end
    return nil
end

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
        SkeletonLines = {},
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
            if type(v) == "userdata" and v.Remove then v:Remove()
            elseif type(v) == "table" then
                for _, line in pairs(v) do
                    if line and line.Remove then line:Remove() end
                end
            end
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
    for _, line in pairs(data.SkeletonLines) do line.Visible = false end
end

local function updateSkeleton(data, char, rigType, color)
    local bones = BONE_MAP[rigType]
    while #data.SkeletonLines < #bones do
        local line = Drawing.new("Line")
        line.Visible = false; line.Thickness = 1
        table.insert(data.SkeletonLines, line)
    end
    for i, pair in ipairs(bones) do
        local line = data.SkeletonLines[i]
        local a = char:FindFirstChild(pair[1])
        local b = char:FindFirstChild(pair[2])
        if a and b then
            local ap, _ = Camera:WorldToViewportPoint(a.Position)
            local bp, _ = Camera:WorldToViewportPoint(b.Position)
            if ap.Z > 0 and bp.Z > 0 then
                line.Visible = true
                line.From = Vector2.new(ap.X, ap.Y)
                line.To = Vector2.new(bp.X, bp.Y)
                line.Color = color
            else line.Visible = false end
        else line.Visible = false end
    end
end

local function updateESP(player, data)
    if Config.ESPTeamCheck and sameTeam(player) then
        hide(data) return
    end

    local char = player.Character
    if not char then hide(data) return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not humanoid or not root or not head or humanoid.Health <= 0 then hide(data) return end

    local distance = (Camera.CFrame.Position - root.Position).Magnitude
    if distance > Config.MaxDistance then hide(data) return end

    local headPos = Camera:WorldToViewportPoint(head.Position)
    local rootPos = Camera:WorldToViewportPoint(root.Position)
    if headPos.Z <= 0 or rootPos.Z <= 0 then hide(data) return end

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

    if Config.Distance then
        data.Distance.Visible = true
        data.Distance.Text = string.format("[%d]", math.floor(distance))
        data.Distance.Position = Vector2.new(headPos.X, y + height + 2)
        data.Distance.Color = Color3.fromRGB(255, 255, 255)
    else data.Distance.Visible = false end

    if Config.Health then
        local hp = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        local bw, bh = 4, height
        local bx, by = x - bw - 5, y

        data.HealthBarOutline.Visible = true
        data.HealthBarOutline.Size = Vector2.new(bw + 2, bh + 2)
        data.HealthBarOutline.Position = Vector2.new(bx - 1, by - 1)
        data.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)

        data.HealthBar.Visible = true
        data.HealthBar.Size = Vector2.new(bw, bh * hp)
        data.HealthBar.Position = Vector2.new(bx, by + bh * (1 - hp))
        data.HealthBar.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 0)
    else
        data.HealthBar.Visible = false; data.HealthBarOutline.Visible = false
    end

    if Config.Tracer then
        data.Tracer.Visible = true
        data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        data.Tracer.To = Vector2.new(headPos.X, y + height)
        data.Tracer.Color = Color3.fromRGB(255, 255, 255)
        data.Tracer.Thickness = 1
    else data.Tracer.Visible = false end

    if Config.HeadDot then
        data.HeadDot.Visible = true
        data.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
        data.HeadDot.Radius = 3
        data.HeadDot.Color = Color3.fromRGB(255, 255, 255)
    else data.HeadDot.Visible = false end

    if Config.Skeleton then
        local rigType = detectRig(char)
        if rigType then updateSkeleton(data, char, rigType, Config.SkeletonColor)
        else for _, line in pairs(data.SkeletonLines) do line.Visible = false end end
    else for _, line in pairs(data.SkeletonLines) do line.Visible = false end end
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
-- Aegis Solutions | PART 2 of 3

local fovCircle = Drawing.new("Circle")
fovCircle.Visible=false; fovCircle.Thickness=1
fovCircle.Color=Color3.fromRGB(255,255,255); fovCircle.Filled=false; fovCircle.NumSides=64

local silentFovCircle = Drawing.new("Circle")
silentFovCircle.Visible=false; silentFovCircle.Thickness=1
silentFovCircle.Color=Color3.fromRGB(0,200,255); silentFovCircle.Filled=false; silentFovCircle.NumSides=64

RunService.RenderStepped:Connect(safe(function()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    if Config.AimbotShowFOV and Config.AimbotEnabled then
        fovCircle.Visible = true
        fovCircle.Radius = Config.AimbotFOV
        fovCircle.Position = center
    else fovCircle.Visible = false end
    if Config.SilentAimShowFOV and Config.SilentAimEnabled then
        silentFovCircle.Visible = true
        silentFovCircle.Radius = Config.SilentAimFOV
        silentFovCircle.Position = center
    else silentFovCircle.Visible = false end
end))

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
        if teamCheck and sameTeam(player) then continue end
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

local silentActive = false
local originalNamecall

local function startSilentAim()
    if silentActive then return end
    if not getnamecallmethod or not hookmetamethod then
        warn("[Aegis] Silent aim not supported on this executor")
        return
    end
    originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and Config.SilentAimEnabled then
            if math.random(1, 100) <= Config.SilentAimHitChance then
                local targets = getValidTargets(Config.SilentAimFOV, Config.SilentAimTeamCheck, Config.SilentAimWallCheck, Config.SilentAimMaxDistance, Config.SilentAimTargetPart)
                if #targets > 0 then
                    local tp = targets[1].part.Position
                    local args = {...}
                    for i, v in ipairs(args) do
                        if typeof(v) == "Vector3" then args[i] = tp
                        elseif typeof(v) == "CFrame" then args[i] = CFrame.new(v.Position, tp) end
                    end
                    return originalNamecall(self, table.unpack(args))
                end
            end
        end
        return originalNamecall(self, ...)
    end)
    silentActive = true
end

local function stopSilentAim()
    if silentActive and originalNamecall then
        hookmetamethod(game, "__namecall", originalNamecall)
        silentActive = false
    end
end

local hitboxConn

local function applyHitbox(player)
    local char = player.Character
    if not char then return end
    local part = char:FindFirstChild(Config.HitboxTargetPart)
    if not part or not part:IsA("BasePart") then return end
    if not Config.HitboxCache[player] then
        Config.HitboxCache[player] = {size=part.Size, transparency=part.Transparency, cancollide=part.CanCollide}
    end
    part.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
    part.Transparency = Config.HitboxTransparency
    part.CanCollide = false
end

local function restoreHitbox(player)
    local c = Config.HitboxCache[player]
    if not c then return end
    local char = player.Character
    if char then
        local part = char:FindFirstChild(Config.HitboxTargetPart)
        if part and part:IsA("BasePart") then
            part.Size = c.size; part.Transparency = c.transparency; part.CanCollide = c.cancollide
        end
    end
    Config.HitboxCache[player] = nil
end

local function startHitbox()
    if hitboxConn then return end
    hitboxConn = RunService.Heartbeat:Connect(safe(function()
        if not Config.HitboxEnabled then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if Config.HitboxTeamCheck and sameTeam(player) then continue end
            applyHitbox(player)
        end
    end))
end

local function stopHitbox()
    if hitboxConn then hitboxConn:Disconnect(); hitboxConn = nil end
    for player, _ in pairs(Config.HitboxCache) do restoreHitbox(player) end
    Config.HitboxCache = {}
end

local triggerConn

local function getCrosshairTarget()
    local ray = Camera:ViewportPointToRay(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local result = workspace:Raycast(ray.Origin, ray.Direction * Config.TriggerBotMaxDistance)
    if not result then return nil end
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local player = Players:GetPlayerFromCharacter(model)
    if not player or player == LocalPlayer then return nil end
    if Config.TriggerBotTeamCheck and sameTeam(player) then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return player
end

local function fireWeapon()
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        for _, name in ipairs({"Fire","Shoot","Attack","Remote","FireWeapon"}) do
            local r = tool:FindFirstChild(name)
            if r and r:IsA("RemoteEvent") then
                pcall(function() r:FireServer() end); return
            end
        end
    end
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end)
end

local function startTriggerBot()
    if triggerConn then return end
    triggerConn = RunService.RenderStepped:Connect(safe(function()
        if not Config.TriggerBotEnabled then return end
        if not Config.TriggerBotKeyHeld then return end
        local now = tick()
        if now - Config.TriggerBotLastFire < Config.TriggerBotDelay then return end
        if not getCrosshairTarget() then return end
        Config.TriggerBotLastFire = now
        fireWeapon()
    end))
end

local function stopTriggerBot()
    if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Config.AimbotKey then Config.AimbotKeyHeld = true end
    if input.UserInputType == Config.TriggerBotKey then Config.TriggerBotKeyHeld = true end
    if input.KeyCode == Config.AimbotCycleKey and Config.AimbotEnabled then cycleAimbotTarget() end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.AimbotKey then Config.AimbotKeyHeld = false end
    if input.UserInputType == Config.TriggerBotKey then Config.TriggerBotKeyHeld = false end
end)

local touchStartTime = 0
local TRIGGER_HOLD_TIME = 0.3

UserInputService.TouchStarted:Connect(function()
    Config.AimbotTouchHeld = true
    touchStartTime = tick()
    task.spawn(function()
        task.wait(TRIGGER_HOLD_TIME)
        if Config.AimbotTouchHeld and (tick() - touchStartTime) >= TRIGGER_HOLD_TIME then
            Config.TriggerBotKeyHeld = true
        end
    end)
end)

UserInputService.TouchEnded:Connect(function()
    Config.AimbotTouchHeld = false
    Config.TriggerBotKeyHeld = false
    touchStartTime = 0
end)
-- Aegis Solutions | PART 3 of 3

ESPTab:CreateSection("Main")
ESPTab:CreateToggle({Name="Enable ESP", CurrentValue=true, Flag="ESPEnabled", Callback=function(v)
    Config.ESPEnabled=v; if v then startESP() else stopESP() end
end})

ESPTab:CreateSection("Options")
ESPTab:CreateToggle({Name="Box", CurrentValue=true, Flag="ESPBox", Callback=function(v) Config.Box=v end})
ESPTab:CreateToggle({Name="Name", CurrentValue=true, Flag="ESPName", Callback=function(v) Config.Name=v end})
ESPTab:CreateToggle({Name="Health", CurrentValue=true, Flag="ESPHealth", Callback=function(v) Config.Health=v end})
ESPTab:CreateToggle({Name="Distance", CurrentValue=false, Flag="ESPDistance", Callback=function(v) Config.Distance=v end})
ESPTab:CreateToggle({Name="Tracer", CurrentValue=true, Flag="ESPTracer", Callback=function(v) Config.Tracer=v end})
ESPTab:CreateToggle({Name="Head Dot", CurrentValue=false, Flag="ESPHeadDot", Callback=function(v) Config.HeadDot=v end})
ESPTab:CreateToggle({Name="Skeleton", CurrentValue=false, Flag="ESPSkeleton", Callback=function(v) Config.Skeleton=v end})
ESPTab:CreateToggle({Name="Team Check", CurrentValue=false, Flag="ESPTeamCheck", Callback=function(v) Config.ESPTeamCheck=v end})
ESPTab:CreateSlider({Name="Max Distance", Range={10,5000}, Increment=10, Suffix=" studs", CurrentValue=4920, Flag="ESPMaxDistance", Callback=function(v) Config.MaxDistance=v end})

AimbotTab:CreateSection("Aimbot")
AimbotTab:CreateToggle({Name="Enable Aimbot", CurrentValue=true, Flag="AimbotEnabled", Callback=function(v)
    Config.AimbotEnabled=v; if v then startAimbot() else stopAimbot() end
end})
AimbotTab:CreateDropdown({Name="Activation Mode", Options={"Hold Key","Always On","Touch"}, CurrentOption={"Always On"}, Flag="AimbotActivation",
    Callback=function(o) Config.AimbotActivation=o[1] or "Always On"; Config.AimbotLockedTarget=nil end})
AimbotTab:CreateDropdown({Name="Target Part", Options={"Head","HumanoidRootPart","UpperTorso","Torso"}, CurrentOption={"Head"}, Flag="AimbotTarget",
    Callback=function(o) Config.AimbotTargetPart=o[1] or "Head" end})
AimbotTab:CreateToggle({Name="Target Lock (hard lock)", CurrentValue=true, Flag="AimbotTargetLock",
    Callback=function(v) Config.AimbotTargetLock=v; Config.AimbotLockedTarget=nil end})
AimbotTab:CreateSlider({Name="Switch Delay", Range={0,5}, Increment=0.1, Suffix="s", CurrentValue=0.2, Flag="AimbotSwitchDelay", Callback=function(v) Config.AimbotSwitchDelay=v end})
AimbotTab:CreateToggle({Name="Team Check", CurrentValue=false, Flag="AimbotTeamCheck", Callback=function(v) Config.AimbotTeamCheck=v; Config.AimbotLockedTarget=nil end})
AimbotTab:CreateToggle({Name="Wall Check", CurrentValue=true, Flag="AimbotWallCheck", Callback=function(v) Config.AimbotWallCheck=v end})
AimbotTab:CreateToggle({Name="Show FOV Circle", CurrentValue=true, Flag="AimbotShowFOV", Callback=function(v) Config.AimbotShowFOV=v end})
AimbotTab:CreateSlider({Name="FOV", Range={10,500}, Increment=5, Suffix=" px", CurrentValue=55, Flag="AimbotFOV", Callback=function(v) Config.AimbotFOV=v end})
AimbotTab:CreateSlider({Name="Smoothness", Range={1,20}, Increment=1, Suffix="x", CurrentValue=2, Flag="AimbotSmooth", Callback=function(v) Config.AimbotSmoothness=v end})
AimbotTab:CreateSlider({Name="Max Distance", Range={10,5000}, Increment=10, Suffix=" studs", CurrentValue=1000, Flag="AimbotMaxDist", Callback=function(v) Config.AimbotMaxDistance=v end})
AimbotTab:CreateLabel("Cycle Target key: Q (hardcoded)")

AimbotTab:CreateSection("Silent Aim")
AimbotTab:CreateToggle({Name="Enable Silent Aim", CurrentValue=false, Flag="SilentAimEnabled",
    Callback=function(v) Config.SilentAimEnabled=v; if v then startSilentAim() else stopSilentAim() end end})
AimbotTab:CreateDropdown({Name="Target Part", Options={"Head","HumanoidRootPart","UpperTorso","Torso"}, CurrentOption={"Head"}, Flag="SilentAimTarget",
    Callback=function(o) Config.SilentAimTargetPart=o[1] or "Head" end})
AimbotTab:CreateToggle({Name="Team Check", CurrentValue=true, Flag="SilentAimTeamCheck", Callback=function(v) Config.SilentAimTeamCheck=v end})
AimbotTab:CreateToggle({Name="Wall Check", CurrentValue=true, Flag="SilentAimWallCheck", Callback=function(v) Config.SilentAimWallCheck=v end})
AimbotTab:CreateToggle({Name="Show FOV Circle", CurrentValue=false, Flag="SilentAimShowFOV", Callback=function(v) Config.SilentAimShowFOV=v end})
AimbotTab:CreateSlider({Name="Silent FOV", Range={10,500}, Increment=5, Suffix=" px", CurrentValue=150, Flag="SilentAimFOV", Callback=function(v) Config.SilentAimFOV=v end})
AimbotTab:CreateSlider({Name="Hit Chance", Range={0,100}, Increment=1, Suffix="%", CurrentValue=100, Flag="SilentAimHitChance", Callback=function(v) Config.SilentAimHitChance=v end})
AimbotTab:CreateSlider({Name="Max Distance", Range={10,5000}, Increment=10, Suffix=" studs", CurrentValue=1000, Flag="SilentAimMaxDist", Callback=function(v) Config.SilentAimMaxDistance=v end})

AimbotTab:CreateSection("Hitbox Expander")
AimbotTab:CreateToggle({Name="Enable Hitbox Expander", CurrentValue=false, Flag="HitboxEnabled",
    Callback=function(v) Config.HitboxEnabled=v; if v then startHitbox() else stopHitbox() end end})
AimbotTab:CreateDropdown({Name="Hitbox Part", Options={"HumanoidRootPart","Head","UpperTorso","Torso"}, CurrentOption={"HumanoidRootPart"}, Flag="HitboxPart",
    Callback=function(o) if Config.HitboxEnabled then stopHitbox() end; Config.HitboxTargetPart=o[1] or "HumanoidRootPart"; if Config.HitboxEnabled then startHitbox() end end})
AimbotTab:CreateToggle({Name="Hitbox Team Check", CurrentValue=true, Flag="HitboxTeamCheck", Callback=function(v) Config.HitboxTeamCheck=v end})
AimbotTab:CreateSlider({Name="Hitbox Size", Range={1,50}, Increment=1, Suffix=" studs", CurrentValue=10, Flag="HitboxSize", Callback=function(v) Config.HitboxSize=v end})
AimbotTab:CreateSlider({Name="Hitbox Transparency", Range={0,1}, Increment=0.1, Suffix="", CurrentValue=0.7, Flag="HitboxTransparency", Callback=function(v) Config.HitboxTransparency=v end})

AimbotTab:CreateSection("Trigger Bot")
AimbotTab:CreateToggle({Name="Enable Trigger Bot", CurrentValue=false, Flag="TriggerBotEnabled",
    Callback=function(v) Config.TriggerBotEnabled=v; if v then startTriggerBot() else stopTriggerBot() end end})
AimbotTab:CreateToggle({Name="Trigger Team Check", CurrentValue=true, Flag="TriggerTeamCheck", Callback=function(v) Config.TriggerBotTeamCheck=v end})
AimbotTab:CreateSlider({Name="Trigger Delay", Range={0,1}, Increment=0.01, Suffix="s", CurrentValue=0.05, Flag="TriggerDelay", Callback=function(v) Config.TriggerBotDelay=v end})
AimbotTab:CreateSlider({Name="Trigger Max Distance", Range={10,1000}, Increment=10, Suffix=" studs", CurrentValue=500, Flag="TriggerMaxDist", Callback=function(v) Config.TriggerBotMaxDistance=v end})

SettingsTab:CreateSection("Script")
SettingsTab:CreateButton({
    Name = "Delete Script",
    Callback = function()
        stopESP(); stopAimbot(); stopSilentAim(); stopHitbox(); stopTriggerBot()
        if fovCircle and fovCircle.Remove then fovCircle:Remove() end
        if silentFovCircle and silentFovCircle.Remove then silentFovCircle:Remove() end
        Rayfield:Destroy(); Rayfield = nil
    end,
})

SettingsTab:CreateSection("Credits")
SettingsTab:CreateLabel("made by _.ingnix._")
SettingsTab:CreateLabel("ui: rayfield")

startESP()
startAimbot()
