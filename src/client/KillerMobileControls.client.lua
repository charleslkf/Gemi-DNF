-- KillerMobileControls.client.lua
-- This script creates and manages the mobile-specific controls for the Killer.

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Player Globals
local player = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")

-- Only run this script for mobile users
if not UserInputService.TouchEnabled then return end

-- Wait for the player to be on the Killers team
local killersTeam = Teams:WaitForChild("Killers")
if player.Team ~= killersTeam then
    local connection
    connection = player:GetPropertyChangedSignal("Team"):Connect(function()
        if player.Team == killersTeam then
            connection:Disconnect()
            -- Defer the rest of the script to avoid race conditions
            task.wait()
            script:Clone().Parent = script.Parent
            script:Destroy()
        end
    end)
    return
end

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KillerMobileControlsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Create the Attack Button
local attackButton = Instance.new("TextButton")
attackButton.Name = "AttackButton"
attackButton.Text = "X"
attackButton.TextColor3 = Color3.new(1, 1, 1)
attackButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
attackButton.BackgroundTransparency = 0.3
attackButton.BorderSizePixel = 0
attackButton.Size = UDim2.new(0, 80, 0, 80)
attackButton.AnchorPoint = Vector2.new(1, 1)
attackButton.Position = UDim2.new(1, -20, 1, -20)
attackButton.Font = Enum.Font.SourceSansBold
attackButton.TextSize = 40
attackButton.ZIndex = 10
attackButton.Parent = screenGui

-- Create a UICorner to make the button circular
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0.5, 0)
uiCorner.Parent = attackButton

-- Handle the button click
attackButton.MouseButton1Click:Connect(function()
    print("[KillerMobileControls] Attack button clicked. Firing AttackRequest.")
    -- Fire the event without any arguments, letting the server handle hit detection.
    -- This mirrors the most likely behavior of the desktop controls for security.
    AttackRequest:FireServer()
end)

print("KillerMobileControls.client.lua executed for mobile killer.")
