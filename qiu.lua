local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local GUIPARENT = (gethui and gethui()) or game:GetService("CoreGui")

local Config = {
    Enabled     = false,
    AimPart     = "Head",
    FOV         = 150,
    Smoothness  = 0.18,
    MaxDistance = 1000,
    WallCheck   = true,
    ShowFOV     = false,
    AutoFire    = false,
    Prediction  = 0,
    SpeedValue  = 16,
    JumpValue   = 50,
    NoclipWalk  = false,
    FlyEnabled  = false,
    FlySpeed    = 50,
}

local state = { targetName = "待机", targetCount = 0 }

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "AimbotFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.Parent = GUIPARENT

local circle = Instance.new("Frame")
circle.Name = "Circle"
circle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
circle.Position = UDim2.fromScale(0.5, 0.5)
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.BackgroundTransparency = 1
circle.BorderSizePixel = 0
circle.Parent = fovGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 80, 80)
stroke.Thickness = 1.5
stroke.Transparency = 0.4
stroke.Parent = circle

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = circle

fovGui.Enabled = Config.ShowFOV

local function isValidCharacter(char)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getAimPart(char)
    if not char then return nil end
    if Config.AimPart == "Head" then
        return char:FindFirstChild("Head")
    elseif Config.AimPart == "HumanoidRootPart" then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function wallBlocked(char, part)
    if not Config.WallCheck then return false end
    rayParams.FilterDescendantsInstances = { LP.Character, Camera }
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, rayParams)
    if not result then return false end
    return not result.Instance:IsDescendantOf(char)
end

local function getPredictedPosition(part)
    if Config.Prediction <= 0 then return part.Position end
    local vel = part.AssemblyLinearVelocity
    if vel.Magnitude < 1 then return part.Position end
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    return part.Position + vel * (dist / 1500) * Config.Prediction
end

local function getBestTarget()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestD = nil, math.huge
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local char = player.Character
            if isValidCharacter(char) then
                local part = getAimPart(char)
                if part and (part.Position - Camera.CFrame.Position).Magnitude <= Config.MaxDistance then
                    local targetPos = getPredictedPosition(part)
                    local sp, onScreen = Camera:WorldToViewportPoint(targetPos)
                    if onScreen and sp.Z > 0 then
                        local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d2 <= Config.FOV then
                            count = count + 1
                            if d2 < bestD and not wallBlocked(char, part) then
                                best, bestD = player, d2
                            end
                        end
                    end
                end
            end
        end
    end
    state.targetCount = count
    return best
end

local function aimAt(player)
    local char = player.Character
    if not isValidCharacter(char) then return end
    local part = getAimPart(char)
    if not part then return end
    local goal = CFrame.new(Camera.CFrame.Position, getPredictedPosition(part))
    if Config.Smoothness >= 1 then
        Camera.CFrame = goal
    else
        Camera.CFrame = Camera.CFrame:Lerp(goal, Config.Smoothness)
    end
end

local function applySpeedAndJump()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    if not Config.FlyEnabled then
        hum.WalkSpeed = Config.SpeedValue
    end
    hum.UseJumpPower = true
    hum.JumpPower = Config.JumpValue
end

local function applyNoclip()
    local char = LP.Character
    if not char then return end
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Config.NoclipWalk
        end
    end
end

local function applyFlyAndFloat()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if Config.FlyEnabled or Config.NoclipWalk then
        -- 使用 BodyVelocity 悬停，抵消重力
        local bv = hrp:FindFirstChild("QiUFloat")
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "QiUFloat"
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Parent = hrp
        end

        if Config.FlyEnabled then
            -- 摇杆的移动意图
            local moveDir = hum.MoveDirection
            
            if moveDir.Magnitude > 0.1 then
                -- 把摇杆方向转换为相对于摄像机的空间方向
                -- 当镜头朝上时，Camera.LookVector 的 Y 轴分量会变大，人物就会往上飞
                local flyDir = (Camera.CFrame.LookVector * moveDir.Z + Camera.CFrame.RightVector * moveDir.X).Unit
                bv.Velocity = flyDir * Config.FlySpeed
            else
                -- 没有摇杆输入时悬停
                bv.Velocity = Vector3.zero
            end
        else
            -- 踏空模式：锁定 Y 轴速度为 0，但不影响水平移动
            bv.Velocity = Vector3.new(0, 0, 0)
        end
    else
        local bv = hrp:FindFirstChild("QiUFloat")
        if bv then bv:Destroy() end
    end
