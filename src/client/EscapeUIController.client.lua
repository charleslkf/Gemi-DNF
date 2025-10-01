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

local currentPath = nil -- This will hold the table of waypoints for the path
local currentWaypointIndex = 1 -- This tracks which waypoint the player is heading towards
local lastPathCalculationTime = 0 -- Timer to track when the path was last calculated

-- Create a container for all the arrow images
local arrows = {
    Up = Instance.new("ImageLabel"),
    Down = Instance.new("ImageLabel"),
    Left = Instance.new("ImageLabel"),
    Right = Instance.new("ImageLabel")
}

local ARROW_ASSETS = {
    Up = "rbxassetid://9852743601",
    Down = "rbxassetid://9852746340",
    Left = "rbxassetid://9852736337",
    Right = "rbxassetid://9852741341"
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

    for _, arrow in pairs(arrows) do arrow.Visible = false end

    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not camera or #activeGates == 0 then return end

    -- Dynamic Path Recalculation in a non-blocking thread
    local currentTime = tick()
    if currentTime - lastPathCalculationTime > 1 then
        lastPathCalculationTime = currentTime
        task.spawn(function()
            local nearestGate = findNearestGateFromActive()
            if nearestGate then
                local path = PathfindingService:CreatePath()
                path:ComputeAsync(humanoidRootPart.Position, nearestGate.Position)
                if path.Status == Enum.PathStatus.Success then
                    currentPath = path:GetWaypoints()
                    currentWaypointIndex = (#currentPath > 1) and 2 or 1
                else
                    currentPath = nil
                end
            end
        end)
    end

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
    if onScreen and currentPath and currentWaypointIndex == #currentPath and (humanoidRootPart.Position - targetPosition).Magnitude < 12 then
        return -- Hide all arrows if close to the final destination
    end

    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit

    local angle = math.deg(math.atan2(direction.Y, direction.X))
    local arrowToShow

    if angle >= -45 and angle < 45 then
        arrowToShow = arrows.Right
        arrowToShow.Position = UDim2.new(1, -50, 0.5, 0)
    elseif angle >= 45 and angle < 135 then
        arrowToShow = arrows.Down
        arrowToShow.Position = UDim2.new(0.5, 0, 1, -50)
    elseif angle >= 135 or angle < -135 then
        arrowToShow = arrows.Left
        arrowToShow.Position = UDim2.new(0, 50, 0.5, 0)
    else -- angle is between -135 and -45
        arrowToShow = arrows.Up
        arrowToShow.Position = UDim2.new(0.5, 0, 0, 50)
    end

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
    lastPathCalculationTime = 0 -- Reset timer

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