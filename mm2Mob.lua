--// VoiderHex Hub - MM2 Module
--// Integrated with UniversalHex Framework (MOBILE EDITION v1.9-M)
local IS_BETA = true
local SCRIPT_VERSION = "1.9-M"
local HUB_NAME = "VoiderHex"
local PROJECT_ID = HUB_NAME .. "_MM2_Mobile"

local SYSTEM_LOADING = true 
getgenv()[HUB_NAME .. "_Drawings"] = getgenv()[HUB_NAME .. "_Drawings"] or {}
if getgenv()[PROJECT_ID .. "_Cleanup"] then pcall(getgenv()[PROJECT_ID .. "_Cleanup"]) end
getgenv()[PROJECT_ID .. "_Active"] = true

local Players = game:GetService("Players")

getgenv()[PROJECT_ID .. "_Cleanup"] = function()
    getgenv()[PROJECT_ID .. "_Active"] = false
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            for _, child in ipairs(player.Character:GetDescendants()) do
                if child.Name == "PlayerHighlight" or child.Name == "ChamsAdornment" or child.Name == HUB_NAME.."OwnerTag" then pcall(function() child:Destroy() end) end
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "HighCoin" or obj.Name == "HighGun" then pcall(function() obj:Destroy() end) end
    end
    if getgenv()[HUB_NAME .. "_Drawings"] then
        for _, draw in ipairs(getgenv()[HUB_NAME .. "_Drawings"]) do pcall(function() draw:Remove() end) end
    end
    table.clear(getgenv()[HUB_NAME .. "_Drawings"])
    if getgenv()[HUB_NAME .. "_Rayfield"] then pcall(function() getgenv()[HUB_NAME .. "_Rayfield"]:Destroy() end) end
    
    -- Cleanup Mobile HUDs
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if string.find(gui.Name, HUB_NAME .. "_MobileBtn_") then gui:Destroy() end
    end
end

local UniversalHex = loadstring(game:HttpGet("https://raw.githubusercontent.com/VoiderHex/Scripts/refs/heads/main/UniversalHex.lua"))()
local Hex = UniversalHex.new({ Mode = "client", ProjectId = PROJECT_ID })
Hex.Janitor:Add(function() pcall(getgenv()[PROJECT_ID .. "_Cleanup"]) end, true)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
getgenv()[HUB_NAME .. "_Rayfield"] = Rayfield
Hex:AttachUI(Rayfield)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local GameplayRemotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local FadeEvent = GameplayRemotes and GameplayRemotes:WaitForChild("Gameplay", 5) and GameplayRemotes.Gameplay:WaitForChild("Fade", 5)
local VictoryEvent = GameplayRemotes and GameplayRemotes.Gameplay:WaitForChild("VictoryScreen", 5)
local PlayerDataEvent = GameplayRemotes and GameplayRemotes.Gameplay:WaitForChild("PlayerDataChanged", 5)

local function getCharacterData()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local UI_INTERACTION_NOTIFS = true
local function NotifyAlert(title, content, duration) pcall(function() Rayfield:Notify({Title = title, Content = content, Duration = duration or 3, Image = 4483362458}) end) end
local function UIToggleNotify(featureName, state) if not UI_INTERACTION_NOTIFS or SYSTEM_LOADING then return end NotifyAlert("Feature Updated", featureName .. " is now " .. (state and "ON" or "OFF"), 1.5) end
local function UIButtonNotify(actionName) if not UI_INTERACTION_NOTIFS or SYSTEM_LOADING then return end NotifyAlert("Action Triggered", actionName .. " executed.", 1.5) end

local ESPGLOBAL, ESPGUN, ESP_M_S, ESPCOIN, ESPTEXT, ESPTRACER = false, false, false, false, false, false
local ESP_STYLE = "Highlight"
local AUTOGUN, NOTIFY_GUN, NOTIFY_ROLES, NOTIFY_FARM, NOTIFY_COMBAT = false, false, false, true, true
local SpinbotActive, SpinbotSpeed, spinbotConn = false, 20, nil
local AutoFlingMurderer, AutoFlingSheriff = false, false
local FlungThisRound = {Murderer = false, Sheriff = false}

