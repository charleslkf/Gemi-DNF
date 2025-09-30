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

-- Create a container for all the arrow images
local arrows = {
    Up = Instance.new("ImageLabel"),
    Down = Instance.new("ImageLabel"),
    Left = Instance.new("ImageLabel"),
    Right = Instance.new("ImageLabel")
}

local ARROW_ASSETS = {
    Up = "rbxassetid://9852743620",
    Down = "rbxassetid://9852746355",
    Left = "rbxassetid://9852736351",
    Right = "rbxassetid://9852741348"
}

for direction, arrow in pairs(arrows) do
    arrow.Name = "Arrow" .. direction
    arrow.Image = ARROW_ASSETS[direction]
    arrow.Size = UDim2.new(0, 50, 0, 50)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.BackgroundTransparency = 1
    arrow.Visible = false
    arrow.ZIndex = 2
    arrow.Parent = screenGui
end

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

    -- Hide all arrows by default each frame
    for _, arrow in pairs(arrows) do
        arrow.Visible = false
    end

    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not camera then return end

    local targetPosition
    if currentPath and #currentPath > 0 and currentPath[currentWaypointIndex] then
        local waypoint = currentPath[currentWaypointIndex]
        targetPosition = waypoint.Position
        if (humanoidRootPart.Position - waypoint.Position).Magnitude < 8 then
            currentWaypointIndex = math.min(currentWaypointIndex + 1, #currentPath)
        end
    else
        local nearestGate = findNearestGateFromActive()
        if nearestGate then targetPosition = nearestGate.Position else return end
    end

    local screenPoint, onScreen = camera:WorldToScreenPoint(targetPosition)
    -- Hide the arrow only if we are close to the FINAL waypoint and it's on screen.
    if onScreen and currentPath and currentWaypointIndex == #currentPath and (humanoidRootPart.Position - targetPosition).Magnitude < 12 then
        return -- Hide all arrows
    end

    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit

    -- Determine which arrow to show based on the angle of the direction vector
    local angle = math.deg(math.atan2(direction.Y, direction.X))
    local arrowToShow

    if angle >= -45 and angle < 45 then
        arrowToShow = arrows.Right
    elseif angle >= 45 and angle < 135 then
        arrowToShow = arrows.Down
    elseif angle >= 135 or angle < -135 then
        arrowToShow = arrows.Left
    else -- angle is between -135 and -45
        arrowToShow = arrows.Up
    end

    -- Position the chosen arrow
    local boundX = math.clamp(screenCenter.X + direction.X * (screenCenter.X * 0.8), 50, camera.ViewportSize.X - 50)
    local boundY = math.clamp(screenCenter.Y + direction.Y * (screenCenter.Y * 0.8), 50, camera.ViewportSize.Y - 50)

    arrowToShow.Position = UDim2.new(0, boundX, 0, boundY)
    arrowToShow.Visible = true
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
        -- CRITICAL FIX: If the path has waypoints, start by targeting the second one.
        -- The first waypoint is the player's current location, which causes the arrow to hide immediately.
        if #currentPath > 1 then
            currentWaypointIndex = 2
        end
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
            for _, arrow in pairs(arrows) do
                arrow.Visible = false
            end
            activeGates = {}
        end
    end
end)

print("EscapeUIController.client.lua loaded.")