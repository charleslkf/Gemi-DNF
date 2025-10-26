-- KillerMobileControls.client.lua
-- This script creates and manages a single, contextual action button for the Killer on mobile.

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Modules
local CONFIG = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("Config"))
local SimulatedPlayerManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("SimulatedPlayerManager"))

-- Only run this script for mobile users
if not UserInputService.TouchEnabled then
    return
end

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")
local RequestGrab = Remotes:WaitForChild("RequestGrab")
local RequestHang = Remotes:WaitForChild("RequestHang")
local CarryingStateChanged = Remotes:WaitForChild("CarryingStateChanged")

-- State
local screenGui = nil
local actionButton = nil
local killersTeam = Teams:WaitForChild("Killers")
local isCarrying = false
local currentAction = "Attack" -- "Attack", "Grab", or "Hang"
local currentTarget = nil

-- HELPER FUNCTIONS
local function findNearestDownedCharacter(position, maxDistance)
    local nearestCharacter = nil
    local minDistance = maxDistance
    -- Check Players
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetCharacter = otherPlayer.Character
            if targetCharacter:GetAttribute("Downed") == true then
                local distance = (position - targetCharacter.HumanoidRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestCharacter = targetCharacter
                end
            end
        end
    end
    -- Check Bots
    pcall(function()
        local activeBots = SimulatedPlayerManager.getSpawnedBots()
        for _, botModel in ipairs(activeBots) do
            if botModel and botModel.Parent and botModel:FindFirstChild("HumanoidRootPart") then
                if botModel:GetAttribute("Downed") == true then
                    local distance = (position - botModel.HumanoidRootPart.Position).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        nearestCharacter = botModel
                    end
                end
            end
        end
    end)
    return nearestCharacter
end

local function findNearestHanger(position, maxDistance)
    local hangersFolder = Workspace:FindFirstChild("Hangers")
    local closestHanger = nil
    local minDistance = maxDistance
    if hangersFolder then
        for _, hanger in ipairs(hangersFolder:GetChildren()) do
            if hanger:FindFirstChild("AttachPoint") then
                local distance = (position - hanger.AttachPoint.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestHanger = hanger
                end
            end
        end
    end
    return closestHanger
end

-- UI CREATION AND DESTRUCTION
local function createKillerUI()
    if screenGui then return end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KillerMobileControlsGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = playerGui

    actionButton = Instance.new("TextButton")
    actionButton.Name = "ActionButton"
    actionButton.TextColor3 = Color3.new(1, 1, 1)
    actionButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    actionButton.BackgroundTransparency = 0.3
    actionButton.BorderSizePixel = 0
    actionButton.Size = UDim2.new(0, 100, 0, 100)
    actionButton.AnchorPoint = Vector2.new(1, 0.5)
    actionButton.Position = UDim2.new(1, -30, 0.5, 0)
    actionButton.Font = Enum.Font.SourceSansBold
    actionButton.TextSize = 32
    actionButton.ZIndex = 10
    actionButton.Parent = screenGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0.5, 0)
    uiCorner.Parent = actionButton

    actionButton.MouseButton1Click:Connect(function()
        print(string.format("[KillerMobileControls] Button clicked. Action: %s", currentAction))
        if currentAction == "Attack" then
            AttackRequest:FireServer(nil)
        elseif currentAction == "Grab" and currentTarget then
            RequestGrab:FireServer(currentTarget)
        elseif currentAction == "Hang" and currentTarget then
            RequestHang:FireServer(currentTarget)
        end
    end)
end

local function destroyKillerUI()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
        actionButton = nil
    end
end

-- MAIN TEAM CHECK AND UI MANAGEMENT
local function onTeamChanged()
    if player.Team == killersTeam then
        createKillerUI()
    else
        destroyKillerUI()
    end
end

-- LISTENERS
CarryingStateChanged.OnClientEvent:Connect(function(newState)
    isCarrying = newState
    print("[KillerMobileControls] Carrying state updated to:", newState)
end)

player:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)

-- MAIN UPDATE LOOP
RunService.RenderStepped:Connect(function()
    -- Only run logic if the UI is active
    if not actionButton or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local killerPos = player.Character.HumanoidRootPart.Position
    local newAction = "Attack"
    local newTarget = nil

    if isCarrying then
        -- Context 2: Carrying a survivor, check for hangers
        local nearestHanger = findNearestHanger(killerPos, CONFIG.HANGER_INTERACT_DISTANCE)
        if nearestHanger then
            newAction = "Hang"
            newTarget = nearestHanger
        else
            -- If carrying but not near a hanger, default to no action (or drop action if implemented)
            -- For now, we will just show "Attack" but it will do nothing in this state
            newAction = "Attack"
            newTarget = nil
        end
    else
        -- Context 1: Not carrying, check for downed survivors
        local nearestDowned = findNearestDownedCharacter(killerPos, CONFIG.GRAB_DISTANCE)
        if nearestDowned then
            newAction = "Grab"
            newTarget = nearestDowned
        end
    end

    -- Update state and button text only if they have changed
    if newAction ~= currentAction then
        currentAction = newAction
        actionButton.Text = string.upper(currentAction)
    end
    currentTarget = newTarget
end)

-- Initial check
onTeamChanged()

print("KillerMobileControls.client.lua v3 (Contextual) loaded and initialized.")