local lastGunState, knownMurderer, knownSheriff, knownHero = false, nil, nil, nil
local MatchPlayers, isKillingAll = {}, false

local colorMurder, colorSheriff, colorHero, colorInnocent = Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(0, 255, 0)
local colorGunDrop, colorCoin = Color3.fromRGB(255, 100, 0), Color3.fromRGB(212, 175, 55)

local TableMM = {["Murderer"] = nil, ["Sheriff"] = nil, ["Hero"] = nil}
local isFarmActive, farmMethod, farmSpeed, tweenWaitDelay = false, "Walk", 50, 0.2
local isTeleportingGun, iAmDead, bagFullNotified = false, false, false
local totalSessionCoins, coinsThisRound, processedCoins = 0, 0, {}
local autoResetOnFull, autoKillAtMaxCoins, SessionCoinLabel = false, false, nil 
local cachedCoinContainer = nil
local currentAvatarAnim, gameEmoteSelected = "Anthro (Default)", "zen"

local function getSheriffOrHero()
    local hero = TableMM["Hero"] if hero and hero.Character and hero.Character:FindFirstChild("HumanoidRootPart") and hero.Character:FindFirstChild("Humanoid") and hero.Character.Humanoid.Health > 0 then return hero end
    local sheriff = TableMM["Sheriff"] if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("HumanoidRootPart") and sheriff.Character:FindFirstChild("Humanoid") and sheriff.Character.Humanoid.Health > 0 then return sheriff end
    return nil
end

local function findNewCoinContainer()
    if cachedCoinContainer and cachedCoinContainer.Parent then return cachedCoinContainer end
    local map = workspace:FindFirstChild("Normal") or workspace:FindFirstChild("Map")
    if map then cachedCoinContainer = map:FindFirstChild("CoinContainer", true) end
    if not cachedCoinContainer then for _, obj in ipairs(workspace:GetDescendants()) do if obj.Name == "CoinContainer" then cachedCoinContainer = obj break end end end
    return cachedCoinContainer
end

local function clearCoinESP() local container = findNewCoinContainer() if container then for _, obj in ipairs(container:GetDescendants()) do if obj.Name == "HighCoin" then pcall(function() obj:Destroy() end) end end end end
local function clearGunESP() local gunObj = workspace:FindFirstChild("GunDrop", true) if gunObj then local hl = gunObj:FindFirstChild("HighGun") if hl then pcall(function() hl:Destroy() end) end end end

local function handleMatchReset()
    iAmDead = false coinsThisRound = 0 bagFullNotified = false table.clear(processedCoins) cachedCoinContainer = nil
    TableMM["Murderer"] = nil TableMM["Sheriff"] = nil TableMM["Hero"] = nil
    knownMurderer = nil knownSheriff = nil knownHero = nil
    FlungThisRound.Murderer = false FlungThisRound.Sheriff = false
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then 
            for _, child in ipairs(player.Character:GetDescendants()) do 
                if child.Name == "PlayerHighlight" or child.Name == "ChamsAdornment" or (child:IsA("BillboardGui") and child.Name ~= HUB_NAME.."OwnerTag") then pcall(function() child:Destroy() end) end 
            end 
        end
    end
    clearCoinESP() clearGunESP()
end

