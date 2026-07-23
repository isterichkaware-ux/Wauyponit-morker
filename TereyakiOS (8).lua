local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Settings = {
    Enabled = false,
    IsDead = false,
    IgnoredList = {},
    ProcessedList = {},
    TempIgnored = {},
    IgnoreDuration = 60,
    DebugPrintEnabled = true,
    TargetY = 4.8,
    MoveSpeed = 22,
    SomeFlag = true,
    WaypointSpacing = 3,
    SomeOtherParam = 3,
    PickupDistance = 8,
    MaxSomething = 999999,
    BreakMethod = "Crowbar", -- "Crowbar" or "Lockpick"
    AutoDeposit = false,
    AutoDepositThreshold = 5000,
    AutoAllowance = false,
    NeedsStartupToolCheck = false,
}

local StatsInfo = {
    CashAmount = 0,
    AllowanceAmount = 0,
    AllowanceText = "",
    AllowanceSecondsLeft = nil,
    BankAmount = 0,
    DepositInProgress = false,
    DepositCooldownUntil = 0,
    DepositLastAttemptAt = 0,
    LastAllowanceClaimAttempt = 0,
}

local PickupLock = {Lock = {Busy = false}}

-- Экспортируем Settings наружу, чтобы твоя отдельная GUI могла менять
-- Settings.BreakMethod (и вообще любые настройки) прямо из другого скрипта:
--   _G.FarmSettings.BreakMethod = "Lockpick"
_G.FarmSettings = Settings
local LastTick = tick()
local CurrentTargetPart = nil
local IsMovingToTarget = false
local SomeFlag2 = false
local SomeNil = nil
local StatusText = "Ожидание"
local AvailableSafesCount = 0
local AvailableRegistersCount = 0
local Unused1 = 0
local Unused2 = 0
local TotalSafesCount = 0
local TotalRegistersCount = 0
local AvailableSafes = {}
local AvailableRegisters = {}
local TotalAvailableTargets = 0
local SuggestionText = ""
local SomeNil2 = nil
local BrokenStatusMap = {}
local RetryCount = 0
local LastShopMainPart = nil
local IsRising = false
local SortedTargets = {}
local HasReachedTargetY = false

-- ==================== On-screen лог-панель ====================
-- На телефоне нет удобного доступа к Developer Console, поэтому дублируем
-- все Log(...) сообщения в маленькую панель прямо на экране.
local DebugLogGui = Instance.new("ScreenGui")
DebugLogGui.Name = "TereyakiDebugLog"
DebugLogGui.ResetOnSpawn = false
DebugLogGui.IgnoreGuiInset = true
DebugLogGui.DisplayOrder = 1000
DebugLogGui.Parent = PlayerGui

local DebugLogFrame = Instance.new("Frame")
DebugLogFrame.Name = "LogFrame"
DebugLogFrame.Size = UDim2.new(0, 340, 0, 220)
DebugLogFrame.Position = UDim2.new(1, -350, 0, 70)
DebugLogFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
DebugLogFrame.BackgroundTransparency = 0.25
DebugLogFrame.BorderSizePixel = 0
DebugLogFrame.Active = true
DebugLogFrame.Draggable = true
DebugLogFrame.Parent = DebugLogGui

local DebugLogCorner = Instance.new("UICorner")
DebugLogCorner.CornerRadius = UDim.new(0, 6)
DebugLogCorner.Parent = DebugLogFrame

local DebugLogTitle = Instance.new("TextLabel")
DebugLogTitle.Size = UDim2.new(1, 0, 0, 22)
DebugLogTitle.BackgroundTransparency = 1
DebugLogTitle.Text = "Tereyaki Debug Log (тапни чтобы скрыть/показать)"
DebugLogTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
DebugLogTitle.TextSize = 12
DebugLogTitle.Font = Enum.Font.Code
DebugLogTitle.TextXAlignment = Enum.TextXAlignment.Left
DebugLogTitle.Position = UDim2.new(0, 6, 0, 2)
DebugLogTitle.Parent = DebugLogFrame

local DebugLogScroll = Instance.new("ScrollingFrame")
DebugLogScroll.Size = UDim2.new(1, -6, 1, -26)
DebugLogScroll.Position = UDim2.new(0, 3, 0, 24)
DebugLogScroll.BackgroundTransparency = 1
DebugLogScroll.BorderSizePixel = 0
DebugLogScroll.ScrollBarThickness = 4
DebugLogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DebugLogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DebugLogScroll.Parent = DebugLogFrame

local DebugLogText = Instance.new("TextLabel")
DebugLogText.Size = UDim2.new(1, 0, 0, 0)
DebugLogText.AutomaticSize = Enum.AutomaticSize.Y
DebugLogText.BackgroundTransparency = 1
DebugLogText.Text = ""
DebugLogText.TextColor3 = Color3.fromRGB(220, 220, 220)
DebugLogText.TextSize = 12
DebugLogText.Font = Enum.Font.Code
DebugLogText.TextXAlignment = Enum.TextXAlignment.Left
DebugLogText.TextYAlignment = Enum.TextYAlignment.Top
DebugLogText.TextWrapped = true
DebugLogText.Parent = DebugLogScroll

local DebugLogLines = {}
local DEBUG_LOG_MAX_LINES = 60

local function pushDebugLogLine(msg)
    table.insert(DebugLogLines, os.date("%H:%M:%S") .. " " .. tostring(msg))
    while #DebugLogLines > DEBUG_LOG_MAX_LINES do
        table.remove(DebugLogLines, 1)
    end
    DebugLogText.Text = table.concat(DebugLogLines, "\n")
    DebugLogScroll.CanvasPosition = Vector2.new(0, math.huge)
end

do
    local visible = true
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 22)
    toggleButton.BackgroundTransparency = 1
    toggleButton.Text = ""
    toggleButton.Parent = DebugLogTitle
    toggleButton.MouseButton1Click:Connect(function()
        visible = not visible
        DebugLogScroll.Visible = visible
        DebugLogFrame.Size = visible and UDim2.new(0, 340, 0, 220) or UDim2.new(0, 340, 0, 24)
    end)
end

print("[AutoFarm] Debug log panel created, parent:", DebugLogGui.Parent and DebugLogGui.Parent:GetFullName())
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Tereyaki Debug",
        Text = "Панель лога создана (правый верх)",
        Duration = 4,
    })
end)

local function Log(msg)
    if Settings.DebugPrintEnabled then
        print("[AutoFarm]", msg)
    end
    pcall(pushDebugLogLine, msg)
end

local VirtualUser = game:GetService("VirtualUser")
local AntiAfkEnabled = true
local AntiAfkConnection = nil

local function EnableAntiAfk()
    if AntiAfkConnection then return end
    AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if AntiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            Log("Анти-АФК сработал")
        end
    end)
    Log("Анти-АФК запущен")
end

local function DisableAntiAfk()
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection = nil
    end
    Log("Анти-АФК остановлен")
end

EnableAntiAfk()

local AutoPickupRunning = false
local AutoPickupConnection = nil

local function StartAutoPickup()
    if AutoPickupRunning then return end
    AutoPickupRunning = true
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    AutoPickupConnection = RunService.RenderStepped:Connect(function()
        if not AutoPickupRunning or Settings.IsDead then return end
        local spawnedBreadFolder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
        local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
        if not spawnedBreadFolder or not pickupEvent then return end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if PickupLock.Lock.Busy then return end
        local charPos = hrp.Position
        for _, breadPart in ipairs(spawnedBreadFolder:GetChildren()) do
            if (charPos - breadPart.Position).Magnitude <= Settings.PickupDistance then
                if not PickupLock.Lock.Busy then
                    PickupLock.Lock.Busy = true
                    pcall(function() pickupEvent:FireServer(breadPart) end)
                    task.wait(1.1)
                    PickupLock.Lock.Busy = false
                    break
                end
            end
        end
    end)
end

local function StopAutoPickup()
    if not AutoPickupRunning then return end
    AutoPickupRunning = false
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    if PickupLock and PickupLock.Lock then
        PickupLock.Lock.Busy = false
    end
end

StartAutoPickup()
Log("Авто-подбор денег активирован")

