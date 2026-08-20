-- UniversalHex - Advanced Exploit Module
-- Built for scalability, performance, memory safety, and universal utility.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Standalone Janitor dependency
local Janitor = loadstring(game:HttpGet("https://raw.githubusercontent.com/VoiderHex/Scripts/refs/heads/main/Janitor.lua"))()

local UniversalHex = {}
UniversalHex.__index = UniversalHex

function UniversalHex.new(config)
    config = config or {}
    local projectId = config.ProjectId or "UniversalHex_Default"
    
    if getgenv()[projectId] then
        pcall(function() getgenv()[projectId]:Destroy() end)
        task.wait(0.1)
    end
    
    local self = setmetatable({}, UniversalHex)
    
    self.Mode = config.Mode or "client"
    self.ProjectId = projectId
    self.Janitor = Janitor.new()
    
    self._state = {
        SpeedValue = 16,
        JumpPowerValue = 50,
        OriginalLighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd
        }
    }
    
    self._espGroups = {}
    self._espCache = {}
    self._espEngineRunning = false
    
    self._fpsCache = {}
    
    getgenv()[projectId] = self
    self:_log("INFO", "Initialized successfully in " .. self.Mode .. " mode for project: " .. projectId)
    
    return self
end

function UniversalHex:_log(level, message)
    if self.Mode == "dev" then
        print(string.format("[UniversalHex | %s] %s", string.upper(level), message))
    end
end

function UniversalHex:_getChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

function UniversalHex:AttachUI(uiInstance)
    if typeof(uiInstance) == "Instance" or type(uiInstance) == "table" then
        self.Janitor:Add(uiInstance, "Destroy", "Main_Rayfield_UI")
    end
end

-- DYNAMIC ESP ENGINE (Players & Parts)

function UniversalHex:CreateEspGroup(groupName, groupType)
    groupType = groupType or "Players"
    
    local group = {
        Name = groupName,
        Type = groupType,
        Color = Color3.fromRGB(255, 255, 255),
        Enabled = true,
        Filter = function() return true end,
        PartsList = {},
        Highlight = { Enabled = true, Fill = 0.5, Outline = 0 }
    }
    
    function group:SetColor(c) self.Color = c; return self end
    function group:SetFilter(f) self.Filter = f; return self end
    function group:SetEnabled(e) self.Enabled = e; return self end
    function group:SetPartsList(list) self.PartsList = list; return self end
    function group:EnableHighlight(enabled, fill, outline)
        self.Highlight.Enabled = enabled
        if fill then self.Highlight.Fill = fill end
        if outline then self.Highlight.Outline = outline end
        return self
    end
    
    self._espGroups[groupName] = group
    self._espCache[groupName] = {}
    
    self:_startEspEngine()
    
    return group
end

function UniversalHex:_startEspEngine()
    if self._espEngineRunning then return end
    self._espEngineRunning = true
    
    local espFolder = Instance.new("Folder")
    espFolder.Name = "UniversalHex_ESP"
    pcall(function()
        if gethui then espFolder.Parent = gethui() else espFolder.Parent = CoreGui end
    end)
    self.Janitor:Add(espFolder, "Destroy", "EspFolder")
    
    local connection = RunService.RenderStepped:Connect(function()
        for groupName, group in pairs(self._espGroups) do
            local currentCache = self._espCache[groupName]
            
            if not group.Enabled then
                for inst, highlight in pairs(currentCache) do highlight:Destroy() end
                table.clear(currentCache)
                continue
            end
            
            local validInstances = {}
            
            if group.Type == "Players" then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 and group.Filter(player) then
                            validInstances[player.Character] = true
                        end
                    end
                end
            elseif group.Type == "Parts" then
                for _, part in ipairs(group.PartsList) do
                    if part and part.Parent and part:IsA("BasePart") and group.Filter(part) then
                        validInstances[part] = true
                    end
                end
            end
            
            for inst, highlight in pairs(currentCache) do
                if not validInstances[inst] or not inst.Parent then
                    highlight:Destroy()
                    currentCache[inst] = nil
                end
            end
            
            for inst, _ in pairs(validInstances) do
                local highlight = currentCache[inst]
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "ESP_" .. groupName
                    highlight.Parent = espFolder
                    highlight.Adornee = inst
                    currentCache[inst] = highlight
                end
                
                if group.Highlight.Enabled then
                    highlight.Enabled = true
                    highlight.FillColor = group.Color
                    highlight.OutlineColor = group.Color
                    highlight.FillTransparency = group.Highlight.Fill
                    highlight.OutlineTransparency = group.Highlight.Outline
                else
                    highlight.Enabled = false
                end
            end
        end
    end)
    
    self.Janitor:Add(connection, "Disconnect", "EspEngineLoop")
end

-- COMBAT: FLING & ANTI-FLING (Optimized)

function UniversalHex:SetAntiFlingEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("AntiFlingLoop")
        return
    end
    
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local localChar, _, _ = self:_getChar()
            if not localChar then return end
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "AntiFlingLoop")
end

function UniversalHex:SetFlingActivate(enabled, targetPlayer)
    if not enabled then
        self.Janitor:Remove("FlingLoop")
        pcall(function()
            local _, hrp, _ = self:_getChar()
            if hrp then
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
            end
        end)
        return
    end
    
    local connection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local _, hrp, hum = self:_getChar()
            if not hrp or not hum or hum.Health <= 0 then return end
            
            hrp.RotVelocity = Vector3.new(20000, 20000, 20000)
            
            if targetPlayer and targetPlayer.Character then
                local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    hrp.CFrame = targetHrp.CFrame
                end
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "FlingLoop")
end

-- CHARACTER & MOVEMENT CONTROLS

