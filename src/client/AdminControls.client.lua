--[[
    AdminControls.client.lua
    by Jules

    This script creates the client-side UI for admin/debug controls.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local resetRoundEvent = remotes:WaitForChild("ResetRoundRequest")
local startRoundEvent = remotes:WaitForChild("StartRoundRequest")
local testDamageEvent = remotes:WaitForChild("TestDamageRequest")
local testCageEvent = remotes:WaitForChild("TestCageRequest")
local testAddItemEvent = remotes:WaitForChild("TestAddItemRequest")

-- Create UI
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name = "AdminControlsGui"
screenGui.ResetOnSpawn = false

-- Main container frame for the buttons
local buttonContainer = Instance.new("Frame", screenGui)
buttonContainer.Size = UDim2.new(1, 0, 0, 50) -- Single row height
buttonContainer.Position = UDim2.new(0, 0, 0, 10)
buttonContainer.BackgroundTransparency = 1

local listLayout = Instance.new("UIListLayout", buttonContainer)
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Padding = UDim.new(0, 10)

-- Helper function to create a standard button
local function createAdminButton(name, text, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.TextSize = 18
    button.Size = UDim2.new(0, 150, 0, 40)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.fromRGB(0, 0, 0)
    button.Font = Enum.Font.SourceSansBold
    button.Parent = buttonContainer
    return button
end

-- Create Buttons
local resetButton = createAdminButton("ResetButton", "Soft Reset", Color3.fromRGB(200, 50, 50))
local startButton = createAdminButton("StartButton", "Manual Start", Color3.fromRGB(50, 200, 50))
local damageButton = createAdminButton("DamageButton", "Test Damage", Color3.fromRGB(200, 120, 50))
local cageButton = createAdminButton("CageButton", "Test Cage Me", Color3.fromRGB(100, 100, 100))
local addHammerButton = createAdminButton("AddHammerButton", "Add Hammer", Color3.fromRGB(150, 150, 200))
local addKeyButton = createAdminButton("AddKeyButton", "Add Key", Color3.fromRGB(200, 200, 150))

-- Event Connections
resetButton.MouseButton1Click:Connect(function() resetRoundEvent:FireServer() end)
startButton.MouseButton1Click:Connect(function() startRoundEvent:FireServer() end)
damageButton.MouseButton1Click:Connect(function() testDamageEvent:FireServer() end)
cageButton.MouseButton1Click:Connect(function() testCageEvent:FireServer() end)
addHammerButton.MouseButton1Click:Connect(function() testAddItemEvent:FireServer("Hammer") end)
addKeyButton.MouseButton1Click:Connect(function() testAddItemEvent:FireServer("Key") end)

-- Logic to show/hide buttons based on state (proxied by player altitude)
RunService.RenderStepped:Connect(function()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local isInLobby = character.HumanoidRootPart.Position.Y > 40

        resetButton.Visible = true

        if isInLobby then
            startButton.Visible = true
            damageButton.Visible = false
            cageButton.Visible = false
            addHammerButton.Visible = false
            addKeyButton.Visible = false
        else
            startButton.Visible = false
            damageButton.Visible = true
            cageButton.Visible = true
            addHammerButton.Visible = true
            addKeyButton.Visible = true
        end
    else
        resetButton.Visible = false
        startButton.Visible = false
        damageButton.Visible = false
        cageButton.Visible = false
        addHammerButton.Visible = false
        addKeyButton.Visible = false
    end
end)

print("AdminControls.client.lua loaded.")
