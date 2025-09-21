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
topFrame.Position = UDim2.new(0.5, -200, 0, 10) -- Centered, 10px from top
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
local healthBarFrame = Instance.new("Frame")
healthBarFrame.Name = "HealthBarFrame"
healthBarFrame.Size = UDim2.new(0, 300, 0, 20)
healthBarFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
healthBarFrame.BorderSizePixel = 1
healthBarFrame.LayoutOrder = 1
healthBarFrame.Parent = bottomFrame

local healthBar = Instance.new("Frame")
healthBar.Name = "HealthBar"
healthBar.Size = UDim2.new(1, 0, 1, 0) -- Start at 100%
healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
healthBar.Parent = healthBarFrame

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


print("UIManager.client.lua loaded and created base frames.")
