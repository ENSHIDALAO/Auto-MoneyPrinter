local player = game:GetService("Players").LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- 等待角色加载
local character = player.Character or player.CharacterAdded:Wait()
local HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local scriptStartTime = os.time()
local forbiddenZoneCenter = Vector3.new(352.884155, 13.0287256, -1353.05396)
local forbiddenRadius = 80

-- 目标物品列表
local targetItems = {
    "Money Printer",
    "Blue Candy Cane",
    "Bunny Balloon",
    "Ghost Balloon",
    "Clover Balloon",
    "Bat Balloon",
    "Gold Clover Balloon",
    "Golden Rose",
    "Black Rose",
    "Heart Balloon","Spectral Scythe","Skull Balloon"
}

-- 转换为集合以便快速查找
local targetItemSet = {}
for _, item in ipairs(targetItems) do
    targetItemSet[item] = true
end

-- 控制变量
local isAutoWalking = false
local walkConnection = nil

local function ShowNotification(text)
    game.StarterGui:SetCore(
        "SendNotification",
        {
            Title = "BEN",
            Text = text,
            Duration = 5
        }
    )
end

local function checkTimeout()
    return (os.time() - scriptStartTime) >= 120
end

local function GetAvailableServers()
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"))
        local currentJobId = game.JobId
        local availableServers = {}
        
        for _, server in ipairs(servers.data) do
            if server.id ~= currentJobId and server.playing < server.maxPlayers then
                table.insert(availableServers, server.id)
            end
        end
        return availableServers
    end)
    
    if success then
        return result
    else
        ShowNotification("获取服务器列表失败")
        return {}
    end
end

local function TPServer()
    local availableServers = GetAvailableServers()
    if #availableServers > 0 then
        ShowNotification("正在传送到新服务器...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, availableServers[math.random(1, #availableServers)])
    else
    end
end

-- 模拟按键函数
local function SimulateEKey()
    -- 方法1: 使用虚拟输入
    pcall(function()
        virtualInput = virtualInput or game:GetService("VirtualInputManager")
        virtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.1)
        virtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    
    -- 方法2: 使用移动角色触发
    humanoid:Move(Vector3.new(0, 0, 0))
end

-- 自动行走函数
local function StartAutoWalk()
    if isAutoWalking then return end
    
    isAutoWalking = true
    ShowNotification("开始自动行走")
    
    walkConnection = RunService.Heartbeat:Connect(function()
        if not isAutoWalking then 
            walkConnection:Disconnect()
            return
        end
        
        -- 模拟按下W键
        pcall(function()
            virtualInput = virtualInput or game:GetService("VirtualInputManager")
            virtualInput:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            task.wait(0.1)
            virtualInput:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        end)
        
        -- 同时保持角色向前移动
        humanoid:Move(Vector3.new(0, 0, -1))
    end)
end

local function StopAutoWalk()
    isAutoWalking = false
    if walkConnection then
        walkConnection:Disconnect()
        walkConnection = nil
    end
end

-- 查找最近的稀有物品
local function FindNearestTargetItem()
    local closestItem = nil
    local closestDistance = math.huge
    local closestProximityPrompt = nil
    
    local itemFolder = game:GetService("Workspace").Game.Entities.ItemPickup
    if not itemFolder then return nil, nil end
    
    for _, itemContainer in pairs(itemFolder:GetChildren()) do
        for _, item in pairs(itemContainer:GetChildren()) do
            if item:IsA("MeshPart") or item:IsA("Part") then
                local itemPos = item.Position
                local distance = (itemPos - forbiddenZoneCenter).Magnitude
                
                -- 检查是否在禁区外
                if distance > forbiddenRadius then
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA("ProximityPrompt") and targetItemSet[child.ObjectText] then
                            local distanceToPlayer = (itemPos - HumanoidRootPart.Position).Magnitude
                            if distanceToPlayer < closestDistance then
                                closestDistance = distanceToPlayer
                                closestItem = item
                                closestProximityPrompt = child
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestItem, closestProximityPrompt
end

-- 传送到物品位置并拾取
local function TeleportAndPickItem(item, prompt)
    if not item or not item.Parent or not prompt then
        return false
    end
    
    
    -- 停止自动行走
    StopAutoWalk()
    
    -- 传送到物品位置
    HumanoidRootPart.CFrame = item.CFrame * CFrame.new(0, 3, 0)
    
    -- 等待传送完成
    task.wait(0.5)
    
    -- 循环模拟E键直到物品被拾取或超时
    local startTime = tick()
    local timeout = 3 -- 3秒超时
    
    while item and item.Parent and tick() - startTime < timeout do
        -- 确保仍在物品附近
        local distance = (item.Position - HumanoidRootPart.Position).Magnitude
        if distance > 10 then
            HumanoidRootPart.CFrame = item.CFrame * CFrame.new(0, 3, 0)
        end
        
        -- 触发 proximity prompt
        fireproximityprompt(prompt)
        
        -- 模拟E键
        SimulateEKey()
        
        -- 检查物品是否还存在
        if not item or not item.Parent then
            -- 重新开始自动行走
            StartAutoWalk()
            return true
        end
        
        task.wait(0.1)
    end
    
    -- 重新开始自动行走
    StartAutoWalk()
    return false
end

-- 主循环函数
local function AutoPickItem()
    
    -- 开始自动行走
    StartAutoWalk()
    
    while task.wait(1) do
        -- 检查超时
        if checkTimeout() then
            StopAutoWalk()
            TPServer()
            break
        end
        
        -- 查找最近的稀有物品
        local targetItem, targetPrompt = FindNearestTargetItem()
        
        if targetItem and targetPrompt then
            -- 找到物品，尝试拾取
            local success = TeleportAndPickItem(targetItem, targetPrompt)
            
            if not success then
            end
        else
            -- 没有找到物品，换服
            ShowNotification("准备换服")
            StopAutoWalk()
            TPServer()
            break
        end
    end
end

-- 重新连接角色死亡事件
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    humanoid = newChar:WaitForChild("Humanoid")
    
    -- 重新开始物品拾取循环
    task.wait(3) -- 等待角色完全加载
    AutoPickItem()
end)

-- 添加键盘控制（可选）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        if isAutoWalking then
            StopAutoWalk()
        else
            StartAutoWalk()
        end
    end
end)

-- 启动脚本
AutoPickItem()
