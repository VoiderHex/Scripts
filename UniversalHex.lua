--  - Advanced Exploit Module

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Janitor = loadstring(game:HttpGet("https://raw.githubusercontent.com/VoiderHex/Scripts/refs/heads/main/Janitor.lua"))()

local UniversalHex = {}
UniversalHex.__index = UniversalHex

-- Constructor
function UniversalHex.new(config)
    config = config or {}
    
    local self = setmetatable({}, UniversalHex)
    
    self.Mode = config.Mode or "client"
    self.Janitor = Janitor.new()
    
    -- Centralized state storage to keep track of current configurations
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
        
        -- Environment Cache (so we can restore them later)
        OriginalLighting = {
            Ambient = Lighting.Ambient,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            ColorShift_Top = Lighting.ColorShift_Top
        }
    }
    
    self:_log("INFO", "UniversalHex initialized successfully in " .. self.Mode .. " mode.")
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
    
    -- Create a secure folder in CoreGui to hide our visual instances from the game
    local espFolder = Instance.new("Folder")
    espFolder.Name = "UniversalHex_ESP"
    
    -- Protect the folder assignment with pcall in case the executor lacks CoreGui permissions
    pcall(function()
        if gethui then
            espFolder.Parent = gethui()
        else
            espFolder.Parent = CoreGui
        end
    end)
    
    self.Janitor:Add(espFolder, "Destroy", "EspFolder")
    
    -- Setup the render loop
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
                        
                        -- Manage distance limits and rendering
                        if distance <= self._state.EspDistanceLimit and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                            
                            -- Logic for Highlight Style
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
                            
                            -- NOTE: For Box, Tracer, and Text styles, you would use Camera:WorldToViewportPoint()
                            -- coupled with Drawing API (if supported) or 2D Frames here. 
                            -- Leaving the Highlight logic active as the primary robust example.
                            
                        else
                            -- Target is out of range or dead, clean up their specific ESP instance
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
    -- Trigger a reset of the ESP to apply the new style immediately
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
                -- Force the game to use JumpPower instead of JumpHeight if needed
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
        
        -- Restore original lighting settings gracefully
        pcall(function()
            Lighting.Ambient = self._state.OriginalLighting.Ambient
            Lighting.ColorShift_Bottom = self._state.OriginalLighting.ColorShift_Bottom
            Lighting.ColorShift_Top = self._state.OriginalLighting.ColorShift_Top
        end)
        
        self:_log("INFO", "Fullbright disabled. Original lighting restored.")
        return
    end

    self:_log("INFO", "Fullbright enabled. Let there be light!")
    
    -- We use a loop because many games actively try to reset the lighting to make it dark again
    local connection = RunService.LightingChanged:Connect(function()
        pcall(function()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
            Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
        end)
    end)
    
    -- Force trigger it immediately
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    
    self.Janitor:Add(connection, "Disconnect", "FullbrightLoop")
end

function UniversalHex:TeleportToCFrame(targetCFrame, smooth)
    pcall(function()
        local char, hrp, _ = self:_getChar()
        if not char or not hrp then return end
        
        if smooth then
            self:_log("INFO", "Executing smooth teleport.")
            local tweenInfo = TweenInfo.new(
                1, -- 1 second duration, you can parameterize this later
                Enum.EasingStyle.Linear
            )
            local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
            tween:Play()
        else
            self:_log("INFO", "Executing direct teleport.")
            char:PivotTo(targetCFrame)
        end
    end)
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
    self:SetFovValue(70) -- Standard Roblox FOV
end

function UniversalHex:Destroy()
    self:_log("WARN", "Destroy invoked. Nuking UniversalHex from memory.")
    
    -- First, cleanly revert changes applied to the environment
    self:ResetAll()
    
    -- Wipe all connections, threads, and instances tracked by the Janitor
    self.Janitor:Destroy()
    
    -- Clear out our state dictionary completely
    table.clear(self._state)
    
    -- Render the module table unusable to catch any lingering references
    setmetatable(self, nil)
end

return UniversalHex
