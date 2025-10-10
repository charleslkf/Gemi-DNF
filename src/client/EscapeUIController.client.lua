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


-- #############################
-- ## Pathfinding Logic       ##
-- #############################

local function findNearestGate()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") or #activeGates == 0 then return nil end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nearestGate, minDistance = nil, math.huge

    for _, part in ipairs(activeGates) do
        if part and part.Parent then
            local distance = (playerPos - part.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                nearestGate = part
            end
        end
    end
    return nearestGate
end

local function updatePath()
    local playerChar = player.Character
    local nearestGate = findNearestGate()

    if not playerChar or not nearestGate or not playerChar:FindFirstChild("HumanoidRootPart") then
        currentPath = nil
        return
    end

    local humanoidRootPart = playerChar.HumanoidRootPart
    local path = PathfindingService:CreatePath()

    -- Compute the path asynchronously to avoid yielding
    local success, errorMessage = pcall(function()
        path:ComputeAsync(humanoidRootPart.Position, nearestGate.Position)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        currentPath = path
        -- print("[Pathfinding] Successfully computed new path.")
    else
        currentPath = nil
        -- warn("[Pathfinding] Failed to compute path: ", errorMessage or path.Status)
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

    -- 1. Hide all arrows by default each frame
    for _, arrow in pairs(arrows) do
        arrow.Visible = false
    end

    local playerChar = player.Character
    if not currentPath or not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") then return end

    local waypoints = currentPath:GetWaypoints()
    if #waypoints < 2 then return end

    -- 2. Target the *second* waypoint to avoid looking at the player's feet
    local targetWaypoint = waypoints[2]
    local playerPos = playerChar.HumanoidRootPart.Position

    -- 3. Hide the arrow if the player is very close to the *final* destination
    local finalDestination = waypoints[#waypoints].Position
    if (playerPos - finalDestination).Magnitude < 15 then
        return
    end

    -- 4. Calculate the direction vector in world space
    local directionVector = (targetWaypoint.Position - playerPos)

    -- 5. Convert the world space direction to be relative to the camera's orientation
    local cameraRelativeVector = camera.CFrame:VectorToObjectSpace(directionVector)

    -- 6. Determine which direction has the greatest magnitude
    local absX, absY = math.abs(cameraRelativeVector.X), math.abs(cameraRelativeVector.Y)

    if absX > absY then
        -- Left or Right
        if cameraRelativeVector.X > 0 then
            if arrows.Right then arrows.Right.Visible = true end
        else
            if arrows.Left then arrows.Left.Visible = true end
        end
    else
        -- Up or Down
        if cameraRelativeVector.Y > 0 then
            if arrows.Up then arrows.Up.Visible = true end
        else
            if arrows.Down then arrows.Down.Visible = true end
        end
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
