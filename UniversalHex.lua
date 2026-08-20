-- UniversalHex - Advanced Exploit Module
-- Built for scalability, performance, memory safety, and universal utility.
-- Author: VoiderHex

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

-- Loads the Janitor module to handle garbage collection and memory leaks
local Janitor = loadstring(game:HttpGet("https://raw.githubusercontent.com/VoiderHex/Scripts/refs/heads/main/Janitor.lua"))()

local UniversalHex = {}
UniversalHex.__index = UniversalHex

-- Initializes a new UniversalHex instance
function UniversalHex.new(config)
    config = config or {}
    local projectId = config.ProjectId or "UniversalHex_Default"
    
    -- Prevent duplicate instances from running in the same project
    if getgenv()[projectId] then
        pcall(function() getgenv()[projectId]:Destroy() end)
        task.wait(0.1)
    end
    
    local self = setmetatable({}, UniversalHex)
    
    self.Mode = config.Mode or "client"
    self.ProjectId = projectId
    self.Janitor = Janitor.new()
    
    -- Stores default states so we can revert them later if needed
    self._state = {
        SpeedValue = 16,
        JumpPowerValue = 50,
        FlySpeed = 50,
        OriginalLighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd
        }
    }
    
    self._espGroups = {}
    self._espCache = {}
    self._espEngineRunning = false
    
    -- Cache for FPS optimization to restore textures and materials
    self._fpsCache = {
        Materials = {},
        Textures = {},
        Effects = {}
    }
    
    getgenv()[projectId] = self
    self:_log("INFO", "Initialized successfully in " .. self.Mode .. " mode for project: " .. projectId)
    
    return self
end

-- Internal logger for dev mode
function UniversalHex:_log(level, message)
    if self.Mode == "dev" then
        print(string.format("[UniversalHex | %s] %s", string.upper(level), message))
    end
end

-- Safely retrieves local player's character data
function UniversalHex:GetCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

-- Binds UI to Janitor so it cleans up when the script is destroyed
function UniversalHex:AttachUI(uiInstance)
    if typeof(uiInstance) == "Instance" or type(uiInstance) == "table" then
        self.Janitor:Add(uiInstance, "Destroy", "Main_Rayfield_UI")
    end
end

--// =======================================================
--// DYNAMIC ESP ENGINE
--// =======================================================

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
        espFolder.Parent = gethui and gethui() or CoreGui
    end)
    self.Janitor:Add(espFolder, "Destroy", "EspFolder")
    
    local connection = RunService.RenderStepped:Connect(function()
        for groupName, group in pairs(self._espGroups) do
            local currentCache = self._espCache[groupName]
            
            -- Clear highlights if the group is disabled
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
            
            -- Remove highlights for instances that are no longer valid
            for inst, highlight in pairs(currentCache) do
                if not validInstances[inst] or not inst.Parent then
                    highlight:Destroy()
                    currentCache[inst] = nil
                end
            end
            
            -- Create or update highlights for valid instances
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

--// =======================================================
--// COMBAT & DEFENSE
--// =======================================================

-- Protects the user from being flung by other players by stripping collisions and freezing angular velocity
function UniversalHex:SetAntiFlingEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("AntiFlingLoop")
        return
    end
    
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local localChar, hrp, _ = self:GetCharacter()
            if not localChar then return end
            
            -- Kill unexpected intense velocities on our character
            if hrp and (hrp.AssemblyAngularVelocity.Magnitude > 50 or hrp.AssemblyLinearVelocity.Magnitude > 200) then
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            
            -- Disable collisions with other players
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, part in ipairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "AntiFlingLoop")
end

