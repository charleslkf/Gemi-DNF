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
    -- Update standard HUD elements
    local minutes = math.floor(newState.Timer / 60)
    local seconds = newState.Timer % 60
    timerLabel.Text = string.format("%d:%02d", minutes, seconds)
    machineLabel.Text = string.format("Machines: %d/%d", newState.MachinesCompleted, newState.MachinesTotal)
    killsLabel.Text = string.format("Kills: %d", newState.Kills)
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

-- Listen for generic notifications from the server
local showNotificationEvent = Remotes:WaitForChild("ShowNotification")
showNotificationEvent.OnClientEvent:Connect(function(message)
    local notificationLabel = Instance.new("TextLabel")
    notificationLabel.Name = "NotificationLabel"
    notificationLabel.Size = UDim2.new(0, 300, 0, 50)
    notificationLabel.Position = UDim2.new(0.5, -150, 0.3, 0) -- Start position
    notificationLabel.Font = Enum.Font.SourceSansBold
    notificationLabel.TextSize = 28
    notificationLabel.TextColor3 = Color3.new(1, 1, 0) -- Yellow color
    notificationLabel.BackgroundTransparency = 1
    notificationLabel.Text = message
    notificationLabel.Parent = screenGui

    -- Animate the notification
    local TweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(
        2, -- Time
        Enum.EasingStyle.Quad, -- EasingStyle
        Enum.EasingDirection.Out, -- EasingDirection
        0, -- RepeatCount
        false, -- Reverses
        0 -- DelayTime
    )

    local goal = {
        Position = UDim2.new(0.5, -150, 0.2, 0), -- End position (moves up)
        TextTransparency = 1
    }

    local tween = TweenService:Create(notificationLabel, tweenInfo, goal)
    tween:Play()

    -- Clean up after the tween is complete
    tween.Completed:Connect(function()
        notificationLabel:Destroy()
    end)
end)

-- Create the Interaction Prompt label
local interactionPrompt = Instance.new("TextLabel")
interactionPrompt.Name = "InteractionPrompt"
interactionPrompt.Size = UDim2.new(1, 0, 0, 100)
interactionPrompt.Position = UDim2.new(0, 0, 0.5, -50) -- Centered vertically
interactionPrompt.Font = Enum.Font.SourceSansBold
interactionPrompt.TextSize = 36
interactionPrompt.TextColor3 = Color3.new(1, 1, 1)
interactionPrompt.BackgroundTransparency = 1
interactionPrompt.Text = ""
interactionPrompt.Parent = screenGui

-- Expose a global function to control the interaction prompt
_G.UI = {}
function _G.UI.setInteractionPrompt(text)
    if interactionPrompt and interactionPrompt.Parent then
        interactionPrompt.Text = text
    end
end