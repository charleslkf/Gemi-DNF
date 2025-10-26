-- KillerMobileControls.client.lua
-- This script creates and manages the mobile-specific controls for the Killer.

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Only run this script for mobile users
if not UserInputService.TouchEnabled then
    print("KillerMobileControls: Not a touch device, script will not run.")
    return
end

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")

-- Variables
local screenGui = nil -- Keep track of the UI
local killersTeam = Teams:WaitForChild("Killers")

-- This function creates the UI. It's called only when we confirm the player is a killer.
local function createKillerUI()
    if screenGui then return end -- Don't create if it already exists

    print("KillerMobileControls: Player is on the Killers team. Creating UI.")

    -- Create the ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KillerMobileControlsGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = playerGui

    -- Create the Attack Button
    local attackButton = Instance.new("TextButton")
    attackButton.Name = "AttackButton"
    attackButton.Text = "X"
    attackButton.TextColor3 = Color3.new(1, 1, 1)
    attackButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
    attackButton.BackgroundTransparency = 0.3
    attackButton.BorderSizePixel = 0
    attackButton.Size = UDim2.new(0, 80, 0, 80)
    -- Corrected Position: Middle-Right
    attackButton.AnchorPoint = Vector2.new(1, 0.5)
    attackButton.Position = UDim2.new(1, -30, 0.5, 0)
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
        AttackRequest:FireServer(nil) -- Explicitly send nil
    end)
end

-- This function destroys the UI if it exists.
local function destroyKillerUI()
    if screenGui then
        print("KillerMobileControls: Player is not on the Killers team. Destroying UI.")
        screenGui:Destroy()
        screenGui = nil
    end
end

-- This function handles team changes.
local function onTeamChanged()
    if player.Team == killersTeam then
        createKillerUI()
    else
        destroyKillerUI()
    end
end

-- Initial check when the script first runs
onTeamChanged()

-- Listen for any subsequent team changes
player:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)

print("KillerMobileControls.client.lua loaded and initialized.")