do
    repeat task.wait() until game:IsLoaded()
    local clonerefSafe = cloneref or function(...) return ... end
    local services = setmetatable({}, { __index = function(_, k) return clonerefSafe(game:GetService(k)) end })
    local localPlayer = services.Players.LocalPlayer
    local character, humanoid, hrp

    local function updateChar()
        character = localPlayer.Character
        if character then
            hrp = character:FindFirstChild("HumanoidRootPart")
            humanoid = character:FindFirstChildOfClass("Humanoid")
        else
            hrp = nil
            humanoid = nil
        end
    end
    updateChar()

    local heartbeat = RunService.Heartbeat
    local renderStepped = RunService.RenderStepped
    local coreGui = game:GetService("CoreGui")
    local starterGui = game:GetService("StarterGui")

    local InvisPossible = true
    if character and not character:FindFirstChild("Torso") then
        pcall(function() starterGui:SetCore("SendNotification", { Title = "Невидимость НЕ РАБОТАЕТ", Text = "Требуется R6 аватар", Duration = 5 }) end)
        InvisPossible = false
    end

    local warningGui = Instance.new("ScreenGui")
    warningGui.Name = "InvisWarningGUI"
    warningGui.Parent = coreGui
    warningGui.ResetOnSpawn = false
    warningGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local InvisWarningLabel = Instance.new("TextLabel", warningGui)
    InvisWarningLabel.Text = "⚠️ВЫ ВИДИМЫ⚠️"
    InvisWarningLabel.Visible = false
    InvisWarningLabel.Size = UDim2.new(0, 200, 0, 30)
    InvisWarningLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
    InvisWarningLabel.BackgroundTransparency = 1
    InvisWarningLabel.Font = Enum.Font.GothamSemibold
    InvisWarningLabel.TextSize = 24
    InvisWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    InvisWarningLabel.TextStrokeTransparency = 0.5
    InvisWarningLabel.ZIndex = 10

    local InvisActive = false
    local InvisAnim = Instance.new("Animation")
    InvisAnim.AnimationId = "rbxassetid://215384594"
    local InvisAnimTrack = nil

    local function isGrounded()
        return humanoid and humanoid:IsDescendantOf(workspace) and humanoid.FloorMaterial ~= Enum.Material.Air
    end

    local function loadInvisAnim()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if humanoid then
            local success, track = pcall(function() return humanoid:LoadAnimation(InvisAnim) end)
            if success then
                InvisAnimTrack = track
                InvisAnimTrack.Priority = Enum.AnimationPriority.Action4
            else
                InvisAnimTrack = nil
            end
        else
            InvisAnimTrack = nil
        end
    end

    local function disableInvis()
        if not InvisActive then return end
        InvisActive = false
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if humanoid then
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency == 1 then
                    part.Transparency = 0
                end
            end
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end

    local function enableInvis()
        if InvisActive or not InvisPossible then return end
        updateChar()
        if not character or not humanoid or not hrp then return end
        if not character:FindFirstChild("Torso") then
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Невидимость НЕ РАБОТАЕТ", Text = "Требуется R6 аватар", Duration = 5 }) end)
            return
        end
        InvisActive = true
        workspace.CurrentCamera.CameraSubject = hrp
        loadInvisAnim()
    end

    local function toggleInvis()
        if InvisActive then
            disableInvis()
        else
            enableInvis()
        end
        return InvisActive
    end

    _G.Invis_Enable = enableInvis
    _G.Invis_Disable = disableInvis
    _G.Invis_Toggle = toggleInvis
    _G.IsInvisEnabled = function() return InvisActive end

    localPlayer.CharacterAdded:Connect(function(newChar)
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        task.wait()
        updateChar()
        if not humanoid then
            task.wait(0.5)
            updateChar()
            if not humanoid then
                InvisPossible = false
                if InvisActive then disableInvis() end
                pcall(function() starterGui:SetCore("SendNotification", { Title = "Ошибка невидимости", Text = "Не удалось определить тип персонажа", Duration = 5 }) end)
                return
            end
        end
        if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            InvisPossible = false
            if InvisActive then disableInvis() end
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Предупреждение", Text = "Обнаружен не-R6 аватар. Невидимость отключена", Duration = 5 }) end)
            return
        else
            InvisPossible = true
        end
        if InvisActive then
            if hrp then workspace.CurrentCamera.CameraSubject = hrp end
            loadInvisAnim()
        end
    end)

    localPlayer.CharacterRemoving:Connect(function()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end)

    heartbeat:Connect(function(dt)
        if not InvisActive or not InvisPossible then
            if not InvisActive and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency == 1 then
                        part.Transparency = 0
                    end
                end
            end
            if InvisWarningLabel then
                InvisWarningLabel.Visible = false
            end
            return
        end
        if not character or not humanoid or not hrp or not humanoid:IsDescendantOf(workspace) or humanoid.Health <= 0 then
            if InvisWarningLabel then InvisWarningLabel.Visible = false end
            return
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = not isGrounded()
        end

        local speed = 12
        if humanoid.MoveDirection.Magnitude > 0 then
            local move = humanoid.MoveDirection * speed * dt
            hrp.CFrame = hrp.CFrame + move
        end

        local originalCF = hrp.CFrame
        local originalCamOffset = humanoid.CameraOffset
        local _, cameraYaw = workspace.CurrentCamera.CFrame:ToOrientation()

        hrp.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.fromOrientation(0, cameraYaw, 0)
        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

        if InvisAnimTrack then
            local success = pcall(function()
                if not InvisAnimTrack.IsPlaying then
                    InvisAnimTrack:Play()
                end
                InvisAnimTrack:AdjustSpeed(0)
                InvisAnimTrack.TimePosition = 0.3
            end)
            if not success then
                loadInvisAnim()
            end
        elseif humanoid and humanoid.Health > 0 then
            loadInvisAnim()
        end

        renderStepped:Wait()

        if humanoid and humanoid:IsDescendantOf(workspace) then
            humanoid.CameraOffset = originalCamOffset
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = originalCF
        end
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            local lookVec = workspace.CurrentCamera.CFrame.LookVector
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
            if flatLook.Magnitude > 0.1 then
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatLook)
            end
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency ~= 1 then
                    part.Transparency = 1
                end
            end
        end
    end)
end

