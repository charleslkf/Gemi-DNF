--[[
    UIManager.client.lua
    by Jules

    This LocalScript is responsible for creating, updating, and managing all
    of the main gameplay HUD elements for the player.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Create the Top Center frame for game info
local topFrame = Instance.new("Frame")
topFrame.Name = "TopFrame"
topFrame.Size = UDim2.new(0, 400, 0, 50)
topFrame.Position = UDim2.new(0.5, -200, 0, 40) -- Centered, 40px from top
topFrame.BackgroundTransparency = 1
topFrame.Parent = screenGui

-- Add a layout to the top frame
local topListLayout = Instance.new("UIListLayout")
topListLayout.FillDirection = Enum.FillDirection.Horizontal
topListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
topListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
topListLayout.SortOrder = Enum.SortOrder.LayoutOrder
topListLayout.Padding = UDim.new(0, 20)
topListLayout.Parent = topFrame

-- Create the labels for the top frame
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 100, 1, 0)
timerLabel.Font = Enum.Font.SourceSansBold
timerLabel.TextSize = 24
timerLabel.TextColor3 = Color3.new(1, 1, 1)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "5:00"
timerLabel.LayoutOrder = 1
timerLabel.Parent = topFrame

local machineLabel = Instance.new("TextLabel")
machineLabel.Name = "MachineLabel"
machineLabel.Size = UDim2.new(0, 150, 1, 0)
machineLabel.Font = Enum.Font.SourceSansBold
machineLabel.TextSize = 24
machineLabel.TextColor3 = Color3.new(1, 1, 1)
machineLabel.BackgroundTransparency = 1
machineLabel.Text = "Machines: 0/9"
machineLabel.LayoutOrder = 2
machineLabel.Parent = topFrame

local killsLabel = Instance.new("TextLabel")
killsLabel.Name = "KillsLabel"
killsLabel.Size = UDim2.new(0, 100, 1, 0)
killsLabel.Font = Enum.Font.SourceSansBold
killsLabel.TextSize = 24
killsLabel.TextColor3 = Color3.new(1, 1, 1)
killsLabel.BackgroundTransparency = 1
killsLabel.Text = "Kills: 0"
killsLabel.LayoutOrder = 3
killsLabel.Parent = topFrame

-- Create the Bottom Center frame for player stats
local bottomFrame = Instance.new("Frame")
bottomFrame.Name = "BottomFrame"
bottomFrame.Size = UDim2.new(0, 500, 0, 100)
bottomFrame.Position = UDim2.new(0.5, -250, 1, -110) -- Centered, 10px from bottom
bottomFrame.BackgroundTransparency = 1
bottomFrame.Parent = screenGui

-- Add a layout to the bottom frame
local bottomListLayout = Instance.new("UIListLayout")
bottomListLayout.FillDirection = Enum.FillDirection.Vertical
bottomListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
bottomListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomListLayout.SortOrder = Enum.SortOrder.LayoutOrder
bottomListLayout.Padding = UDim.new(0, 5)
bottomListLayout.Parent = bottomFrame

-- Create Health Bar
-- The Health Bar is now a BillboardGUI managed by HealthManager.
-- The code for the 2D HUD health bar has been removed.

-- Create Coin Count Label
local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "CoinLabel"
coinLabel.Size = UDim2.new(0, 300, 0, 25)
coinLabel.Font = Enum.Font.SourceSansBold
coinLabel.TextSize = 22
coinLabel.TextColor3 = Color3.new(1, 1, 1)
coinLabel.BackgroundTransparency = 1
coinLabel.Text = "Coins: 0"
coinLabel.LayoutOrder = 2
coinLabel.Parent = bottomFrame

-- Create Item Display Label
local itemLabel = Instance.new("TextLabel")
itemLabel.Name = "ItemLabel"
itemLabel.Size = UDim2.new(0, 300, 0, 25)
itemLabel.Font = Enum.Font.SourceSansBold
itemLabel.TextSize = 22
itemLabel.TextColor3 = Color3.new(1, 1, 1)
itemLabel.BackgroundTransparency = 1
itemLabel.Text = "Item: None"
itemLabel.LayoutOrder = 3
itemLabel.Parent = bottomFrame


-- Listen for game state updates from the server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")

-- #############################
-- ## Escape Sequence UI      ##
-- #############################

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local camera = Workspace.CurrentCamera

local arrowImage = Instance.new("ImageLabel")
arrowImage.Name = "EscapeArrow"
arrowImage.Image = "rbxassetid://5989193313"
arrowImage.Size = UDim2.new(0, 50, 0, 50)
arrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
arrowImage.BackgroundTransparency = 1
arrowImage.Visible = false
arrowImage.Parent = screenGui

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522"
screenCrackImage.ImageTransparency = 0.8
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.Visible = false
screenCrackImage.Parent = screenGui

local escapeConnection = nil
local flickerCounter = 0
local activeGates = {} -- Will be populated by the server event

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

    local nearestGate = findNearestGateFromActive()
    print("[UIManager-DEBUG] updateEscapeUI frame. Nearest gate found:", nearestGate)

    if nearestGate and camera then
        arrowImage.Visible = true
        print("[UIManager-DEBUG] Arrow should be visible.")
        local gatePos = nearestGate.Position
        local screenPoint, onScreen = camera:WorldToScreenPoint(gatePos)
        if onScreen then
            arrowImage.Position = UDim2.new(0, screenPoint.X, 0, screenPoint.Y)
            arrowImage.Rotation = 0
        else
            local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit
            local boundX = math.clamp(screenCenter.X + direction.X * 1000, 50, camera.ViewportSize.X - 50)
            local boundY = math.clamp(screenCenter.Y + direction.Y * 1000, 50, camera.ViewportSize.Y - 50)
            arrowImage.Position = UDim2.new(0, boundX, 0, boundY)
            arrowImage.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
        end
    else
        arrowImage.Visible = false
        print("[UIManager-DEBUG] Arrow should be hidden. Reason: nearestGate is", nearestGate, "and camera is", camera)
    end
end

-- Listen for the new dedicated escape event
local escapeEvent = Remotes:WaitForChild("EscapeSequenceStarted")
escapeEvent.OnClientEvent:Connect(function(gates)
    print("[UIManager-DEBUG] Received EscapeSequenceStarted event.")
    if type(gates) == "table" then
        print("[UIManager-DEBUG] Gates table received with #", #gates, "elements.")
        for i, gate in ipairs(gates) do
            print("[UIManager-DEBUG] Gate", i, ":", gate:GetFullName(), "at", gate.Position)
        end
    else
        print("[UIManager-DEBUG] Gates received is not a table:", gates)
    end
    activeGates = gates
    if not escapeConnection then
        escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
    end
end)

-- CONSOLIDATED LISTENER
GameStateChanged.OnClientEvent:Connect(function(newState)
    -- Update standard HUD elements
    local minutes = math.floor(newState.Timer / 60)
    local seconds = newState.Timer % 60
    timerLabel.Text = string.format("%d:%02d", minutes, seconds)
    machineLabel.Text = string.format("Machines: %d/%d", newState.MachinesCompleted, newState.MachinesTotal)
    killsLabel.Text = string.format("Kills: %d", newState.Kills)

    -- Handle stopping the Escape State UI
    if newState.Name ~= "Escape" then
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
            screenCrackImage.Visible = false
            arrowImage.Visible = false
            activeGates = {}
            print("[UIManager] Escape sequence UI deactivated.")
        end
    end
end)

-- Listen for local player stat changes
local leaderstats = player:WaitForChild("leaderstats")
local levelCoins = leaderstats:WaitForChild("LevelCoins")
levelCoins.Changed:Connect(function(newCoins)
    coinLabel.Text = string.format("Coins: %d", newCoins)
end)

-- Listen for health updates
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local HealthManager = require(MyModules:WaitForChild("HealthManager"))
local healthChangedEvent = Remotes:WaitForChild("HealthChanged")
healthChangedEvent.OnClientEvent:Connect(function(player, currentHealth, maxHealth)
    HealthManager.createOrUpdateHealthBar(player, currentHealth, maxHealth)
end)

print("UIManager.client.lua loaded and created base frames.")