local function applyGodMode()
    local char, _, _ = getCharacterData() if not char then return end
    local oldHum = char:FindFirstChild("Humanoid") if not oldHum or oldHum.Name ~= "Humanoid" then return end
    for _, acc in ipairs(char:GetChildren()) do if acc:IsA("Accessory") or acc:IsA("Hat") then acc:Destroy() end end
    local head = char:FindFirstChild("Head") if head then local face = head:FindFirstChild("face") or head:FindFirstChild("Face") if face then face:Destroy() end end
    local animate = char:FindFirstChild("Animate") if animate then animate.Disabled = true end
    oldHum.Name = "deku" local newHum = oldHum:Clone() newHum.Name = "Humanoid" newHum.Parent = char
    Camera.CameraSubject = newHum newHum.HipHeight = -1.5 
    newHum.Died:Connect(function() local h = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") if h then Camera.CameraSubject = h end end)
    task.wait(0.1) if not getgenv()[PROJECT_ID.."_Active"] then return end
    if char:FindFirstChild("deku") then char.deku:Destroy() end if animate then animate.Disabled = false end
    if NOTIFY_COMBAT then NotifyAlert("God Mode", "Classic bypass applied.") end
end

local AI_Patch = {}
local ai_loopActive, ai_stopCurrentMovement, ai_coinFolder = false, false, nil
local ai_path = PathfindingService:CreatePath({AgentRadius = 1.5, AgentHeight = 4.0, AgentCanJump = true, AgentJumpHeight = 7, AgentMaxSlope = 45, WaypointSpacing = 2})

function AI_Patch.Configure(config) ai_coinFolder, farmMethod, farmSpeed = config.Folder, config.Method or "Walk", config.Speed or 50 end
function AI_Patch.StopMovement() ai_stopCurrentMovement = true Hex:CancelTween() end

function AI_Patch.MoveTo(destination)
    ai_stopCurrentMovement = false
    local _, hrp, hum = getCharacterData() if not hrp or not hum or iAmDead then return false end
    local targetPosition = typeof(destination) == "Vector3" and destination or (destination:IsA("BasePart") and destination.Position) if not targetPosition then return false end

    if farmMethod == "Walk" then
        local success, _ = pcall(function() ai_path:ComputeAsync(hrp.Position, targetPosition) end)
        if not success or ai_path.Status ~= Enum.PathStatus.Success then hum:MoveTo(targetPosition) task.wait(1) if typeof(destination) == "Instance" then Hex:TouchPart(destination) end return true end
        for _, waypoint in ipairs(ai_path:GetWaypoints()) do
            if not getgenv()[PROJECT_ID.."_Active"] or ai_stopCurrentMovement or iAmDead or not isFarmActive then return false end
            local raycastResult = workspace:Raycast(hrp.Position, (waypoint.Position - hrp.Position).Unit * 4)
            if raycastResult or waypoint.Action == Enum.PathWaypointAction.Jump or (waypoint.Position.Y - hrp.Position.Y > 3) then if hum:GetState() ~= Enum.HumanoidStateType.Jumping then hum.Jump = true task.wait(0.3) end end
            hum:MoveTo(waypoint.Position)
            if not hum.MoveToFinished:Wait(1.0) then hum.Jump = true task.wait(0.4) end
        end
    else
        Hex:TweenTo(CFrame.new(targetPosition), farmSpeed, true)
        if tweenWaitDelay > 0 then task.wait(tweenWaitDelay) end
    end
    if typeof(destination) == "Instance" then Hex:TouchPart(destination) end return true
end

function AI_Patch.StartCollection()
    if ai_loopActive or iAmDead or not ai_coinFolder then return end
    ai_loopActive = true
    task.spawn(function()
        while getgenv()[PROJECT_ID.."_Active"] and ai_loopActive and not iAmDead and isFarmActive do
            if coinsThisRound >= 40 then
                if not bagFullNotified then
                    bagFullNotified = true
                    local isMurderer = (TableMM["Murderer"] == LocalPlayer)
                    if isMurderer and autoKillAtMaxCoins then 
                        if performKillAllFunc then performKillAllFunc() end
                    elseif not isMurderer and autoResetOnFull then 
                        local _, _, hum = getCharacterData() 
                        if hum and hum.Health > 0 then iAmDead = true AI_Patch.StopCollection() hum.Health = 0 end
                    else AI_Patch.StopCollection() end
                end
                break
            end
            
            local _, hrp, _ = getCharacterData() if not hrp then task.wait(1) continue end
            local closestCoin, shortestDistance = nil, math.huge
            for _, obj in ipairs(ai_coinFolder:GetChildren()) do
                local targetPart = (obj.Name == "Coin_Server" and obj:FindFirstChild("CoinVisual")) or (obj:IsA("BasePart") and obj)
                if targetPart and not processedCoins[targetPart] then local dist = (hrp.Position - targetPart.Position).Magnitude if dist < shortestDistance then shortestDistance = dist closestCoin = targetPart end end
            end
            
            if closestCoin then
                if AI_Patch.MoveTo(closestCoin) and not processedCoins[closestCoin] then 
                    processedCoins[closestCoin] = true 
                    pcall(function() game:GetService("ReplicatedStorage").Remotes.Gameplay.CoinCollected:FireServer("Coin", 12, 40, {["Value"] = 1}) end)
                    totalSessionCoins, coinsThisRound = totalSessionCoins + 1, coinsThisRound + 1
                    if SessionCoinLabel then SessionCoinLabel:Set("Total Coins: " .. tostring(totalSessionCoins)) end 
                    task.wait(0.2) pcall(function() closestCoin:Destroy() end)
                else task.wait(0.5) end
            else task.wait(0.5) end
        end
    end)
end

function AI_Patch.StopCollection() ai_loopActive = false AI_Patch.StopMovement() end
local function setFarmState(isEnabled) isFarmActive = isEnabled if not isEnabled then AI_Patch.StopCollection() end end

local function teleportToGunFunc()
    if isTeleportingGun or iAmDead or TableMM["Murderer"] == LocalPlayer then return end
    local gunDrop = workspace:FindFirstChild("GunDrop", true) if not gunDrop then return end
    isTeleportingGun = true 
    pcall(function() ReplicatedStorage.Remotes.Gameplay.GiveWeapon:FireServer("Gun") end)
    task.wait(0.15)
    local hasGun = LocalPlayer.Character:FindFirstChild("Gun") or LocalPlayer.Backpack:FindFirstChild("Gun")
    if not hasGun and gunDrop:IsA("BasePart") then
        local _, hrp, _ = getCharacterData()
        if hrp then
            local oldCFrame = gunDrop.CFrame gunDrop.CFrame = hrp.CFrame task.wait(0.05) Hex:TouchPart(gunDrop) task.wait(0.05)
            if gunDrop.Parent then gunDrop.CFrame = oldCFrame end
        end
    end
    task.wait(0.8) isTeleportingGun = false
end

--// MOBILE HUD ENGINE (Touch & Drag)
local MobileHUD = {}
local function CreateMobileButton(id, text, pos, colorHex, callback)
    if MobileHUD[id] then MobileHUD[id]:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = HUB_NAME .. "_MobileBtn_" .. id
    pcall(function() sg.Parent = gethui and gethui() or game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    Hex.Janitor:Add(sg, "Destroy", sg.Name)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Parent = sg
    
    local uiCorner = Instance.new("UICorner") uiCorner.CornerRadius = UDim.new(1, 0) uiCorner.Parent = btn
    local uiStroke = Instance.new("UIStroke") uiStroke.Color = colorHex or Color3.fromRGB(85, 0, 255) uiStroke.Thickness = 2 uiStroke.Parent = btn
    
    local dragging, dragStart, startPos, isClick = false, nil, nil, true
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true isClick = true dragStart = input.Position startPos = btn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then isClick = false btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false if isClick then callback() end
        end
    end)
    MobileHUD[id] = sg
end

local function ToggleHUD(id, state, text, pos, color, callback)
    if state then CreateMobileButton(id, text, pos, color, callback)
    elseif MobileHUD[id] then MobileHUD[id]:Destroy() MobileHUD[id] = nil end
end
--// =======================================================
--// 11. COMBAT OVERHAUL (NETWORK BYPASS SILENT AIM)
--// =======================================================

local function getGun()
    local char, _, _ = getCharacterData()
    if char and char:FindFirstChild("Gun") then return char.Gun end
    if LocalPlayer.Backpack:FindFirstChild("Gun") then return LocalPlayer.Backpack.Gun end
    local function scanGun(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and (string.find(string.lower(item.Name), "gun") or string.find(string.lower(item.Name), "revolver") or item:FindFirstChild("Shoot")) then return item end
        end
    end
    return scanGun(char) or scanGun(LocalPlayer.Backpack)
end

local function LocalBringAndKill(targetChar, knife)
    local _, myRoot, _ = Hex:GetCharacter()
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end
    
    local originalCFrame = targetRoot.CFrame
    for _, part in ipairs(targetChar:GetDescendants()) do 
        if part:IsA("BasePart") then part.CanCollide = false part.Transparency = 1 
        elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 1 end 
    end
    
    targetRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -2.5)
    task.wait(0.05) knife:Activate() task.wait(0.05)
    if targetRoot and targetRoot.Parent then targetRoot.CFrame = originalCFrame end
end

getgenv().performKillAllFunc = function()
    if iAmDead or isKillingAll then return end
    local myChar, _, myHum = Hex:GetCharacter()
    local knife = myChar and (myChar:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife"))
    if not knife then return end

    isKillingAll = true
    task.spawn(function()
        if knife.Parent == LocalPlayer.Backpack then myHum:EquipTool(knife) task.wait(0.2) end
        while getgenv()[PROJECT_ID.."_Active"] and isKillingAll and not iAmDead do
            local targetsAlive = 0
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local pData = MatchPlayers[player.Name]
                    if pData and not pData.Dead and not pData.Killed then
                        local char = player.Character
                        local targetHum = char and char:FindFirstChildOfClass("Humanoid")
                        if targetHum and targetHum.Health > 0 then
                            targetsAlive = targetsAlive + 1
                            LocalBringAndKill(char, knife)
                        end
                    end
                end
            end
            if targetsAlive == 0 then break end
            task.wait(0.1)
        end
        isKillingAll = false
    end)
end

-- Network Direct Shoot (Always Torso)
local function performShoot(targetRoot)
    local gun = getGun()
    if not gun then return end
    local char, myRoot, _ = getCharacterData()
    
    local pingOffset = math.clamp(Hex:GetPing() / 1000, 0.05, 0.2)
    local predictedPos = targetRoot.Position + (targetRoot.AssemblyLinearVelocity * pingOffset)
    
    local shootEvent = gun:FindFirstChild("Shoot")
    if shootEvent then
        local origin = myRoot.CFrame
        local att = myRoot:FindFirstChild("GunRaycastAttachment")
        if att then origin = att.WorldCFrame end
        
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(predictedPos.X, myRoot.Position.Y, predictedPos.Z))
        shootEvent:FireServer(origin, CFrame.new(predictedPos))
        
        pcall(function()
            local handle = gun:FindFirstChild("Handle")
            local weaponService = ReplicatedStorage:FindFirstChild("ClientServices") and ReplicatedStorage.ClientServices:FindFirstChild("WeaponService")
            if weaponService and weaponService:FindFirstChild("GunFired") and handle then
                weaponService.GunFired:FireServer(handle, origin.Position, predictedPos, targetRoot)
            end
        end)
        if NOTIFY_COMBAT then NotifyAlert("Assassination", "Target Executed!") end
    end
end

local function executeRealKill(targetRole)
    if iAmDead then return end
    local target = (targetRole == "Sheriff") and getSheriffOrHero() or TableMM["Murderer"]
    if not target or not target.Character then return end

    local myChar, myRoot, _ = Hex:GetCharacter() 
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    if targetRole == "Sheriff" then 
        local tool = myChar:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
        if not tool then return end
        local _, _, hum = getCharacterData()
        if tool.Parent == LocalPlayer.Backpack and hum then hum:EquipTool(tool) task.wait(0.3) end
        LocalBringAndKill(target.Character, tool)
        if NOTIFY_COMBAT then NotifyAlert("Assassination", "Sheriff Down!") end
    else
        local gun = getGun()
        if not gun then return end
        local _, _, hum = getCharacterData()
        if gun.Parent == LocalPlayer.Backpack and hum then hum:EquipTool(gun) task.wait(0.3) end
        task.spawn(function()
            if not getgenv()[PROJECT_ID.."_Active"] or iAmDead then return end
            performShoot(targetRoot) 
        end)
    end
end

--// =======================================================
--// 12. EVENT CONNECTIONS & BACKGROUND LOOPS
--// =======================================================
if PlayerDataEvent then
    Hex.Janitor:Add(PlayerDataEvent.OnClientEvent:Connect(function(data)
        if data then
            for plrName, pData in pairs(data) do MatchPlayers[plrName] = pData end
            local myData = data[LocalPlayer.Name]
            if myData and (myData.Dead or myData.Killed) and not iAmDead then iAmDead = true AI_Patch.StopCollection() end
        end
    end), "Disconnect")
end

if FadeEvent then
    Hex.Janitor:Add(FadeEvent.OnClientEvent:Connect(function(data)
        handleMatchReset() MatchPlayers = data or {} 
        for playerName, playerData in pairs(data) do
            local playerResult = Players:FindFirstChild(playerName)
            if playerResult then
                if playerData.Role == "Murderer" then TableMM["Murderer"] = playerResult
                elseif playerData.Role == "Sheriff" then TableMM["Sheriff"], OriginalSheriff = playerResult, playerResult end
            end
        end
    end), "Disconnect")
end

if VictoryEvent then Hex.Janitor:Add(VictoryEvent.OnClientEvent:Connect(function() handleMatchReset() end), "Disconnect") end
if ReloadFuncs then Hex.Janitor:Add(ReloadFuncs.OnClientEvent:Connect(function() handleMatchReset() end), "Disconnect") end

task.spawn(function()
    while getgenv()[PROJECT_ID.."_Active"] do
        task.wait(0.1)
        if isFarmActive and not ai_loopActive and not iAmDead then
            local currentContainer = findNewCoinContainer()
            if currentContainer then AI_Patch.Configure({Folder = currentContainer, Method = farmMethod, Speed = farmSpeed}) AI_Patch.StartCollection() end
        end
        local currentGunDrop = workspace:FindFirstChild("GunDrop", true)
        if AUTOGUN and not isTeleportingGun and currentGunDrop and not iAmDead then teleportToGunFunc() end
    end
end)

--// =======================================================
--// 13. UI BUILDER (MOBILE OPTIMIZED)
--// =======================================================
local UI_Title = "MM2 Mobile 📱" .. BetaTag
local Window = Rayfield:CreateWindow({
   Name = UI_Title, LoadingTitle = UI_Title, LoadingSubtitle = "by "..HUB_NAME,
   ConfigurationSaving = { Enabled = true, FolderName = HUB_NAME.."HubConfigs", FileName = "MM2_MobileConfig" }
})

-- 🏠 HOME TAB
local MainTab = Window:CreateTab("🏠 Home", nil)
MainTab:CreateButton({Name = "Join Random Server", Callback = function() Hex:ServerHop() end})
MainTab:CreateButton({Name = "Rejoin Current Server", Callback = function() Hex:RejoinServer() end})
MainTab:CreateToggle({Name = "FPS Booster (Hide Textures)", CurrentValue = getgenv()[HUB_NAME.."_OptState"], Flag = "MobileOptToggle", Callback = function(Value) getgenv()[HUB_NAME.."_OptState"] = Value Hex:SetAutoOptimizeFPS(Value, false) end})
MainTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Flag = "InfJumpToggle", Callback = function(Value) Hex:SetInfiniteJumpEnabled(Value) end})
MainTab:CreateSlider({Name = "WalkSpeed", Range = {16, 200}, Increment = 1, Suffix = "", CurrentValue = 16, Flag = "sliderws", Callback = function(Value) Hex:SetSpeedValue(Value) Hex:SetSpeedEnabled(Value > 16) end})

