--[[
    AdminControls.client.lua
    by Jules (v3 - Simplified Rewrite)

    This script creates the client-side UI for admin/debug controls.
    This version uses a radically simplified layout and logic model to ensure stability.
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

--== Create Buttons Manually ==--

-- Reset Button
local resetButton = Instance.new("TextButton", screenGui)
resetButton.Name = "ResetButton"
resetButton.Text = "Soft Reset"
resetButton.TextSize = 18
resetButton.Size = UDim2.new(0, 120, 0, 40)
resetButton.Position = UDim2.new(0.5, -305, 0, 10)
resetButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
resetButton.TextColor3 = Color3.fromRGB(0, 0, 0)
resetButton.Font = Enum.Font.SourceSansBold

-- Start Button
local startButton = Instance.new("TextButton", screenGui)
startButton.Name = "StartButton"
startButton.Text = "Manual Start"
startButton.TextSize = 18
startButton.Size = UDim2.new(0, 120, 0, 40)
startButton.Position = UDim2.new(0.5, -180, 0, 10)
startButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
startButton.TextColor3 = Color3.fromRGB(0, 0, 0)
startButton.Font = Enum.Font.SourceSansBold

-- Damage Button
local damageButton = Instance.new("TextButton", screenGui)
damageButton.Name = "DamageButton"
damageButton.Text = "Test Damage"
damageButton.TextSize = 18
damageButton.Size = UDim2.new(0, 120, 0, 40)
damageButton.Position = UDim2.new(0.5, -55, 0, 10)
damageButton.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
damageButton.TextColor3 = Color3.fromRGB(0, 0, 0)
damageButton.Font = Enum.Font.SourceSansBold

-- Cage Button
local cageButton = Instance.new("TextButton", screenGui)
cageButton.Name = "CageButton"
cageButton.Text = "Test Cage Me"
cageButton.TextSize = 18
cageButton.Size = UDim2.new(0, 120, 0, 40)
cageButton.Position = UDim2.new(0.5, 70, 0, 10)
cageButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
cageButton.TextColor3 = Color3.fromRGB(0, 0, 0)
cageButton.Font = Enum.Font.SourceSansBold

-- Add Hammer Button
local addHammerButton = Instance.new("TextButton", screenGui)
addHammerButton.Name = "AddHammerButton"
addHammerButton.Text = "Add Hammer"
addHammerButton.TextSize = 18
addHammerButton.Size = UDim2.new(0, 120, 0, 40)
addHammerButton.Position = UDim2.new(0.5, 195, 0, 10)
addHammerButton.BackgroundColor3 = Color3.fromRGB(150, 150, 200)
addHammerButton.TextColor3 = Color3.fromRGB(0, 0, 0)
addHammerButton.Font = Enum.Font.SourceSansBold

-- Add Key Button
local addKeyButton = Instance.new("TextButton", screenGui)
addKeyButton.Name = "AddKeyButton"
addKeyButton.Text = "Add Key"
addKeyButton.TextSize = 18
addKeyButton.Size = UDim2.new(0, 120, 0, 40)
addKeyButton.Position = UDim2.new(0.5, 320, 0, 10)
addKeyButton.BackgroundColor3 = Color3.fromRGB(200, 200, 150)
addKeyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
addKeyButton.Font = Enum.Font.SourceSansBold

--== Event Connections ==--
resetButton.MouseButton1Click:Connect(function() resetRoundEvent:FireServer() end)
startButton.MouseButton1Click:Connect(function() startRoundEvent:FireServer() end)
damageButton.MouseButton1Click:Connect(function() testDamageEvent:FireServer() end)
cageButton.MouseButton1Click:Connect(function() testCageEvent:FireServer() end)
addHammerButton.MouseButton1Click:Connect(function()
    print("[DEBUG] AddHammerButton clicked!")
    print("[DEBUG] Firing AddItem event to server for Hammer...")
    testAddItemEvent:FireServer("Hammer")
end)
addKeyButton.MouseButton1Click:Connect(function() testAddItemEvent:FireServer("Key") end)

--== Visibility Logic ==--
RunService.RenderStepped:Connect(function()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local isInLobby = character.HumanoidRootPart.Position.Y > 40
        local isSurvivor = player.Team and player.Team.Name == "Survivors"

        resetButton.Visible = true
        startButton.Visible = isInLobby

        local inRound = not isInLobby
        damageButton.Visible = inRound
        cageButton.Visible = inRound
        addHammerButton.Visible = inRound and isSurvivor
        addKeyButton.Visible = inRound and isSurvivor
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
