--[[
    AdminControls.client.lua
    by Jules

    This script creates the client-side UI for admin/debug controls,
    such as the soft reset, manual start, and test damage buttons.
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

-- Create UI
local screenGui = Instance.new("ScreenGui", playerGui)
screenGui.Name = "AdminControlsGui"
screenGui.ResetOnSpawn = false

-- Reset Button
local resetButton = Instance.new("TextButton", screenGui)
resetButton.Name = "ResetButton"
resetButton.Text = "Soft Reset Round"
resetButton.TextSize = 18
resetButton.Size = UDim2.new(0, 150, 0, 40)
resetButton.Position = UDim2.new(0.5, -75, 0, 10)
resetButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
resetButton.TextColor3 = Color3.fromRGB(0, 0, 0)
resetButton.Font = Enum.Font.SourceSansBold

-- Start Button
local startButton = Instance.new("TextButton", screenGui)
startButton.Name = "StartButton"
startButton.Text = "Manual Start"
startButton.TextSize = 18
startButton.Size = UDim2.new(0, 150, 0, 40)
startButton.Position = UDim2.new(0.5, -75, 0, 60)
startButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
startButton.TextColor3 = Color3.fromRGB(0, 0, 0)
startButton.Font = Enum.Font.SourceSansBold
startButton.Visible = false -- Hidden by default

-- Damage Button
local damageButton = Instance.new("TextButton", screenGui)
damageButton.Name = "DamageButton"
damageButton.Text = "Test Damage (-10 HP)"
damageButton.TextSize = 18
damageButton.Size = UDim2.new(0, 150, 0, 40)
damageButton.Position = UDim2.new(0.5, -75, 0, 110)
damageButton.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
damageButton.TextColor3 = Color3.fromRGB(0, 0, 0)
damageButton.Font = Enum.Font.SourceSansBold
damageButton.Visible = false -- Hidden by default

-- Event Connections
resetButton.MouseButton1Click:Connect(function()
    print("Client: Firing ResetRoundRequest.")
    resetRoundEvent:FireServer()
end)

startButton.MouseButton1Click:Connect(function()
    print("Client: Firing StartRoundRequest.")
    startRoundEvent:FireServer()
end)

damageButton.MouseButton1Click:Connect(function()
    print("Client: Firing TestDamageRequest.")
    testDamageEvent:FireServer()
end)

-- Logic to show/hide buttons based on state (proxied by player altitude)
RunService.RenderStepped:Connect(function()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local isInLobby = character.HumanoidRootPart.Position.Y > 40

        if isInLobby then
            startButton.Visible = true
            damageButton.Visible = false
        else
            startButton.Visible = false
            damageButton.Visible = true
        end
    else
        startButton.Visible = false
        damageButton.Visible = false
    end
end)

print("AdminControls.client.lua loaded.")
