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

GameStateChanged.OnClientEvent:Connect(function(newState)
    -- Update Timer
    local minutes = math.floor(newState.Timer / 60)
    local seconds = newState.Timer % 60
    timerLabel.Text = string.format("%d:%02d", minutes, seconds)

    -- Update Machine Count
    machineLabel.Text = string.format("Machines: %d/%d", newState.MachinesCompleted, newState.MachinesTotal)

    -- Update Kills Count
    killsLabel.Text = string.format("Kills: %d", newState.Kills)
end)

-- Listen for local player stat changes
local leaderstats = player:WaitForChild("leaderstats")
local levelCoins = leaderstats:WaitForChild("LevelCoins")

levelCoins.Changed:Connect(function(newCoins)
    coinLabel.Text = string.format("Coins: %d", newCoins)
end)

-- Listen for health updates directly from the HealthManager
-- Listen for health updates for all players and delegate to HealthManager
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local HealthManager = require(MyModules:WaitForChild("HealthManager"))
local healthChangedEvent = Remotes:WaitForChild("HealthChanged")

healthChangedEvent.OnClientEvent:Connect(function(player, currentHealth, maxHealth)
    HealthManager.createOrUpdateHealthBar(player, currentHealth, maxHealth)
end)

-- #############################
-- ## Escape Sequence UI      ##
-- #############################

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Create the UI elements for the escape sequence
local arrowGui = Instance.new("BillboardGui")
arrowGui.Name = "EscapeArrowGui"
arrowGui.Size = UDim2.new(0, 100, 0, 100)
arrowGui.Adornee = player.Character and player.Character:FindFirstChild("Head")
arrowGui.AlwaysOnTop = true
arrowGui.Enabled = false
arrowGui.Parent = playerGui

local arrowImage = Instance.new("ImageLabel")
arrowImage.Image = "rbxassetid://5989193313" -- A simple arrow texture
arrowImage.Size = UDim2.new(1, 0, 1, 0)
arrowImage.BackgroundTransparency = 1
arrowImage.Parent = arrowGui

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522" -- A screen crack texture
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.BackgroundTransparency = 0.5
screenCrackImage.Visible = false
screenCrackImage.Parent = screenGui

local escapeConnection = nil

local function findNearestGate()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nearestGate, minDistance = nil, math.huge

    for _, part in ipairs(Workspace:GetChildren()) do
        if part.Name:match("VictoryGate") then
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
    local nearestGate = findNearestGate()
    if nearestGate and player.Character and player.Character:FindFirstChild("Head") then
        arrowGui.Adornee = player.Character.Head
        local direction = (nearestGate.Position - player.Character.Head.Position).Unit
        arrowGui.CFrame = CFrame.new(player.Character.Head.Position + direction * 5) * CFrame.Angles(0, math.rad(90), 0)
    else
        arrowGui.Enabled = false
    end
end

-- Update the main state change listener
GameStateChanged.OnClientEvent:Connect(function(newState)
    -- Update Timer, Machines, Kills (existing logic)
    local minutes = math.floor(newState.Timer / 60)
    local seconds = newState.Timer % 60
    timerLabel.Text = string.format("%d:%02d", minutes, seconds)
    machineLabel.Text = string.format("Machines: %d/%d", newState.MachinesCompleted, newState.MachinesTotal)
    killsLabel.Text = string.format("Kills: %d", newState.Kills)

    -- Handle Escape State
    if newState.Name == "Escape" then
        if not escapeConnection then
            screenCrackImage.Visible = true
            arrowGui.Enabled = true
            escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
            print("[UIManager] Escape sequence UI activated.")
        end
    else
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
            screenCrackImage.Visible = false
            arrowGui.Enabled = false
            print("[UIManager] Escape sequence UI deactivated.")
        end
    end
end)


print("UIManager.client.lua loaded and created base frames.")