function UniversalHex:SetSpeedEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("SpeedLoop")
        return
    end
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local _, _, hum = self:_getChar()
            if hum and hum.Health > 0 then hum.WalkSpeed = self._state.SpeedValue end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "SpeedLoop")
end

function UniversalHex:SetSpeedValue(speed)
    self._state.SpeedValue = speed
end

function UniversalHex:SetJumpPowerEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("JumpLoop")
        return
    end
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local _, _, hum = self:_getChar()
            if hum and hum.Health > 0 then
                hum.UseJumpPower = true 
                hum.JumpPower = self._state.JumpPowerValue
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "JumpLoop")
end

function UniversalHex:SetJumpPowerValue(power)
    self._state.JumpPowerValue = power
end

function UniversalHex:SetNoclipEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("NoclipLoop")
        return
    end
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "NoclipLoop")
end

function UniversalHex:SetInfiniteJumpEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("InfJumpConnection")
        return
    end
    local connection = UserInputService.JumpRequest:Connect(function()
        pcall(function()
            local _, _, hum = self:_getChar()
            if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "InfJumpConnection")
end

function UniversalHex:TeleportToCFrame(targetCFrame, smooth)
    pcall(function()
        local char, hrp, _ = self:_getChar()
        if not char or not hrp then return end
        if smooth then
            local tween = TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
            tween:Play()
        else
            char:PivotTo(targetCFrame)
        end
    end)
end

-- UTILITY & NETWORK CONTROLS

function UniversalHex:SetAntiAfkEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("AntiAfkConnection")
        return
    end
    local connection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "AntiAfkConnection")
end

function UniversalHex:_applyOptimization(obj, extremeMode)
    pcall(function()
        -- Initialize cache for the object if restoring is intended
        if not extremeMode and not self._fpsCache[obj] then
            self._fpsCache[obj] = {}
        end
        
        if obj:IsA("BasePart") then
            if not extremeMode and not self._fpsCache[obj].Material then
                self._fpsCache[obj].Material = obj.Material
                self._fpsCache[obj].Reflectance = obj.Reflectance
                self._fpsCache[obj].CastShadow = obj.CastShadow
            end
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            if not extremeMode and not self._fpsCache[obj].Transparency then
                self._fpsCache[obj].Transparency = obj.Transparency
            end
            obj.Transparency = 1
        elseif obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            if not extremeMode and self._fpsCache[obj].Enabled == nil then
                self._fpsCache[obj].Enabled = obj.Enabled
            end
            obj.Enabled = false
        end
    end)
end

function UniversalHex:SetAutoOptimizeFPS(enabled, extremeMode)
    if not enabled then
        self.Janitor:Remove("AutoFPS")
        
        -- Restore all cached properties
        for obj, props in pairs(self._fpsCache) do
            pcall(function()
                if obj and obj.Parent then
                    for propName, propValue in pairs(props) do
                        obj[propName] = propValue
                    end
                end
            end)
        end
        table.clear(self._fpsCache)
        
        -- Restore Lighting
        pcall(function()
            Lighting.GlobalShadows = self._state.OriginalLighting.GlobalShadows
            Lighting.FogEnd = self._state.OriginalLighting.FogEnd
        end)
        
        self:_log("INFO", "Auto FPS Optimization disabled. Visuals restored.")
        return
    end

    self:_log("INFO", "Auto FPS Optimization enabled. ExtremeMode: " .. tostring(extremeMode))
    
    task.spawn(function()
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            for _, obj in ipairs(workspace:GetDescendants()) do
                self:_applyOptimization(obj, extremeMode)
            end
        end)
    end)
    
    local connection = workspace.DescendantAdded:Connect(function(obj)
        self:_applyOptimization(obj, extremeMode)
    end)
    
    self.Janitor:Add(connection, "Disconnect", "AutoFPS")
end

function UniversalHex:RejoinServer()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

function UniversalHex:ServerHop()
    task.spawn(function()
        pcall(function()
            local serversApi = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
            local requestFunc = syn and syn.request or request or http_request or fluxus and fluxus.request
            if not requestFunc then return end
            
            local response = requestFunc({ Url = serversApi, Method = "GET" })
            if response.StatusCode == 200 then
                local data = HttpService:JSONDecode(response.Body)
                local availableServers = {}
                
                for _, server in ipairs(data.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(availableServers, server.id)
                    end
                end
                
                if #availableServers > 0 then
                    local randomServer = availableServers[math.random(1, #availableServers)]
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
                end
            end
        end)
    end)
end

function UniversalHex:GetPing()
    local ping = 0
    pcall(function()
        local pingString = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        ping = tonumber(pingString:match("%d+")) or 0
    end)
    return ping
end

function UniversalHex:GetFPS()
    local fps = 0
    pcall(function() fps = math.floor(workspace:GetRealPhysicsFPS()) end)
    return fps
end

-- LIFECYCLE & STATE MANAGEMENT

function UniversalHex:ResetAll()
    self:SetSpeedEnabled(false)
    self:SetJumpPowerEnabled(false)
    self:SetNoclipEnabled(false)
    self:SetInfiniteJumpEnabled(false)
    self:SetAntiAfkEnabled(false)
    self:SetFlingActivate(false)
    self:SetAntiFlingEnabled(false)
    self:SetAutoOptimizeFPS(false, false)
    
    for _, group in pairs(self._espGroups) do
        group:SetEnabled(false)
    end
end

function UniversalHex:Destroy()
    self:_log("WARN", "Destroy invoked. Nuking UniversalHex from memory.")
    self:ResetAll()
    self.Janitor:Destroy()
    table.clear(self._state)
    table.clear(self._espGroups)
    
    if getgenv()[self.ProjectId] == self then
        getgenv()[self.ProjectId] = nil
    end
    
    setmetatable(self, nil)
end

return UniversalHex
