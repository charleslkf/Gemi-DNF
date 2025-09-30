--[[
    EscapeUIController.client.lua

    This script is solely responsible for managing the UI effects during
    the escape sequence (the screen crack and the directional arrow).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- Use WaitForChild to ensure all remote events are loaded before continuing
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local EscapeSequenceStarted = Remotes:WaitForChild("EscapeSequenceStarted")

-- Use WaitForChild to ensure the UIManager has created the MainHUD
local screenGui = playerGui:WaitForChild("MainHUD", 10)
if not screenGui then
    print("[EscapeUIController] FATAL: MainHUD not found after 10 seconds. Aborting.")
    return
end

local arrowImage = Instance.new("ImageLabel")
arrowImage.Name = "EscapeArrow"
arrowImage.Image = "rbxassetid://4984448565" -- New, valid asset ID provided by user
arrowImage.Size = UDim2.new(0, 50, 0, 50)
arrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
arrowImage.BackgroundTransparency = 1
arrowImage.Visible = false
arrowImage.ZIndex = 2 -- Set ZIndex to render on top
arrowImage.Parent = screenGui

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522"
screenCrackImage.ImageTransparency = 0.8
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.Visible = false
screenCrackImage.ZIndex = 1 -- Keep crack effect behind the arrow
screenCrackImage.Parent = screenGui

local escapeConnection = nil
local flickerCounter = 0
local activeGates = {}
local currentPath = nil -- This will hold the table of waypoints for the path
local currentWaypointIndex = 1 -- This tracks which waypoint the player is heading towards

local function findNearestGateFromActive()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") or #activeGates == 0 then return nil end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nearestGate, minDistance = nil, math.huge

    for _, part in ipairs(activeGates) do
        if part and part.Parent then -- Check if gate is valid
            local distance = (playerPos - part.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                nearestGate = part
            end
        end
    end
    return nearestGate
end

local function updateEscapeUI()
    flickerCounter = (flickerCounter + 1) % 10
    screenCrackImage.Visible = (flickerCounter < 5)

    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not camera then
        arrowImage.Visible = false
        return
    end

    local targetPosition
    -- Determine the target: the next waypoint or the gate itself
    if currentPath and #currentPath > 0 and currentPath[currentWaypointIndex] then
        local waypoint = currentPath[currentWaypointIndex]
        targetPosition = waypoint.Position

        -- Check if player has reached the current waypoint, then advance
        if (humanoidRootPart.Position - waypoint.Position).Magnitude < 8 then
            currentWaypointIndex = math.min(currentWaypointIndex + 1, #currentPath)
        end
    else
        -- Fallback: if no path, find the nearest gate directly
        local nearestGate = findNearestGateFromActive()
        if nearestGate then
            targetPosition = nearestGate.Position
        else
            arrowImage.Visible = false
            return
        end
    end

    -- If we have a target, update the arrow's position and rotation
    arrowImage.Visible = true

    -- Always clamp the arrow to the edge of the screen for compass-like behavior
    local screenPoint, onScreen = camera:WorldToScreenPoint(targetPosition)
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    -- If player is very close to the final target and it's on screen, hide the arrow
    if onScreen and (humanoidRootPart.Position - targetPosition).Magnitude < 12 then
         arrowImage.Visible = false
         return
    end

    local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit
    local boundX = math.clamp(screenCenter.X + direction.X * (screenCenter.X * 0.8), 50, camera.ViewportSize.X - 50)
    local boundY = math.clamp(screenCenter.Y + direction.Y * (screenCenter.Y * 0.8), 50, camera.ViewportSize.Y - 50)

    arrowImage.Position = UDim2.new(0, boundX, 0, boundY)
    arrowImage.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
end

-- Listen for the dedicated escape event to start the UI
EscapeSequenceStarted.OnClientEvent:Connect(function(gateNames)
    if player.Team and player.Team.Name ~= "Survivors" then return end

    -- Correctly populate activeGates from the received names
    table.clear(activeGates)
    for _, name in ipairs(gateNames) do
        local gatePart = Workspace:FindFirstChild(name)
        if gatePart then
            table.insert(activeGates, gatePart)
        else
            warn("[EscapeUIController] Could not find a gate named: " .. name)
        end
    end

    currentPath = nil
    currentWaypointIndex = 1

    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or #activeGates == 0 then return end

    local nearestGate = findNearestGateFromActive()
    if not nearestGate then return end

    -- Create and compute the path
    local path = PathfindingService:CreatePath()
    path:ComputeAsync(humanoidRootPart.Position, nearestGate.Position)

    if path.Status == Enum.PathStatus.Success then
        print("[EscapeUIController] Path to nearest gate computed successfully.")
        currentPath = path:GetWaypoints()
    else
        warn("[EscapeUIController] Could not compute path to the nearest gate. Arrow will point directly at the gate.")
    end

    if not escapeConnection then
        print("[EscapeUIController] Escape sequence started. Activating UI.")
        escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
    end
end)

-- Listen for general game state changes to know when to stop
GameStateChanged.OnClientEvent:Connect(function(newState)
    if newState.Name ~= "Escape" then
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
            screenCrackImage.Visible = false
            arrowImage.Visible = false
            activeGates = {}
        end
    end
end)

print("EscapeUIController.client.lua loaded.")