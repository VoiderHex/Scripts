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

-- Constructor
function UniversalHex.new(config)
    config = config or {}
    local projectId = config.ProjectId or "UniversalHex_Default"
    
    -- Anti-Duplication (Pre-load): Cleans up any previously running instance of this project
    if getgenv()[projectId] then
        pcall(function()
            getgenv()[projectId]:Destroy()
        end)
        task.wait(0.1) -- Yield briefly to allow the engine to clear visual instances
    end
    
    local self = setmetatable({}, UniversalHex)
    
    self.Mode = config.Mode or "client"
    self.ProjectId = projectId
    self.Janitor = Janitor.new()
    
    -- Centralized state storage
    self._state = {
        -- Visuals
        EspEnabled = false,
        EspColor = Color3.fromRGB(255, 0, 0),
        EspStyle = "Highlight", 
        EspTransparency = { Fill = 0.5, Outline = 0 },
        EspDistanceLimit = 1000,
        
        -- Movement
        SpeedEnabled = false,
        SpeedValue = 16,
        JumpPowerEnabled = false,
        JumpPowerValue = 50,
        NoclipEnabled = false,
        InfiniteJumpEnabled = false,
        
        -- Utilities
        AntiAfkEnabled = false,
        
        -- Environment Cache (stored for clean restoration)
        OriginalLighting = {
            Ambient = Lighting.Ambient,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            ColorShift_Top = Lighting.ColorShift_Top
        }
    }
    
    -- Register the new instance in the global environment
    getgenv()[projectId] = self
    
    self:_log("INFO", "Initialized successfully in " .. self.Mode .. " mode for project: " .. projectId)
    return self
end

-- Internal helper for conditional logging
function UniversalHex:_log(level, message)
    if self.Mode == "dev" then
        print(string.format("[UniversalHex | %s] %s", string.upper(level), message))
    end
end

-- Safely retrieves the player's character components to prevent nil reference errors
function UniversalHex:_getChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    return char, hrp, hum
end

-- UI Integration

-- Attaches the main UI instance (e.g., Rayfield window) to the Janitor for automatic cleanup
function UniversalHex:AttachUI(uiInstance)
    if typeof(uiInstance) == "Instance" or type(uiInstance) == "table" then
        self.Janitor:Add(uiInstance, "Destroy", "Main_Rayfield_UI")
        self:_log("INFO", "UI attached to Janitor successfully.")
    end
end

-- Visuals & Debug Overlays

function UniversalHex:SetEspEnabled(enabled)
    self._state.EspEnabled = enabled
    
    if not enabled then
        self.Janitor:Remove("EspFolder")
        self.Janitor:Remove("EspLoop")
        self:_log("INFO", "ESP system disabled and cleaned up.")
        return
    end

    self:_log("INFO", "ESP system enabled. Setting up rendering loop.")
    
    local espFolder = Instance.new("Folder")
    espFolder.Name = "UniversalHex_ESP"
    
    pcall(function()
        if gethui then
            espFolder.Parent = gethui()
        else
            espFolder.Parent = CoreGui
        end
    end)
    
    self.Janitor:Add(espFolder, "Destroy", "EspFolder")
    
    local connection = RunService.RenderStepped:Connect(function()
        pcall(function()
            local localChar, localHrp, _ = self:_getChar()
            if not localHrp then return end
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
                    
                    if targetHrp then
                        local distance = (localHrp.Position - targetHrp.Position).Magnitude
                        local objectName = "ESP_" .. player.Name
                        local existingEsp = espFolder:FindFirstChild(objectName)
                        
                        if distance <= self._state.EspDistanceLimit and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                            
                            if self._state.EspStyle == "Highlight" then
                                if not existingEsp or not existingEsp:IsA("Highlight") then
                                    if existingEsp then existingEsp:Destroy() end
                                    local highlight = Instance.new("Highlight")
                                    highlight.Name = objectName
                                    highlight.Parent = espFolder
                                    highlight.Adornee = player.Character
                                    existingEsp = highlight
                                end
                                
                                existingEsp.FillColor = self._state.EspColor
                                existingEsp.OutlineColor = self._state.EspColor
                                existingEsp.FillTransparency = self._state.EspTransparency.Fill
                                existingEsp.OutlineTransparency = self._state.EspTransparency.Outline
                            end
                        else
                            if existingEsp then
                                existingEsp:Destroy()
                            end
                        end
                    end
                end
            end
        end)
    end)
    
    self.Janitor:Add(connection, "Disconnect", "EspLoop")
end

function UniversalHex:SetEspColor(color)
    self._state.EspColor = color
    self:_log("INFO", "ESP Color updated.")
end

function UniversalHex:SetEspStyle(style)
    self._state.EspStyle = style
    self:_log("INFO", "ESP Style updated to: " .. style)
    
    if self._state.EspEnabled then
        self:SetEspEnabled(false)
        task.wait()
        self:SetEspEnabled(true)
    end
end

function UniversalHex:SetEspTransparency(fill, outline)
    self._state.EspTransparency.Fill = fill
    self._state.EspTransparency.Outline = outline
end

function UniversalHex:SetEspDistanceLimit(maxDistance)
    self._state.EspDistanceLimit = maxDistance
end

-- Character & Movement Controls

function UniversalHex:SetSpeedEnabled(enabled)
    self._state.SpeedEnabled = enabled
    if not enabled then
        self.Janitor:Remove("SpeedLoop")
        self:_log("INFO", "Speed modifier disabled.")
        return
    end

    self:_log("INFO", "Speed modifier enabled.")
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local _, _, hum = self:_getChar()
            if hum and hum.Health > 0 then
                hum.WalkSpeed = self._state.SpeedValue
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "SpeedLoop")
end

