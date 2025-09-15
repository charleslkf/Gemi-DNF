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

local buttonContainer = Instance.new("Frame", screenGui)
buttonContainer.Size = UDim2.new(1, 0, 0, 100)
buttonContainer.Position = UDim2.new(0, 0, 0, 10)
buttonContainer.BackgroundTransparency = 1

local listLayout = Instance.new("UIListLayout", buttonContainer)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Padding = UDim.new(0, 10)

local function createAdminButton(name, text, color, parent)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.TextSize = 18
    button.Size = UDim2.new(0, 150, 0, 40)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.fromRGB(0, 0, 0)
    button.Font = Enum.Font.SourceSansBold
    button.Parent = parent
    return button
end

local topRow = Instance.new("Frame", buttonContainer)
topRow.BackgroundTransparency = 1; topRow.Size = UDim2.new(1, 0, 0, 40)
local topRowLayout = Instance.new("UIListLayout", topRow); topRowLayout.FillDirection = Enum.FillDirection.Horizontal; topRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; topRowLayout.Padding = UDim.new(0, 10)

local bottomRow = Instance.new("Frame", buttonContainer)
bottomRow.BackgroundTransparency = 1; bottomRow.Size = UDim2.new(1, 0, 0, 40)
local bottomRowLayout = Instance.new("UIListLayout", bottomRow); bottomRowLayout.FillDirection = Enum.FillDirection.Horizontal; bottomRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; bottomRowLayout.Padding = UDim.new(0, 10)

local resetButton = createAdminButton("ResetButton", "Soft Reset", Color3.fromRGB(200, 50, 50), topRow)
local startButton = createAdminButton("StartButton", "Manual Start", Color3.fromRGB(50, 200, 50), topRow)
local damageButton = createAdminButton("DamageButton", "Test Damage", Color3.fromRGB(200, 120, 50), topRow)
local cageButton = createAdminButton("CageButton", "Test Cage Me", Color3.fromRGB(100, 100, 100), topRow)
local addHammerButton = createAdminButton("AddHammerButton", "Add Hammer", Color3.fromRGB(150, 150, 200), bottomRow)
local addKeyButton = createAdminButton("AddKeyButton", "Add Key", Color3.fromRGB(200, 200, 150), bottomRow)

-- Event Connections
resetButton.MouseButton1Click:Connect(function() resetRoundEvent:FireServer() end)
startButton.MouseButton1Click:Connect(function() startRoundEvent:FireServer() end)
damageButton.MouseButton1Click:Connect(function() testDamageEvent:FireServer() end)
cageButton.MouseButton1Click:Connect(function() testCageEvent:FireServer() end)
addHammerButton.MouseButton1Click:Connect(function() testAddItemEvent:FireServer("Hammer") end)
addKeyButton.MouseButton1Click:Connect(function() testAddItemEvent:FireServer("Key") end)

-- Visibility Logic
local function updateButtonVisibility()
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
end

-- Update visibility when team changes or character spawns/despawns
player:GetPropertyChangedSignal("Team"):Connect(updateButtonVisibility)
player.CharacterAdded:Connect(function() task.wait(0.1); updateButtonVisibility() end)
player.CharacterRemoving:Connect(function() task.wait(0.1); updateButtonVisibility() end)

-- Initial update
updateButtonVisibility()

print("AdminControls.client.lua loaded.")
