--[[
    EscapeUIController.client.lua

    This script is solely responsible for managing the UI effects during
    the escape sequence, including the screen crack effect and the directional
    arrow that guides players to the nearest Victory Gate.
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
    warn("[EscapeUIController] FATAL: MainHUD not found after 10 seconds. Aborting.")
    return
end

-- Arrow UI Setup
local arrowAssets = {
    Up = "rbxassetid://12486915223",
    Down = "rbxassetid://12486914838",
    Left = "rbxassetid://12486914495",
    Right = "rbxassetid://12486914094"
}

local arrows = {}
for name, id in pairs(arrowAssets) do
    local arrowImage = Instance.new("ImageLabel")
    arrowImage.Name = "EscapeArrow" .. name
    arrowImage.Image = id
    arrowImage.Size = UDim2.new(0, 100, 0, 100)
    arrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
    arrowImage.BackgroundTransparency = 1
    arrowImage.Visible = false
    arrowImage.ZIndex = 2
    arrowImage.Parent = screenGui
    arrows[name] = arrowImage
end

arrows["Up"].Position = UDim2.new(0.5, 0, 0, 50)
arrows["Down"].Position = UDim2.new(0.5, 0, 1, -50)
arrows["Left"].Position = UDim2.new(0, 50, 0.5, 0)
arrows["Right"].Position = UDim2.new(1, -50, 0.5, 0)

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522"
screenCrackImage.ImageTransparency = 0.8
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.Visible = false
screenCrackImage.ZIndex = 1
screenCrackImage.Parent = screenGui

-- State Variables
local escapeConnection = nil
local pathfindingCoroutine = nil
local activeGates = {}
local currentPath = nil
local isEscapeActive = false

-- Helper function to calculate the total length of a path by summing the magnitude between its waypoints.
local function calculatePathLength(path)
    local waypoints = path:GetWaypoints()
    if #waypoints < 2 then
        return 0
    end

    local totalLength = 0
    for i = 1, #waypoints - 1 do
        totalLength = totalLength + (waypoints[i+1].Position - waypoints[i].Position).Magnitude
    end
    return totalLength
end

-- Helper function to find the nearest gate by pathfinding distance
local function findNearestGate()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") or #activeGates == 0 then return nil end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nearestGate, shortestPath, minDistance = nil, nil, math.huge

    for _, gate in ipairs(activeGates) do
        if gate and gate.Parent then
            local path = PathfindingService:CreatePath()
            path:ComputeAsync(playerPos, gate.Position)
            if path.Status == Enum.PathStatus.Success then
                local currentLength = calculatePathLength(path)
                if currentLength < minDistance then
                    minDistance = currentLength
                    shortestPath = path
                    nearestGate = gate
                end
            end
        end
    end
    return nearestGate, shortestPath
end

-- Non-blocking coroutine to handle path recalculation
local function managePathfinding()
    while isEscapeActive do
        local _, path = findNearestGate()
        currentPath = path
        task.wait(1) -- Recalculate path every second
    end
end

-- Main UI update loop
local function updateEscapeUI()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") then
        for _, arrow in pairs(arrows) do arrow.Visible = false end
        return
    end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nextWaypoint = nil

    local waypoints = currentPath and currentPath:GetWaypoints()
    if waypoints and #waypoints > 0 then
        -- If there's only one waypoint, it's the destination. Otherwise, aim for the next one.
        nextWaypoint = waypoints[#waypoints > 1 and 2 or 1].Position
    end

    for _, arrow in pairs(arrows) do arrow.Visible = false end

    if nextWaypoint then
        local direction = (nextWaypoint - playerPos).Unit
        local cameraDirection = camera.CFrame.LookVector
        local angle = math.atan2(direction.X, direction.Z) - math.atan2(cameraDirection.X, cameraDirection.Z)

        if angle > math.pi then angle = angle - 2 * math.pi end
        if angle < -math.pi then angle = angle + 2 * math.pi end

        if math.abs(angle) < math.pi / 4 then
            arrows["Up"].Visible = true
        elseif math.abs(angle) > 3 * math.pi / 4 then
            arrows["Down"].Visible = true
        elseif angle > 0 then
            arrows["Right"].Visible = true
        else
            arrows["Left"].Visible = true
        end
    end

    -- Flicker the screen crack effect
    screenCrackImage.Visible = (os.clock() % 0.2 < 0.1)
end

-- Event Handlers
EscapeSequenceStarted.OnClientEvent:Connect(function(gateNames)
    if player.Team and player.Team.Name == "Survivors" then
        -- The server sends gate names, so we need to find the actual parts in the Workspace.
        table.clear(activeGates)
        for _, name in ipairs(gateNames) do
            local gatePart = Workspace:FindFirstChild(name)
            if gatePart then
                table.insert(activeGates, gatePart)
            else
                warn("[EscapeUIController] Could not find gate part named: " .. name)
            end
        end

        isEscapeActive = true
        if not pathfindingCoroutine then
            pathfindingCoroutine = task.spawn(managePathfinding)
        end
        if not escapeConnection then
            escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
        end
    end
end)

GameStateChanged.OnClientEvent:Connect(function(newState)
    if newState.Name ~= "Escape" then
        isEscapeActive = false
        if pathfindingCoroutine then
            -- Let the coroutine finish naturally
            pathfindingCoroutine = nil
        end
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
        end
        screenCrackImage.Visible = false
        for _, arrow in pairs(arrows) do
            arrow.Visible = false
        end
        table.clear(activeGates)
    end
end)

print("EscapeUIController.client.lua loaded.")