function UniversalHex:SetSpeedValue(speed)
    self._state.SpeedValue = speed
end

function UniversalHex:SetJumpPowerEnabled(enabled)
    self._state.JumpPowerEnabled = enabled
    if not enabled then
        self.Janitor:Remove("JumpLoop")
        self:_log("INFO", "Jump power modifier disabled.")
        return
    end

    self:_log("INFO", "Jump power modifier enabled.")
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
    self._state.NoclipEnabled = enabled
    if not enabled then
        self.Janitor:Remove("NoclipLoop")
        self:_log("INFO", "Noclip disabled.")
        return
    end

    self:_log("INFO", "Noclip enabled.")
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
    self._state.InfiniteJumpEnabled = enabled
    if not enabled then
        self.Janitor:Remove("InfJumpConnection")
        self:_log("INFO", "Infinite Jump disabled.")
        return
    end
    
    self:_log("INFO", "Infinite Jump enabled.")
    local connection = UserInputService.JumpRequest:Connect(function()
        pcall(function()
            local _, _, hum = self:_getChar()
            if hum and hum.Health > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "InfJumpConnection")
end

-- Camera & Environment Utilities

function UniversalHex:SetFovValue(fov)
    pcall(function()
        Camera.FieldOfView = fov
        self:_log("INFO", "Field of View updated to: " .. tostring(fov))
    end)
end

function UniversalHex:SetFullbrightEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("FullbrightLoop")
        
        pcall(function()
            Lighting.Ambient = self._state.OriginalLighting.Ambient
            Lighting.ColorShift_Bottom = self._state.OriginalLighting.ColorShift_Bottom
            Lighting.ColorShift_Top = self._state.OriginalLighting.ColorShift_Top
        end)
        
        self:_log("INFO", "Fullbright disabled. Original lighting restored.")
        return
    end

    self:_log("INFO", "Fullbright enabled.")
    
    local connection = RunService.LightingChanged:Connect(function()
        pcall(function()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
        end)
    end)
    
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    self.Janitor:Add(connection, "Disconnect", "FullbrightLoop")
end

function UniversalHex:TeleportToCFrame(targetCFrame, smooth)
    pcall(function()
        local char, hrp, _ = self:_getChar()
        if not char or not hrp then return end
        
        if smooth then
            self:_log("INFO", "Executing smooth teleport.")
            local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
            tween:Play()
        else
            self:_log("INFO", "Executing direct teleport.")
            char:PivotTo(targetCFrame)
        end
    end)
end

-- Utility & Network Controls

function UniversalHex:SetAntiAfkEnabled(enabled)
    self._state.AntiAfkEnabled = enabled
    
    if not enabled then
        self.Janitor:Remove("AntiAfkConnection")
        self:_log("INFO", "Anti-AFK disabled.")
        return
    end

    self:_log("INFO", "Anti-AFK enabled. Preventing idle disconnects.")
    
    local connection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            self:_log("INFO", "Anti-AFK triggered to prevent timeout.")
        end)
    end)
    
    self.Janitor:Add(connection, "Disconnect", "AntiAfkConnection")
end

function UniversalHex:OptimizeFPS()
    self:_log("WARN", "Executing FPS Optimization. Visual fidelity will be reduced.")
    
    task.spawn(function()
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.ShadowSoftness = 0
            
            if sethiddenproperty then
                pcall(function() sethiddenproperty(Lighting, "Technology", 2) end)
            end

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Clouds") then
                    obj.Enabled = false
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    obj.Enabled = false
                end
            end
            
            self:_log("INFO", "FPS Optimization completed.")
        end)
    end)
end

function UniversalHex:RejoinServer()
    self:_log("INFO", "Initiating server rejoin sequence.")
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

function UniversalHex:ServerHop()
    self:_log("INFO", "Initiating server hop sequence. Searching for optimal servers...")
    
    task.spawn(function()
        pcall(function()
            local serversApi = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
            local requestFunc = syn and syn.request or request or http_request or fluxus and fluxus.request
            
            if not requestFunc then
                self:_log("ERROR", "Executor does not support HTTP requests required for Server Hop.")
                return
            end
            
            local response = requestFunc({
                Url = serversApi,
                Method = "GET"
            })
            
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
                    self:_log("INFO", "Found available server. Teleporting...")
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
                else
                    self:_log("WARN", "No suitable servers found for hopping.")
                end
            else
                self:_log("ERROR", "Failed to fetch server list. HTTP Status: " .. tostring(response.StatusCode))
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
    pcall(function()
        fps = math.floor(workspace:GetRealPhysicsFPS())
    end)
    return fps
end

-- Lifecycle & State Management

function UniversalHex:ResetAll()
    self:_log("WARN", "ResetAll invoked. Returning character and environment to default states.")
    
    self:SetEspEnabled(false)
    self:SetSpeedEnabled(false)
    self:SetJumpPowerEnabled(false)
    self:SetNoclipEnabled(false)
    self:SetInfiniteJumpEnabled(false)
    self:SetFullbrightEnabled(false)
    self:SetAntiAfkEnabled(false)
    self:SetFovValue(70)
end

function UniversalHex:Destroy()
    self:_log("WARN", "Destroy invoked. Nuking UniversalHex from memory.")
    
    self:ResetAll()
    self.Janitor:Destroy()
    table.clear(self._state)
    
    -- Remove from global environment
    if getgenv()[self.ProjectId] == self then
        getgenv()[self.ProjectId] = nil
    end
    
    setmetatable(self, nil)
end

return UniversalHex