RunService.Stepped:Connect(function()
    if Settings.Enabled and LocalPlayer.Character then
        pcall(function()
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

local function DisableDoorsCollision()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local doors = map:FindFirstChild("Doors")
        if doors then
            for _, door in ipairs(doors:GetDescendants()) do
                pcall(function() if door:IsA("BasePart") then door.CanCollide = false end end)
            end
        end
        Log("Коллизия дверей отключена")
    end
end
DisableDoorsCollision()

local function RiseToTargetY()
    if HasReachedTargetY then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y < 4.7 and not IsRising then
        Log("Персонаж ниже 4.7, поднимаю по точкам до 4.8...")
        StatusText = "Подъём на 4.8"
        IsRising = true

        local startPos = hrp.Position
        local targetY = 4.8
        local startY = startPos.Y
        local deltaY = targetY - startY
        if deltaY <= 0 then
            IsRising = false
            StatusText = "Ожидание"
            return
        end

        local steps = math.max(3, math.floor(deltaY * 2))
        local waypoints = {}
        for i = 1, steps do
            local alpha = i / steps
            local y = startY + deltaY * alpha
            table.insert(waypoints, Vector3.new(startPos.X, y, startPos.Z))
        end

        for _, wp in ipairs(waypoints) do
            if not Settings.Enabled then break end
            local currentRot = hrp.CFrame - hrp.CFrame.Position
            local targetCF = CFrame.new(wp) * currentRot
            local dist = (wp - hrp.Position).Magnitude
            local duration = math.min(0.5, dist / 10)

            local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
        end

        hrp.CFrame = CFrame.new(startPos.X, targetY, startPos.Z) * (hrp.CFrame - hrp.CFrame.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        Log("Достиг 4.8, замираю на 3 секунды...")
        task.wait(3)
        Log("Замер завершён, продолжаю")

        IsRising = false
        HasReachedTargetY = true
        StatusText = "Ожидание"
    end
end

local PathVisualsFolder = Instance.new("Folder")
PathVisualsFolder.Name = "PathVisuals"
PathVisualsFolder.Parent = Workspace

local currentTargetHighlight = nil

local HIGHLIGHT_COLORS = {
    dealer = Color3.fromRGB(255, 40, 40),
    atm = Color3.fromRGB(40, 130, 255),
    target = Color3.fromRGB(40, 255, 90),
}

local function ClearPathVisuals()
    if currentTargetHighlight then
        pcall(function() currentTargetHighlight:Destroy() end)
        currentTargetHighlight = nil
    end
end

local function SetTargetHighlight(part, kind)
    ClearPathVisuals()
    if not part then return end

    local color = HIGHLIGHT_COLORS[kind] or HIGHLIGHT_COLORS.target
    local adornee = part.Parent and part.Parent:IsA("Model") and part.Parent or part

    local highlight = Instance.new("Highlight")
    highlight.Name = "FarmTargetHighlight"
    highlight.FillColor = color
    highlight.FillTransparency = 0.55
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.Adornee = adornee
    highlight.Parent = PathVisualsFolder

    currentTargetHighlight = highlight
end

local function VisualizePath(waypoints, startPos, destinationPart, kind)
    if destinationPart then
        SetTargetHighlight(destinationPart, kind)
    end
end

local function ComputePath(startPos, endPos)
    local pathParamsList = {
        { Radius = 1, Height = 4, Spacing = 2 },
        { Radius = 1.2, Height = 4.5, Spacing = 2.5 },
        { Radius = 1.5, Height = 5, Spacing = 3 },
        { Radius = 2, Height = 5.5, Spacing = 4 },
        { Radius = 2.5, Height = 6, Spacing = 5 },
        { Radius = 3, Height = 6.5, Spacing = 5 },
        { Radius = 3.5, Height = 7, Spacing = 6 },
        { Radius = 4, Height = 7.5, Spacing = 6 },
        { Radius = 1, Height = 8, Spacing = 3 },
        { Radius = 5, Height = 5, Spacing = 5 },
        { Radius = 1.8, Height = 4.2, Spacing = 2.2 },
        { Radius = 2.2, Height = 5.8, Spacing = 4.5 },
        { Radius = 2.8, Height = 6.2, Spacing = 5.5 },
        { Radius = 3.2, Height = 6.8, Spacing = 5.8 },
        { Radius = 3.8, Height = 7.2, Spacing = 6.2 }
    }
    for _, params in ipairs(pathParamsList) do
        local pathParams = {
            AgentRadius = params.Radius,
            AgentHeight = params.Height,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = params.Spacing,
            CostCalibration = true
        }
        local path = PathfindingService:CreatePath(pathParams)
        local success, _ = pcall(function() path:ComputeAsync(startPos, endPos) end)
        if success and path.Status == Enum.PathStatus.Success then
            local rawWaypoints = path:GetWaypoints()
            if not rawWaypoints or #rawWaypoints < 2 then return rawWaypoints end
            local refinedWaypoints = {}
            local spacing = Settings.WaypointSpacing
            table.insert(refinedWaypoints, rawWaypoints[1])
            for i = 2, #rawWaypoints do
                local prev = rawWaypoints[i - 1].Position
                local curr = rawWaypoints[i].Position
                local dist = (curr - prev).Magnitude
                if dist <= spacing then
                    table.insert(refinedWaypoints, rawWaypoints[i])
                else
                    local steps = math.ceil(dist / spacing)
                    for j = 1, steps do
                        local alpha = j / steps
                        local pos = prev:Lerp(curr, alpha)
                        local action = (j == steps and rawWaypoints[i].Action) or Enum.PathWaypointAction.Walk
                        table.insert(refinedWaypoints, { Position = pos, Action = action })
                    end
                end
            end
            return refinedWaypoints
        end
        task.wait(0.05)
    end
    return nil
end

local function GetPositionInFrontOfTarget(targetPart, fromPos)
    if not targetPart then return nil end
    local success, cf = pcall(function() return targetPart.CFrame end)
    if not success then return nil end
    local lookVec = cf.LookVector
    lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
    if lookVec.Magnitude < 0.1 then
        lookVec = (fromPos - cf.Position).Unit
        lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
        if lookVec.Magnitude < 0.1 then lookVec = Vector3.new(1, 0, 0) end
    end
    return cf.Position + lookVec * 4
end

local function GetFootPosition()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position - Vector3.new(0, 2.5, 0)
end

local function MoveToTarget(targetPart, targetObj, kind)
    RiseToTargetY()
    local character = LocalPlayer.Character
    if not character then
        Log("Нет персонажа")
        return false
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        Log("Нет HRP или Humanoid")
        return false
    end
    if not targetPart or not targetPart:IsA("BasePart") then
        Log("Неверная цель")
        return false
    end

    local function isTargetBroken()
        if not targetObj or not targetObj.Parent then
            return false
        end
        local values = targetObj:FindFirstChild("Values")
        local broken = values and values:FindFirstChild("Broken")
        return broken and broken.Value == true
    end

    if isTargetBroken() then
        Log("Цель уже сломана, меняю таргет")
        return false, "target_broken"
    end

    CurrentTargetPart = targetPart
    IsMovingToTarget = true
    SomeFlag2 = false
    StatusText = "Путь к цели"
    local startPos = hrp.Position
    local targetFrontPos = GetPositionInFrontOfTarget(targetPart, startPos)
    if not targetFrontPos then
        Log("Не удалось вычислить позицию перед объектом")
        IsMovingToTarget = false
        StatusText = "Ожидание"
        return false
    end
    local endPos = targetFrontPos
    Log("Поиск пути к цели, расстояние " .. math.floor((endPos - startPos).Magnitude))
    local path = ComputePath(startPos, endPos)
    if not path then
        Log("Путь не найден, временно игнорирую цель")
        IsMovingToTarget = false
        StatusText = "Ожидание"
        return false
    end
    Log("Путь найден, точек: " .. #path)
    VisualizePath(path, startPos, targetPart, kind)
    for _, waypoint in ipairs(path) do
        if not Settings.Enabled then
            ClearPathVisuals()
            IsMovingToTarget = false
            StatusText = "Ожидание"
            return false
        end
        if isTargetBroken() then
            Log("Цель сломана во время пути, меняю таргет")
            ClearPathVisuals()
            IsMovingToTarget = false
            StatusText = "Ожидание"
            return false, "target_broken"
        end
        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetPos = waypoint.Position
        local targetHRP = targetPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCF = CFrame.new(targetHRP) * currentRot
        local dist = (targetHRP - hrp.Position).Magnitude
        if dist > 0.2 then
            local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
            LastTick = tick()
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
            task.wait(0.1)
        end
    end
    if isTargetBroken() then
        Log("Цель сломана по приходу, меняю таргет")
        ClearPathVisuals()
        IsMovingToTarget = false
        StatusText = "Ожидание"
        return false, "target_broken"
    end
    ClearPathVisuals()
    local finalPos = endPos
    local finalHRP = finalPos + Vector3.new(0, 2.5, 0)
    hrp.CFrame = CFrame.new(finalHRP) * CFrame.Angles(0, math.rad(90), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    Log("Цель достигнута")
    IsMovingToTarget = false
    StatusText = "Ожидание"
    return true
end

local function HasTool(toolName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    return (backpack and backpack:FindFirstChild(toolName)) or (character and character:FindFirstChild(toolName))
end

-- ==================== Буферные зоны ====================
-- Некоторые сейфы/регистры физически находятся в отдельных "карманах" карты
-- (метро, подземелья и т.п.), куда обычный путь до конкретной цели не
-- строится напрямую. Для них задаём 2 точки: сначала обычным умным путём
-- идём до вейпоинта 1 (вход в зону), затем телепорт на вейпоинт 2 (уже
-- внутри зоны), и уже оттуда обычным умным путём идём до реальной цели.
-- Зона матчится по отдельному слову-токену в имени цели (например "HO" в
-- "Medium Safe HO 39" / "Register HO 23").
-- Пожизненный бан - жёстко в коде, GUI на это не влияет вообще.
local PERMANENT_SKIP_LIST = {
    ["SmallSafe_HO_37"] = true,
    ["MediumSafe_HO_24"] = true,
    ["MediumSafe_SEW_2"] = true,
    ["MediumSafe_SEW_8"] = true,
    ["MediumSafe_VC_21"] = true,
    ["MediumSafe_VC_30"] = true,
    ["MediumSafe_VC_38"] = true,
}

-- Опциональный список - управляется через вкладку Skip List в GUI.
local SkipList = {}

local function isTargetSkipped(targetName)
    local name = tostring(targetName)
    return PERMANENT_SKIP_LIST[name] == true or SkipList[name] == true
end

local BufferZones = {
    {
        name = "Burmalda",
        -- Точные имена объектов, которые реально физически относятся к этой
        -- буферной зоне (достижимы через её 2 вейпоинта). НЕ общий токен -
        -- иначе матчатся любые сейфы/регистры с "HO" в имени по всей карте,
        -- даже если они находятся совсем в другом месте.
        names = {
            ["MediumSafe_HO_39"] = true,
            ["Register_HO_23"] = true,
        },
        waypoint1 = Vector3.new(-4447.46, 3.90, -56.37),
        waypoint2 = Vector3.new(-4442.79, 25.48, -57.33),
        radius = 10,
    },
    {
        name = "TSSSS",
        names = {
            ["Register_TS_27"] = true,
            ["Register_TS_4"] = true,
            ["MediumSafe_TS_20"] = true,
        },
        waypoint1 = Vector3.new(-4602.95, 3.80, -152.89),
        waypoint2 = Vector3.new(-4607.30, 4.00, -152.00),
        radius = 20,
    },
    {
        name = "TOWER",
        names = {
            ["MediumSafe_T_45"] = true,
            ["MediumSafe_T_46"] = true,
        },
        waypoint1 = Vector3.new(-4520.39, 126.55, -774.80),
        waypoint2 = Vector3.new(-4523.65, 149.35, -775.08),
        radius = 20,
    },
}

local function getBufferZoneForTarget(targetName)
    local name = tostring(targetName or "")
    for _, zone in ipairs(BufferZones) do
        if zone.names[name] then
            return zone
        end
    end
    return nil
end

-- Путь до "голой" точки в пространстве (без концепции "цели с интерактом
-- спереди", в отличие от MoveToTarget) - используется для похода к вейпоинтам.
local function WalkToPosition(destination)
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return false end

    local startPos = hrp.Position
    local path = ComputePath(startPos, destination)
    if not path then return false end

    for _, waypoint in ipairs(path) do
        if not Settings.Enabled then return false end
        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetPos = waypoint.Position
        local targetHRP = targetPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCF = CFrame.new(targetHRP) * currentRot
        local dist = (targetHRP - hrp.Position).Magnitude
        if dist > 0.2 then
            local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
            LastTick = tick()
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
            task.wait(0.1)
        end
    end
    return true
end

local function TeleportToPosition(position)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(position) * (hrp.CFrame - hrp.CFrame.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Обёртка над MoveToTarget: если цель принадлежит буферной зоне, сначала
-- проходит через её вейпоинты, иначе - обычное поведение MoveToTarget.
local function MoveToTargetSmart(targetPart, targetObj, kind)
    local zone = getBufferZoneForTarget(targetObj and targetObj.Name)
    if not zone or not targetPart then
        return MoveToTarget(targetPart, targetObj, kind)
    end

    local function isTargetAlreadyBroken()
        if not targetObj or not targetObj.Parent then return false end
        local values = targetObj:FindFirstChild("Values")
        local broken = values and values:FindFirstChild("Broken")
        return broken and broken.Value == true
    end

    if isTargetAlreadyBroken() then
        Log("Цель зоны " .. zone.name .. " уже сломана, не иду в зону")
        return false, "target_broken"
    end

    -- Если персонаж уже физически рядом с САМОЙ целью (а не обязательно с
    -- вейпоинтом 2 - в большой зоне цель может стоять далеко от входной
    -- точки, но близко к предыдущей обработанной цели) - не повторяем путь
    -- через вейпоинты, идём напрямую. Радиус свой у каждой зоны.
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local zoneRadius = zone.radius or 10

    if hrp and (hrp.Position - targetPart.Position).Magnitude <= zoneRadius then
        Log("Уже рядом с целью в зоне " .. zone.name .. " (радиус " .. zoneRadius .. "), иду напрямую без вейпоинтов")
        SetTargetHighlight(targetPart, kind)
        return MoveToTarget(targetPart, targetObj, kind)
    end

    SetTargetHighlight(targetPart, kind)
    Log("Буферная зона " .. zone.name .. ": иду к вейпоинту 1, цель - " .. tostring(targetObj and targetObj.Name))
    StatusText = "Буферная зона: вейпоинт 1"
    local reachedWp1 = WalkToPosition(zone.waypoint1)
    if not reachedWp1 then
        Log("Не удалось дойти до вейпоинта 1 зоны " .. zone.name)
        ClearPathVisuals()
        StatusText = "Ожидание"
        return false, "buffer_zone_wp1_failed"
    end

    if isTargetAlreadyBroken() then
        Log("Цель зоны " .. zone.name .. " сломана уже по пути к вейпоинту 1")
        ClearPathVisuals()
        StatusText = "Ожидание"
        return false, "target_broken"
    end

    Log("Телепорт на вейпоинт 2 зоны " .. zone.name)
    TeleportToPosition(zone.waypoint2)
    task.wait(0.2)

    if isTargetAlreadyBroken() then
        Log("Цель зоны " .. zone.name .. " сломана уже после телепорта на вейпоинт 2")
        ClearPathVisuals()
        StatusText = "Ожидание"
        return false, "target_broken"
    end

    Log("От вейпоинта 2 иду к реальной цели (" .. tostring(targetObj and targetObj.Name) .. ")")
    return MoveToTarget(targetPart, targetObj, kind)
end

local function EquipTool(toolName)
    local tool = LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(toolName)
    if tool and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        pcall(function() LocalPlayer.Character.Humanoid:EquipTool(tool) end)
        task.wait(1)
        return true
    end
    return false
end

local function CountTools(toolName)
    local count = 0
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == toolName then count = count + 1 end
        end
    end
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item.Name == toolName then count = count + 1 end
        end
    end
    return count
end

local function getShopMainPart(name)
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function findCrowbarDealer()
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    if not shopz then return nil end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestShop, closestDist = nil, math.huge
    for _, shop in ipairs(shopz:GetChildren()) do
        local stocks = shop:FindFirstChild("CurrentStocks")
        local hasCrowbar = true
        if stocks then
            local crowbarStock = stocks:FindFirstChild("Crowbar")
            hasCrowbar = (not crowbarStock) or crowbarStock.Value > 0
        end
        if hasCrowbar then
            local mainPart = shop:FindFirstChild("MainPart")
            if mainPart then
                local dist = (hrp.Position - mainPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestShop = shop
                end
            end
        end
    end
    return closestShop and closestShop:FindFirstChild("MainPart") or nil
end

local function BuyCrowbar()
    local existing = CountTools("Crowbar") > 0
    if existing then
        EquipTool("Crowbar")
        return true
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = findCrowbarDealer() or getShopMainPart("Dealer")
    local protectionRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")

    if not dealerPart or not protectionRemote or not purchaseRemote then
        return false
    end

    local moved = MoveToTarget(dealerPart, nil, "dealer")
    if not moved then return false end

    task.wait(1.5)
    pcall(protectionRemote.FireServer, protectionRemote, true, "shop", dealerPart, "IllegalStore")
    task.wait(1.0)
    pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    task.wait(1.0)
    pcall(protectionRemote.FireServer, protectionRemote, false)
    task.wait(2.0)

    if CountTools("Crowbar") > 0 then
        EquipTool("Crowbar")
        return true
    end
    return false
end

local function FindLockpickDealer()
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    if not shopz then
        Log("Магазины не найдены")
        return nil
    end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestDealer, closestDist = nil, math.huge
    for _, shop in ipairs(shopz:GetChildren()) do
        local stocks = shop:FindFirstChild("CurrentStocks")
        local hasLockpick = true
        if stocks then
            local lockpickStock = stocks:FindFirstChild("Lockpick")
            hasLockpick = (not lockpickStock) or lockpickStock.Value > 0
        end
        if hasLockpick then
            local mainPart = shop:FindFirstChild("MainPart")
            if mainPart then
                local dist = (hrp.Position - mainPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestDealer = shop
                end
            end
        end
    end
    return closestDealer
end

local function PurchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not shopPart or not events then return false end
    local purchaseRemote = events:FindFirstChild("SSHPRMTE1")
    if not purchaseRemote then return false end

    local illegalOk, illegalAccepted, illegalMessage = pcall(function()
        return purchaseRemote:InvokeServer("IllegalStore", "Misc", "Lockpick", shopPart, nil, true, nil)
    end)
    task.wait(0.25)
    local legalOk, legalAccepted, legalMessage = pcall(function()
        return purchaseRemote:InvokeServer("LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    end)

    return (illegalOk and (illegalAccepted == true or illegalMessage == "PURCHASE COMPLETE"))
        or (legalOk and (legalAccepted == true or legalMessage == "PURCHASE COMPLETE"))
end

local function BuyLockpickBatch()
    local dealer = FindLockpickDealer()
    if not dealer then return false end
    local mainPart = dealer:FindFirstChild("MainPart")
    if not mainPart then
        Log("У дилера нет MainPart")
        return false
    end

    StatusText = "Путь к дилеру за лок-пиком"
    Log("Иду к дилеру за лок-пиком")

    local moveSuccess = MoveToTarget(mainPart, nil, "dealer")
    if not moveSuccess then
        Log("Путь к дилеру не найден, временно пропускаю")
        StatusText = "Ожидание"
        return false
    end

    StatusText = "Покупка лок-пика"
    task.wait(1)

    local startingCount = CountTools("Lockpick")
    local successfulPurchases = 0
    local consecutiveFailures = 0
    local stocks = dealer:FindFirstChild("CurrentStocks")
    local lockpickStock = stocks and stocks:FindFirstChild("Lockpick")

    Log("Скупаю весь сток лок-пиков у дилера" .. (lockpickStock and (" (" .. lockpickStock.Value .. " шт.)") or ""))

    while Settings.Enabled do
        if lockpickStock and lockpickStock.Value <= 0 then
            Log("Сток лок-пиков у дилера закончился")
            break
        end
        if PurchaseLockpickAt(mainPart) then
            successfulPurchases = successfulPurchases + 1
            consecutiveFailures = 0
        else
            consecutiveFailures = consecutiveFailures + 1
            if consecutiveFailures >= 5 then
                Log("5 неудачных покупок подряд, останавливаюсь")
                break
            end
        end
        task.wait(0.20)
    end

    task.wait(0.75)
    StatusText = "Ожидание"

    local bought = CountTools("Lockpick") > startingCount or successfulPurchases > 0
    if bought then
        Log("Лок-пики куплены (" .. successfulPurchases .. " шт.)")
    else
        Log("Не удалось купить лок-пики")
    end
    return bought
end

-- GUI минигры лок-пика: LockpickGUI.MF.LP_Frame.Frames.{B1,B2,B3}.Bar.UIScale
-- (масштаб зон попадания) и MF.LP_Frame.Line (бегущая полоска). Постоянный
-- вотчер увеличивает зоны сразу как только GUI появляется, откуда бы он ни
-- взялся - портировано из v16 один в один.
local function ApplyLockpickGUI()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local lockpickGui = playerGui:FindFirstChild("LockpickGUI")
    if not lockpickGui then return end
    local mf = lockpickGui:FindFirstChild("MF")
    if not mf then return end
    local lpFrame = mf:FindFirstChild("LP_Frame")
    if not lpFrame then return end
    local frames = lpFrame:FindFirstChild("Frames")
    if not frames then return end

    for _, bName in ipairs({"B1", "B2", "B3"}) do
        local b = frames:FindFirstChild(bName)
        if b and b:FindFirstChild("Bar") and b.Bar:FindFirstChild("UIScale") then
            b.Bar.UIScale.Scale = 20
        end
    end
end

local LockpickGuiConnection = nil
local function StartLockpickGUIWatcher()
    if LockpickGuiConnection then return end
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    LockpickGuiConnection = playerGui.ChildAdded:Connect(function(child)
        if child.Name == "LockpickGUI" then
            task.wait(0.05)
            ApplyLockpickGUI()
        end
    end)
    if playerGui:FindFirstChild("LockpickGUI") then
        ApplyLockpickGUI()
    end
end
StartLockpickGUIWatcher()

-- Фиксация камеры на сейф во время взлома - комбо с расширением GUI (x20):
-- камера постоянно смотрит на цель, курсор постоянно наведён на её
-- экранную точку, независимо от того, куда игрок пытается повернуть.
local LockpickCameraConnection = nil
local LockpickCameraPreviousType = nil

local function StartLockpickCameraLock(part)
    local camera = Workspace.CurrentCamera
    if not camera or not part then return end

    if not LockpickCameraConnection then
        LockpickCameraPreviousType = camera.CameraType
    end
    camera.CameraType = Enum.CameraType.Scriptable

    if LockpickCameraConnection then
        LockpickCameraConnection:Disconnect()
    end

    LockpickCameraConnection = RunService.RenderStepped:Connect(function()
        if not part.Parent then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local toTarget = part.Position - hrp.Position
        local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
        if flatDir.Magnitude < 0.01 then
            flatDir = Vector3.new(0, 0, 1)
        end
        flatDir = flatDir.Unit

        local camPos = hrp.Position - flatDir * 10 + Vector3.new(0, 4, 0)
        cam.CFrame = CFrame.new(camPos, part.Position)

        local screenPos, onScreen = cam:WorldToScreenPoint(part.Position)
        if onScreen then
            pcall(VirtualInputManager.SendMouseMoveEvent, VirtualInputManager, screenPos.X, screenPos.Y, game)
        end
    end)
end

local function StopLockpickCameraLock()
    if LockpickCameraConnection then
        LockpickCameraConnection:Disconnect()
        LockpickCameraConnection = nil
    end
    local camera = Workspace.CurrentCamera
    if camera and LockpickCameraPreviousType then
        camera.CameraType = LockpickCameraPreviousType
    end
    LockpickCameraPreviousType = nil
end

local function HackSafeWithLockpick(safeObj)
    if CountTools("Lockpick") == 0 then
        if not BuyLockpickBatch() then return false end
    end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Lockpick")) then
        EquipTool("Lockpick")
        task.wait(1)
    end

    local aimPart = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if aimPart then
        StartLockpickCameraLock(aimPart)
    end

    local function openMinigame()
        local posPart = safeObj:FindFirstChild("PosPart") or safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if not posPart then return false end
        local cam = Workspace.CurrentCamera
        local screenPos, onScreen = cam:WorldToScreenPoint(posPart.Position)
        if not onScreen then return false end
        VirtualInputManager:SendMouseMoveEvent(screenPos.X, screenPos.Y, game)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1)
        return true
    end

    Log("Начинаю взлом лок-пиком")
    StatusText = "Взлом лок-пиком"
    local startTime = tick()
    local rejectedLockpicks = {}

    local function pickLockpickExcluding()
        local character = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")

        local equipped = character and character:FindFirstChild("Lockpick")
        if equipped and not rejectedLockpicks[equipped] then
            return equipped, equipped:FindFirstChild("Uses"), equipped:FindFirstChild("Remote")
        end

        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item.Name == "Lockpick" and not rejectedLockpicks[item] then
                    EquipTool("Lockpick")
                    task.wait(0.5)
                    local fresh = character and character:FindFirstChild("Lockpick")
                    return fresh, fresh and fresh:FindFirstChild("Uses"), fresh and fresh:FindFirstChild("Remote")
                end
            end
        end

        return nil, nil, nil
    end

    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Сейф уже взломан")
            break
        end
        if tick() - startTime > 60 then
            Log("Таймаут взлома лок-пиком (60 сек), меняю таргет")
            break
        end

        local lp, usesVal, remote = pickLockpickExcluding()
        if not lp or not remote then
            if not BuyLockpickBatch() then break end
            rejectedLockpicks = {}
            EquipTool("Lockpick")
            task.wait(1)
            lp, usesVal, remote = pickLockpickExcluding()
            if not lp or not remote then break end
        end

        local opened = openMinigame()
        if not opened then
            task.wait(0.3)
            continue
        end

        -- Ждём появления LockpickGUI И реальных "кубиков" (баров B1/B2/B3) -
        -- само появление LockpickGUI не значит что минигра реально
        -- запустилась, кубики - надёжный признак. Если за 2 сек их нет -
        -- переключаемся на другой лок-пик из инвентаря, этот помечаем
        -- пропущенным (не удаляем, просто не берём его следующим).
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local lockpickGui, frames = nil, nil
        local waited = 0
        repeat
            lockpickGui = pg and pg:FindFirstChild("LockpickGUI")
            local mf = lockpickGui and lockpickGui:FindFirstChild("MF")
            local lpFrame = mf and mf:FindFirstChild("LP_Frame")
            frames = lpFrame and lpFrame:FindFirstChild("Frames")
            local cubesExist = frames
                and frames:FindFirstChild("B1")
                and frames.B1:FindFirstChild("Bar")

            if not cubesExist then
                task.wait(0.1)
                waited = waited + 0.1
            end
        until (frames and frames:FindFirstChild("B1") and frames.B1:FindFirstChild("Bar")) or waited >= 2

        if not frames or not frames:FindFirstChild("B1") or not frames.B1:FindFirstChild("Bar") then
            Log("Минигра не началась за 2 сек (кубики не появились), меняю лок-пик")
            rejectedLockpicks[lp] = true
            task.wait(0.2)
            continue
        end

        if lockpickGui then
            local mf = lockpickGui:FindFirstChild("MF")
            local lpFrame = mf and mf:FindFirstChild("LP_Frame")
            local line = lpFrame and lpFrame:FindFirstChild("Line")

            if frames then
                for _, bName in ipairs({"B1", "B2", "B3"}) do
                    local b = frames:FindFirstChild(bName)
                    local bar = b and b:FindFirstChild("Bar")
                    local uiScale = bar and bar:FindFirstChild("UIScale")
                    if uiScale then uiScale.Scale = 20 end
                end
            end

            if line and frames then
                local prevUses = usesVal and usesVal.Value or 0
                local autoStart = tick()
                while Settings.Enabled and tick() - autoStart < 10 do
                    if not lockpickGui or not lockpickGui.Parent then break end
                    if not line or not line.Parent then break end
                    if not frames or not frames.Parent then break end

                    pcall(function()
                        for _, bName in ipairs({"B1", "B2", "B3"}) do
                            local b = frames:FindFirstChild(bName)
                            local bar = b and b:FindFirstChild("Bar")
                            local uiScale = bar and bar:FindFirstChild("UIScale")
                            if uiScale then uiScale.Scale = 20 end
                        end
                    end)

                    local inZone = false
                    pcall(function()
                        local lineX = line.AbsolutePosition.X + line.AbsoluteSize.X / 2
                        for _, bName in ipairs({"B1", "B2", "B3"}) do
                            if inZone then break end
                            local b = frames:FindFirstChild(bName)
                            local bar = b and b:FindFirstChild("Bar")
                            if bar and bar.Parent then
                                local barLeft = bar.AbsolutePosition.X
                                local barRight = barLeft + bar.AbsoluteSize.X
                                if lineX >= barLeft and lineX <= barRight then
                                    inZone = true
                                end
                            end
                        end
                    end)

                    if inZone then
                        -- Спамим клики, пока линия в зоне, вместо одного клика -
                        -- повышает шанс реально засчитать попадание.
                        for _ = 1, 4 do
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            task.wait(0.02)
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            task.wait(0.02)
                        end
                    end

                    pcall(function()
                        local newUses = usesVal and usesVal.Value or 0
                        if newUses > prevUses then
                            prevUses = newUses
                            StatusText = "Lockpick: " .. newUses .. "/" .. (usesVal and usesVal.MaxValue or 3)
                        end
                    end)

                    task.wait(0.008)
                end
            end
        end

        task.wait(0.1)
        LastTick = tick()
    end

    -- Явно ждём подтверждения Broken ещё немного перед финальной проверкой -
    -- сервер может выставить флаг с небольшой задержкой после того, как
    -- минигра визуально завершилась.
    do
        local confirmStart = tick()
        while safeObj and safeObj.Parent and tick() - confirmStart < 3 do
            local values = safeObj:FindFirstChild("Values")
            local broken = values and values:FindFirstChild("Broken")
            if broken and broken.Value then break end
            task.wait(0.1)
        end
    end

    StopLockpickCameraLock()
    StatusText = "Ожидание"
    local finalValues = safeObj and safeObj.Parent and safeObj:FindFirstChild("Values")
    local finalBroken = finalValues and finalValues:FindFirstChild("Broken")
    local ok = finalBroken and finalBroken.Value == true

    if not ok then
        Log("Сейф так и не открылся лок-пиком, меняю таргет")
    end

    return ok
end


local function HackWithFists(safeObj)
    local fistsInBackpack = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Fists")
    if fistsInBackpack then
        EquipTool("Fists")
        task.wait(0.5)
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    local remote1 = events:FindFirstChild("XMHH.2")
    local remote2 = events:FindFirstChild("XMHH2.2")
    local mainPart = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if not remote1 or not remote2 or not mainPart then return false end

    Log("Открываю кассу кулаками")
    StatusText = "Взлом кассы (кулаки)"
    local startTime = tick()
    local hits = 0

    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Касса уже взломана")
            break
        end
        if tick() - startTime > 8 then
            Log("Таймаут взлома кулаками")
            break
        end
        task.wait(0.25)

        local char = LocalPlayer.Character
        if not char then break end
        local fists = char:FindFirstChild("Fists")
        if not fists then
            local bp = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Fists")
            if bp then
                EquipTool("Fists")
                task.wait(0.3)
                fists = char:FindFirstChild("Fists")
            end
        end

        local arm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        if not arm then break end

        local ok, result = pcall(function()
            return remote1:InvokeServer("🍞", tick(), fists, "DZDRRRKI", safeObj, "Register")
        end)
        if ok and result then
            pcall(function()
                remote2:FireServer("🍞", tick(), fists, "2389ZFX34", result, false, arm, mainPart, safeObj, mainPart.Position, mainPart.Position)
            end)
            hits = hits + 1
        end
        LastTick = tick()
    end

    task.wait(0.3)
    Log("Касса обработана кулаками, ударов: " .. hits)
    StatusText = "Ожидание"
    return true
end

local function parseCashTextToNumber(value)
    if type(value) == "number" then
        return value
    end
    local text = tostring(value or "")
    text = text:gsub(",", "")
    text = text:gsub("%$", "")
    text = text:gsub("%s+", "")
    local number = tonumber(text:match("%-?%d+%.?%d*"))
    return number or 0
end

-- Кэш найденных объектов, чтобы не гонять GetDescendants() по всему PlayerGui
-- на каждой итерации основного цикла (это дорого, особенно на мобиле).
local statLabelCache = {}

local function findStatValueNearLabel(keyword)
    keyword = tostring(keyword):lower()

    local cached = statLabelCache[keyword]
    if cached and cached.Parent then
        local ok, text = pcall(function() return cached.Text end)
        if ok and tostring(text):match("%d") then
            return tostring(text)
        end
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = tostring(obj.Text or ""):lower()
            local name = tostring(obj.Name or ""):lower()
            if text == keyword or name == keyword or name:find(keyword, 1, true) then
                local parent = obj.Parent
                if parent then
                    for _, sibling in ipairs(parent:GetChildren()) do
                        if sibling ~= obj and (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) then
                            local sText = tostring(sibling.Text or "")
                            if sText:match("%d") then
                                statLabelCache[keyword] = sibling
                                return sText
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function readCashAmountValue()
    local text = findStatValueNearLabel("cash")
    if text then
        StatsInfo.CashAmount = parseCashTextToNumber(text)
    end
    return StatsInfo.CashAmount
end

local function readStatsGui()
    local bankText = findStatValueNearLabel("bank")
    if bankText then
        StatsInfo.BankAmount = parseCashTextToNumber(bankText)
    end

    -- Allowance в этой игре - таймер обратного отсчёта ("12:32"), а не сумма
    -- денег, поэтому храним и сырой текст, и числовое приближение отдельно.
    local allowanceText = findStatValueNearLabel("allowance")
    if allowanceText then
        StatsInfo.AllowanceText = allowanceText
        local minutes, seconds = allowanceText:match("(%d+):(%d+)")
        if minutes and seconds then
            StatsInfo.AllowanceSecondsLeft = tonumber(minutes) * 60 + tonumber(seconds)
        else
            StatsInfo.AllowanceAmount = parseCashTextToNumber(allowanceText)
        end
    end
end

local function findATMMainPart()
    local map = Workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    if not atmz then return nil end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closestPart, closestDist = nil, math.huge
    for _, atm in ipairs(atmz:GetChildren()) do
        local mainPart = atm:FindFirstChild("MainPart")
        if mainPart and mainPart:IsA("BasePart") then
            local dist = (hrp.Position - mainPart.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPart = mainPart
            end
        end
    end
    return closestPart
end

local function performDepositRequest(events, cash)
    local remote = events and events:FindFirstChild("ATM")
    local atmMainPart = findATMMainPart()
    if not remote or not remote:IsA("RemoteFunction") or not atmMainPart then
        Log("Депозит: не найден ремоут или ближайший АТМ")
        return false
    end
    local moved, moveReason = MoveToTarget(atmMainPart, nil, "atm")
    if not moved then
        Log("Депозит: не дошёл до АТМ (" .. tostring(moveReason) .. ")")
        return false
    end
    local ok, accepted = pcall(remote.InvokeServer, remote, "DP", cash, atmMainPart)
    Log("Депозит: InvokeServer ok=" .. tostring(ok) .. " accepted=" .. tostring(accepted))
    return ok and accepted == true
end

local function tryDeposit()
    if not Settings.AutoDeposit then return false end
    if StatsInfo.DepositInProgress then return true end

    local currentTime = tick()
    if currentTime < StatsInfo.DepositCooldownUntil then return false end
    if currentTime - StatsInfo.DepositLastAttemptAt < 1.5 then return false end

    local cash = readCashAmountValue()
    local threshold = Settings.AutoDepositThreshold or 5000
    if threshold <= 0 or cash < threshold then return false end

    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end

    StatsInfo.DepositLastAttemptAt = tick()
    StatsInfo.DepositInProgress = true
    Log("Автодепозит: несу $" .. math.floor(cash) .. " в банк")
    StatusText = "Депозит в банк"

    local ok, success = pcall(function()
        local result = performDepositRequest(events, cash)
        task.wait(0.2)
        return result and readCashAmountValue() <= 0
    end)

    StatsInfo.DepositInProgress = false
    StatsInfo.DepositCooldownUntil = tick() + 2.5
    StatusText = "Ожидание"

    if ok and success then
        Log("Автодепозит выполнен")
    end

    return ok and success == true
end

local function maybeAutoDeposit()
    if not Settings.AutoDeposit then return false end
    return tryDeposit()
end

local function claimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()
    if not remote or not atm then
        return false, "allowance_unavailable"
    end

    local moved, moveReason = MoveToTarget(atm, nil, "atm")
    if not moved then
        Log("Аллованс: не дошёл до АТМ (" .. tostring(moveReason) .. ")")
        return false, "atm_unreachable"
    end

    local ok, accepted, message, blocked, amount = pcall(remote.InvokeServer, remote, atm)
    Log("Аллованс: InvokeServer ok=" .. tostring(ok) .. " accepted=" .. tostring(accepted))
    if not ok then return false, accepted end
    if type(amount) == "number" then
        StatsInfo.AllowanceAmount = amount
    end
    return accepted == true, message, blocked, amount
end

local function CleanupTempIgnored()
    local now = tick()
    for obj, expiry in pairs(Settings.TempIgnored) do
        if now > expiry then
            Settings.TempIgnored[obj] = nil
            for i, v in ipairs(Settings.IgnoredList) do
                if v == obj then
                    table.remove(Settings.IgnoredList, i)
                    break
                end
            end
            Log("Игнорируемый объект разблокирован")
        end
    end
end

local function UpdateTargetsList()
    CleanupTempIgnored()
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then
        bredFolder = map:FindFirstChild("BredMakurz")
    end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then
            bredFolder = filter:FindFirstChild("BredMakurz")
        end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if not bredFolder then
        Log("Папка BredMakurz не найдена")
        return 0, 0
    end
    local character = LocalPlayer.Character
    if not character then return 0, 0 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, 0 end
    local safes = {}
    local registers = {}
    TotalSafesCount = 0
    TotalRegistersCount = 0
    SortedTargets = {}
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            if nameLower:find("safe") then
                TotalSafesCount = TotalSafesCount + 1
            else
                TotalRegistersCount = TotalRegistersCount + 1
            end
            if isTargetSkipped(obj.Name) then continue end
            if Settings.ProcessedList[obj] then continue end
            if Settings.TempIgnored[obj] then continue end
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and not broken.Value then
                    local mainPart = obj:FindFirstChild("MainPart") or obj.PrimaryPart
                    local isSubwayZone = nameLower:find("%f[%a]sw%f[%A]") ~= nil
                    local isBufferZoneTarget = getBufferZoneForTarget(obj.Name) ~= nil
                    if mainPart and (mainPart.Position.Y >= 4.8 or isSubwayZone or isBufferZoneTarget) then
                        local targetInfo = { obj = obj, part = mainPart, pos = mainPart.Position }
                        if nameLower:find("safe") then
                            table.insert(safes, targetInfo)
                        else
                            table.insert(registers, targetInfo)
                        end
                        table.insert(SortedTargets, targetInfo)
                    end
                end
            end
        end
    end
    AvailableSafes = safes
    AvailableRegisters = registers
    table.sort(SortedTargets, function(a, b)
        return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude
    end)
    AvailableSafesCount = #safes
    AvailableRegistersCount = #registers
    return AvailableSafesCount + AvailableRegistersCount, TotalSafesCount + TotalRegistersCount
end

local function AnalyzeTargetsCount()
    local available, total = UpdateTargetsList()
    TotalAvailableTargets = available
    Log("Всего доступно: " .. available .. "/" .. total .. " целей")
    if available < 20 then
        SuggestionText = "Мало целей (" .. available .. "), много конкурентов. Смени сервер."
        Log("⚠️ " .. SuggestionText)
        pcall(function()
            HttpService:SetCore("SendNotification", {
                Title = "Рекомендация",
                Text = SuggestionText,
                Duration = 10
            })
        end)
    else
        SuggestionText = "Достаточно целей (" .. available .. "), можно фармить."
    end
end
AnalyzeTargetsCount()

local function FindMoneyNearTarget(targetObj)
    local mainPart = targetObj:FindFirstChild("MainPart") or targetObj.PrimaryPart
    if not mainPart then return {} end
    local spawnedBread = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
    if not spawnedBread then return {} end
    local moneyParts = {}
    for _, bread in ipairs(spawnedBread:GetChildren()) do
        pcall(function()
            if bread:IsA("Part") and bread.Transparency < 1 then
                if (bread.Position - mainPart.Position).Magnitude <= 25 then
                    table.insert(moneyParts, bread)
                end
            end
        end)
    end
    return moneyParts
end

local function CollectMoneyNearTarget(targetObj)
    local moneyParts = FindMoneyNearTarget(targetObj)
    if #moneyParts == 0 then return false end
    Log("Собираю " .. #moneyParts .. " пачек денег возле сейфа")
    StatusText = "Сбор денег"
    for _, money in ipairs(moneyParts) do
        if not Settings.Enabled then break end
        pcall(function()
            if money and money.Parent and money.Transparency < 1 then
                MoveToTarget(money)
                local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
                if pickupEvent then
                    pcall(function() pickupEvent:FireServer(money) end)
                end
                task.wait(0.3)
            end
        end)
    end
    StatusText = "Ожидание"
    return #FindMoneyNearTarget(targetObj) > 0
end

local function HackSafe(safeObj)
    if not HasTool("Crowbar") then
        Log("Нет лома для открытия сейфа, пробую купить...")
        local bought = BuyCrowbar()
        if not bought then
            Log("Не удалось купить лом, пропускаю сейф")
            return false
        end
        Log("Лом куплен, возвращаюсь к сейфу")
        local mainPartForReturn = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if mainPartForReturn then
            MoveToTargetSmart(mainPartForReturn, safeObj, "target")
        end
    end
    if not LocalPlayer.Character:FindFirstChild("Crowbar") then
        Log("Лом в рюкзаке, экипирую...")
        EquipTool("Crowbar")
        task.wait(1)
    end
    if not HasTool("Crowbar") then
        Log("Лом так и не появился, пропускаю")
        return false
    end
    task.wait(1.5)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        Log("Папка Events не найдена")
        return false
    end
    local remote1 = events:FindFirstChild("XMHH.2")
    local remote2 = events:FindFirstChild("XMHH2.2")
    local mainPart = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
    if not remote1 or not remote2 then
        Log("Remote events для взлома не найдены")
        return false
    end
    if not mainPart then
        Log("У сейфа нет основной части")
        return false
    end
    Log("Начинаю взлом сейфа")
    StatusText = "Взлом сейфа"
    local startTime = tick()
    local hits = 0
    while Settings.Enabled and safeObj and safeObj.Parent do
        local values = safeObj:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then
            Log("Сейф уже взломан")
            break
        end
        if tick() - startTime > 25 then
            Log("Таймаут взлома")
            break
        end
        task.wait(0.4)
        local crowbar = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Crowbar")
        if not crowbar then
            crowbar = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Crowbar")
            if crowbar then EquipTool("Crowbar") end
        end
        if not crowbar then break end
        local arm = LocalPlayer.Character:FindFirstChild("Right Arm") or LocalPlayer.Character:FindFirstChild("RightHand")
        if not arm then break end
        local success, result = pcall(function() return remote1:InvokeServer("🍞", tick(), crowbar, "DZDRRRKI", safeObj, "Register") end)
        if success and result then
            pcall(function() remote2:FireServer("🍞", tick(), crowbar, "2389ZFX34", result, false, arm, mainPart, safeObj, mainPart.Position, mainPart.Position) end)
            hits = hits + 1
        end
        if hits % 4 == 0 then task.wait(0.8) end
        LastTick = tick()
    end
    task.wait(2)
    Log("Взлом завершен, ударов: " .. hits)
    StatusText = "Ожидание"
    return true
end

local IsRespawning = false
local RespawnConnection = nil

local function PressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function StopRespawnHandler()
    if IsRespawning then
        IsRespawning = false
        if RespawnConnection then
            RespawnConnection:Disconnect()
            RespawnConnection = nil
        end
    end
end

local function StartRespawnHandler()
    if IsRespawning then return end
    IsRespawning = true
    Log("Смерть обнаружена - нажимаю E для возрождения")
    StatusText = "Смерть"
    RespawnConnection = RunService.Heartbeat:Connect(function()
        if not IsRespawning then
            if RespawnConnection then
                RespawnConnection:Disconnect()
                RespawnConnection = nil
            end
            return
        end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if character and humanoid and humanoid.Health > 0 then
            StopRespawnHandler()
            StatusText = "Ожидание"
            return
        end
        pcall(PressE)
    end)
end

local function OnCharacterAdded(newChar)
    StopRespawnHandler()
    task.wait(3)
    IsRising = false
    HasReachedTargetY = false
    if Settings.Enabled then
        Settings.IsDead = false
        LastTick = tick()
        RiseToTargetY()
        Settings.NeedsStartupToolCheck = true
        Log("Персонаж возродился, продолжаю")
        StatusText = "Ожидание"
    end
    local humanoid = newChar:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.Died:Connect(StartRespawnHandler)
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end

local EspEnabled = false
local EspHeartbeatConnection = nil
local EspElements = {}
local EspTextSize = 20

local function FormatName(rawName)
    rawName = string.gsub(rawName, "([a-z])([A-Z])", "%1 %2")
    rawName = string.gsub(rawName, "_", " ")
    if rawName:lower():find("safe") then
        return "🔒 " .. rawName
    elseif rawName:lower():find("register") then
        return "💰 " .. rawName
    end
    return rawName
end

local function CreateHighlight(part, color)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = part
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Parent = part
    return highlight
end

local function UpdateESP()
    if not EspEnabled then return end
    local bredFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("BredMakurz") or Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("BredMakurz")
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if not bredFolder then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            local mainPart = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if not mainPart then continue end
            local values = obj:FindFirstChild("Values")
            local brokenVal = values and values:FindFirstChild("Broken")
            local isBroken = brokenVal and brokenVal.Value
            local color = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
            local esp = EspElements[obj]
            if not esp then
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "ESP_Billboard"
                billboard.Adornee = mainPart
                billboard.Size = UDim2.new(0, 200, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true
                billboard.MaxDistance = 1000
                billboard.Parent = obj
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.SourceSansBold
                label.TextScaled = false
                label.Text = FormatName(obj.Name)
                label.TextColor3 = color
                label.TextStrokeTransparency = 0
                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                label.TextSize = EspTextSize
                label.Parent = billboard
                local highlight = CreateHighlight(obj, color)
                EspElements[obj] = {
                    billboard = billboard,
                    highlight = highlight,
                    label = label
                }
                if brokenVal then
                    brokenVal:GetPropertyChangedSignal("Value"):Connect(function()
                        if not EspEnabled or not EspElements[obj] then return end
                        local e = EspElements[obj]
                        if brokenVal.Value then
                            e.label.TextColor3 = Color3.new(1, 0, 0)
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(1, 0, 0)
                            end
                        else
                            e.label.TextColor3 = Color3.new(0, 1, 0)
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(0, 1, 0)
                            end
                        end
                    end)
                end
            else
                if brokenVal then
                    esp.label.TextColor3 = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                    if esp.highlight then
                        esp.highlight.FillColor = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                    end
                end
                if esp.label then
                    esp.label.TextSize = EspTextSize
                end
            end
        end
    end
    for obj, data in pairs(EspElements) do
        if not obj or not obj.Parent then
            pcall(function()
                if data.billboard then data.billboard:Destroy() end
                if data.highlight then data.highlight:Destroy() end
            end)
            EspElements[obj] = nil
        end
    end
end

local function EnableESP()
    if EspEnabled then return end
    EspEnabled = true
    EspHeartbeatConnection = RunService.Heartbeat:Connect(UpdateESP)
    Log("ESP для всех сейфов/касс ВКЛЮЧЕН")
end

local function DisableESP()
    if not EspEnabled then return end
    EspEnabled = false
    if EspHeartbeatConnection then
        EspHeartbeatConnection:Disconnect()
        EspHeartbeatConnection = nil
    end
    for obj, data in pairs(EspElements) do
        pcall(function()
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
        end)
    end
    EspElements = {}
    Log("ESP для всех сейфов/касс ВЫКЛЮЧЕН")
end

local function SetupBrokenTracking()
    Log("Запуск анализа целей...")
    BrokenStatusMap = {}
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then
        bredFolder = map:FindFirstChild("BredMakurz")
    end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then
            bredFolder = filter:FindFirstChild("BredMakurz")
        end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if bredFolder then
        for _, obj in ipairs(bredFolder:GetChildren()) do
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken then
                    BrokenStatusMap[obj] = broken.Value
                    broken:GetPropertyChangedSignal("Value"):Connect(function()
                        if Settings.Enabled then
                            BrokenStatusMap[obj] = broken.Value
                            UpdateTargetsList()
                            AnalyzeTargetsCount()
                            Log("Статус цели изменен: " .. obj.Name .. " теперь " .. tostring(broken.Value))
                        end
                    end)
                end
            end
        end
        Log("Анализ целей завершен, отслеживается " .. #BrokenStatusMap .. " объектов")
    end
end
SetupBrokenTracking()

local function getPostBreakWaitSeconds(targetName)
    local nameLower = tostring(targetName):lower()
    if nameLower:find("register") then
        return 3
    elseif nameLower:find("small") then
        return 4
    elseif nameLower:find("medium") or nameLower:find("big") or nameLower:find("large") then
        return 6
    end
    return 4
end

local function BreakTargetAndCollect(targetObj)
    local hackSuccess
    local isRegister = targetObj.Name:lower():find("register") ~= nil

    if isRegister then
        hackSuccess = HackWithFists(targetObj)
    elseif Settings.BreakMethod == "Lockpick" then
        hackSuccess = HackSafeWithLockpick(targetObj)
    else
        if not LocalPlayer.Character:FindFirstChild("Crowbar") then
            EquipTool("Crowbar")
        end
        Log("Открываю сейф")
        hackSuccess = HackSafe(targetObj)
    end

    if hackSuccess then
        Log("Сейф открыт, собираю деньги")
        local stillMoney = CollectMoneyNearTarget(targetObj)
        local attempts = 5
        while stillMoney and attempts > 0 do
            task.wait(2)
            stillMoney = CollectMoneyNearTarget(targetObj)
            attempts = attempts - 1
        end
        Settings.ProcessedList[targetObj] = true
        Log("Сейф полностью обработан")

        local waitTime = getPostBreakWaitSeconds(targetObj.Name)
        Log("Стою на месте " .. waitTime .. " сек после взлома (" .. targetObj.Name .. ")")
        task.wait(waitTime)
        return true
    else
        Log("Не удалось открыть сейф, временно игнорирую")
        Settings.TempIgnored[targetObj] = tick() + Settings.IgnoreDuration
        table.insert(Settings.IgnoredList, targetObj)
        return false
    end
end

-- Ищем ЛЮБОЙ другой ещё не обработанный/не сломанный объект из ТОЙ ЖЕ
-- буферной зоны в радиусе 1000 стадов от текущей позиции персонажа. Не
-- ограничено 2 объектами - работает цепочкой пока в зоне остаются цели.
local function findNearbyZoneSibling(zone, excludeObj)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, closestDist = nil, math.huge
    for _, info in ipairs(SortedTargets) do
        if info.obj ~= excludeObj and zone.names[info.obj.Name] and not Settings.TempIgnored[info.obj] then
            local dist = (info.pos - hrp.Position).Magnitude
            if dist <= 1000 and dist < closestDist then
                closestDist = dist
                closest = info
            end
        end
    end
    return closest
end

local function MainFarmLoop()
    Log("Цикл автофермы запущен")
    RiseToTargetY()
    while true do
        task.wait(0.3)
        if not Settings.Enabled then
            task.wait(0.5)
            continue
        end
        Log("=== Цикл фермы ===")
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        Settings.IsDead = (not humanoid) or (humanoid.Health <= 0)
        if Settings.IsDead then
            Log("Персонаж мертв, ожидание")
            task.wait(3)
            continue
        end
        RiseToTargetY()

        if Settings.NeedsStartupToolCheck then
            Settings.NeedsStartupToolCheck = false
            local needed = Settings.BreakMethod
            local have = (needed == "Lockpick" and CountTools("Lockpick") > 0)
                or (needed == "Crowbar" and HasTool("Crowbar"))

            if have then
                Log("Перед стартом: " .. needed .. " уже есть в инвентаре, иду фармить")
            else
                Log("Перед стартом: нет " .. needed .. " в инвентаре, сначала иду к дилеру")
                StatusText = "Иду к дилеру за инструментом"
                local bought
                if needed == "Lockpick" then
                    bought = BuyLockpickBatch()
                else
                    bought = BuyCrowbar()
                end
                if bought then
                    Log("Инструмент куплен, иду фармить")
                else
                    Log("Не удалось купить инструмент перед стартом, попробую по ходу фарма")
                end
            end
        end

        pcall(readStatsGui)
        pcall(readCashAmountValue)
        if Settings.AutoAllowance
            and StatsInfo.AllowanceSecondsLeft ~= nil
            and StatsInfo.AllowanceSecondsLeft <= 2
            and tick() - StatsInfo.LastAllowanceClaimAttempt > 30
        then
            StatsInfo.LastAllowanceClaimAttempt = tick()
            Log("Таймер аллованса подошёл к 0, иду получать")
            local claimed = claimAllowance()
            if claimed then
                Log("Аллованс получен")
            end
        end
        if Settings.AutoDeposit then
            pcall(maybeAutoDeposit)
        end
        local available, total = UpdateTargetsList()
        TotalAvailableTargets = available
        if available < 5 then
            Log("Осталось мало целей (" .. available .. "), рекомендую сменить сервер")
        end
        if available == 0 then
            Log("Нет доступных целей, жду 5 сек")
            task.wait(5)
            continue
        end
        local nextTarget = nil
        local minDist = math.huge
        for _, targetInfo in ipairs(SortedTargets) do
            if not Settings.TempIgnored[targetInfo.obj] then
                local dist = (targetInfo.pos - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nextTarget = targetInfo.obj
                end
            end
        end
        if not nextTarget then
            Log("Нет доступных целей, жду 5 сек")
            task.wait(5)
            continue
        end
        local mainPart = nextTarget:FindFirstChild("MainPart") or nextTarget.PrimaryPart
        if not mainPart then
            Log("У цели нет MainPart, пропускаю")
            Settings.ProcessedList[nextTarget] = true
            continue
        end
        Log("Движение к цели: " .. nextTarget.Name .. ", расстояние " .. math.floor((mainPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude))
        local moveSuccess, moveReason = MoveToTargetSmart(mainPart, nextTarget, "target")
        if moveReason == "target_broken" then
            Log("Кто-то другой сломал цель раньше, беру следующую")
            Settings.ProcessedList[nextTarget] = true
            continue
        end
        if moveSuccess then
            local success = BreakTargetAndCollect(nextTarget)

            if success then
                local zone = getBufferZoneForTarget(nextTarget.Name)
                if zone then
                    while Settings.Enabled do
                        UpdateTargetsList()
                        local sibling = findNearbyZoneSibling(zone, nextTarget)
                        if not sibling then break end

                        Log("В зоне " .. zone.name .. " есть ещё цель рядом (" .. sibling.obj.Name .. "), иду напрямую без вейпоинтов")
                        SetTargetHighlight(sibling.part, "target")
                        local siblingMove = MoveToTarget(sibling.part, sibling.obj, "target")
                        if not siblingMove then
                            Settings.TempIgnored[sibling.obj] = tick() + Settings.IgnoreDuration
                            break
                        end

                        BreakTargetAndCollect(sibling.obj)
                        nextTarget = sibling.obj
                    end
                end
            end
        else
            Log("Не удалось достичь цели, временно игнорирую")
            Settings.TempIgnored[nextTarget] = tick() + Settings.IgnoreDuration
            table.insert(Settings.IgnoredList, nextTarget)
        end
        task.wait(2)
    end
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Тереяки с Клаудом",
    SubTitle = "",
    TabWidth = 120,
    Size = UDim2.fromOffset(450, 400),
    Acrylic = true,
    Theme = "DarkPurple",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Farm", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Info", Icon = "info" }),
    Skip = Window:AddTab({ Title = "Skip List", Icon = "ban" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
}

local SKIP_LIST_ALL_NAMES = {
    "MediumSafe_HO_39", "MediumSafe_HO_41",
    "MediumSafe_SU_32", "MediumSafe_SW_9", "MediumSafe_TS_20",
    "MediumSafe_T_45", "MediumSafe_T_46",
    "Register_BS_47", "Register_B_10", "Register_B_19", "Register_B_33",
    "Register_B_40", "Register_B_7", "Register_C_1", "Register_GS_16",
    "Register_HO_23", "Register_M_25", "Register_M_31", "Register_M_5",
    "Register_M_6", "Register_P_13", "Register_P_14", "Register_TS_27",
    "Register_TS_4", "Register_VI_29",
    "SmallSafe_BD_12", "SmallSafe_BD_18", "SmallSafe_C_3", "SmallSafe_FA_34",
    "SmallSafe_FA_35", "SmallSafe_FA_36", "SmallSafe_M_17",
    "SmallSafe_SU_15", "SmallSafe_SU_22", "SmallSafe_SW_11", "SmallSafe_SW_26",
    "SmallSafe_TO_42", "SmallSafe_TO_43", "SmallSafe_TO_44", "SmallSafe_WH_28",
}

Tabs.Skip:AddDropdown("SkipListDropdown", {
    Title = "Skip these objects",
    Description = "Фарм будет полностью игнорировать выбранные сейфы/регистры",
    Values = SKIP_LIST_ALL_NAMES,
    Multi = true,
    Default = {},
    Callback = function(selected)
        local newSkipList = {}
        if type(selected) == "table" then
            for key, value in pairs(selected) do
                if value == true then
                    newSkipList[key] = true
                elseif type(key) == "number" and type(value) == "string" then
                    newSkipList[value] = true
                end
            end
        end
        SkipList = newSkipList
        Log("Skip List обновлён: " .. table.concat((function()
            local names = {}
            for name in pairs(SkipList) do table.insert(names, name) end
            return names
        end)(), ", "))
    end
})

Tabs.Main:AddToggle("AutoFarmToggle", {
    Title = "Start Farm",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.Enabled = value
        if value then
            Settings.IgnoredList = {}
            Settings.ProcessedList = {}
            Settings.TempIgnored = {}
            Settings.NeedsStartupToolCheck = true
            UpdateTargetsList()
            AnalyzeTargetsCount()
            RiseToTargetY()
            Log("Автоферма ВКЛЮЧЕНА")
            Fluent:Notify({ Title = "Тереяки с Клаудом", Content = "Запущено", Duration = 2 })
        else
            ClearPathVisuals()
            SomeFlag2 = false
            StatusText = "Ожидание"
            Log("Автоферма ВЫКЛЮЧЕНА")
            Fluent:Notify({ Title = "Тереяки с Клаудом", Content = "Остановлено", Duration = 2 })
        end
    end
})

Tabs.Main:AddToggle("AutoPickupMoneyToggle", {
    Title = "Auto Money",
    Description = "",
    Default = true,
    Callback = function(value)
        if value then
            StartAutoPickup()
            Log("Авто-подбор денег ВКЛЮЧЕН")
        else
            StopAutoPickup()
            Log("Авто-подбор денег ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddToggle("InvisibilityToggle", {
    Title = "Invis (R6)",
    Description = "",
    Default = false,
    Callback = function(value)
        if value then
            _G.Invis_Enable()
            Log("Невидимость ВКЛЮЧЕНА")
        else
            _G.Invis_Disable()
            Log("Невидимость ВЫКЛЮЧЕНА")
        end
    end
})

Tabs.Main:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "",
    Default = true,
    Callback = function(value)
        AntiAfkEnabled = value
        if value then
            EnableAntiAfk()
            Log("Анти-АФК ВКЛЮЧЕН")
        else
            DisableAntiAfk()
            Log("Анти-АФК ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddDropdown("BreakMethodDropdown", {
    Title = "Safe Break Method",
    Description = "Только для сейфов, кассы всегда кулаками",
    Values = { "Crowbar", "Lockpick" },
    Multi = false,
    Default = Settings.BreakMethod,
    Callback = function(value)
        Settings.BreakMethod = value
        Log("Метод взлома сейфов: " .. value)
        Fluent:Notify({ Title = "Break Method", Content = value, Duration = 2 })

        if value == "Lockpick" then
            task.spawn(function()
                if CountTools("Lockpick") > 0 then
                    Log("Лок-пики уже есть в инвентаре, продолжаю фармить")
                else
                    Log("Лок-пиков нет в инвентаре, иду к дилеру докупать")
                    Fluent:Notify({ Title = "Break Method", Content = "Нет лок-пиков, иду к дилеру", Duration = 2 })
                    BuyLockpickBatch()
                end
            end)
        end
    end
})

Tabs.Main:AddSlider("SpeedSlider", {
    Title = "Speed",
    Description = "",
    Default = 22,
    Min = 10,
    Max = 45,
    Rounding = 1,
    Callback = function(value)
        Settings.MoveSpeed = value
        Log("Скорость " .. value)
    end
})

Tabs.Main:AddToggle("AutoDepositToggle", {
    Title = "Auto Deposit",
    Description = "Нести кэш в банк по достижении порога",
    Default = false,
    Callback = function(value)
        Settings.AutoDeposit = value
        Log("Автодепозит: " .. tostring(value))
    end
})

Tabs.Main:AddSlider("DepositThresholdSlider", {
    Title = "Deposit At ($)",
    Description = "",
    Default = 5000,
    Min = 500,
    Max = 50000,
    Rounding = 0,
    Callback = function(value)
        Settings.AutoDepositThreshold = value
    end
})

Tabs.Main:AddToggle("AutoAllowanceToggle", {
    Title = "Auto Claim Allowance",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.AutoAllowance = value
        Log("Авто-аллованс: " .. tostring(value))
    end
})

Tabs.Visuals:AddToggle("SafeESPToggle", {
    Title = "Safe/Register ESP",
    Default = false,
    Callback = function(value)
        if value then
            EnableESP()
        else
            DisableESP()
        end
    end
})

Tabs.Visuals:AddSlider("TextSizeSlider", {
    Title = "Text Size",
    Default = 20,
    Min = 10,
    Max = 40,
    Rounding = 0,
    Callback = function(value)
        EspTextSize = value
        for _, data in pairs(EspElements) do
            if data.label then
                data.label.TextSize = EspTextSize
            end
        end
    end
})

local statusPara = Tabs.Stats:AddParagraph({
    Title = "Статус",
    Content = "Загрузка..."
})

local safesPara = Tabs.Stats:AddParagraph({
    Title = "Сейфы",
    Content = "0/0"
})

local registersPara = Tabs.Stats:AddParagraph({
    Title = "Кассы",
    Content = "0/0"
})

local remainingPara = Tabs.Stats:AddParagraph({
    Title = "Осталось",
    Content = "0/0"
})

local suggestionPara = Tabs.Stats:AddParagraph({
    Title = "Совет",
    Content = "Загрузка..."
})

local cashPara = Tabs.Stats:AddParagraph({
    Title = "Cash",
    Content = "$0"
})

local bankPara = Tabs.Stats:AddParagraph({
    Title = "Bank",
    Content = "$0"
})

local allowancePara = Tabs.Stats:AddParagraph({
    Title = "Allowance",
    Content = "$0"
})

task.spawn(function()
    while true do
        if Settings.Enabled then
            statusPara:SetDesc(StatusText)
            safesPara:SetDesc(AvailableSafesCount .. "/" .. TotalSafesCount)
            registersPara:SetDesc(AvailableRegistersCount .. "/" .. TotalRegistersCount)
            remainingPara:SetDesc((AvailableSafesCount + AvailableRegistersCount) .. "/" .. (TotalSafesCount + TotalRegistersCount))
            suggestionPara:SetDesc(SuggestionText)
        else
            statusPara:SetDesc("Ожидание")
            safesPara:SetDesc("0/0")
            registersPara:SetDesc("0/0")
            remainingPara:SetDesc("0/0")
            suggestionPara:SetDesc("Запусти ферму")
        end
        pcall(readStatsGui)
        pcall(readCashAmountValue)
        cashPara:SetDesc("$" .. math.floor(StatsInfo.CashAmount))
        bankPara:SetDesc("$" .. math.floor(StatsInfo.BankAmount))
        allowancePara:SetDesc(StatsInfo.AllowanceText ~= "" and StatsInfo.AllowanceText or ("$" .. math.floor(StatsInfo.AllowanceAmount)))
        task.wait(0.5)
    end
end)

Fluent:Notify({ Title = "Тереяки с Клаудом", Content = "Загружено", Duration = 2 })

task.spawn(MainFarmLoop)