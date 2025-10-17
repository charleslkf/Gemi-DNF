--[[
    EscapeUIController.client.lua

    Restored version.
    This script manages the four-arrow pathfinding UI during the escape sequence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local EscapeSequenceStarted = Remotes:WaitForChild("EscapeSequenceStarted")

-- Main HUD
local screenGui = playerGui:WaitForChild("MainHUD", 10)
if not screenGui then
    print("[EscapeUIController] FATAL: MainHUD not found after 10 seconds. Aborting.")
    return
end

-- State variables
local activeGates = {}
local currentPath = nil
local pathUpdateConnection = nil
local uiUpdateConnection = nil
local arrows = {}
local screenCrackImage = nil
local flickerCounter = 0

-- #############################
-- ## UI Creation & Teardown  ##
-- #############################

local function destroyArrows()
    for _, arrow in pairs(arrows) do
        arrow:Destroy()
    end
    table.clear(arrows)
    if screenCrackImage then
        screenCrackImage:Destroy()
        screenCrackImage = nil
    end
end

local function createArrows()
    destroyArrows() -- Clear any existing arrows first

    local ARROW_SIZE = UDim2.new(0, 100, 0, 100)
    local ASSET_IDS = {
        Up = "rbxassetid://9852743601",
        Down = "rbxassetid://9852746340",
        Left = "rbxassetid://9852736337",
        Right = "rbxassetid://9852741341"
    }

    local positions = {
        Up = UDim2.new(0.5, 0, 0, 50),
        Down = UDim2.new(0.5, 0, 1, -50),
        Left = UDim2.new(0, 50, 0.5, 0),
        Right = UDim2.new(1, -50, 0.5, 0)
    }

    for direction, id in pairs(ASSET_IDS) do
        local arrow = Instance.new("ImageLabel")
        arrow.Name = direction .. "Arrow"
        arrow.Image = id
        arrow.Size = ARROW_SIZE
        arrow.Position = positions[direction]
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.BackgroundTransparency = 1
        arrow.Visible = false
        arrow.Parent = screenGui
        arrows[direction] = arrow
    end
    print("[EscapeUIController] Created four directional arrows.")

    -- Also create the screen crack effect
    if not screenCrackImage then
        screenCrackImage = Instance.new("ImageLabel")
        screenCrackImage.Name = "ScreenCrackEffect"
        screenCrackImage.Image = "rbxassetid://268393522"
        screenCrackImage.ImageTransparency = 0.8
        screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
        screenCrackImage.Visible = false
        screenCrackImage.ZIndex = 1 -- Keep crack effect behind the arrows
        screenCrackImage.Parent = screenGui
    end
end


-- #############################
-- ## Pathfinding Logic       ##
-- #############################

local function getPathDistance(path)
    local distance = 0
    local waypoints = path:GetWaypoints()
    for i = 1, #waypoints - 1 do
        distance = distance + (waypoints[i+1].Position - waypoints[i].Position).Magnitude
    end
    return distance
end

local function updatePath()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") or #activeGates == 0 then
        currentPath = nil
        return
    end

    local humanoidRootPart = playerChar.HumanoidRootPart
    local shortestPath, minDistance = nil, math.huge

    -- Iterate through all active gates to find the one with the shortest *path*
    for _, gate in ipairs(activeGates) do
        local path = PathfindingService:CreatePath()
        local success, _ = pcall(function()
            path:ComputeAsync(humanoidRootPart.Position, gate.Position)
        end)

        if success and path.Status == Enum.PathStatus.Success then
            local distance = getPathDistance(path)
            if distance < minDistance then
                minDistance = distance
                shortestPath = path
            end
        end
    end

    if shortestPath then
        currentPath = shortestPath
        -- print("[Pathfinding] Found shortest path with distance:", minDistance)
    else
        currentPath = nil
        -- warn("[Pathfinding] Could not compute a valid path to any gate.")
    end
end


-- #############################
-- ## UI Update Logic         ##
-- #############################

local function updateUI()
    -- Handle screen crack flicker
    if screenCrackImage then
        flickerCounter = (flickerCounter + 1) % 10
        screenCrackImage.Visible = (flickerCounter < 5)
    end

    -- Hide all arrows by default each frame
    for _, arrow in pairs(arrows) do
        arrow.Visible = false
    end

    local playerChar = player.Character
    if not currentPath or not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") then return end

    local waypoints = currentPath:GetWaypoints()
    if #waypoints < 2 then return end

    local hrp = playerChar.HumanoidRootPart

    -- Find the closest waypoint and target the next one
    local closestWaypointIndex = 1
    local minDistance = math.huge
    for i, waypoint in ipairs(waypoints) do
        local distance = (hrp.Position - waypoint.Position).Magnitude
        if distance < minDistance then
            minDistance = distance
            closestWaypointIndex = i
        end
    end

    -- Target the next waypoint in the path, unless we are at the end
    local targetWaypointIndex = math.min(closestWaypointIndex + 1, #waypoints)
    local targetPos = waypoints[targetWaypointIndex].Position

    -- Hide arrow if player is very close to the final destination
    if (hrp.Position - waypoints[#waypoints].Position).Magnitude < 15 then
        return
    end

    -- Get the camera's forward direction, but only on the horizontal plane (X, Z)
    local cameraLookVector = camera.CFrame.LookVector * Vector3.new(1, 0, 1)

    -- Get the direction to the target, also only on the horizontal plane
    local targetDirection = (targetPos - hrp.Position) * Vector3.new(1, 0, 1)

    -- If the vectors are very small, we can't get a reliable direction, so exit.
    if targetDirection.Magnitude < 0.1 or cameraLookVector.Magnitude < 0.1 then
        arrows.Up.Visible = true -- Default to 'Up' if we're on top of the waypoint
        return
    end

    cameraLookVector = cameraLookVector.Unit
    targetDirection = targetDirection.Unit

    -- The dot product tells us if the target is in front of or behind the camera.
    local dotProduct = cameraLookVector:Dot(targetDirection)

    if dotProduct < -0.3 then
        -- Target is mostly behind the player, so tell them to turn around.
        arrows.Down.Visible = true
        return
    end

    -- The cross product's Y value tells us if the target is to the left or right.
    local crossProduct = cameraLookVector:Cross(targetDirection)

    -- Use a threshold to decide if the direction is "forward" or "sideways"
    if math.abs(crossProduct.Y) > 0.4 then
        if crossProduct.Y > 0 then
            -- Target is to the left
            arrows.Left.Visible = true
        else
            -- Target is to the right
            arrows.Right.Visible = true
        end
    else
        -- Target is mostly in front of the player, so "go forward."
        arrows.Up.Visible = true
    end
end


-- #############################
-- ## Event Listeners         ##
-- #############################

-- Listen for the dedicated escape event to start the UI
EscapeSequenceStarted.OnClientEvent:Connect(function(gateNames)
    if player.Team and player.Team.Name == "Survivors" then
        print("[EscapeUIController] Escape sequence started. Restoring pathfinding system.")
        table.clear(activeGates)
        for _, name in ipairs(gateNames) do
            local gatePart = Workspace:WaitForChild(name, 10)
            if gatePart then
                table.insert(activeGates, gatePart)
            end
        end

        createArrows()

        -- Start path recalculation loop
        if not pathUpdateConnection then
            pathUpdateConnection = task.spawn(function()
                while true do
                    updatePath()
                    task.wait(1) -- Recalculate every second
                end
            end)
        end

        -- Start UI update loop
        if not uiUpdateConnection then
            uiUpdateConnection = RunService.Heartbeat:Connect(updateUI)
        end
    end
end)

-- Listen for general game state changes to know when to stop
GameStateChanged.OnClientEvent:Connect(function(newState)
    if newState.Name ~= "Escape" then
        if pathUpdateConnection then
            task.cancel(pathUpdateConnection)
            pathUpdateConnection = nil
        end
        if uiUpdateConnection then
            uiUpdateConnection:Disconnect()
            uiUpdateConnection = nil
        end
        destroyArrows()
        currentPath = nil
        table.clear(activeGates)
    end
end)

print("EscapeUIController.client.lua (Pathfinding Version) loaded.")
