--[[
    EscapeUIController.client.lua

    This script is solely responsible for managing the UI effects during
    the escape sequence (the screen crack and the directional arrow).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- Use WaitForChild to ensure all remote events are loaded before continuing
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local EscapeSequenceStarted = Remotes:WaitForChild("EscapeSequenceStarted")

-- Use WaitForChild to ensure the UIManager has created the MainHUD
local screenGui = playerGui:WaitForChild("MainHUD", 10)
if not screenGui then
    print("[EscapeUIController] FATAL: MainHUD not found after 10 seconds. Aborting.")
    return
end

-- Create a container for all the arrow images
local arrows = {
    Up = Instance.new("ImageLabel"),
    Down = Instance.new("ImageLabel"),
    Left = Instance.new("ImageLabel"),
    Right = Instance.new("ImageLabel")
}

local ARROW_ASSETS = {
    Up = "rbxassetid://9852743620",
    Down = "rbxassetid://9852746355",
    Left = "rbxassetid://9852736351",
    Right = "rbxassetid://9852741348"
}

for direction, arrow in pairs(arrows) do
    arrow.Name = "Arrow" .. direction
    arrow.Image = ARROW_ASSETS[direction]
    arrow.Size = UDim2.new(0, 50, 0, 50)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.BackgroundTransparency = 1
    arrow.Visible = false
    arrow.ZIndex = 2
    arrow.Parent = screenGui
end

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522"
screenCrackImage.ImageTransparency = 0.8
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.Visible = false
screenCrackImage.ZIndex = 1 -- Keep crack effect behind the arrow
screenCrackImage.Parent = screenGui

local escapeConnection = nil
local flickerCounter = 0
local activeGates = {}

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
    -- DIAGNOSTIC: Force the UP arrow to be visible in the center of the screen.
    arrows.Up.Visible = true
    arrows.Up.Position = UDim2.new(0.5, 0, 0.5, 0)
end

-- Listen for the dedicated escape event to start the UI
EscapeSequenceStarted.OnClientEvent:Connect(function(gates)
    if player.Team and player.Team.Name == "Survivors" then
        activeGates = gates
        if not escapeConnection then
            escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
        end
    end
end)

-- Listen for general game state changes to know when to stop
GameStateChanged.OnClientEvent:Connect(function(newState)
    if newState.Name ~= "Escape" then
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
            screenCrackImage.Visible = false
            arrowImage.Visible = false
            activeGates = {}
        end
    end
end)

print("EscapeUIController.client.lua loaded.")