-- Activates a local fling exploit targeting a specific player
function UniversalHex:SetFlingActivate(enabled, targetPlayer)
    if not enabled then
        self.Janitor:Remove("FlingLoop")
        pcall(function()
            local _, hrp, _ = self:GetCharacter()
            if hrp then
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
            end
        end)
        return
    end
    
    local connection = RunService.Heartbeat:Connect(function()
        pcall(function()
            local _, hrp, hum = self:GetCharacter()
            if not hrp or not hum or hum.Health <= 0 then return end
            
            -- Spin the character at extreme speeds
            hrp.RotVelocity = Vector3.new(20000, 20000, 20000)
            
            -- Stick to target
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

--// =======================================================
--// MOVEMENT, FLY & KINEMATICS
--// =======================================================

function UniversalHex:SetSpeedEnabled(enabled)
    if not enabled then self.Janitor:Remove("SpeedLoop") return end
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local _, _, hum = self:GetCharacter()
            if hum and hum.Health > 0 then hum.WalkSpeed = self._state.SpeedValue end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "SpeedLoop")
end
function UniversalHex:SetSpeedValue(speed) self._state.SpeedValue = speed end

function UniversalHex:SetJumpPowerEnabled(enabled)
    if not enabled then self.Janitor:Remove("JumpLoop") return end
    local connection = RunService.Stepped:Connect(function()
        pcall(function()
            local _, _, hum = self:GetCharacter()
            if hum and hum.Health > 0 then
                hum.UseJumpPower = true 
                hum.JumpPower = self._state.JumpPowerValue
            end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "JumpLoop")
end
function UniversalHex:SetJumpPowerValue(power) self._state.JumpPowerValue = power end

function UniversalHex:SetNoclipEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("NoclipLoop")
        pcall(function()
            local _, _, hum = self:GetCharacter()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
        end)
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
    if not enabled then self.Janitor:Remove("InfJumpConnection") return end
    local connection = UserInputService.JumpRequest:Connect(function()
        pcall(function()
            local _, _, hum = self:GetCharacter()
            if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "InfJumpConnection")
end

function UniversalHex:SetFlySpeed(speed)
    self._state.FlySpeed = speed
end

-- Implements a smooth BodyMover-based flight system
function UniversalHex:SetFlyEnabled(enabled)
    if not enabled then
        self.Janitor:Remove("FlyInputBegan")
        self.Janitor:Remove("FlyInputEnded")
        self.Janitor:Remove("FlyLoop")
        self.Janitor:Remove("FlyBG")
        self.Janitor:Remove("FlyBV")
        
        local _, _, hum = self:GetCharacter()
        if hum then hum.PlatformStand = false end
        return
    end

    local char, hrp, hum = self:GetCharacter()
    if not char or not hrp or not hum then return end

    hum.PlatformStand = true
    
    local bg = Instance.new("BodyGyro", hrp)
    bg.P = 9e4
    bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    self.Janitor:Add(bg, "Destroy", "FlyBG")
    
    local bv = Instance.new("BodyVelocity", hrp)
    bv.velocity = Vector3.new(0, 0.1, 0)
    bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
    self.Janitor:Add(bv, "Destroy", "FlyBV")
    
    local flyCtrl = {f = 0, b = 0, l = 0, r = 0}

    self.Janitor:Add(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.W then flyCtrl.f = 1
        elseif input.KeyCode == Enum.KeyCode.S then flyCtrl.b = -1
        elseif input.KeyCode == Enum.KeyCode.A then flyCtrl.l = -1
        elseif input.KeyCode == Enum.KeyCode.D then flyCtrl.r = 1 end
    end), "Disconnect", "FlyInputBegan")

    self.Janitor:Add(UserInputService.InputEnded:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.W then flyCtrl.f = 0
        elseif input.KeyCode == Enum.KeyCode.S then flyCtrl.b = 0
        elseif input.KeyCode == Enum.KeyCode.A then flyCtrl.l = 0
        elseif input.KeyCode == Enum.KeyCode.D then flyCtrl.r = 0 end
    end), "Disconnect", "FlyInputEnded")

    self.Janitor:Add(RunService.RenderStepped:Connect(function()
        local _, currHrp, _ = self:GetCharacter()
        if not currHrp or not bg or not bv then return end
        
        local speed = self._state.FlySpeed
        local moveDir = Vector3.zero
        
        if (flyCtrl.l + flyCtrl.r) ~= 0 or (flyCtrl.f + flyCtrl.b) ~= 0 then
            moveDir = (Camera.CFrame.LookVector * (flyCtrl.f + flyCtrl.b)) + (Camera.CFrame.RightVector * (flyCtrl.r + flyCtrl.l))
            bv.velocity = moveDir * speed
        else
            bv.velocity = Vector3.new(0, 0.1, 0) 
        end
        bg.cframe = Camera.CFrame
    end), "Disconnect", "FlyLoop")
end

--// =======================================================
--// WORLD & TELEPORT UTILITIES
--// =======================================================

function UniversalHex:Teleport(targetCFrame)
    local char, hrp, _ = self:GetCharacter()
    if not char or not hrp then return false end
    pcall(function() char:PivotTo(targetCFrame) end)
    return true
end

function UniversalHex:CancelTween()
    self.Janitor:Remove("CurrentTweenConn")
    self.Janitor:Remove("CurrentTweenAction")
end

-- Moves the player smoothly to a target CFrame, anchoring them during transit to prevent anti-cheat glitches
function UniversalHex:TweenTo(targetCFrame, speed, yield)
    self:CancelTween()
    local char, hrp, hum = self:GetCharacter()
    if not hrp or not hum then return false end
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local timeToTake = distance / (speed or 50)
    
    local tweenInfo = TweenInfo.new(timeToTake, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    local wasAnchored = hrp.Anchored
    hrp.Anchored = true 
    
    local completed = false
    local conn = tween.Completed:Connect(function()
        completed = true
        if hrp then hrp.Anchored = wasAnchored end
    end)
    
    self.Janitor:Add(conn, "Disconnect", "CurrentTweenConn")
    self.Janitor:Add(function()
        if tween.PlaybackState == Enum.PlaybackState.Playing then tween:Cancel() end
        if hrp then hrp.Anchored = wasAnchored end
    end, true, "CurrentTweenAction")
    
    tween:Play()
    
    if yield then
        while not completed and getgenv()[self.ProjectId.."_Active"] do
            task.wait(0.01)
        end
    end
    return true
end

-- Simulates touching a part via the Roblox engine
function UniversalHex:TouchPart(part)
    local _, hrp, _ = self:GetCharacter()
    if hrp and part and part:FindFirstChild("TouchInterest") then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait(0.01)
            firetouchinterest(hrp, part, 1)
        end)
        return true
    end
    return false
end

--// =======================================================
--// SYSTEM & NETWORK CONTROLS
--// =======================================================

function UniversalHex:SetAntiAfkEnabled(enabled)
    if not enabled then self.Janitor:Remove("AntiAfkConnection") return end
    local connection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
    self.Janitor:Add(connection, "Disconnect", "AntiAfkConnection")
end

-- Modifies visuals to reduce rendering cost
function UniversalHex:_applyOptimization(obj, extremeMode)
    pcall(function()
        if obj:IsA("BasePart") then
            if not extremeMode and not self._fpsCache.Materials[obj] then
                self._fpsCache.Materials[obj] = obj.Material
            end
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
            
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            -- Properly unparenting textures usually gives better performance than transparency
            if not extremeMode and self._fpsCache.Textures[obj] == nil then
                self._fpsCache.Textures[obj] = obj.Parent
            end
            obj.Parent = nil
            
        elseif obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            if not extremeMode and self._fpsCache.Effects[obj] == nil then
                self._fpsCache.Effects[obj] = obj.Enabled
            end
            obj.Enabled = false
        end
    end)
end

-- Toggles map graphics to increase FPS
function UniversalHex:SetAutoOptimizeFPS(enabled, extremeMode)
    if not enabled then
        self.Janitor:Remove("AutoFPS")
        
        -- Restore all cached properties
        pcall(function()
            Lighting.GlobalShadows = self._state.OriginalLighting.GlobalShadows
            Lighting.FogEnd = self._state.OriginalLighting.FogEnd
            
            for part, mat in pairs(self._fpsCache.Materials) do
                if part and part.Parent then part.Material = mat end
            end
            for tex, parent in pairs(self._fpsCache.Textures) do
                if tex then tex.Parent = parent end
            end
            for effect, state in pairs(self._fpsCache.Effects) do
                if effect and effect.Parent then effect.Enabled = state end
            end
        end)
        
        table.clear(self._fpsCache.Materials)
        table.clear(self._fpsCache.Textures)
        table.clear(self._fpsCache.Effects)
        
        self:_log("INFO", "FPS Optimization disabled. Visuals restored.")
        return
    end

    self:_log("INFO", "FPS Optimization enabled.")
    
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

-- Safely rejoins the server with a fallback to avoid "Cannot teleport to empty instance id" warning
function UniversalHex:RejoinServer()
    local success, err = pcall(function()
        -- Ensure game.JobId exists. If empty, fallback to simple place teleport.
        if game.JobId == "" or #Players:GetPlayers() <= 1 then
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
    
    if not success then
        self:_log("WARN", "Rejoin failed or blocked by executor: " .. tostring(err))
    end
end

-- Finds an active public server and teleports the user to it securely
function UniversalHex:ServerHop()
    task.spawn(function()
        local requestFunc = (getgenv and getgenv().request) or request or http_request or (syn and syn.request)
        
        if requestFunc then
            local success, response = pcall(function()
                return requestFunc({
                    Url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100",
                    Method = "GET"
                })
            end)
            
            if success and response and response.Body then
                local decodeSuccess, data = pcall(function()
                    return HttpService:JSONDecode(response.Body)
                end)
                
                if decodeSuccess and data and data.data then
                    local availableServers = {}
                    for _, server in ipairs(data.data) do
                        if type(server) == "table" and server.playing and server.maxPlayers and server.id then
                            -- Critical: Ensure server.id is not empty before validating
                            if server.id ~= "" and server.playing < (server.maxPlayers - 1) and server.id ~= game.JobId then
                                table.insert(availableServers, server.id)
                            end
                        end
                    end
                    
                    if #availableServers > 0 then
                        local randomServer = availableServers[math.random(1, #availableServers)]
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
                        end)
                        return
                    end
                end
            end
        end
        
        -- Fallback if HTTP request fails, returns empty IDs, or no valid servers are found
        self:_log("WARN", "HTTP request failed or no valid server IDs found. Using native Teleport fallback.")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end

function UniversalHex:GetPing()
    local ping = 0
    pcall(function() ping = tonumber(Stats.Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 0 end)
    return ping
end

function UniversalHex:GetFPS()
    local fps = 0
    pcall(function() fps = math.floor(workspace:GetRealPhysicsFPS()) end)
    return fps
end

-- Tears down the framework and releases all memory hooks
function UniversalHex:Destroy()
    self:_log("WARN", "Destroying UniversalHex environment.")
    self:SetSpeedEnabled(false)
    self:SetJumpPowerEnabled(false)
    self:SetNoclipEnabled(false)
    self:SetFlyEnabled(false)
    self:SetInfiniteJumpEnabled(false)
    self:SetAntiAfkEnabled(false)
    self:SetFlingActivate(false)
    self:SetAntiFlingEnabled(false)
    self:SetAutoOptimizeFPS(false, false)
    self:CancelTween()
    
    for _, group in pairs(self._espGroups) do group:SetEnabled(false) end
    
    self.Janitor:Destroy()
    table.clear(self._state)
    table.clear(self._espGroups)
    
    if getgenv()[self.ProjectId] == self then getgenv()[self.ProjectId] = nil end
    setmetatable(self, nil)
end

return UniversalHex