-- 💰 FARMING TAB
local FarmTab = Window:CreateTab("💰 Farm", nil)
FarmTab:CreateDropdown({Name = "Movement", Options = {"Walk", "Tween"}, CurrentOption = {"Walk"}, MultipleOptions = false, Flag = "FarmMethodDropdown", Callback = function(Option) farmMethod = Option[1] end})
FarmTab:CreateSlider({Name = "Speed", Range = {10, 50}, Increment = 1, Suffix = "", CurrentValue = 15, Flag = "FarmSpeedSlider", Callback = function(Value) farmSpeed = Value end})
SessionCoinLabel = FarmTab:CreateLabel("Total Coins: 0")
FarmTab:CreateToggle({Name = "Auto Farm Active", CurrentValue = false, Flag = "ToggleFarmMoney", Callback = function(Value) setFarmState(Value) end})

-- ⚔️ COMBAT & HUD TAB
local CombatTab = Window:CreateTab("⚔️ Combat", nil)
CombatTab:CreateSection("Mobile HUD Controls (Draggable)")
CombatTab:CreateToggle({Name = "Show 'Shoot' Button", CurrentValue = false, Flag = "HudShoot", Callback = function(Value) ToggleHUD("Shoot", Value, "Shoot", UDim2.new(0.85, 0, 0.7, 0), Color3.fromRGB(0, 255, 100), function() executeRealKill("Murderer") end) end})
CombatTab:CreateToggle({Name = "Show 'Kill All' Button", CurrentValue = false, Flag = "HudKillAll", Callback = function(Value) ToggleHUD("KillAll", Value, "Kill All", UDim2.new(0.85, 0, 0.4, 0), Color3.fromRGB(255, 0, 50), getgenv().performKillAllFunc) end})
CombatTab:CreateToggle({Name = "Show 'Kill Sheriff' Button", CurrentValue = false, Flag = "HudKillCop", Callback = function(Value) ToggleHUD("KillCop", Value, "Kill Cop", UDim2.new(0.85, 0, 0.55, 0), Color3.fromRGB(0, 100, 255), function() executeRealKill("Sheriff") end) end})
CombatTab:CreateToggle({Name = "Show 'Kill Murderer' Button", CurrentValue = false, Flag = "HudKillMur", Callback = function(Value) ToggleHUD("KillMur", Value, "Kill Mur", UDim2.new(0.85, 0, 0.55, 0), Color3.fromRGB(255, 150, 0), function() executeRealKill("Murderer") end) end})