end

pcall(function() RunService:UnbindFromRenderStep("UniversalAimLoop") end)
RunService:BindToRenderStep("UniversalAimLoop", Enum.RenderPriority.Camera.Value + 1, function()
    Camera = workspace.CurrentCamera
    
    applySpeedAndJump()
    applyNoclip()
    applyFlyAndFloat()

    if not Config.Enabled then
        state.targetName = "待机"
        return
    end
    local best = getBestTarget()
    if best then
        state.targetName = best.Name
        aimAt(best)
        if Config.AutoFire then
            local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    else
        state.targetName = state.targetCount > 0 and "被遮挡" or "无目标"
    end
end)

LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    applySpeedAndJump()
end)

local Window = WindUI:CreateWindow({
    Title = "QiU",
    Icon = "crosshair",
    Author = "QiU",
    Size = UDim2.fromOffset(500, 420),
    Transparent = true,
    Theme = "Dark",
})

local NoticeTab = Window:Tab({ Title = "公告", Icon = "megaphone" })

NoticeTab:Paragraph({
    Title = "说明",
    Desc = "本脚本永久免费为Q7制作",
})

NoticeTab:Paragraph({
    Title = "QIU脚本主群",
    Desc = "932584465",
})

NoticeTab:Paragraph({
    Title = "赞助支持",
    Desc = "如果觉得我做的好就请赞助点吧",
    Image = "https://your-image-url-here.png"
})

local GeneralTab = Window:Tab({ Title = "通用", Icon = "user" })

GeneralTab:Slider({
    Title = "移速增强",
    Step = 1,
    Value = { Min = 16, Max = 250, Default = 16 },
    Callback = function(v) if v then Config.SpeedValue = v end end,
})

GeneralTab:Slider({
    Title = "跳跃增强",
    Step = 1,
    Value = { Min = 50, Max = 100, Default = 50 },
    Callback = function(v) if v then Config.JumpValue = v end end,
})

GeneralTab:Toggle({
    Title = "踏空 / 悬浮",
    Value = false,
    Callback = function(v) Config.NoclipWalk = v == true end,
})

GeneralTab:Toggle({
    Title = "开启飞行",
    Value = false,
    Callback = function(v) Config.FlyEnabled = v == true end,
})

GeneralTab:Slider({
    Title = "飞行速度",
    Step = 1,
    Value = { Min = 10, Max = 150, Default = 50 },
    Callback = function(v) if v then Config.FlySpeed = v end end,
})

local AimTab = Window:Tab({ Title = "自瞄", Icon = "crosshair" })

AimTab:Toggle({
    Title = "启用自瞄",
    Value = false,
    Callback = function(v) Config.Enabled = v == true end,
})

AimTab:Dropdown({
    Title = "瞄准部位",
    Values = { "Head", "HumanoidRootPart", "UpperTorso" },
    Value = "Head",
    Callback = function(v) if v then Config.AimPart = v end end,
})

AimTab:Slider({
    Title = "FOV (px)",
    Step = 5,
    Value = { Min = 30, Max = 500, Default = 150 },
    Callback = function(v)
        if v then
            Config.FOV = v
            circle.Size = UDim2.fromOffset(v * 2, v * 2)
        end
    end,
})

AimTab:Slider({
    Title = "平滑度",
    Step = 0.01,
    Value = { Min = 0.01, Max = 1, Default = 0.18 },
    Callback = function(v) if v then Config.Smoothness = v end end,
})

AimTab:Slider({
    Title = "最大距离",
    Step = 50,
    Value = { Min = 50, Max = 3000, Default = 1000 },
    Callback = function(v) if v then Config.MaxDistance = v end end,
})

AimTab:Slider({
    Title = "预判强度",
    Step = 0.05,
    Value = { Min = 0, Max = 2, Default = 0 },
    Callback = function(v) if v then Config.Prediction = v end end,
})
AimTab:Toggle({
    Title = "墙体检测",
    Value = true,
    Callback = function(v) Config.WallCheck = v == true end,
})

AimTab:Toggle({
    Title = "显示 FOV 圈",
    Value = false,
    Callback = function(v)
        Config.ShowFOV = v == true
        fovGui.Enabled = Config.ShowFOV
    end,
})

AimTab:Toggle({
    Title = "自动开火",
    Value = false,
    Callback = function(v) Config.AutoFire = v == true end,
})

WindUI:Notify({
    Title = "QiU",
    Content = "已加载",
    Duration = 4,
})