CombatTab:CreateSection("Automation")
CombatTab:CreateToggle({Name = "Auto Collect Gun", CurrentValue = false, Flag = "ToggleAutoGunGrabber", Callback = function(Value) AUTOGUN = Value end})
CombatTab:CreateButton({Name = "Grab Gun Now", Callback = function() teleportToGunFunc() end})

-- 🏝 TP & MISC TAB
local TPTab = Window:CreateTab("🏝 TP/Misc", nil)
TPTab:CreateButton({Name = "TP to Lobby", Callback = function()
    local _, hrp, _ = getCharacterData() if not hrp then return end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and (model.Name == "RegularLobby" or model.Name == "Lobby") then 
            local spawns = model:FindFirstChild("Spawns")
            local spawnPart = spawns and (spawns:FindFirstChild("Spawn") or spawns:FindFirstChild("SpawnLocation"))
            if spawnPart and spawnPart:IsA("BasePart") then Hex:Teleport(spawnPart.CFrame + Vector3.new(0,3,0)) break end 
        end
    end
end})
TPTab:CreateButton({Name = "TP to Map", Callback = function()
    local _, hrp, _ = getCharacterData() if not hrp then return end
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Spawns") and model.Name ~= "RegularLobby" and model.Name ~= "Lobby" then 
            local spawns = model:FindFirstChild("Spawns")
            local randomSpawn = spawns and (spawns:FindFirstChild("Spawn") or spawns:FindFirstChild("PlayerSpawn"))
            if randomSpawn and randomSpawn:IsA("BasePart") then Hex:Teleport(randomSpawn.CFrame + Vector3.new(0,3,0)) break end 
        end
    end
end})

TPTab:CreateSection("Extra Features")
TPTab:CreateButton({Name = "God Mode (Classic)", Callback = function() applyGodMode() end})
TPTab:CreateButton({Name = "Anti-AFK", Callback = function() Hex:SetAntiAfkEnabled(true) end})

Rayfield:Notify({Title = HUB_NAME, Content = "Mobile Edition Loaded.", Duration = 4, Image = 4483362458})
task.spawn(function() task.wait(2) SYSTEM_LOADING = false end)
